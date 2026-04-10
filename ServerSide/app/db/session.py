"""
Database connection and session management.
"""

from typing import Optional
import logging
from pymongo import MongoClient
from pymongo.errors import ConnectionFailure, ServerSelectionTimeoutError
import motor.motor_asyncio

from app.core import settings

logger = logging.getLogger(__name__)


class MongoDB:
    """MongoDB connection manager."""

    client: Optional[MongoClient] = None
    db = None

    @classmethod
    async def connect_db(cls):
        """Establish database connection."""
        try:
            cls.client = MongoClient(settings.MONGODB_URL)
            # Verify connection
            cls.client.admin.command("ping")
            cls.db = cls.client[settings.DATABASE_NAME]
            logger.info("✓ Successfully connected to MongoDB")
        except (ConnectionFailure, ServerSelectionTimeoutError) as e:
            logger.error(f"✗ Failed to connect to MongoDB: {str(e)}")
            raise

    @classmethod
    async def close_db(cls):
        """Close database connection."""
        if cls.client:
            cls.client.close()
            logger.info("✓ MongoDB connection closed")

    @classmethod
    def get_db(cls):
        """Get database instance."""
        if cls.db is None:
            raise Exception("Database not connected. Call connect_db() first.")
        return cls.db


# Singleton pattern for database connection
_db_instance: Optional[MongoDB] = None


def get_database():
    """Get database connection instance."""
    return MongoDB.get_db()


# Collection names as constants to avoid typos
class CollectionNames:
    """MongoDB collection names."""

    USERS = "users-register"
    SESSIONS = "user-sessions"
    SERVICES = "services"
    POSTS = "user-posts"
    REQUESTS = "service-requests"
    MESSAGES = "messages"
    BLOCKED_USERS = "users-block"
    REPORTS = "reports"
    REVIEWS = "reviews"
    SAFE_AREA = "safe_area"
    PAYMENTS = "payments"
