"""
app/api/v1/endpoints/requests.py
──────────────────────────────────
GET    /requests/user/{user_id}         — طلبات المستخدم
GET    /requests/user/{email}/completed
GET    /requests/worker/{email}          — طلبات العامل
GET    /requests/worker/{email}/completed
PUT    /requests/{id}/accept
PUT    /requests/{id}/ready
DELETE /requests/{id}                   — رفض / إلغاء
"""
import json
from datetime import datetime, timezone
from enum import Enum
from typing import Optional, Set, Dict

from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException, Response, status
from pydantic import BaseModel

from app.api.dependencies import get_current_user
from app.db import requests_collection
from app.schemas.common import MessageResponse, PagedResponse, PaginationParams

router = APIRouter(prefix="/requests", tags=["Service Requests"])

# Shared connection registry (populated by chat endpoint)
_notification_connections: Dict[str, Set] = {}


def get_notification_connections() -> Dict[str, Set]:
    return _notification_connections


async def _notify(email: str, event: dict) -> None:
    """Push real-time event to user's notification WebSocket."""
    try:
        from app.api.v1.endpoints.chat import active_notification_connections
        conns = active_notification_connections.get(email, set())
        payload = json.dumps(event)
        for ws in list(conns):
            try:
                await ws.send_text(payload)
            except Exception:
                pass
    except Exception:
        pass


class RequestStatus(str, Enum):
    PENDING            = "pending"
    ACCEPTED           = "accepted"
    REJECTED           = "rejected"
    READY_FOR_DELIVERY = "ready_for_delivery"
    COMPLETED          = "completed"


class RequestOut(BaseModel):
    id:              str
    service_id:      str
    service_name:    str
    user_email:      str
    user_name:       str
    worker_email:    str
    status:          str
    created_at:      str
    deadline:        Optional[str] = None
    safe_area_active: bool = False

    @classmethod
    def from_doc(cls, doc: dict) -> "RequestOut":
        deadline = doc.get("deadline")
        if isinstance(deadline, datetime):
            deadline = deadline.isoformat()
        created = doc.get("created_at", datetime.now(timezone.utc))
        if isinstance(created, datetime):
            created = created.isoformat()
        return cls(
            id=              str(doc["_id"]),
            service_id=      doc.get("service_id", ""),
            service_name=    doc.get("service_name", ""),
            user_email=      doc.get("user_email", ""),
            user_name=       doc.get("user_name", ""),
            worker_email=    doc.get("worker_email", ""),
            status=          doc.get("status", RequestStatus.PENDING),
            created_at=      created,
            deadline=        deadline,
            safe_area_active=doc.get("safe_area_active", False),
        )


def _req_or_404(request_id: str) -> dict:
    try:
        doc = requests_collection.find_one({"_id": ObjectId(request_id)})
    except Exception:
        doc = requests_collection.find_one({"_id": request_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Request not found")
    return doc


# ─── User endpoints ──────────────────────────────────────

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
        query["status"] = {"$nin": [RequestStatus.COMPLETED, RequestStatus.REJECTED]}

    total = requests_collection.count_documents(query)
    docs = list(
        requests_collection.find(query)
        .sort("created_at", -1)
        .skip(pagination.skip)
        .limit(pagination.size)
    )
    return PagedResponse.build([RequestOut.from_doc(d) for d in docs], total, pagination)


@router.get("/user/{user_email}/completed", response_model=list[RequestOut])
async def user_completed(user_email: str, current_user: dict = Depends(get_current_user)):
    if current_user["email"] != user_email:
        raise HTTPException(status_code=403, detail="Not authorized")
    docs = list(requests_collection.find(
        {"user_email": user_email, "status": RequestStatus.COMPLETED}
    ).sort("created_at", -1))
    return [RequestOut.from_doc(d) for d in docs]


# ─── Worker endpoints ────────────────────────────────────

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
        "status": {"$nin": [RequestStatus.COMPLETED, RequestStatus.REJECTED]},
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
async def worker_completed(worker_email: str, current_user: dict = Depends(get_current_user)):
    if current_user["email"] != worker_email:
        raise HTTPException(status_code=403, detail="Not authorized")
    docs = list(requests_collection.find(
        {"worker_email": worker_email, "status": RequestStatus.COMPLETED}
    ).sort("created_at", -1))
    return [RequestOut.from_doc(d) for d in docs]


# ─── Actions ─────────────────────────────────────────────

@router.put("/{request_id}/accept", response_model=MessageResponse)
async def accept_request(
    request_id: str,
    deadline:   str,
    current_user: dict = Depends(get_current_user),
):
    req = _req_or_404(request_id)
    if req["worker_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    if req["status"] != RequestStatus.PENDING:
        raise HTTPException(status_code=400, detail="Request is not pending")

    try:
        deadline_dt = datetime.fromisoformat(deadline)
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid deadline (ISO 8601 required)")

    requests_collection.update_one(
        {"_id": req["_id"]},
        {"$set": {
            "status":          RequestStatus.ACCEPTED,
            "deadline":        deadline_dt,
            "safe_area_active": True,
        }},
    )
    await _notify(req["user_email"], {
        "type":         "request_accepted",
        "service_name": req.get("service_name", ""),
        "deadline":     deadline_dt.isoformat(),
    })
    return {"message": "Request accepted"}


@router.put("/{request_id}/ready", response_model=MessageResponse)
async def mark_ready(request_id: str, current_user: dict = Depends(get_current_user)):
    req = _req_or_404(request_id)
    if req["worker_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    if req["status"] != RequestStatus.ACCEPTED:
        raise HTTPException(status_code=400, detail="Request must be accepted first")

    requests_collection.update_one(
        {"_id": req["_id"]},
        {"$set": {"status": RequestStatus.READY_FOR_DELIVERY}},
    )
    await _notify(req["user_email"], {
        "type":         "request_ready",
        "service_name": req.get("service_name", ""),
    })
    return {"message": "Marked as ready for delivery"}


@router.delete("/{request_id}", status_code=204)
async def delete_or_reject(
    request_id: str,
    current_user: dict = Depends(get_current_user),
):
    req = _req_or_404(request_id)

    if req["user_email"] == current_user["email"]:
        if req["status"] != RequestStatus.PENDING:
            raise HTTPException(status_code=400, detail="Can only cancel pending requests")
        requests_collection.delete_one({"_id": req["_id"]})

    elif req["worker_email"] == current_user["email"]:
        requests_collection.update_one(
            {"_id": req["_id"]},
            {"$set": {"status": RequestStatus.REJECTED}},
        )
        await _notify(req["user_email"], {
            "type":         "request_rejected",
            "service_name": req.get("service_name", ""),
        })
    else:
        raise HTTPException(status_code=403, detail="Not authorized")

    return Response(status_code=204)
