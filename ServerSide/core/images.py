"""
core/images.py
──────────────
رفع الصور + إعادة URL يستخدم نفس host الطلب الوارد.

الإصلاح الجوهري:
  بدل حفظ BASE_URL الثابت (localhost) في DB،
  نستخدم request.base_url لبناء URL يطابق العنوان الذي يتصل به العميل.
  هكذا يستطيع Flutter جلب الصورة بنفس العنوان الذي أرسل إليه الطلب.
"""
import imghdr
import uuid
from pathlib import Path
from typing import Optional

from fastapi import HTTPException, Request, UploadFile, status

from core.config import (
    MAX_IMAGE_SIZE_MB,
    PROFILES_DIR,
    SAFE_AREA_DIR,
    SERVICES_DIR,
)

_FOLDER_MAP: dict[str, Path] = {
    "profiles":  PROFILES_DIR,
    "services":  SERVICES_DIR,
    "safe_area": SAFE_AREA_DIR,
}

_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".gif"}

_IMGHDR_EXT = {
    "jpeg": ".jpg", "png": ".png",
    "gif": ".gif",  "webp": ".webp",
}


def _is_image(data: bytes, content_type: str, filename: str) -> bool:
    """تحقق إذا كان الملف صورة — من magic bytes أو content_type أو امتداد."""
    ct = (content_type or "").lower()

    # content_type صريح
    if any(ct.startswith(t) for t in
           {"image/jpeg", "image/jpg", "image/png", "image/webp", "image/gif"}):
        return True

    # magic bytes
    if imghdr.what(None, h=data):
        return True

    # امتداد
    return Path(filename or "").suffix.lower() in _IMAGE_EXTENSIONS


def _pick_extension(data: bytes, filename: str) -> str:
    ext = Path(filename or "").suffix.lower()
    if ext in _IMAGE_EXTENSIONS:
        return ext
    detected = imghdr.what(None, h=data)
    return _IMGHDR_EXT.get(detected or "", ".jpg")


def _build_url(request: Optional[Request], folder: str, filename: str) -> str:
    """
    يبني URL للصورة بناءً على host الطلب الوارد.
    مثال: طلب من 127.0.0.1:8000 → http://127.0.0.1:8000/uploads/services/abc.jpg
    """
    if request is not None:
        # base_url = http://host:port/
        base = str(request.base_url).rstrip("/")
        return f"{base}/uploads/{folder}/{filename}"

    # fallback إذا لم يكن request متاحاً
    from core.config import BASE_URL
    return f"{BASE_URL}/uploads/{folder}/{filename}"


async def save_upload_image(
    file: UploadFile,
    folder: str,
    request: Optional[Request] = None,
) -> str:
    """
    يحفظ الصورة على disk ويُعيد URL صحيح بناءً على host الطلب.
    """
    content = await file.read()

    if not content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Empty file received.",
        )

    max_bytes = MAX_IMAGE_SIZE_MB * 1024 * 1024
    if len(content) > max_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Image too large (max {MAX_IMAGE_SIZE_MB} MB).",
        )

    if not _is_image(content, file.content_type or "", file.filename or ""):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File does not appear to be an image "
                   f"(type: {file.content_type or 'unknown'}).",
        )

    ext          = _pick_extension(content, file.filename or "upload.jpg")
    filename_out = f"{uuid.uuid4().hex}{ext}"
    dest_dir     = _FOLDER_MAP[folder]
    dest_dir.mkdir(parents=True, exist_ok=True)
    (dest_dir / filename_out).write_bytes(content)

    return _build_url(request, folder, filename_out)


def delete_image_file(url: Optional[str]) -> None:
    """يحذف الملف المرتبط بـ URL (best-effort)."""
    if not url:
        return
    try:
        parts = url.split("/uploads/", 1)
        if len(parts) == 2:
            folder, fname = parts[1].split("/", 1)
            (_FOLDER_MAP[folder] / fname).unlink(missing_ok=True)
    except Exception:
        pass
