import asyncio
import json
from datetime import datetime
from typing import Dict, Optional, Set

from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException, Query, WebSocket, WebSocketDisconnect, status
from pydantic import BaseModel

from core.database import messages_collection, users_block_collection, users_collection
from core.schemas import MessageResponse
from core.security import get_current_user, get_current_user_ws

router = APIRouter(tags=["Chat"])

# ─── Connection managers ─────────────────────────────────
# email → set of WebSocket connections
active_chat_connections: Dict[str, Set[WebSocket]] = {}
active_notification_connections: Dict[str, Set[WebSocket]] = {}


# ═══════════════════════════════════════════════════════════
#  WebSocket — Chat
# ═══════════════════════════════════════════════════════════

@router.websocket("/ws/chat/{user_email}")
async def chat_ws(
    websocket: WebSocket,
    user_email: str,
    token: str = Query(...),
):
    # ── Auth ──────────────────────────────────────────────
    try:
        current_user = await get_current_user_ws(token)
    except HTTPException:
        await websocket.close(code=1008, reason="Authentication failed")
        return

    if current_user["email"] != user_email:
        await websocket.close(code=1008, reason="Email mismatch")
        return

    await websocket.accept()
    active_chat_connections.setdefault(user_email, set()).add(websocket)

    try:
        while True:
            raw = await websocket.receive_text()
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                await websocket.send_text(json.dumps({"error": "Invalid JSON"}))
                continue

            if msg.get("type") == "chat_message":
                await _handle_chat_message(msg, current_user)
            else:
                await websocket.send_text(json.dumps({"error": "Unknown message type"}))

    except WebSocketDisconnect:
        pass
    finally:
        active_chat_connections.get(user_email, set()).discard(websocket)


async def _handle_chat_message(msg: dict, sender: dict):
    recipient_email = msg.get("recipient_email")
    message_text = msg.get("message", "").strip()

    if not recipient_email or not message_text:
        return

    # Check if sender is blocked by recipient
    if users_block_collection.find_one(
        {"blocker_email": recipient_email, "blocked_email": sender["email"]}
    ):
        return  # silently drop blocked messages

    message_doc = {
        "_id": str(ObjectId()),
        "sender_email": sender["email"],
        "sender_username": sender.get("username", ""),
        "recipient_email": recipient_email,
        "message": message_text,
        "timestamp": datetime.utcnow().isoformat(),
        "read": False,
    }
    messages_collection.insert_one(message_doc)

    payload = json.dumps(message_doc)

    # Deliver to recipient (all open tabs)
    for conn in list(active_chat_connections.get(recipient_email, [])):
        try:
            await conn.send_text(payload)
        except Exception:
            pass

    # Echo back to sender (all open tabs)
    for conn in list(active_chat_connections.get(sender["email"], [])):
        try:
            await conn.send_text(payload)
        except Exception:
            pass

    # Update unread notification count for recipient
    await _push_unread_count(recipient_email)


# ═══════════════════════════════════════════════════════════
#  WebSocket — Notifications
# ═══════════════════════════════════════════════════════════

@router.websocket("/ws/notifications/{user_email}")
async def notifications_ws(
    websocket: WebSocket,
    user_email: str,
    token: str = Query(...),
):
    try:
        current_user = await get_current_user_ws(token)
    except HTTPException:
        await websocket.close(code=1008, reason="Authentication failed")
        return

    if current_user["email"] != user_email:
        await websocket.close(code=1008, reason="Email mismatch")
        return

    await websocket.accept()
    active_notification_connections.setdefault(user_email, set()).add(websocket)

    # Send current unread count immediately on connect
    await _push_unread_count(user_email)

    try:
        # Keep alive with periodic ping
        while True:
            await asyncio.sleep(30)
            try:
                await websocket.send_text(json.dumps({"type": "ping"}))
            except Exception:
                break
    except WebSocketDisconnect:
        pass
    finally:
        active_notification_connections.get(user_email, set()).discard(websocket)


