"""
core/config.py
──────────────
كل الإعدادات في مكان واحد.
BASE_URL يُقرأ من متغير بيئة SERVER_HOST (اختياري).
"""
import os
import secrets
from pathlib import Path

# ─── Paths ───────────────────────────────────────────────
BASE_DIR   = Path(__file__).resolve().parent.parent
UPLOAD_DIR = BASE_DIR / "uploads"
PROFILES_DIR  = UPLOAD_DIR / "profiles"
SERVICES_DIR  = UPLOAD_DIR / "services"
SAFE_AREA_DIR = UPLOAD_DIR / "safe_area"

for _d in [PROFILES_DIR, SERVICES_DIR, SAFE_AREA_DIR]:
    _d.mkdir(parents=True, exist_ok=True)

# ─── JWT ─────────────────────────────────────────────────
SECRET_KEY               = secrets.token_urlsafe(32)
ALGORITHM                = "HS256"
TOKEN_EXPIRATION_MINUTES = 60 * 24 * 7   # 7 days

# ─── Server URL ──────────────────────────────────────────
# يُقرأ من متغير بيئة SERVER_HOST إذا وُجد، وإلا يستخدم localhost
# عند تشغيل السيرفر:
#   SERVER_HOST=192.168.1.5 uvicorn main:app ...
_host = os.getenv("SERVER_HOST", "localhost")
_port = int(os.getenv("SERVER_PORT", "8000"))

SERVER_HOST = _host
SERVER_PORT = _port
BASE_URL    = f"http://{_host}:{_port}"

# ─── Pagination ──────────────────────────────────────────
DEFAULT_PAGE_SIZE = 20
MAX_PAGE_SIZE     = 100

# ─── Image upload limits ─────────────────────────────────
MAX_IMAGE_SIZE_MB = 10   # رُفع إلى 10MB

# نقبل كل صيغ الصور الشائعة + octet-stream كـ fallback
ALLOWED_IMAGE_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
    "image/gif",
    "application/octet-stream",   # Flutter يُرسل هذا أحياناً
}
