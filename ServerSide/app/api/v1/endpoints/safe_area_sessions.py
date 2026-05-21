"""
app/api/v1/endpoints/safe_area_sessions.py
───────────────────────────────────────────
Safe Area Session — عقد رقمي بين Worker وUser

POST /safe-area-sessions              — Worker ينشئ جلسة ويدعو User
GET  /safe-area-sessions/{id}         — تفاصيل الجلسة
PUT  /safe-area-sessions/{id}/accept  — User يقبل (خلال 6 ساعات)
PUT  /safe-area-sessions/{id}/reject  — User يرفض
GET  /safe-area-sessions/my           — كل جلساتي

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
from app.db import safe_area_sessions_collection, users_collection
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
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid deadline (ISO 8601 required)")

    now = datetime.now(timezone.utc)
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

    # إشعار الـ Worker
    try:
        from app.api.v1.endpoints.chat import push_notification
        await push_notification(doc["initiator_email"], {
            "type":         "safe_area_session_accepted",
            "session_id":   session_id,
            "contract_ref": doc["contract_ref"],
            "user_name":    current_user.get("username", ""),
            "title":        doc["title"],
        })
    except Exception as e:
        logger.warning("Failed to notify worker %s of session accept: %s", doc["initiator_email"], e)

    return {"message": "Session accepted. Safe Area contract is now active."}


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
