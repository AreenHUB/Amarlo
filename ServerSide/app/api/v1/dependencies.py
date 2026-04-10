"""
Dependency functions for API endpoints.
"""

import logging
from fastapi import Header, HTTPException, status

from app.utils import extract_token_from_header, decode_token
from app.services import UserService

logger = logging.getLogger(__name__)


async def get_current_user(authorization: str = Header(None, alias="Authorization")):
    """
    Get current authenticated user from JWT token.

    Args:
        authorization: Authorization header

    Returns:
        dict: Current user data

    Raises:
        HTTPException: If authentication fails
    """
    try:
        token = extract_token_from_header(authorization)
        payload = decode_token(token)
        email = payload.get("sub")

        if not email:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token",
                headers={"WWW-Authenticate": "Bearer"},
            )

        user = UserService.get_user_by_email(email)

        if not user:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found",
                headers={"WWW-Authenticate": "Bearer"},
            )

        return user

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting current user: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication failed",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def get_optional_user(authorization: str = Header(None, alias="Authorization")):
    """
    Get current user if authenticated, otherwise return None.

    Args:
        authorization: Authorization header

    Returns:
        dict or None: Current user data or None
    """
    if not authorization:
        return None

    try:
        return await get_current_user(authorization)
    except HTTPException:
        return None
