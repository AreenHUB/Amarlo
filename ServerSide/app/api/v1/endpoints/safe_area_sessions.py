"""
app/api/v1/endpoints/safe_area_sessions.py
───────────────────────────────────────────
Safe Area Session — عقد رقمي بين Worker وUser

POST /safe-area-sessions                  — Worker ينشئ جلسة ويدعو User
GET  /safe-area-sessions/my               — كل جلساتي
GET  /safe-area-sessions/{id}             — تفاصيل جلسة
PUT  /safe-area-sessions/{id}/accept      — User يقبل (خلال 6 ساعات)
PUT  /safe-area-sessions/{id}/reject      — User يرفض
PUT  /safe-area-sessions/{id}/complete    — تأكيد إتمام الجلسة (يُستدعى تلقائياً)

Contract ref format: SA-YYYY-XXXXX
"""
import logging
import random
import string
from datetime import datetime, timedelta, timezone
from typing import Optional

logger = logging.getLogger(__name__)

from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.api.dependencies import get_current_user
from app.db import requests_collection, safe_area_sessions_collection, users_collection
from app.schemas.common import MessageResponse

router = APIRouter(prefix="/safe-area-sessions", tags=["Safe Area Sessions"])

SESSION_INVITATION_HOURS = 6  # صلاحية الدعوة


# ─── Contract ref generator ───────────────────────────────
def _generate_contract_ref() -> str:
    year = datetime.now(timezone.utc).year
    suffix = ''.join(random.choices(string.ascii_uppercase + string.digits, k=5))
    ref = f"SA-{year}-{suffix}"
    # تأكد من عدم التكرار
    while safe_area_sessions_collection.find_one({"contract_ref": ref}):
        suffix = ''.join(random.choices(string.ascii_uppercase + string.digits, k=5))
        ref = f"SA-{year}-{suffix}"
    return ref


def _serialize(doc: dict) -> dict:
    d = dict(doc)
    d["id"] = str(d.pop("_id"))
    for field in ["created_at", "invitation_expires_at", "accepted_at"]:
        if isinstance(d.get(field), datetime):
            d[field] = d[field].isoformat()
    return d


