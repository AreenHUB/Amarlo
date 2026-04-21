from datetime import datetime
from enum import Enum
from typing import Optional

from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException, Response, status
from pydantic import BaseModel, EmailStr

import json
from core.database import requests_collection
from core.schemas import MessageResponse, PagedResponse, PaginationParams
from core.security import get_current_user


# ─── Notification helper ──────────────────────
async def _notify_user(email: str, event: dict) -> None:
    """Sends a real-time event to a user's notification WebSocket."""
    try:
        from routers.chat import active_notification_connections
        payload = json.dumps(event)
        for ws in list(active_notification_connections.get(email, set())):
            try:
                await ws.send_text(payload)
            except Exception:
                pass
    except Exception:
        pass  # non-critical

router = APIRouter(prefix="/requests", tags=["Service Requests"])


# ─── Schemas ─────────────────────────────────────────────
class RequestStatus(str, Enum):
    PENDING           = "pending"
    ACCEPTED          = "accepted"
    REJECTED          = "rejected"
    READY_FOR_DELIVERY = "ready_for_delivery"
    COMPLETED         = "completed"


class ServiceRequestIn(BaseModel):
    service_id: str
    user_email: EmailStr
    user_name: str
    worker_email: EmailStr
    service_name: str


class RequestOut(BaseModel):
    id: str
    service_id: str
    service_name: str
    user_email: str
    user_name: str
    worker_email: str
    status: str
    created_at: str
    deadline: Optional[str] = None
    safe_area_active: bool = False

    @classmethod
    def from_doc(cls, doc: dict) -> "RequestOut":
        deadline = doc.get("deadline")
        if isinstance(deadline, datetime):
            deadline = deadline.isoformat()
        created = doc.get("created_at", datetime.utcnow())
        if isinstance(created, datetime):
            created = created.isoformat()
        return cls(
            id=str(doc["_id"]),
            service_id=doc.get("service_id", ""),
            service_name=doc.get("service_name", ""),
            user_email=doc.get("user_email", ""),
            user_name=doc.get("user_name", ""),
            worker_email=doc.get("worker_email", ""),
            status=doc.get("status", RequestStatus.PENDING.value),
            created_at=created,
            deadline=deadline,
            safe_area_active=doc.get("safe_area_active", False),
        )


# ─── Create request (via WebSocket handled in chat router) ─
# نبقي endpoint HTTP للحالات التي لا يستخدم فيها WebSocket
@router.post("", status_code=201, response_model=RequestOut)
async def create_request(
    body: ServiceRequestIn,
    current_user: dict = Depends(get_current_user),
):
    if current_user["email"] != body.user_email:
        raise HTTPException(status_code=403, detail="Not authorized")

    doc = {
        **body.dict(),
        "status": RequestStatus.PENDING.value,
        "created_at": datetime.utcnow(),
        "safe_area_active": False,
    }
    result = requests_collection.insert_one(doc)
    doc["_id"] = result.inserted_id
    return RequestOut.from_doc(doc)


# ─── User requests ───────────────────────────────────────

@router.get("/user/{user_id}", response_model=PagedResponse[RequestOut])
async def get_user_requests(
    user_id: str,
    include_completed: bool = False,
    pagination: PaginationParams = Depends(),
    current_user: dict = Depends(get_current_user),
):
    if current_user["_id"] != user_id:
        raise HTTPException(status_code=403, detail="Not authorized")

    query: dict = {"user_email": current_user["email"]}
    if not include_completed:
        query["status"] = {"$ne": RequestStatus.COMPLETED.value}

    total = requests_collection.count_documents(query)
    docs = list(
        requests_collection.find(query)
        .sort("created_at", -1)
        .skip(pagination.skip)
        .limit(pagination.size)
    )
    return PagedResponse.build([RequestOut.from_doc(d) for d in docs], total, pagination)


@router.get("/user/{user_email}/completed", response_model=list[RequestOut])
async def get_user_completed(
    user_email: str,
    current_user: dict = Depends(get_current_user),
):
    if current_user["email"] != user_email:
        raise HTTPException(status_code=403, detail="Not authorized")
    docs = list(requests_collection.find(
        {"user_email": user_email, "status": RequestStatus.COMPLETED.value}
    ).sort("created_at", -1))
    return [RequestOut.from_doc(d) for d in docs]


