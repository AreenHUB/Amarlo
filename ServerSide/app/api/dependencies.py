"""
app/api/dependencies.py
───────────────────────
Shared API dependencies - auth, pagination, etc.
"""
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError

from app.core.security import decode_token
from app.db import users_collection

# ─── OAuth2 scheme (for /docs Authorize button) ─────
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/token", auto_error=False)


def _get_user_from_token(token: str) -> dict:
    """Decode access token and return the user document."""
    credentials_exc = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = decode_token(token, expected_type="access")
    except JWTError:
        raise credentials_exc

    email = payload.get("sub")
    if not email:
        raise credentials_exc

    user = users_collection.find_one({"email": email})
    if not user:
        raise credentials_exc
    return user


async def get_current_user(
    token: Optional[str] = Depends(oauth2_scheme),
) -> dict:
    """Required auth dependency."""
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return _get_user_from_token(token)


async def get_current_user_optional(
    token: Optional[str] = Depends(oauth2_scheme),
) -> Optional[dict]:
    """Optional auth dependency — returns None if no token."""
    if not token:
        return None
    try:
        return _get_user_from_token(token)
    except HTTPException:
        return None


async def get_current_user_ws(token: str) -> dict:
    """WebSocket auth — token from query string."""
    if not token:
        raise HTTPException(status_code=401, detail="Not authenticated")
    return _get_user_from_token(token)


async def require_worker(current: dict = Depends(get_current_user)) -> dict:
    """Only workers can call this."""
    if current.get("userType") != "Worker":
        raise HTTPException(status_code=403, detail="Workers only")
    return current
