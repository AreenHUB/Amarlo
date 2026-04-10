"""
Configuration management for the application.
Handles environment variables and application settings.
"""

import os
import logging
from typing import List
from functools import lru_cache
import secrets

from pydantic_settings import BaseSettings
from pydantic import field_validator


class Settings(BaseSettings):
    """Application settings read from environment variables."""

    # Database
    MONGODB_URL: str = os.getenv("MONGODB_URL", "mongodb://localhost:27017/")
    DATABASE_NAME: str = os.getenv("DATABASE_NAME", "flutter-app2")

    # Security
    SECRET_KEY: str = os.getenv("SECRET_KEY", secrets.token_urlsafe(32))
    ALGORITHM: str = os.getenv("ALGORITHM", "HS256")
    ACCESS_TOKEN_EXPIRE_MINUTES: int = int(
        os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "10080")
    )

    # API
    API_TITLE: str = os.getenv("API_TITLE", "Amarlo API")
    API_VERSION: str = os.getenv("API_VERSION", "1.0.0")
    DEBUG: bool = os.getenv("DEBUG", "False").lower() == "true"

    # Server
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))

    # CORS
    CORS_ORIGINS: List[str] = [
        "http://localhost",
        "http://localhost:8080",
        "http://10.0.2.2:8000",
    ]

    # Logging
    LOG_LEVEL: str = os.getenv("LOG_LEVEL", "INFO")

    # File Upload
    MAX_UPLOAD_SIZE: int = int(os.getenv("MAX_UPLOAD_SIZE", "52428800"))  # 50MB
    ALLOWED_EXTENSIONS_RAW: str = "pdf,doc,docx,txt,zip,rar"

    @property
    def ALLOWED_EXTENSIONS(self) -> List[str]:
        return [
            item.strip()
            for item in self.ALLOWED_EXTENSIONS_RAW.split(",")
            if item.strip()
        ]

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def parse_cors_origins(cls, value):
        if isinstance(value, str):
            value = value.strip()
            if value.startswith("[") and value.endswith("]"):
                return [
                    item.strip().strip('"').strip("'")
                    for item in value[1:-1].split(",")
                    if item.strip()
                ]
            return [item.strip() for item in value.split(",") if item.strip()]
        return value

    model_config = {
        "env_file": ".env",
        "case_sensitive": True,
        "extra": "ignore",
    }


@lru_cache()
def get_settings() -> Settings:
    """Get cached application settings."""
    return Settings()


def setup_logging():
    """Configure logging for the application."""
    settings = get_settings()

    logging.basicConfig(
        level=settings.LOG_LEVEL,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
        handlers=[
            logging.StreamHandler(),
            (
                logging.FileHandler("logs/app.log")
                if os.path.exists("logs")
                else logging.StreamHandler()
            ),
        ],
    )

    return logging.getLogger(__name__)


# Initialize settings
settings = get_settings()
logger = setup_logging()