# ─── Worker requests ─────────────────────────────────────

@router.get("/worker/{worker_email}", response_model=PagedResponse[RequestOut])
async def get_worker_requests(
    worker_email: str,
    pagination: PaginationParams = Depends(),
    current_user: dict = Depends(get_current_user),
):
    if current_user["email"] != worker_email:
        raise HTTPException(status_code=403, detail="Not authorized")

    query = {
        "worker_email": worker_email,
        "status": {"$nin": [RequestStatus.COMPLETED.value, RequestStatus.REJECTED.value]},
    }
    total = requests_collection.count_documents(query)
    docs = list(
        requests_collection.find(query)
        .sort("created_at", -1)
        .skip(pagination.skip)
        .limit(pagination.size)
    )
    return PagedResponse.build([RequestOut.from_doc(d) for d in docs], total, pagination)


@router.get("/worker/{worker_email}/completed", response_model=list[RequestOut])
async def get_worker_completed(
    worker_email: str,
    current_user: dict = Depends(get_current_user),
):
    if current_user["email"] != worker_email:
        raise HTTPException(status_code=403, detail="Not authorized")
    docs = list(requests_collection.find(
        {"worker_email": worker_email, "status": RequestStatus.COMPLETED.value}
    ).sort("created_at", -1))
    return [RequestOut.from_doc(d) for d in docs]


# ─── Actions ─────────────────────────────────────────────

@router.put("/{request_id}/accept", response_model=MessageResponse)
async def accept_request(
    request_id: str,
    deadline: str,           # ISO 8601
    current_user: dict = Depends(get_current_user),
):
    req = requests_collection.find_one({"_id": ObjectId(request_id)})
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")
    if req["worker_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    if req["status"] != RequestStatus.PENDING.value:
        raise HTTPException(status_code=400, detail="Request is not pending")

    try:
        deadline_dt = datetime.fromisoformat(deadline)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid deadline format (ISO 8601 required)")

    requests_collection.update_one(
        {"_id": ObjectId(request_id)},
        {"$set": {
            "status": RequestStatus.ACCEPTED.value,
            "deadline": deadline_dt,
            "safe_area_active": True,
        }},
    )

    # إشعار المستخدم بقبول طلبه
    await _notify_user(req["user_email"], {
        "type": "request_accepted",
        "service_name": req.get("service_name", ""),
        "deadline": deadline_dt.isoformat(),
    })

    return {"message": "Request accepted", "deadline": deadline_dt.isoformat()}


@router.put("/{request_id}/ready", response_model=MessageResponse)
async def mark_ready(request_id: str, current_user: dict = Depends(get_current_user)):
    req = requests_collection.find_one({"_id": ObjectId(request_id)})
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")
    if req["worker_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    if req["status"] != RequestStatus.ACCEPTED.value:
        raise HTTPException(status_code=400, detail="Request must be accepted first")

    requests_collection.update_one(
        {"_id": ObjectId(request_id)},
        {"$set": {"status": RequestStatus.READY_FOR_DELIVERY.value}},
    )
    return {"message": "Request marked as ready for delivery"}


@router.delete("/{request_id}", status_code=204)
async def delete_or_reject_request(
    request_id: str,
    current_user: dict = Depends(get_current_user),
):
    req = requests_collection.find_one({"_id": ObjectId(request_id)})
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")

    if req["user_email"] == current_user["email"]:
        if req["status"] != RequestStatus.PENDING.value:
            raise HTTPException(status_code=400, detail="Can only delete pending requests")
        requests_collection.delete_one({"_id": ObjectId(request_id)})
    elif req["worker_email"] == current_user["email"]:
        requests_collection.update_one(
            {"_id": ObjectId(request_id)},
            {"$set": {"status": RequestStatus.REJECTED.value}},
        )
        # إشعار المستخدم برفض طلبه
        await _notify_user(req["user_email"], {
            "type": "request_rejected",
            "service_name": req.get("service_name", ""),
        })
    else:
        raise HTTPException(status_code=403, detail="Not authorized")

    return Response(status_code=204)
