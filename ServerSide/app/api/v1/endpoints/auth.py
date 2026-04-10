"""
Authentication API router.
Handles user registration, login, and logout.
"""

import logging
from fastapi import APIRouter, HTTPException, status, Header, Depends
from datetime import timedelta

from app.schemas import UserCreate, UserLogin, UserOut
from app.services import AuthService, UserService
from app.utils import create_access_token
from app.db import get_database, CollectionNames
from app.api.v1.dependencies import get_current_user

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/auth", tags=["Authentication"])


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
async def register(user: UserCreate):
    """
    Register a new user.

    Args:
        user: User registration data

    Returns:
        UserOut: Registered user data

    Raises:
        HTTPException: If registration fails
    """
    try:
        user_data = AuthService.register_user(user)
        result = UserOut(
            id=user_data["_id"],
            username=user_data["username"],
            email=user_data["email"],
            userType=user_data["userType"],
            speciality=user_data.get("speciality"),
            imageBase64=user_data.get("imageBase64"),
            introduction=user_data.get("introduction"),
            number=user_data.get("number"),
            city=user_data.get("city"),
        )
        return result
    except ValueError as e:
        logger.warning(f"Registration failed: {str(e)}")
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
    except Exception as e:
        logger.error(f"Registration error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Registration failed",
        )


@router.post("/login")
async def login(credentials: UserLogin):
    """
    Login user and return access token.

    Args:
        credentials: User login credentials

    Returns:
        dict: Access token and user info

    Raises:
        HTTPException: If login fails
    """
    try:
        user = AuthService.authenticate_user(credentials.email, credentials.password)

        if not user:
            logger.warning(f"Failed login attempt for: {credentials.email}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid email or password",
            )

        response = AuthService.create_login_response(user)
        logger.info(f"User logged in: {credentials.email}")
        return response

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Login error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Login failed"
        )


@router.post("/logout", status_code=status.HTTP_200_OK)
async def logout(current_user: dict = Depends(get_current_user)):
    """
    Logout user.
    """
    try:
        logger.info(f"User logged out: {current_user.get('email')}")
        return {"message": "Logged out successfully"}
    except Exception as e:
        logger.error(f"Logout error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Logout failed",
        )
