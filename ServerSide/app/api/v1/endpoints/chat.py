"""
app/api/v1/endpoints/chat.py
─────────────────────────────
إصلاح المشاكل الجذرية:

1. asyncio.wait_for timeout يُغلق الاتصال إذا لم تصل رسالة خلال 120 ثانية
   الحل: حذف الـ timeout من receive_text تماماً — WebSocket ينتظر بلا حدود

2. عند قبول الاتصال لا يوجد confirmation → Flutter يبقى على "Connecting..."
   الحل: نُرسل {"type": "connected"} فور قبول الاتصال

3. ping/pong: نستجيب بـ pong لكل ping يصل
"""
import asyncio
import json
import logging
from datetime import datetime, timezone
from typing import Dict, Set

logger = logging.getLogger(__name__)

from bson import ObjectId
from fastapi import (APIRouter, Depends, HTTPException,
                     Query, WebSocket, WebSocketDisconnect)

from app.api.dependencies import get_current_user, get_current_user_ws
from app.db import (blocks_collection, messages_collection,
                    pending_notifications_collection, users_collection)
from app.schemas.common import MessageResponse

router = APIRouter(tags=["Chat"])

# ─── Connection registries ────────────────────────────────
active_chat_connections:         Dict[str, Set[WebSocket]] = {}
active_notification_connections: Dict[str, Set[WebSocket]] = {}
# email → True إذا متصل الآن
online_users: Dict[str, bool] = {}


# ─── Notification helpers ─────────────────────────────────

# Notification types that are ephemeral (chat messages handled separately)
# and should NOT be persisted to the pending queue.
_EPHEMERAL_TYPES = {"unread_count", "ping", "pong", "connected"}


async def push_notification(email: str, event: dict) -> None:
    """
    يُرسل حدث إشعار لكل connections المستخدم.
    إذا لم يكن المستخدم متصلاً، يُخزَّن الحدث في pending_notifications
    ويُرسَل فور اتصاله.
    """
    connections = list(active_notification_connections.get(email, set()))
    payload = json.dumps(event, ensure_ascii=False)
    delivered = False

    for ws in connections:
        try:
            await ws.send_text(payload)
            delivered = True
        except Exception as e:
            logger.warning("push_notification failed for %s (event=%s): %s",
                           email, event.get("type", "?"), e)
            active_notification_connections.get(email, set()).discard(ws)

    # إذا لم يصل لأي connection — خزّنه للإرسال عند الاتصال التالي
    event_type = event.get("type", "")
    if not delivered and event_type not in _EPHEMERAL_TYPES:
        try:
            pending_notifications_collection.insert_one({
                "recipient_email": email,
                "event":           event,
                "created_at":      datetime.now(timezone.utc),
            })
        except Exception as e:
            logger.warning("Failed to persist notification for %s: %s", email, e)


async def _flush_pending_notifications(email: str, ws: WebSocket) -> None:
    """يُرسل الإشعارات المخزّنة للمستخدم فور اتصاله ويحذفها."""
    pending = list(pending_notifications_collection.find(
        {"recipient_email": email}
    ).sort("created_at", 1))

    if not pending:
        return

    ids_to_delete = []
    for doc in pending:
        try:
            await ws.send_text(json.dumps(doc["event"], ensure_ascii=False))
            ids_to_delete.append(doc["_id"])
        except Exception:
            break  # connection dropped — stop flushing, leave remaining in DB

    if ids_to_delete:
        pending_notifications_collection.delete_many({"_id": {"$in": ids_to_delete}})


async def _push_unread_count(email: str) -> None:
    count = messages_collection.count_documents(
        {"recipient_email": email, "read": False}
    )
    await push_notification(email, {"type": "unread_count", "count": count})


# ═══════════════════════════════════════════════════════════
#  WebSocket — Chat
# ═══════════════════════════════════════════════════════════

