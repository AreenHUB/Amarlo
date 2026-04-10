"""
Authentication service.
Handles user registration, login, and token management.
"""

import logging
from datetime import timedelta
from typing import Optional, Dict, Any

from app.db import get_database, CollectionNames
from app.utils import hash_password, verify_password, create_access_token
from app.schemas import UserCreate, UserLogin

logger = logging.getLogger(__name__)


class AuthService:
    """Service for authentication operations."""

    @staticmethod
    def register_user(user_data: UserCreate) -> Dict[str, Any]:
        """
        Register a new user.

        Args:
            user_data: User registration data

        Returns:
            dict: Registered user data

        Raises:
            ValueError: If user already exists or registration fails
        """
        try:
            db = get_database()
            users_collection = db[CollectionNames.USERS]

            # Check if user already exists
            existing_user = users_collection.find_one({"email": user_data.email})
            if existing_user:
                raise ValueError("User with this email already exists")

            existing_user = users_collection.find_one({"number": user_data.number})
            if existing_user:
                raise ValueError("User with this phone number already exists")

            # Hash password
            hashed_password = hash_password(user_data.password)

            # Prepare user document
            user_doc = {
                "_id": user_data.email,  # Use email as primary key
                **user_data.dict(exclude={"password", "image"}),
                "password": hashed_password,
                "imageBase64": user_data.image,
                "created_at": None,  # Will be set by the database
            }

            # Insert user
            users_collection.insert_one(user_doc)

            logger.info(f"User registered successfully: {user_data.email}")
            return user_doc

        except ValueError as e:
            logger.warning(f"User registration failed: {str(e)}")
            raise
        except Exception as e:
            logger.error(f"Error registering user: {str(e)}")
            raise ValueError("Failed to register user")

    @staticmethod
    def authenticate_user(email: str, password: str) -> Optional[Dict[str, Any]]:
        """
        Authenticate user with email and password.

        Args:
            email: User email
            password: User password

        Returns:
            dict: User data if authenticated, None otherwise
        """
        try:
            db = get_database()
            users_collection = db[CollectionNames.USERS]

            user = users_collection.find_one({"email": email})

            if not user or not verify_password(password, user.get("password", "")):
                logger.warning(f"Authentication failed for email: {email}")
                return None

            logger.info(f"User authenticated: {email}")
            return user

        except Exception as e:
            logger.error(f"Error authenticating user: {str(e)}")
            return None

    @staticmethod
    def create_login_response(user: Dict[str, Any]) -> Dict[str, Any]:
        """
        Create login response with access token.

        Args:
            user: User document

        Returns:
            dict: Login response with token
        """
        try:
            access_token_expires = timedelta(minutes=10080)  # 7 days
            access_token = create_access_token(
                data={"sub": user["email"]}, expires_delta=access_token_expires
            )

            return {
                "access_token": access_token,
                "token_type": "bearer",
                "userType": user.get("userType"),
                "user_id": user.get("_id"),
                "email": user.get("email"),
                "username": user.get("username"),
            }
        except Exception as e:
            logger.error(f"Error creating login response: {str(e)}")
            raise
