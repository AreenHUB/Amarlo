"""
User service.
Handles user operations like profile updates, user retrieval, etc.
"""

import logging
from typing import Optional, Dict, Any

from app.db import get_database, CollectionNames
from app.utils import convert_object_id_to_string, sanitize_string

logger = logging.getLogger(__name__)


class UserService:
    """Service for user operations."""

    @staticmethod
    def get_user_by_email(email: str) -> Optional[Dict[str, Any]]:
        """
        Get user by email.

        Args:
            email: User email

        Returns:
            dict: User data or None
        """
        try:
            db = get_database()
            users_collection = db[CollectionNames.USERS]
            user = users_collection.find_one({"email": email})
            return user
        except Exception as e:
            logger.error(f"Error fetching user: {str(e)}")
            return None

    @staticmethod
    def update_user_profile(
        user_id: str, update_data: Dict[str, Any]
    ) -> Optional[Dict[str, Any]]:
        """
        Update user profile.

        Args:
            user_id: User ID
            update_data: Data to update

        Returns:
            dict: Updated user data or None
        """
        try:
            db = get_database()
            users_collection = db[CollectionNames.USERS]

            # Sanitize string fields
            if "username" in update_data:
                update_data["username"] = sanitize_string(update_data["username"], 50)
            if "introduction" in update_data:
                update_data["introduction"] = sanitize_string(
                    update_data["introduction"], 500
                )

            result = users_collection.update_one(
                {"_id": user_id}, {"$set": update_data}
            )

            if result.matched_count == 0:
                return None

            updated_user = users_collection.find_one({"_id": user_id})
            logger.info(f"User profile updated: {user_id}")
            return updated_user

        except Exception as e:
            logger.error(f"Error updating user profile: {str(e)}")
            return None

    @staticmethod
    def get_user_for_response(user_id: str) -> Optional[Dict[str, Any]]:
        """
        Get user data formatted for API response.

        Args:
            user_id: User ID

        Returns:
            dict: User data for response or None
        """
        try:
            db = get_database()
            users_collection = db[CollectionNames.USERS]
            user = users_collection.find_one({"_id": user_id})

            if not user:
                return None

            # Remove sensitive data
            user.pop("password", None)
            return user

        except Exception as e:
            logger.error(f"Error fetching user for response: {str(e)}")
            return None
