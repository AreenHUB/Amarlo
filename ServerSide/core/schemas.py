from typing import Generic, List, Optional, TypeVar
from pydantic import BaseModel
from fastapi import Query
import math

T = TypeVar("T")


# ─── Pagination ──────────────────────────────────────────
class PaginationParams:
    def __init__(
        self,
        page: int = Query(1, ge=1, description="Page number"),
        size: int = Query(20, ge=1, le=100, description="Items per page"),
    ):
        self.page = page
        self.size = size
        self.skip = (page - 1) * size


class PagedResponse(BaseModel, Generic[T]):
    items: List[T]
    total: int
    page: int
    size: int
    pages: int

    @classmethod
    def build(cls, items: List[T], total: int, params: PaginationParams):
        return cls(
            items=items,
            total=total,
            page=params.page,
            size=params.size,
            pages=math.ceil(total / params.size) if params.size else 1,
        )


# ─── Common response ─────────────────────────────────────
class MessageResponse(BaseModel):
    message: str


# ─── User schemas ────────────────────────────────────────
class UserOut(BaseModel):
    id: str
    username: str
    email: str
    userType: str
    speciality: Optional[str] = None
    image_url: Optional[str] = None          # ← URL بدل base64
    introduction: Optional[str] = None
    facebook: Optional[str] = None
    instagram: Optional[str] = None
    telegram: Optional[str] = None
    number: Optional[str] = None
    city: Optional[str] = None

    @classmethod
    def from_doc(cls, doc: dict) -> "UserOut":
        return cls(
            id=str(doc["_id"]),
            username=doc.get("username", ""),
            email=doc.get("email", ""),
            userType=doc.get("userType", ""),
            speciality=doc.get("speciality"),
            image_url=doc.get("image_url"),
            introduction=doc.get("introduction"),
            facebook=doc.get("facebook"),
            instagram=doc.get("instagram"),
            telegram=doc.get("telegram"),
            number=doc.get("number"),
            city=doc.get("city"),
        )


# ─── Service schemas ─────────────────────────────────────
class ServiceOut(BaseModel):
    id: str
    name: str
    location: str
    price: float
    worker_email: str
    worker_username: str
    image_url: Optional[str] = None          # ← URL بدل base64
    description: str
    category: Optional[str] = None

    @classmethod
    def from_doc(cls, doc: dict, worker_username: str = "Unknown") -> "ServiceOut":
        return cls(
            id=str(doc["_id"]),
            name=doc["name"],
            location=doc["location"],
            price=float(doc["price"]),
            worker_email=doc["worker_email"],
            worker_username=worker_username,
            image_url=doc.get("image_url"),
            description=doc.get("description", ""),
            category=doc.get("category"),
        )
