from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from core.database import users_reports_collection
from core.schemas import MessageResponse
from core.security import get_current_user

router = APIRouter(prefix="/reports", tags=["Reports"])


class ReportCreate(BaseModel):
    description: str


class ReportOut(BaseModel):
    id: str
    description: str
    status: str
    timestamp: str

    @classmethod
    def from_doc(cls, doc: dict) -> "ReportOut":
        ts = doc.get("timestamp", datetime.utcnow())
        return cls(
            id=str(doc["_id"]),
            description=doc["description"],
            status=doc.get("status", "Pending"),
            timestamp=ts.isoformat() if isinstance(ts, datetime) else str(ts),
        )


@router.post("", response_model=MessageResponse, status_code=201)
async def submit_report(
    report: ReportCreate,
    current_user: dict = Depends(get_current_user),
):
    import uuid
    users_reports_collection.insert_one({
        "_id": str(uuid.uuid4()),
        "user_email": current_user["email"],
        "description": report.description,
        "status": "Pending",
        "timestamp": datetime.utcnow(),
    })
    return {"message": "Report submitted successfully"}


@router.get("/my", response_model=list[ReportOut])
async def get_my_reports(current_user: dict = Depends(get_current_user)):
    docs = list(
        users_reports_collection.find({"user_email": current_user["email"]})
        .sort("timestamp", -1)
    )
    return [ReportOut.from_doc(d) for d in docs]
