"""
app/api/v1/endpoints/reports.py
"""
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from app.api.dependencies import get_current_user
from app.db import reports_collection
from app.schemas.common import MessageResponse

router = APIRouter(prefix="/reports", tags=["Reports"])


class ReportCreate(BaseModel):
    reported_email: str
    reason:         str
    details:        Optional[str] = None


@router.post("", status_code=201, response_model=MessageResponse, summary="إرسال بلاغ")
async def create_report(body: ReportCreate, current_user: dict = Depends(get_current_user)):
    if body.reported_email == current_user["email"]:
        raise HTTPException(status_code=400, detail="Cannot report yourself")

    reports_collection.insert_one({
        "_id":            str(uuid.uuid4()),
        "reporter_email": current_user["email"],
        "reported_email": body.reported_email,
        "reason":         body.reason,
        "details":        body.details,
    })
    return {"message": "Report submitted successfully"}


@router.get("/my", summary="بلاغاتي")
async def my_reports(current_user: dict = Depends(get_current_user)):
    docs = list(reports_collection.find(
        {"reporter_email": current_user["email"]}
    ))
    for d in docs:
        d["id"] = str(d.pop("_id"))
    return docs
