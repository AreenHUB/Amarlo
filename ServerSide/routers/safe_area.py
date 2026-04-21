"""
Safe Area Router
================
Flow:
  1. Worker accepts request → safe_area_active = True
  2. Worker uploads work file  → stored on disk (not base64)
  3. Worker marks request ready → status = ready_for_delivery
  4. User views file (watermarked preview)
  5. User sends payment         → payment record created
  6. Both confirm               → file available for clean download, worker balance updated
"""
import io
import uuid
from datetime import datetime
from pathlib import Path
from typing import Optional

from bson import ObjectId
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from fastapi.responses import FileResponse, StreamingResponse
from pydantic import BaseModel

from core.config import BASE_URL, SAFE_AREA_DIR
from core.database import (
    payments_collection,
    requests_collection,
    safe_area_collection,
    users_collection,
)
from core.schemas import MessageResponse
from core.security import get_current_user

router = APIRouter(prefix="/safe-area", tags=["Safe Area"])

ALLOWED_SAFE_TYPES = {
    "image/jpeg", "image/png", "image/webp",
    "application/pdf",
}


# ─── Helper ──────────────────────────────────────────────
def _get_request_or_404(request_id: str) -> dict:
    req = requests_collection.find_one({"_id": ObjectId(request_id)})
    if not req:
        raise HTTPException(status_code=404, detail="Request not found")
    return req


def _get_safe_area_or_404(request_id: str) -> dict:
    entry = safe_area_collection.find_one({"request_id": request_id})
    if not entry:
        raise HTTPException(status_code=404, detail="Safe area entry not found")
    return entry


# ─── Upload ──────────────────────────────────────────────