async def _push_unread_count(user_email: str):
    count = messages_collection.count_documents(
        {"recipient_email": user_email, "read": False}
    )
    payload = json.dumps({"type": "unread_count", "count": count})
    for conn in list(active_notification_connections.get(user_email, [])):
        try:
            await conn.send_text(payload)
        except Exception:
            pass


# ═══════════════════════════════════════════════════════════
#  REST endpoints
# ═══════════════════════════════════════════════════════════

@router.get("/messages/{sender_email}/{recipient_email}")
async def get_messages(
    sender_email: str,
    recipient_email: str,
    current_user: dict = Depends(get_current_user),
):
    if current_user["email"] not in (sender_email, recipient_email):
        raise HTTPException(status_code=403, detail="Not authorized")

    docs = list(
        messages_collection.find({
            "sender_email": {"$in": [sender_email, recipient_email]},
            "recipient_email": {"$in": [sender_email, recipient_email]},
        }).sort("timestamp", 1)
    )
    return docs


@router.get("/conversations/{user_email}")
async def get_conversations(
    user_email: str,
    current_user: dict = Depends(get_current_user),
):
    if current_user["email"] != user_email:
        raise HTTPException(status_code=403, detail="Not authorized")

    # جلب آخر رسالة لكل محادثة
    pipeline = [
        {
            "$match": {
                "$or": [
                    {"sender_email": user_email},
                    {"recipient_email": user_email},
                ]
            }
        },
        {"$sort": {"timestamp": -1}},
        {
            "$group": {
                "_id": {
                    "$cond": [
                        {"$eq": ["$sender_email", user_email]},
                        "$recipient_email",
                        "$sender_email",
                    ]
                },
                "last_message": {"$first": "$message"},
                "timestamp": {"$first": "$timestamp"},
                "message_id": {"$first": "$_id"},
            }
        },
        {"$sort": {"timestamp": -1}},
    ]

    results = list(messages_collection.aggregate(pipeline))
    conversations = []

    for r in results:
        other_email = r["_id"]
        other_user = users_collection.find_one({"email": other_email}) or {}
        unread = messages_collection.count_documents({
            "sender_email": other_email,
            "recipient_email": user_email,
            "read": False,
        })
        conversations.append({
            "other_email": other_email,
            "other_username": other_user.get("username", "Unknown"),
            "other_user_image_url": other_user.get("image_url"),   # URL بدل base64
            "last_message": r["last_message"],
            "timestamp": r["timestamp"],
            "unread_count": unread,
        })

    return conversations


@router.put("/messages/{message_id}/read", response_model=MessageResponse)
async def mark_as_read(
    message_id: str,
    current_user: dict = Depends(get_current_user),
):
    result = messages_collection.update_one(
        {"_id": message_id, "recipient_email": current_user["email"]},
        {"$set": {"read": True}},
    )
    if result.modified_count == 0:
        raise HTTPException(status_code=404, detail="Message not found")

    await _push_unread_count(current_user["email"])
    return {"message": "Message marked as read"}


# ─── Block system ────────────────────────────────────────

@router.post("/toggle-block/{target_email}", response_model=dict)
async def toggle_block(
    target_email: str,
    current_user: dict = Depends(get_current_user),
):
    blocker = current_user["email"]
    existing = users_block_collection.find_one(
        {"blocker_email": blocker, "blocked_email": target_email}
    )
    if existing:
        users_block_collection.delete_one({"_id": existing["_id"]})
        return {"blocked": False}
    users_block_collection.insert_one(
        {"blocker_email": blocker, "blocked_email": target_email}
    )
    return {"blocked": True}


@router.get("/block-status/{target_email}", response_model=dict)
async def block_status(
    target_email: str,
    current_user: dict = Depends(get_current_user),
):
    exists = users_block_collection.find_one(
        {"blocker_email": current_user["email"], "blocked_email": target_email}
    )
    return {"blocked": exists is not None}