@router.websocket("/ws/chat/{user_email}")
async def chat_ws(
    websocket:  WebSocket,
    user_email: str,
    token:      str = Query(...),
):
    # ── Auth ──────────────────────────────────────────────
    try:
        current_user = await get_current_user_ws(token)
    except HTTPException:
        await websocket.close(code=1008, reason="Auth failed")
        return

    if current_user["email"] != user_email:
        await websocket.close(code=1008, reason="Email mismatch")
        return

    # ── Accept + Confirm ──────────────────────────────────
    await websocket.accept()

    # أرسل confirmation فوراً → Flutter يعرف أن الاتصال نجح
    try:
        await websocket.send_text(json.dumps({"type": "connected", "email": user_email}))
    except Exception:
        return

    active_chat_connections.setdefault(user_email, set()).add(websocket)
    online_users[user_email] = True

    # ── Message loop ──────────────────────────────────────
    try:
        while True:
            # لا يوجد timeout — ننتظر حتى يصل شيء أو ينقطع الاتصال
            raw = await websocket.receive_text()

            try:
                msg = json.loads(raw)
            except (json.JSONDecodeError, ValueError):
                continue

            msg_type = msg.get("type", "")

            if msg_type == "ping":
                # استجب بـ pong فوراً
                try:
                    await websocket.send_text(json.dumps({"type": "pong"}))
                except Exception:
                    break

            elif msg_type == "chat_message":
                await _handle_message(msg, current_user, websocket)

    except WebSocketDisconnect:
        pass
    except Exception:
        pass
    finally:
        active_chat_connections.get(user_email, set()).discard(websocket)
        # offline إذا لا توجد connections متبقية
        if not active_chat_connections.get(user_email):
            online_users[user_email] = False


async def _handle_message(msg: dict, sender: dict, sender_ws: WebSocket) -> None:
    recipient_email = msg.get("recipient_email", "").strip()
    text            = (msg.get("message") or msg.get("text") or "").strip()

    if not recipient_email or not text:
        return

    # فحص الحظر
    if blocks_collection.find_one(
        {"blocker_email": recipient_email, "blocked_email": sender["email"]}
    ):
        return

    # حفظ الرسالة
    msg_id = str(ObjectId())
    doc = {
        "_id":             msg_id,
        "sender_email":    sender["email"],
        "sender_username": sender.get("username", ""),
        "recipient_email": recipient_email,
        "message":         text,
        "timestamp":       datetime.now(timezone.utc).isoformat(),
        "read":            False,
    }
    messages_collection.insert_one(doc)

    payload = json.dumps(doc, ensure_ascii=False)

    # إرسال للمستلم فقط — المرسل يعرض الرسالة Optimistically في Flutter
    for conn in list(active_chat_connections.get(recipient_email, set())):
        try:
            await conn.send_text(payload)
        except Exception:
            active_chat_connections.get(recipient_email, set()).discard(conn)

    # Echo للمرسل على أجهزته الأخرى فقط (ليس نفس الـ connection الذي أرسل)
    for conn in list(active_chat_connections.get(sender["email"], set())):
        if conn is sender_ws:
            continue
        try:
            await conn.send_text(payload)
        except Exception:
            active_chat_connections.get(sender["email"], set()).discard(conn)

    # تحديث unread للمستلم
    await _push_unread_count(recipient_email)

    # إشعار للمستلم
    await push_notification(recipient_email, {
        "type":            "new_message",
        "sender_username": sender.get("username", ""),
        "sender_email":    sender["email"],
        "message":         text[:120],
    })


# ═══════════════════════════════════════════════════════════
#  WebSocket — Notifications
# ═══════════════════════════════════════════════════════════

@router.websocket("/ws/notifications/{user_email}")
async def notifications_ws(
    websocket:  WebSocket,
    user_email: str,
    token:      str = Query(...),
):
    try:
        current_user = await get_current_user_ws(token)
    except HTTPException:
        await websocket.close(code=1008, reason="Auth failed")
        return

    if current_user["email"] != user_email:
        await websocket.close(code=1008, reason="Email mismatch")
        return

    await websocket.accept()
    active_notification_connections.setdefault(user_email, set()).add(websocket)

    # أرسل unread count فور الاتصال
    await _push_unread_count(user_email)

    # إرسال الإشعارات المخزّنة أثناء غياب المستخدم
    await _flush_pending_notifications(user_email, websocket)

    try:
        while True:
            # استمع لـ ping من الـ client
            try:
                raw = await asyncio.wait_for(
                    websocket.receive_text(), timeout=40
                )
                data = json.loads(raw)
                if data.get("type") == "ping":
                    await websocket.send_text(json.dumps({"type": "pong"}))
            except asyncio.TimeoutError:
                # أرسل ping من Server لإبقاء الاتصال حياً
                try:
                    await websocket.send_text(json.dumps({"type": "ping"}))
                except Exception:
                    break
            except json.JSONDecodeError:
                pass

    except WebSocketDisconnect:
        pass
    except Exception:
        pass
    finally:
        active_notification_connections.get(user_email, set()).discard(websocket)


