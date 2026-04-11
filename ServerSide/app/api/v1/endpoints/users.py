import logging
from fastapi import APIRouter, HTTPException, status, Depends
from bson import ObjectId

from app.schemas import UserOut, UserProfileUpdate
from app.services import UserService
from app.api.v1.dependencies import get_current_user
from app.db import get_database, CollectionNames

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/users", tags=["Users"])


@router.get("/me", response_model=UserOut)
async def get_current_user_info(current_user: dict = Depends(get_current_user)):
    """Get current user profile."""
    try:
        # Remove password before returning
        current_user.pop("password", None)
        return UserOut(
            id=current_user.get("_id", ""),
            username=current_user.get("username", ""),
            email=current_user.get("email", ""),
            userType=current_user.get("userType", ""),
            number=current_user.get("number"),
            city=current_user.get("city"),
            speciality=current_user.get("speciality"),
            imageBase64=current_user.get("imageBase64"),
            introduction=current_user.get("introduction"),
            facebook=current_user.get("facebook"),
            instagram=current_user.get("instagram"),
            telegram=current_user.get("telegram"),
        )
    except Exception as e:
        logger.error(f"Error fetching current user info: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch user info",
        )


@router.get("/{user_id}", response_model=UserOut)
async def get_user(user_id: str):
    """Get user by ID."""
    try:
        user = UserService.get_user_for_response(user_id)

        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
            )

        return UserOut(
            id=user.get("_id", ""),
            username=user.get("username", ""),
            email=user.get("email", ""),
            userType=user.get("userType", ""),
            number=user.get("number"),
            city=user.get("city"),
            speciality=user.get("speciality"),
            imageBase64=user.get("imageBase64"),
            introduction=user.get("introduction"),
            facebook=user.get("facebook"),
            instagram=user.get("instagram"),
            telegram=user.get("telegram"),
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching user: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch user",
        )


@router.put("/{user_id}", response_model=UserOut)
async def update_user(
    user_id: str,
    profile_update: UserProfileUpdate,
    current_user: dict = Depends(get_current_user),
):
    """Update user profile."""
    try:
        if current_user.get("_id") != user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN, detail="Unauthorized"
            )

        update_data = profile_update.dict(exclude_unset=True)
        updated_user = UserService.update_user_profile(user_id, update_data)

        if not updated_user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
            )

        return UserOut(
            id=updated_user.get("_id", ""),
            username=updated_user.get("username", ""),
            email=updated_user.get("email", ""),
            userType=updated_user.get("userType", ""),
            number=updated_user.get("number"),
            city=updated_user.get("city"),
            speciality=updated_user.get("speciality"),
            imageBase64=updated_user.get("imageBase64"),
            introduction=updated_user.get("introduction"),
            facebook=updated_user.get("facebook"),
            instagram=updated_user.get("instagram"),
            telegram=updated_user.get("telegram"),
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating user: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update user",
        )


@router.get("")
async def get_user_by_email(email: str = None):
    """Get user by email."""
    try:
        if not email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email parameter is required",
            )

        user = UserService.get_user_by_email(email)

        if not user:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
            )

        user.pop("password", None)
        return user
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching user by email: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch user",
        )
