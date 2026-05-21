"""
app/schemas/common.py
─────────────────────
Shared response schemas used across multiple endpoints.
"""
from typing import Generic, List, TypeVar

from fastapi import Query
from pydantic import BaseModel, Field

T = TypeVar("T")


class MessageResponse(BaseModel):
    """Simple message response."""
    message: str


class PaginationParams:
    """FastAPI dependency for pagination."""
    def __init__(
        self,
        page: int = Query(1, ge=1, description="Page number"),
        size: int = Query(20, ge=1, le=500, description="Items per page"),
    ):
        self.page = page
        self.size = size
        self.skip = (page - 1) * size


class PagedResponse(BaseModel, Generic[T]):
    """Generic paginated response."""
    items: List[T]
    total: int
    page: int
    size: int
    pages: int

    @classmethod
    def build(cls, items: List[T], total: int, params: PaginationParams) -> "PagedResponse[T]":
        import math
        return cls(
            items=items,
            total=total,
            page=params.page,
            size=params.size,
            pages=max(1, math.ceil(total / params.size)) if total else 0,
        )


class TokenResponse(BaseModel):
    """Authentication token pair response."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int = Field(..., description="Access token lifetime in seconds")


class LoginResponse(TokenResponse):
    """Login response with user info."""
    user_id: str
    user_type: str
    email: str
    username: str