def _session_or_404(session_id: str) -> dict:
    try:
        doc = safe_area_sessions_collection.find_one({"_id": ObjectId(session_id)})
    except Exception:
        doc = safe_area_sessions_collection.find_one({"_id": session_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Session not found")
    return doc


# ─── Schemas ────────────────────────────────────────────────
class SessionCreate(BaseModel):
    participant_email: str          # الـ User الذي سيُدعى
    title:             str          # عنوان العمل
    description:       str          # وصف تفصيلي للعمل المطلوب
    deliverables:      str          # ما سيُسلَّم بالضبط
    price:             float        # المبلغ المتفق عليه
    deadline:          str          # ISO 8601 — تاريخ التسليم
    delivery_type:     str = "online"  # "online" | "in_person"
    post_ref:          Optional[str] = None   # إذا جاء من بوست
    offer_ref:         Optional[str] = None   # إذا جاء من offer


# ─── Endpoints ────────────────────────────────────────────────

@router.post("", status_code=201, summary="Worker ينشئ جلسة")
async def create_session(
    body: SessionCreate,
    current_user: dict = Depends(get_current_user),
):
    if current_user.get("userType") != "Worker":
        raise HTTPException(status_code=403, detail="Only Workers can create sessions")

    # تحقق أن الـ participant موجود
    participant = users_collection.find_one({"email": body.participant_email})
    if not participant:
        raise HTTPException(status_code=404, detail="Participant not found")

    try:
        deadline_dt = datetime.fromisoformat(body.deadline)
        if deadline_dt.tzinfo is None:
            deadline_dt = deadline_dt.replace(tzinfo=timezone.utc)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid deadline (ISO 8601 required)")

    now = datetime.now(timezone.utc)
    if deadline_dt <= now:
        raise HTTPException(status_code=400, detail="Deadline must be in the future")
    if deadline_dt > now + timedelta(days=365):
        raise HTTPException(status_code=400, detail="Deadline cannot be more than 1 year away")
    doc = {
        "contract_ref":       _generate_contract_ref(),
        "initiator_email":    current_user["email"],
        "initiator_username": current_user.get("username", ""),
        "participant_email":  body.participant_email,
        "participant_username": participant.get("username", ""),
        "title":              body.title,
        "description":        body.description,
        "deliverables":       body.deliverables,
        "price":              body.price,
        "deadline":           deadline_dt,
        "delivery_type":      body.delivery_type,
        "post_ref":           body.post_ref,
        "offer_ref":          body.offer_ref,
        "status":             "pending_acceptance",
        "invitation_expires_at": now + timedelta(hours=SESSION_INVITATION_HOURS),
        "created_at":         now,
        "accepted_at":        None,
        "worker_confirmed":   False,
        "user_confirmed":     False,
    }
    result = safe_area_sessions_collection.insert_one(doc)
    doc["_id"] = result.inserted_id

    # إشعار الـ participant
    try:
        from app.api.v1.endpoints.chat import push_notification
        await push_notification(body.participant_email, {
            "type":           "safe_area_session_invite",
            "session_id":     str(result.inserted_id),
            "contract_ref":   doc["contract_ref"],
            "worker_name":    current_user.get("username", ""),
            "title":          body.title,
            "price":          body.price,
            "expires_in_hrs": SESSION_INVITATION_HOURS,
        })
    except Exception as e:
        logger.warning("Failed to notify %s of session invite: %s", body.participant_email, e)

    return _serialize(doc)


@router.get("/my", summary="كل جلساتي")
async def my_sessions(current_user: dict = Depends(get_current_user)):
    email = current_user["email"]
    docs = list(safe_area_sessions_collection.find({
        "$or": [
            {"initiator_email":   email},
            {"participant_email": email},
        ]
    }).sort("created_at", -1).limit(50))
    return [_serialize(d) for d in docs]


@router.get("/{session_id}", summary="تفاصيل جلسة")
async def get_session(
    session_id: str,
    current_user: dict = Depends(get_current_user),
):
    doc = _session_or_404(session_id)
    email = current_user["email"]
    if email not in (doc["initiator_email"], doc["participant_email"]):
        raise HTTPException(status_code=403, detail="Not authorized")
    return _serialize(doc)


@router.put("/{session_id}/accept", response_model=MessageResponse, summary="User يقبل الدعوة")
async def accept_session(
    session_id: str,
    current_user: dict = Depends(get_current_user),
):
    doc = _session_or_404(session_id)

    if current_user["email"] != doc["participant_email"]:
        raise HTTPException(status_code=403, detail="Only the invited user can accept")
    if doc["status"] != "pending_acceptance":
        raise HTTPException(status_code=400, detail="Session is not pending acceptance")

    # تحقق من الصلاحية
    expires = doc.get("invitation_expires_at")
    if expires and datetime.now(timezone.utc) > expires:
        safe_area_sessions_collection.update_one(
            {"_id": doc["_id"]}, {"$set": {"status": "expired"}}
        )
        raise HTTPException(status_code=410, detail="Invitation has expired")

    now = datetime.now(timezone.utc)
    safe_area_sessions_collection.update_one(
        {"_id": doc["_id"]},
        {"$set": {"status": "active", "accepted_at": now}},
    )

    # إنشاء service_request حتى تعمل Safe Area upload/confirm endpoints
    existing_req = requests_collection.find_one({
        "session_id":   session_id,
        "status":       {"$nin": ["completed", "rejected"]},
    })
    request_id = None
    if not existing_req:
        req_doc = {
            "session_id":        session_id,
            "contract_ref":      doc["contract_ref"],
            "service_id":        session_id,          # الـ session هي المرجع
            "service_name":      doc["title"],
            "user_email":        doc["participant_email"],
            "user_name":         doc.get("participant_username", ""),
            "worker_email":      doc["initiator_email"],
            "worker_username":   doc.get("initiator_username", ""),
            "agreed_price":      doc.get("price", 0),
            "service_price":     doc.get("price", 0),
            "delivery_type":     doc.get("delivery_type", "online"),
            "safe_area_enabled": True,
            "safe_area_active":  True,
            "status":            "accepted",
            "deadline":          doc.get("deadline"),
            "created_at":        now,
        }
        result = requests_collection.insert_one(req_doc)
        request_id = str(result.inserted_id)
        # حفظ request_id في الـ session للرجوع إليه لاحقاً
        safe_area_sessions_collection.update_one(
            {"_id": doc["_id"]},
            {"$set": {"request_id": request_id}},
        )
    else:
        request_id = str(existing_req["_id"])

    # إشعار الـ Worker مع request_id حتى يفتح Safe Area مباشرة
    try:
        from app.api.v1.endpoints.chat import push_notification
        await push_notification(doc["initiator_email"], {
            "type":         "safe_area_session_accepted",
            "session_id":   session_id,
            "request_id":   request_id,
            "contract_ref": doc["contract_ref"],
            "user_name":    current_user.get("username", ""),
            "title":        doc["title"],
        })
    except Exception as e:
        logger.warning("Failed to notify worker %s of session accept: %s", doc["initiator_email"], e)

    return {"message": "Session accepted. Safe Area contract is now active.", "request_id": request_id}


@router.put("/{session_id}/reject", response_model=MessageResponse, summary="User يرفض الدعوة")
async def reject_session(
    session_id: str,
    current_user: dict = Depends(get_current_user),
):
    doc = _session_or_404(session_id)

    if current_user["email"] != doc["participant_email"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    if doc["status"] != "pending_acceptance":
        raise HTTPException(status_code=400, detail="Session is not pending")

    safe_area_sessions_collection.update_one(
        {"_id": doc["_id"]},
        {"$set": {"status": "rejected"}},
    )

    # إشعار الـ Worker
    try:
        from app.api.v1.endpoints.chat import push_notification
        await push_notification(doc["initiator_email"], {
            "type":         "safe_area_session_rejected",
            "session_id":   session_id,
            "contract_ref": doc["contract_ref"],
            "user_name":    current_user.get("username", ""),
        })
    except Exception as e:
        logger.warning("Failed to notify worker %s of session reject: %s", doc["initiator_email"], e)

    return {"message": "Session rejected"}


@router.put("/{session_id}/complete", response_model=MessageResponse, summary="إتمام الجلسة")
async def complete_session(
    session_id: str,
    current_user: dict = Depends(get_current_user),
):
    """
    يُغلق الجلسة بعد تأكيد الطرفين في Safe Area.
    يُستدعى تلقائياً من confirm_deal عند اكتمال الصفقة.
    يُقبل أيضاً يدوياً من أي طرف في الجلسة.
    """
    doc = _session_or_404(session_id)

    if current_user["email"] not in (doc["initiator_email"], doc["participant_email"]):
        raise HTTPException(status_code=403, detail="Not authorized")

    if doc["status"] == "completed":
        return {"message": "Session is already completed"}

    if doc["status"] not in ("active",):
        raise HTTPException(
            status_code=400,
            detail=f"Cannot complete a session with status '{doc['status']}'"
        )

    safe_area_sessions_collection.update_one(
        {"_id": doc["_id"]},
        {"$set": {
            "status":       "completed",
            "completed_at": datetime.now(timezone.utc),
        }},
    )

    # إشعار كلا الطرفين
    try:
        from app.api.v1.endpoints.chat import push_notification
        event = {
            "type":         "deal_complete",
            "session_id":   session_id,
            "contract_ref": doc["contract_ref"],
            "service_name": doc["title"],
            "request_id":   doc.get("request_id", ""),
        }
        for email in (doc["initiator_email"], doc["participant_email"]):
            await push_notification(email, event)
    except Exception as e:
        logger.warning("Failed to send session complete notifications: %s", e)

    return {"message": "Session completed successfully"}