@router.post("/{request_id}/upload", response_model=MessageResponse)
async def upload_work(
    request_id: str,
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user),
):
    req = _get_request_or_404(request_id)

    if req["worker_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    if not req.get("safe_area_active"):
        raise HTTPException(status_code=403, detail="Safe area is not active")

    # Block re-upload after payment confirmed
    existing = safe_area_collection.find_one({"request_id": request_id})
    if existing and existing.get("payment_confirmed"):
        raise HTTPException(status_code=403, detail="Payment confirmed. Cannot replace file.")

    if file.content_type not in ALLOWED_SAFE_TYPES:
        raise HTTPException(status_code=400, detail=f"File type not allowed: {file.content_type}")

    content = await file.read()
    ext = Path(file.filename).suffix or ".bin"
    filename = f"{uuid.uuid4().hex}{ext}"
    file_path = SAFE_AREA_DIR / filename
    file_path.write_bytes(content)

    file_url = f"{BASE_URL}/uploads/safe_area/{filename}"
    is_image = file.content_type.startswith("image/")

    if existing:
        # delete old file
        old_path = SAFE_AREA_DIR / Path(existing.get("file_path", "")).name
        if old_path.exists():
            old_path.unlink(missing_ok=True)
        safe_area_collection.update_one(
            {"request_id": request_id},
            {"$set": {
                "file_path": str(file_path),
                "file_url": file_url,
                "content_type": file.content_type,
                "is_image": is_image,
                "uploaded_at": datetime.utcnow(),
            }},
        )
    else:
        safe_area_collection.insert_one({
            "request_id": request_id,
            "file_path": str(file_path),
            "file_url": file_url,
            "content_type": file.content_type,
            "is_image": is_image,
            "payment_confirmed": False,
            "worker_confirmed": False,
            "user_confirmed": False,
            "uploaded_at": datetime.utcnow(),
        })

    return {"message": "File uploaded successfully"}


# ─── Preview (watermarked for images) ───────────────────

@router.get("/{request_id}/preview")
async def preview_work(
    request_id: str,
    current_user: dict = Depends(get_current_user),
):
    req = _get_request_or_404(request_id)
    if current_user["email"] not in (req["user_email"], req["worker_email"]):
        raise HTTPException(status_code=403, detail="Not authorized")

    entry = _get_safe_area_or_404(request_id)
    file_path = Path(entry["file_path"])

    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found on server")

    # If payment not yet confirmed → watermark images
    if not entry.get("payment_confirmed") and entry.get("is_image"):
        try:
            from PIL import Image, ImageDraw, ImageFont
            img = Image.open(file_path).convert("RGBA")
            overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
            draw = ImageDraw.Draw(overlay)

            # Diagonal watermark
            text = "AMARLO PREVIEW"
            for y in range(0, img.height, 120):
                for x in range(0, img.width, 300):
                    draw.text((x, y), text, fill=(255, 255, 255, 80))

            watermarked = Image.alpha_composite(img, overlay).convert("RGB")
            buf = io.BytesIO()
            watermarked.save(buf, format="JPEG", quality=85)
            buf.seek(0)
            return StreamingResponse(buf, media_type="image/jpeg")
        except ImportError:
            pass  # Pillow not installed, serve original

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
    req = _get_request_or_404(request_id)
    if req["user_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    if payments_collection.find_one({"request_id": request_id}):
        raise HTTPException(status_code=400, detail="Payment already sent")

    payments_collection.insert_one({
        "request_id": request_id,
        "worker_email": req["worker_email"],
        "user_email": req["user_email"],
        "amount": payment.amount,
        "timestamp": datetime.utcnow(),
    })
    safe_area_collection.update_one(
        {"request_id": request_id},
        {"$set": {"payment_confirmed": True}},
    )
    return {"message": "Payment sent. Please confirm the work to complete the deal."}


@router.get("/{request_id}/payment-status")
async def payment_status(
    request_id: str,
    current_user: dict = Depends(get_current_user),
):
    payment = payments_collection.find_one({"request_id": request_id})
    if payment:
        return {"payment_received": True, "amount": payment["amount"]}
    return {"payment_received": False}


# ─── Two-sided confirmation ──────────────────────────────

@router.post("/{request_id}/confirm", response_model=MessageResponse)
async def confirm_deal(
    request_id: str,
    current_user: dict = Depends(get_current_user),
):
    """
    يجب أن يضغط كلا الطرفين على Confirm لإتمام الصفقة.
    """
    req = _get_request_or_404(request_id)
    entry = _get_safe_area_or_404(request_id)

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

    # Re-fetch to check if both confirmed
    entry = safe_area_collection.find_one({"request_id": request_id})
    if entry.get("worker_confirmed") and entry.get("user_confirmed"):
        # Complete the deal
        requests_collection.update_one(
            {"_id": ObjectId(request_id)},
            {"$set": {"status": "completed"}},
        )
        # إشعار الطرفين باكتمال الصفقة
        try:
            from routers.chat import active_notification_connections
            import json as _json
            service_name = req.get("service_name", "")
            deal_event = _json.dumps({
                "type": "deal_complete",
                "service_name": service_name,
                "request_id": request_id,
            })
            for email in [req["user_email"], req["worker_email"]]:
                for ws in list(active_notification_connections.get(email, set())):
                    try:
                        await ws.send_text(deal_event)
                    except Exception:
                        pass
        except Exception:
            pass
        return {"message": "Deal completed! File is now available for download."}

    return {"message": "Confirmation recorded. Waiting for the other party."}


# ─── Download (only after both confirmed) ────────────────

@router.get("/{request_id}/download")
async def download_work(
    request_id: str,
    current_user: dict = Depends(get_current_user),
):
    req = _get_request_or_404(request_id)
    if current_user["email"] not in (req["user_email"], req["worker_email"]):
        raise HTTPException(status_code=403, detail="Not authorized")

    entry = _get_safe_area_or_404(request_id)

    if not (entry.get("worker_confirmed") and entry.get("user_confirmed")):
        raise HTTPException(
            status_code=403,
            detail="Both parties must confirm before downloading",
        )

    file_path = Path(entry["file_path"])
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found on server")

    return FileResponse(
        file_path,
        media_type=entry.get("content_type", "application/octet-stream"),
        filename=file_path.name,
    )


# ─── Worker balance ──────────────────────────────────────

@router.get("/balance/{worker_email}")
async def get_balance(
    worker_email: str,
    current_user: dict = Depends(get_current_user),
):
    if current_user["email"] != worker_email:
        raise HTTPException(status_code=403, detail="Not authorized")

    payments = list(payments_collection.find({"worker_email": worker_email}))
    # Only count payments for completed deals
    completed_ids = {
        str(r["_id"])
        for r in requests_collection.find(
            {"worker_email": worker_email, "status": "completed"}
        )
    }
    total = sum(p["amount"] for p in payments if p["request_id"] in completed_ids)
    return {"balance": total, "currency": "USD"}
