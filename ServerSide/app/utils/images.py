"""
app/utils/images.py
───────────────────
Image upload utility — detects type from magic bytes, uses request host.
"""
import imghdr
import uuid
from pathlib import Path
from typing import Optional

from fastapi import HTTPException, Request, UploadFile, status

from app.core.config import settings

_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".gif"}
_IMGHDR_EXT = {"jpeg": ".jpg", "png": ".png", "gif": ".gif", "webp": ".webp"}


def _folder_path(folder: str) -> Path:
    mapping = {
        "profiles":  settings.PROFILES_PATH,
        "services":  settings.SERVICES_PATH,
        "safe_area": settings.SAFE_AREA_PATH,
    }
    if folder not in mapping:
        raise ValueError(f"Unknown folder: {folder}")
    return mapping[folder]


def _is_image(data: bytes, content_type: str, filename: str) -> bool:
    ct = (content_type or "").lower()
    if any(ct.startswith(t) for t in
           ["image/jpeg", "image/jpg", "image/png", "image/webp", "image/gif"]):
        return True
    if imghdr.what(None, h=data):
        return True
    return Path(filename or "").suffix.lower() in _IMAGE_EXTENSIONS


def _pick_extension(data: bytes, filename: str) -> str:
    ext = Path(filename or "").suffix.lower()
    if ext in _IMAGE_EXTENSIONS:
        return ext
    detected = imghdr.what(None, h=data)
    return _IMGHDR_EXT.get(detected or "", ".jpg")


def _build_url(request: Optional[Request], folder: str, filename: str) -> str:
    """Build URL matching the request host."""
    if request is not None:
        base = str(request.base_url).rstrip("/")
        return f"{base}/uploads/{folder}/{filename}"
    return f"http://{settings.SERVER_HOST}:{settings.SERVER_PORT}/uploads/{folder}/{filename}"


async def save_upload_image(
    file: UploadFile,
    folder: str,
    request: Optional[Request] = None,
) -> str:
    """Save image to disk and return public URL."""
    content = await file.read()

    if not content:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Empty file received.",
        )

    max_bytes = settings.MAX_IMAGE_SIZE_MB * 1024 * 1024
    if len(content) > max_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Image too large (max {settings.MAX_IMAGE_SIZE_MB} MB).",
        )

    if not _is_image(content, file.content_type or "", file.filename or ""):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File does not appear to be an image.",
        )

    ext = _pick_extension(content, file.filename or "upload.jpg")
    filename_out = f"{uuid.uuid4().hex}{ext}"
    dest_dir = _folder_path(folder)
    dest_dir.mkdir(parents=True, exist_ok=True)
    (dest_dir / filename_out).write_bytes(content)

    return _build_url(request, folder, filename_out)


def delete_image_file(url: Optional[str]) -> None:
    """Delete image file by URL (best-effort)."""
    if not url:
        return
    try:
        parts = url.split("/uploads/", 1)
        if len(parts) == 2:
            folder, fname = parts[1].split("/", 1)
            (_folder_path(folder) / fname).unlink(missing_ok=True)
    except Exception:
        pass
