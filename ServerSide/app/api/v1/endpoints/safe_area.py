"""
app/api/v1/endpoints/safe_area.py
───────────────────────────────────
Safe Area — حماية الطرفين في التسليم الرقمي

POST /{id}/upload            — Worker يرفع الملف + صورة إثبات اختيارية
GET  /{id}/preview           — معاينة watermarked (صور) أو proof image (ملفات أخرى)
POST /{id}/send-payment      — User يدفع (يُتحقق من مطابقة سعر الخدمة)
GET  /{id}/payment-status    — حالة الدفع
POST /{id}/confirm           — كلا الطرفين يؤكد (يُكمل الصفقة)
GET  /{id}/download          — User يحمّل الأصل بعد التأكيد
GET  /balance/{email}        — رصيد العامل

ملاحظة: هذه الـ endpoints تخص delivery_type == "online" فقط.
الخدمات In-Person تُكتفى بـ /requests/{id}/confirm-inperson
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

from app.api.dependencies import get_current_user, get_current_user_flexible
from app.core.config import settings
from app.db import (payments_collection, requests_collection,
                    safe_area_collection, users_collection)
from app.schemas.common import MessageResponse

router = APIRouter(prefix="/safe-area", tags=["Safe Area"])

# Allowed MIME types for work uploads — enforced against actual file content
ALLOWED_TYPES = {
    "image/jpeg", "image/jpg", "image/png", "image/webp",
    "application/pdf",
    "application/zip", "application/x-zip-compressed",
    "text/plain",
    "application/octet-stream",  # generic binary fallback
}

# Safe file extensions that map to the allowed types above
ALLOWED_EXTENSIONS = {
    ".jpg", ".jpeg", ".png", ".webp",
    ".pdf",
    ".zip",
    ".txt",
    ".py", ".js", ".ts", ".html", ".css",  # code files delivered as text/plain or octet-stream
    ".bin",
}

MAX_SAFE_AREA_BYTES = settings.MAX_SAFE_AREA_SIZE_MB * 1024 * 1024

# Magic bytes for the most common types — prevents content-type spoofing
_MAGIC: list[tuple[bytes, str]] = [
    (b"\xff\xd8\xff",           "image/jpeg"),
    (b"\x89PNG\r\n\x1a\n",     "image/png"),
    (b"RIFF",                   "image/webp"),   # RIFF....WEBP
    (b"%PDF",                   "application/pdf"),
    (b"PK\x03\x04",            "application/zip"),
]

def _detect_mime(data: bytes) -> str:
    """Return MIME type from magic bytes; fall back to octet-stream."""
    for magic, mime in _MAGIC:
        if data[:len(magic)] == magic:
            return mime
    # WebP has RIFF + WEBP at offset 8
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    return "application/octet-stream"

def _validate_upload(content: bytes, filename: str, declared_type: str) -> str:
    """
    Validate file upload security. Returns the real MIME type.
    Raises HTTPException on any violation.
    """
    # 1. Size limit
    if len(content) > MAX_SAFE_AREA_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"File too large. Maximum size is {settings.MAX_SAFE_AREA_SIZE_MB} MB.",
        )
    if len(content) == 0:
        raise HTTPException(status_code=400, detail="File is empty.")

    # 2. Extension whitelist — from server-cleaned filename only
    suffix = Path(filename).suffix.lower() if filename else ""
    if suffix and suffix not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"File type '{suffix}' is not allowed.",
        )

    # 3. Magic-byte detection — actual file content, not client header
    real_mime = _detect_mime(content)

    # 4. Declared content-type must be in the allowed set
    #    (we trust our magic detection over client claim)
    if real_mime not in ALLOWED_TYPES and declared_type not in ALLOWED_TYPES:
        raise HTTPException(
            status_code=400,
            detail="File type is not supported.",
        )

    return real_mime


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


def _assert_online(req: dict) -> None:
    """يتحقق أن الخدمة رقمية (online). In-person لا تستخدم Safe Area."""
    if req.get("delivery_type", "online") == "in_person":
        raise HTTPException(
            status_code=400,
            detail="In-person services do not use Safe Area. Use /confirm-inperson instead."
        )


# ─── Upload ──────────────────────────────────────────────

@router.post("/{request_id}/upload", response_model=MessageResponse)
async def upload_work(
    request_id:  str,
    file:        UploadFile = File(...),
    proof_image: Optional[UploadFile] = File(None),   # صورة إثبات للملفات غير القابلة للمعاينة
    current_user: dict = Depends(get_current_user),
):
    """
    Worker يرفع ملف العمل.
    - للصور: تُعرض بـ watermark تلقائياً كـ preview
    - لغيرها (كود، PDF، ZIP): proof_image إلزامية — صورة تثبت أن العمل مكتمل
    """
    req = _req_or_404(request_id)
    _assert_online(req)

    if req["worker_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    if not req.get("safe_area_active"):
        raise HTTPException(status_code=403, detail="Safe area is not active for this request")

    existing = safe_area_collection.find_one({"request_id": request_id})
    if existing and existing.get("payment_confirmed"):
        raise HTTPException(status_code=403, detail="Payment already confirmed. Cannot replace file.")

    # ── حفظ الملف الرئيسي ───────────────────────────────
    content = await file.read()

    # Validate: size, extension, and magic-byte MIME — all three must pass
    real_mime = _validate_upload(
        content,
        file.filename or "",
        file.content_type or "",
    )

    # Use a safe, server-generated filename — never trust the client filename
    safe_ext  = Path(file.filename or "work").suffix.lower() or ".bin"
    if safe_ext not in ALLOWED_EXTENSIONS:
        safe_ext = ".bin"
    filename  = f"{uuid.uuid4().hex}{safe_ext}"
    file_path = settings.SAFE_AREA_PATH / filename
    file_path.write_bytes(content)

    is_image = real_mime.startswith("image/")
    ct       = real_mime  # use detected type, not client-supplied header

    # ── صورة الإثبات (proof_image) ───────────────────────
    # مطلوبة للملفات غير الصور
    proof_path_str: Optional[str] = None
    if not is_image:
        if not proof_image or not proof_image.filename:
            raise HTTPException(
                status_code=400,
                detail="proof_image is required for non-image files. "
                       "Upload a screenshot or photo proving the work is complete."
            )
        proof_content = await proof_image.read()
        proof_real_mime = _validate_upload(
            proof_content,
            proof_image.filename or "",
            proof_image.content_type or "",
        )
        if not proof_real_mime.startswith("image/"):
            raise HTTPException(status_code=400, detail="Proof image must be an image file.")

        proof_safe_ext = Path(proof_image.filename).suffix.lower() or ".jpg"
        if proof_safe_ext not in {".jpg", ".jpeg", ".png", ".webp"}:
            proof_safe_ext = ".jpg"
        proof_name = f"proof_{uuid.uuid4().hex}{proof_safe_ext}"
        proof_path = settings.SAFE_AREA_PATH / proof_name
        proof_path.write_bytes(proof_content)
        proof_path_str = str(proof_path)

    update_fields = {
        "file_path":     str(file_path),
        "content_type":  ct,
        "is_image":      is_image,
        "uploaded_at":   datetime.now(timezone.utc),
    }
    if proof_path_str:
        update_fields["proof_image_path"] = proof_path_str

    if existing:
        # حذف الملفات القديمة
        old_main  = settings.SAFE_AREA_PATH / Path(existing.get("file_path", "")).name
        old_main.unlink(missing_ok=True)
        if existing.get("proof_image_path"):
            old_proof = settings.SAFE_AREA_PATH / Path(existing["proof_image_path"]).name
            old_proof.unlink(missing_ok=True)

        safe_area_collection.update_one(
            {"request_id": request_id},
            {"$set": update_fields},
        )
    else:
        safe_area_collection.insert_one({
            "request_id":       request_id,
            "payment_confirmed": False,
            "worker_confirmed":  False,
            "user_confirmed":    False,
            **update_fields,
        })

    # إشعار الـ User أن العامل رفع العمل
    from app.api.v1.endpoints.chat import push_notification
    import asyncio
    asyncio.create_task(push_notification(req["user_email"], {
        "type":             "work_uploaded",
        "service_name":     req.get("service_name", ""),
        "worker_username":  current_user.get("username", ""),
        "request_id":       request_id,
    }))

    return {"message": "Work uploaded successfully"}


# ─── Preview ─────────────────────────────────────────────

@router.get("/{request_id}/preview")
async def preview_work(
    request_id:   str,
    current_user: dict = Depends(get_current_user_flexible),
):
    """
    معاينة العمل قبل الدفع:
    - صور: watermark تلقائي حتى يُؤكَّد الدفع
    - ملفات أخرى: يُعرض proof_image مباشرة
    بعد تأكيد الدفع: يُعرض الأصل بدون watermark
    """
    req = _req_or_404(request_id)
    if current_user["email"] not in (req["user_email"], req["worker_email"]):
        raise HTTPException(status_code=403, detail="Not authorized")

    entry = _sa_or_404(request_id)
    file_path = Path(entry["file_path"])
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found on server")

    payment_confirmed = entry.get("payment_confirmed", False)

    # ── إذا الدفع مؤكد: أعطِ الأصل مباشرة ──────────────
    if payment_confirmed:
        return FileResponse(
            file_path,
            media_type=entry.get("content_type", "application/octet-stream"),
        )

    # ── صور: أضف watermark ───────────────────────────────
    if entry.get("is_image"):
        try:
            from PIL import Image, ImageDraw, ImageFont
            img = Image.open(file_path).convert("RGBA")
            overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
            draw = ImageDraw.Draw(overlay)
            step_x = max(200, img.width  // 4)
            step_y = max(100, img.height // 5)
            for y in range(0, img.height + step_y, step_y):
                for x in range(0, img.width + step_x, step_x):
                    draw.text((x, y), "AMARLO PREVIEW", fill=(255, 255, 255, 90))
            final = Image.alpha_composite(img, overlay).convert("RGB")
            buf = io.BytesIO()
            final.save(buf, format="JPEG", quality=82)
            buf.seek(0)
            return StreamingResponse(buf, media_type="image/jpeg")
        except Exception:
            # Fallback: أعطِ الأصل
            return FileResponse(file_path, media_type=entry.get("content_type", "image/jpeg"))

    # ── ملفات أخرى: أعطِ proof_image ────────────────────
    proof = entry.get("proof_image_path")
    if proof:
        proof_path = Path(proof)
        if proof_path.exists():
            return FileResponse(proof_path, media_type="image/jpeg")

    raise HTTPException(
        status_code=404,
        detail="No preview available. Worker has not uploaded a proof image yet."
    )


# ─── Price Renegotiation ─────────────────────────────────

class PriceProposal(BaseModel):
    new_price: int


@router.post("/{request_id}/propose-price", response_model=MessageResponse)
async def propose_price(
    request_id: str,
    body: PriceProposal,
    current_user: dict = Depends(get_current_user),
):
    """Worker يقترح تغيير السعر قبل الدفع — يُرسل للـ User للموافقة."""
    req = _req_or_404(request_id)
    _assert_online(req)

    if req["worker_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Only the worker can propose a price change")

    if payments_collection.find_one({"request_id": request_id}):
        raise HTTPException(status_code=400, detail="Payment already sent. Cannot change price.")

    if body.new_price <= 0:
        raise HTTPException(status_code=400, detail="Price must be greater than 0")

    try:
        requests_collection.update_one(
            {"_id": ObjectId(request_id)},
            {"$set": {"proposed_price": body.new_price, "price_status": "pending_user_approval"}},
        )
    except Exception:
        requests_collection.update_one(
            {"_id": request_id},
            {"$set": {"proposed_price": body.new_price, "price_status": "pending_user_approval"}},
        )

    # إشعار الـ User
    from app.api.v1.endpoints.chat import push_notification
    import asyncio
    asyncio.create_task(push_notification(req["user_email"], {
        "type":            "price_change_proposed",
        "service_name":    req.get("service_name", ""),
        "worker_username": current_user.get("username", ""),
        "old_price":       int(req.get("agreed_price") or req.get("service_price") or 0),
        "new_price":       body.new_price,
        "request_id":      request_id,
    }))
    return {"message": "Price proposal sent to client"}


@router.post("/{request_id}/confirm-price", response_model=MessageResponse)
async def confirm_price(
    request_id: str,
    accept: bool = True,
    current_user: dict = Depends(get_current_user),
):
    """User يوافق أو يرفض السعر الجديد."""
    req = _req_or_404(request_id)
    _assert_online(req)

    if req["user_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Only the client can confirm the price")

    if req.get("price_status") != "pending_user_approval":
        raise HTTPException(status_code=400, detail="No pending price proposal")

    if payments_collection.find_one({"request_id": request_id}):
        raise HTTPException(status_code=400, detail="Payment already sent")

    from app.api.v1.endpoints.chat import push_notification
    import asyncio

    if accept:
        new_price = req.get("proposed_price", 0)
        try:
            requests_collection.update_one(
                {"_id": ObjectId(request_id)},
                {"$set": {
                    "agreed_price": new_price,
                    "service_price": new_price,
                    "price_status": "confirmed",
                    "proposed_price": None,
                }},
            )
        except Exception:
            requests_collection.update_one(
                {"_id": request_id},
                {"$set": {
                    "agreed_price": new_price,
                    "service_price": new_price,
                    "price_status": "confirmed",
                    "proposed_price": None,
                }},
            )
        asyncio.create_task(push_notification(req["worker_email"], {
            "type":         "price_change_accepted",
            "service_name": req.get("service_name", ""),
            "new_price":    new_price,
            "request_id":   request_id,
        }))
        return {"message": f"Price updated to ${new_price}"}
    else:
        try:
            requests_collection.update_one(
                {"_id": ObjectId(request_id)},
                {"$set": {"price_status": "rejected", "proposed_price": None}},
            )
        except Exception:
            requests_collection.update_one(
                {"_id": request_id},
                {"$set": {"price_status": "rejected", "proposed_price": None}},
            )
        asyncio.create_task(push_notification(req["worker_email"], {
            "type":         "price_change_rejected",
            "service_name": req.get("service_name", ""),
            "request_id":   request_id,
        }))
        return {"message": "Price proposal rejected. Original price remains."}


# ─── Worker Preview (بدون watermark — للوركر فقط) ────────

@router.get("/{request_id}/worker-preview")
async def worker_preview(
    request_id:   str,
    current_user: dict = Depends(get_current_user_flexible),
):
    """
    الوركر يرى الملف الذي رفعه بدون watermark للتحقق منه.
    مقيّد بالـ Worker صاحب الطلب فقط.
    """
    req = _req_or_404(request_id)
    if current_user["email"] != req["worker_email"]:
        raise HTTPException(status_code=403, detail="Only the worker can view this")

    entry = _sa_or_404(request_id)
    file_path = Path(entry["file_path"])
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="File not found on server")

    ct = entry.get("content_type", "application/octet-stream")
    filename = file_path.name

    return FileResponse(
        file_path,
        media_type=ct,
        filename=filename,
        headers={"Content-Disposition": f'inline; filename="{filename}"'},
    )


# ─── Payment ─────────────────────────────────────────────

class PaymentData(BaseModel):
    amount: int


@router.post("/{request_id}/send-payment", response_model=MessageResponse)
async def send_payment(
    request_id: str,
    payment:    PaymentData,
    current_user: dict = Depends(get_current_user),
):
    """
    User يدفع المبلغ — يجب أن يتطابق مع سعر الخدمة.
    المبلغ يُحجز في Escrow حتى يؤكد الطرفان.
    """
    req = _req_or_404(request_id)
    _assert_online(req)

    if req["user_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    # تحقق أن الملف مرفوع قبل الدفع
    entry = safe_area_collection.find_one({"request_id": request_id})
    if not entry:
        raise HTTPException(status_code=400, detail="Worker has not uploaded work yet")

    # تحقق مطابقة المبلغ — agreed_price (من offer) أو service_price
    expected_price = int(req.get("agreed_price") or req.get("service_price") or 0)
    if expected_price > 0 and payment.amount != expected_price:
        raise HTTPException(
            status_code=400,
            detail=f"Payment amount must match the service price (${expected_price})"
        )

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

    # إشعار الـ Worker أن الـ User أرسل الدفع
    from app.api.v1.endpoints.chat import push_notification
    import asyncio
    asyncio.create_task(push_notification(req["worker_email"], {
        "type":           "payment_received",
        "service_name":   req.get("service_name", ""),
        "user_username":  current_user.get("username", ""),
        "amount":         payment.amount,
        "request_id":     request_id,
    }))

    return {"message": "Payment sent and held in escrow. Confirm the work to release it."}


@router.get("/{request_id}/payment-status")
async def payment_status(
    request_id:   str,
    current_user: dict = Depends(get_current_user),
):
    req = _req_or_404(request_id)
    if current_user["email"] not in (req["user_email"], req["worker_email"]):
        raise HTTPException(status_code=403, detail="Not authorized")

    payment = payments_collection.find_one({"request_id": request_id})
    entry   = safe_area_collection.find_one({"request_id": request_id})

    # السعر المتوقع: agreed_price (من offer) أو service_price (من خدمة مباشرة)
    expected = int(req.get("agreed_price") or req.get("service_price") or 0)

    return {
        "payment_received":  payment is not None,
        "amount":            payment["amount"] if payment else 0,
        "expected_price":    expected,
        "file_uploaded":     entry is not None,
        "has_proof_image":   bool(entry and entry.get("proof_image_path")),
        "is_image":          bool(entry and entry.get("is_image")),
        "worker_confirmed":  bool(entry and entry.get("worker_confirmed")),
        "user_confirmed":    bool(entry and entry.get("user_confirmed")),
        "proposed_price":    req.get("proposed_price"),
        "price_status":      req.get("price_status"),
    }


# ─── Confirm ─────────────────────────────────────────────

@router.post("/{request_id}/confirm", response_model=MessageResponse)
async def confirm_deal(
    request_id:   str,
    current_user: dict = Depends(get_current_user),
):
    """كلا الطرفين يضغط Confirm → يُكمل الصفقة ويُحرر المال للعامل."""
    req   = _req_or_404(request_id)
    _assert_online(req)
    entry = _sa_or_404(request_id)

    if not entry.get("payment_confirmed"):
        raise HTTPException(status_code=400, detail="Payment must be sent before confirming")

    update: dict = {}
    if current_user["email"] == req["worker_email"]:
        update["worker_confirmed"] = True
    elif current_user["email"] == req["user_email"]:
        update["user_confirmed"] = True
    else:
        raise HTTPException(status_code=403, detail="Not authorized")

    safe_area_collection.update_one({"request_id": request_id}, {"$set": update})
    entry = safe_area_collection.find_one({"request_id": request_id})

    from app.api.v1.endpoints.chat import push_notification
    import asyncio

    if entry.get("worker_confirmed") and entry.get("user_confirmed"):
        # أكمل الطلب
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

        event = {
            "type":         "deal_complete",
            "service_name": req.get("service_name", ""),
            "request_id":   request_id,
        }
        for email in [req["user_email"], req["worker_email"]]:
            asyncio.create_task(push_notification(email, event))

        return {"message": "Deal completed! File is now available for download."}

    # أحد الطرفين أكّد — أخطر الطرف الآخر
    if current_user["email"] == req["worker_email"]:
        # الوركر أكّد → أخطر اليوزر
        asyncio.create_task(push_notification(req["user_email"], {
            "type":             "worker_confirmed_waiting",
            "service_name":     req.get("service_name", ""),
            "worker_username":  current_user.get("username", ""),
            "request_id":       request_id,
        }))
    else:
        # اليوزر أكّد → أخطر الوركر
        asyncio.create_task(push_notification(req["worker_email"], {
            "type":            "user_confirmed_waiting",
            "service_name":    req.get("service_name", ""),
            "user_username":   current_user.get("username", ""),
            "request_id":      request_id,
        }))

    return {"message": "Your confirmation recorded. Waiting for the other party."}


# ─── In-Person Confirm ────────────────────────────────────

@router.post("/{request_id}/confirm-inperson", response_model=MessageResponse)
async def confirm_inperson(
    request_id:   str,
    current_user: dict = Depends(get_current_user),
):
    """
    للخدمات على أرض الواقع (in_person).
    كلا الطرفين يضغط لتأكيد إتمام العمل — بدون Safe Area أو دفع عبر التطبيق.
    عند تأكيد الطرفين: status → completed ويُفتح باب التقييم.
    """
    req = _req_or_404(request_id)
    if req.get("delivery_type", "online") != "in_person":
        raise HTTPException(
            status_code=400,
            detail="This endpoint is for in-person services only. Use /confirm for online delivery."
        )
    if current_user["email"] not in (req["user_email"], req["worker_email"]):
        raise HTTPException(status_code=403, detail="Not authorized")

    # نستخدم safe_area collection لتخزين حالة التأكيد (بدون ملفات)
    entry = safe_area_collection.find_one({"request_id": request_id})
    if not entry:
        safe_area_collection.insert_one({
            "request_id":      request_id,
            "is_inperson":     True,
            "worker_confirmed": False,
            "user_confirmed":   False,
        })
        entry = safe_area_collection.find_one({"request_id": request_id})

    update: dict = {}
    if current_user["email"] == req["worker_email"]:
        update["worker_confirmed"] = True
    else:
        update["user_confirmed"] = True

    safe_area_collection.update_one({"request_id": request_id}, {"$set": update})
    entry = safe_area_collection.find_one({"request_id": request_id})

    from app.api.v1.endpoints.chat import push_notification
    import asyncio

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

        event = {
            "type":         "deal_complete",
            "service_name": req.get("service_name", ""),
            "request_id":   request_id,
        }
        for email in [req["user_email"], req["worker_email"]]:
            asyncio.create_task(push_notification(email, event))

        return {"message": "Work confirmed by both parties. Deal completed!"}

    # أحد الطرفين أكّد — أخطر الطرف الآخر
    if current_user["email"] == req["worker_email"]:
        asyncio.create_task(push_notification(req["user_email"], {
            "type":             "worker_confirmed_waiting",
            "service_name":     req.get("service_name", ""),
            "worker_username":  current_user.get("username", ""),
            "request_id":       request_id,
        }))
    else:
        asyncio.create_task(push_notification(req["worker_email"], {
            "type":            "user_confirmed_waiting",
            "service_name":    req.get("service_name", ""),
            "user_username":   current_user.get("username", ""),
            "request_id":      request_id,
        }))

    return {"message": "Your confirmation recorded. Waiting for the other party."}


# ─── Download ────────────────────────────────────────────

@router.get("/{request_id}/download")
async def download_work(
    request_id:   str,
    current_user: dict = Depends(get_current_user_flexible),
):
    """يُحمِّل الملف الأصلي بعد تأكيد كلا الطرفين."""
    req = _req_or_404(request_id)
    _assert_online(req)

    if current_user["email"] not in (req["user_email"], req["worker_email"]):
        raise HTTPException(status_code=403, detail="Not authorized")

    entry = _sa_or_404(request_id)
    if not (entry.get("worker_confirmed") and entry.get("user_confirmed")):
        raise HTTPException(
            status_code=403,
            detail="Both parties must confirm before downloading"
        )

    fp = Path(entry["file_path"])
    if not fp.exists():
        raise HTTPException(status_code=404, detail="File not found")

    return FileResponse(
        fp,
        media_type=entry.get("content_type", "application/octet-stream"),
        filename=fp.name,
    )


# ─── Balance ─────────────────────────────────────────────

@router.get("/balance/{worker_email}")
async def get_balance(
    worker_email: str,
    current_user: dict = Depends(get_current_user),
):
    if current_user["email"] != worker_email:
        raise HTTPException(status_code=403, detail="Not authorized")

    completed_ids = {
        str(r["_id"])
        for r in requests_collection.find(
            {"worker_email": worker_email, "status": "completed"}
        )
    }
    payments = list(payments_collection.find({"worker_email": worker_email}))
    total = sum(p["amount"] for p in payments if p["request_id"] in completed_ids)
    return {"balance": total, "currency": "USD"}
