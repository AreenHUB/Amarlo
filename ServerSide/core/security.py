"""
core/security.py
────────────────
JWT + OAuth2PasswordBearer (يُظهر زر Authorize في /docs).
"""
from datetime import datetime, timedelta
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext

from core.config import ALGORITHM, SECRET_KEY
from core.database import users_collection

# ─── Password ────────────────────────────────────────────
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)


# ─── JWT ─────────────────────────────────────────────────
def create_access_token(data: dict, expires_delta: timedelta) -> str:
    payload = {**data, "exp": datetime.utcnow() + expires_delta}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


# ─── OAuth2 scheme ───────────────────────────────────────
# tokenUrl = endpoint الذي يُعيد التوكن (للـ /docs Authorize)
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token", auto_error=False)


def _decode(token: str) -> dict:
    exc = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: Optional[str] = payload.get("sub")
        if not email:
            raise exc
    except JWTError:
        raise exc

    user = users_collection.find_one({"email": email})
    if not user:
        raise exc
    return user


async def get_current_user(
    token: Optional[str] = Depends(oauth2_scheme),
) -> dict:
    """Dependency للـ protected REST endpoints."""
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated — please login first",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return _decode(token)


async def get_current_user_ws(token: str) -> dict:
    """Dependency للـ WebSocket — token من query string."""
    if not token:
        raise HTTPException(status_code=401, detail="Not authenticated")
    return _decode(token)


async def authenticate_user(email: str, password: str) -> Optional[dict]:
    user = users_collection.find_one({"email": email})
    if not user or not verify_password(password, user["password"]):
        return None
    return user
