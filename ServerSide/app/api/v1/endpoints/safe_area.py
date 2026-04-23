"""
app/api/v1/endpoints/safe_area.py
───────────────────────────────────
POST /{id}/upload
GET  /{id}/preview
POST /{id}/send-payment
GET  /{id}/payment-status
POST /{id}/confirm
GET  /{id}/download
GET  /balance/{email}
"""
import io
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from bson import ObjectId
from fastapi import (APIRouter, Depends, File, HTTPException,
                     UploadFile, status)
from fastapi.responses import FileResponse, StreamingResponse
from pydantic import BaseModel

from app.api.dependencies import get_current_user
from app.core.config import settings
from app.db import (payments_collection, requests_collection,
                    safe_area_collection, users_collection)
from app.schemas.common import MessageResponse

router = APIRouter(prefix="/safe-area", tags=["Safe Area"])

ALLOWED_TYPES = {
    "image/jpeg", "image/jpg", "image/png", "image/webp",
    "application/pdf", "application/octet-stream",
}


# ─── Helpers ─────────────────────────────────────────────
def _req_or_404(request_id: str) -> dict:
    try:
        doc = requests_collection.find_one({"_id": ObjectId(request_id)})
    except Exception:
        doc = requests_collection.find_one({"_id": request_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Request not found")
    return doc


def _sa_or_404(request_id: str) -> dict:
    doc = safe_area_collection.find_one({"request_id": request_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Safe area entry not found")
    return doc


# ─── Upload ──────────────────────────────────────────────

@router.post("/{request_id}/upload", response_model=MessageResponse)
async def upload_work(
    request_id: str,
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
):
    req = _req_or_404(request_id)
    if req["worker_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    if not req.get("safe_area_active"):
        raise HTTPException(status_code=403, detail="Safe area is not active")

    existing = safe_area_collection.find_one({"request_id": request_id})
    if existing and existing.get("payment_confirmed"):
        raise HTTPException(status_code=403, detail="Payment confirmed. Cannot replace file.")

    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Empty file")

    ext = Path(file.filename or "work").suffix or ".bin"
    filename = f"{uuid.uuid4().hex}{ext}"
    file_path = settings.SAFE_AREA_PATH / filename
    file_path.write_bytes(content)

    is_image = (file.content_type or "").startswith("image/")
    ct = file.content_type or "application/octet-stream"

    if existing:
        old = settings.SAFE_AREA_PATH / Path(existing.get("file_path", "")).name
        old.unlink(missing_ok=True)
        safe_area_collection.update_one(
            {"request_id": request_id},
            {"$set": {
                "file_path":    str(file_path),
                "content_type": ct,
                "is_image":     is_image,
                "uploaded_at":  datetime.now(timezone.utc),
            }},
        )
    else:
        safe_area_collection.insert_one({
            "request_id":       request_id,
            "file_path":        str(file_path),
            "content_type":     ct,
            "is_image":         is_image,
            "payment_confirmed": False,
            "worker_confirmed": False,
            "user_confirmed":   False,
            "uploaded_at":      datetime.now(timezone.utc),
        })

    return {"message": "File uploaded successfully"}


# ─── Preview ─────────────────────────────────────────────

@router.get("/{request_id}/preview")
async def preview_work(
    request_id: str,
    current_user: dict = Depends(get_current_user),
):
    req = _req_or_404(request_id)
    if current_user["email"] not in (req["user_email"], req["worker_email"]):
        raise HTTPException(status_code=403, detail="Not authorized")

    entry = _sa_or_404(request_id)
    file_path = Path(entry["file_path"])
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found")

    # Watermark for unpaid previews
    if not entry.get("payment_confirmed") and entry.get("is_image"):
        try:
            from PIL import Image, ImageDraw
            img = Image.open(file_path).convert("RGBA")
            overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
            draw = ImageDraw.Draw(overlay)
            for y in range(0, img.height, 120):
                for x in range(0, img.width, 280):
                    draw.text((x, y), "AMARLO PREVIEW", fill=(255, 255, 255, 80))
            final = Image.alpha_composite(img, overlay).convert("RGB")
            buf = io.BytesIO()
            final.save(buf, format="JPEG", quality=85)
            buf.seek(0)
            return StreamingResponse(buf, media_type="image/jpeg")
        except Exception:
            pass

    return FileResponse(file_path, media_type=entry.get("content_type", "application/octet-stream"))


# ─── Payment ─────────────────────────────────────────────

class PaymentData(BaseModel):
    amount: int


@router.post("/{request_id}/send-payment", response_model=MessageResponse)
async def send_payment(
    request_id: str,
    payment: PaymentData,
    current_user: dict = Depends(get_current_user),
):
    req = _req_or_404(request_id)
    if req["user_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    if payments_collection.find_one({"request_id": request_id}):
        raise HTTPException(status_code=400, detail="Payment already sent")

    payments_collection.insert_one({
        "request_id":   request_id,
        "worker_email": req["worker_email"],
        "user_email":   req["user_email"],
        "amount":       payment.amount,
        "timestamp":    datetime.now(timezone.utc),
    })
    safe_area_collection.update_one(
        {"request_id": request_id},
        {"$set": {"payment_confirmed": True}},
    )
    return {"message": "Payment sent. Confirm the work to complete the deal."}


@router.get("/{request_id}/payment-status")
async def payment_status(request_id: str, current_user: dict = Depends(get_current_user)):
    _req_or_404(request_id)
    payment = payments_collection.find_one({"request_id": request_id})
    return {"payment_received": payment is not None, "amount": payment["amount"] if payment else 0}


# ─── Confirm ─────────────────────────────────────────────

@router.post("/{request_id}/confirm", response_model=MessageResponse)
async def confirm_deal(request_id: str, current_user: dict = Depends(get_current_user)):
    req   = _req_or_404(request_id)
    entry = _sa_or_404(request_id)

    if not entry.get("payment_confirmed"):
        raise HTTPException(status_code=400, detail="Payment must be sent first")

    update: dict = {}
    if current_user["email"] == req["worker_email"]:
        update["worker_confirmed"] = True
    elif current_user["email"] == req["user_email"]:
        update["user_confirmed"] = True
    else:
        raise HTTPException(status_code=403, detail="Not authorized")

    safe_area_collection.update_one({"request_id": request_id}, {"$set": update})
    entry = safe_area_collection.find_one({"request_id": request_id})

    if entry.get("worker_confirmed") and entry.get("user_confirmed"):
        try:
            requests_collection.update_one(
                {"_id": ObjectId(request_id)},
                {"$set": {"status": "completed"}},
            )
        except Exception:
            requests_collection.update_one(
                {"_id": request_id},
                {"$set": {"status": "completed"}},
            )

        # Notify both parties
        from app.api.v1.endpoints.chat import push_notification
        import asyncio
        event = {
            "type":         "deal_complete",
            "service_name": req.get("service_name", ""),
            "request_id":   request_id,
        }
        for email in [req["user_email"], req["worker_email"]]:
            asyncio.create_task(push_notification(email, event))

        return {"message": "Deal completed! File is now available for download."}

    return {"message": "Confirmation recorded. Waiting for the other party."}


# ─── Download ────────────────────────────────────────────

@router.get("/{request_id}/download")
async def download_work(request_id: str, current_user: dict = Depends(get_current_user)):
    req = _req_or_404(request_id)
    if current_user["email"] not in (req["user_email"], req["worker_email"]):
        raise HTTPException(status_code=403, detail="Not authorized")

    entry = _sa_or_404(request_id)
    if not (entry.get("worker_confirmed") and entry.get("user_confirmed")):
        raise HTTPException(status_code=403, detail="Both parties must confirm first")

    fp = Path(entry["file_path"])
    if not fp.exists():
        raise HTTPException(status_code=404, detail="File not found")

    return FileResponse(fp, media_type=entry.get("content_type", "application/octet-stream"), filename=fp.name)


# ─── Balance ─────────────────────────────────────────────

@router.get("/balance/{worker_email}")
async def get_balance(worker_email: str, current_user: dict = Depends(get_current_user)):
    if current_user["email"] != worker_email:
        raise HTTPException(status_code=403, detail="Not authorized")

    completed_ids = {
        str(r["_id"])
        for r in requests_collection.find({"worker_email": worker_email, "status": "completed"})
    }
    payments = list(payments_collection.find({"worker_email": worker_email}))
    total = sum(p["amount"] for p in payments if p["request_id"] in completed_ids)
    return {"balance": total, "currency": "USD"}
