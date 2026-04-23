"""
app/core/security.py
────────────────────
JWT authentication with access + refresh tokens.

- access_token  : قصير العمر (30 دقيقة) - يُستخدم في كل طلب
- refresh_token : طويل العمر (30 يوم)   - يُستخدم فقط لتجديد access_token
"""
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional, Tuple

from jose import JWTError, jwt
from passlib.context import CryptContext

from app.core.config import settings

# ─── Password hashing ────────────────────────
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    try:
        return pwd_context.verify(plain, hashed)
    except Exception:
        return False


# ─── Token creation ──────────────────────────
def _create_token(
    subject: str,
    token_type: str,
    expires_delta: timedelta,
    extra: Optional[dict] = None,
) -> str:
    """يُنشئ JWT token مع النوع والانتهاء."""
    expire = datetime.now(timezone.utc) + expires_delta
    jti = str(uuid.uuid4())  # unique id for refresh rotation

    payload = {
        "sub": subject,
        "type": token_type,
        "exp": expire,
        "iat": datetime.now(timezone.utc),
        "jti": jti,
    }
    if extra:
        payload.update(extra)

    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def create_access_token(subject: str, extra: Optional[dict] = None) -> str:
    return _create_token(
        subject=subject,
        token_type="access",
        expires_delta=timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES),
        extra=extra,
    )


def create_refresh_token(subject: str) -> Tuple[str, str]:
    """
    يُنشئ refresh token مع JTI فريد.
    يُعيد (token, jti) — الـ jti يُحفظ في DB لإبطاله عند الحاجة.
    """
    jti = str(uuid.uuid4())
    expire = datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)

    payload = {
        "sub": subject,
        "type": "refresh",
        "exp": expire,
        "iat": datetime.now(timezone.utc),
        "jti": jti,
    }
    token = jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)
    return token, jti


def create_token_pair(subject: str, extra: Optional[dict] = None) -> dict:
    """ينشئ الـ access + refresh tokens معاً."""
    access = create_access_token(subject, extra)
    refresh, jti = create_refresh_token(subject)

    return {
        "access_token": access,
        "refresh_token": refresh,
        "refresh_jti": jti,
        "token_type": "bearer",
        "expires_in": settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
    }


# ─── Token decoding ──────────────────────────
def decode_token(token: str, expected_type: Optional[str] = None) -> dict:
    """
    يفك تشفير JWT. يرفع JWTError في حال:
      - انتهاء الصلاحية
      - توقيع غير صحيح
      - نوع غير متوقع
    """
    payload = jwt.decode(
        token,
        settings.JWT_SECRET_KEY,
        algorithms=[settings.JWT_ALGORITHM],
    )
    if expected_type and payload.get("type") != expected_type:
        raise JWTError(f"Expected token type '{expected_type}', got '{payload.get('type')}'")
    return payload
