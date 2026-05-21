"""
app/core/config.py
─────────────────
Settings management using pydantic-settings.
Reads from .env file automatically.
"""
from functools import lru_cache
from pathlib import Path
from typing import List

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # Application
    APP_NAME: str = "Amarlo API"
    APP_VERSION: str = "2.0.0"
    ENVIRONMENT: str = "development"
    DEBUG: bool = True

    # Server
    SERVER_HOST: str = "0.0.0.0"
    SERVER_PORT: int = 8000

    # MongoDB
    MONGO_URI: str = "mongodb://localhost:27017"
    MONGO_DB_NAME: str = "amarlo_db"

    # JWT
    JWT_SECRET_KEY: str = Field(..., min_length=32)
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # CORS
    CORS_ORIGINS: str = "*"

    # Uploads
    MAX_IMAGE_SIZE_MB: int = 10    # profile / service images
    MAX_SAFE_AREA_SIZE_MB: int = 50 # safe area work files (code zips, PDFs, etc.)
    UPLOAD_DIR: str = "uploads"

    # Pagination
    DEFAULT_PAGE_SIZE: int = 20
    MAX_PAGE_SIZE: int = 100

    # ─── Computed properties ─────────────────
    @property
    def BASE_DIR(self) -> Path:
        return Path(__file__).resolve().parent.parent.parent

    @property
    def UPLOAD_PATH(self) -> Path:
        return self.BASE_DIR / self.UPLOAD_DIR

    @property
    def PROFILES_PATH(self) -> Path:
        return self.UPLOAD_PATH / "profiles"

    @property
    def SERVICES_PATH(self) -> Path:
        return self.UPLOAD_PATH / "services"

    @property
    def SAFE_AREA_PATH(self) -> Path:
        return self.UPLOAD_PATH / "safe_area"

    @property
    def cors_origins_list(self) -> List[str]:
        if self.CORS_ORIGINS == "*":
            return ["*"]
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",")]

    @property
    def is_production(self) -> bool:
        return self.ENVIRONMENT.lower() == "production"


@lru_cache()
def get_settings() -> Settings:
    """Cached settings instance - read once, use everywhere."""
    return Settings()


settings = get_settings()

# Ensure upload directories exist
for _p in [settings.PROFILES_PATH, settings.SERVICES_PATH, settings.SAFE_AREA_PATH]:
    _p.mkdir(parents=True, exist_ok=True)