# ═══════════════════════════════════════════════════════════
#  REST endpoints
# ═══════════════════════════════════════════════════════════

@router.get("/messages/{sender_email}/{recipient_email}")
async def get_messages(
    sender_email:    str,
    recipient_email: str,
    limit:           int = 80,
    current_user:    dict = Depends(get_current_user),
):
    if current_user["email"] not in (sender_email, recipient_email):
        raise HTTPException(status_code=403, detail="Not authorized")

    safe_limit = min(max(limit, 1), 200)

    docs = list(
        messages_collection.find({
            "$or": [
                {"sender_email": sender_email, "recipient_email": recipient_email},
                {"sender_email": recipient_email, "recipient_email": sender_email},
            ]
        })
        .sort("timestamp", 1)
        .limit(safe_limit)
    )
    # إزالة ObjectId من الـ _id إذا كان غير string
    for d in docs:
        if not isinstance(d.get("_id"), str):
            d["_id"] = str(d["_id"])
    return docs


@router.get("/conversations/{user_email}")
async def get_conversations(
    user_email:   str,
    limit:        int = Query(50, ge=1, le=100),
    skip:         int = Query(0,  ge=0),
    current_user: dict = Depends(get_current_user),
):
    if current_user["email"] != user_email:
        raise HTTPException(status_code=403, detail="Not authorized")

    pipeline = [
        {"$match": {"$or": [
            {"sender_email": user_email},
            {"recipient_email": user_email},
        ]}},
        {"$sort": {"timestamp": -1}},
        {"$group": {
            "_id": {"$cond": [
                {"$eq": ["$sender_email", user_email]},
                "$recipient_email",
                "$sender_email",
            ]},
            "last_message": {"$first": "$message"},
            "timestamp":    {"$first": "$timestamp"},
        }},
        {"$sort": {"timestamp": -1}},
        {"$skip":  skip},
        {"$limit": limit},
    ]

    results = list(messages_collection.aggregate(pipeline))
    conversations = []
    for r in results:
        other_email = r["_id"]
        other = users_collection.find_one(
            {"email": other_email},
            {"username": 1, "image_url": 1},   # project only needed fields
        ) or {}
        unread = messages_collection.count_documents({
            "sender_email":    other_email,
            "recipient_email": user_email,
            "read":            False,
        })
        conversations.append({
            "other_email":          other_email,
            "other_username":       other.get("username", "Unknown"),
            "other_user_image_url": other.get("image_url"),
            "last_message":         r["last_message"],
            "timestamp":            r["timestamp"],
            "unread_count":         unread,
        })
    return conversations


@router.put("/messages/{message_id}/read", response_model=MessageResponse)
async def mark_read(message_id: str, current_user: dict = Depends(get_current_user)):
    messages_collection.update_one(
        {"_id": message_id, "recipient_email": current_user["email"]},
        {"$set": {"read": True}},
    )
    await _push_unread_count(current_user["email"])
    return {"message": "Marked as read"}


@router.get("/presence/{user_email}", response_model=dict)
async def get_presence(
    user_email:   str,
    current_user: dict = Depends(get_current_user),
):
    """هل المستخدم متصل الآن؟"""
    is_online = online_users.get(user_email, False)
    # تحقق حقيقي: هل يوجد chat connection نشط
    has_connection = bool(active_chat_connections.get(user_email))
    return {"online": is_online and has_connection, "email": user_email}


@router.post("/toggle-block/{target_email}", response_model=dict)
async def toggle_block(target_email: str, current_user: dict = Depends(get_current_user)):
    blocker = current_user["email"]
    existing = blocks_collection.find_one(
        {"blocker_email": blocker, "blocked_email": target_email}
    )
    if existing:
        blocks_collection.delete_one({"_id": existing["_id"]})
        return {"blocked": False}
    blocks_collection.insert_one({"blocker_email": blocker, "blocked_email": target_email})
    return {"blocked": True}


@router.get("/block-status/{target_email}", response_model=dict)
async def block_status(target_email: str, current_user: dict = Depends(get_current_user)):
    exists = blocks_collection.find_one(
        {"blocker_email": current_user["email"], "blocked_email": target_email}
    )
    return {"blocked": exists is not None}
