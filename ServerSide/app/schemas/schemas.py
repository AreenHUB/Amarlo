"""
Pydantic models for data validation.
These are used for request/response validation.
"""

from datetime import datetime
from typing import Optional, List
from enum import Enum
from pydantic import BaseModel, EmailStr, Field, validator


# ==================== User Models ====================
class UserBase(BaseModel):
    """Base user model with common fields."""

    username: str = Field(..., min_length=3, max_length=50)
    email: EmailStr
    number: str = Field(..., min_length=7, max_length=20)
    gender: str = Field(..., pattern="^(male|female|other)$")
    city: str = Field(..., min_length=2, max_length=100)
    userType: str = Field(..., pattern="^(customer|worker)$")
    speciality: Optional[str] = Field(None, max_length=100)
    introduction: Optional[str] = Field(None, max_length=500)


class UserCreate(UserBase):
    """Model for user registration."""

    password: str = Field(..., min_length=8, max_length=100)
    image: Optional[str] = None

    @validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        """Ensure password has uppercase, lowercase, and digits."""
        if not any(c.isupper() for c in v):
            raise ValueError("Password must contain uppercase letter")
        if not any(c.islower() for c in v):
            raise ValueError("Password must contain lowercase letter")
        if not any(c.isdigit() for c in v):
            raise ValueError("Password must contain digit")
        return v


class UserLogin(BaseModel):
    """Model for user login."""

    email: EmailStr
    password: str


class UserProfileUpdate(BaseModel):
    """Model for updating user profile."""

    username: Optional[str] = Field(None, min_length=3, max_length=50)
    number: Optional[str] = Field(None, min_length=7, max_length=20)
    city: Optional[str] = Field(None, min_length=2, max_length=100)
    speciality: Optional[str] = Field(None, max_length=100)
    introduction: Optional[str] = Field(None, max_length=500)
    facebook: Optional[str] = Field(None, max_length=200)
    instagram: Optional[str] = Field(None, max_length=200)
    telegram: Optional[str] = Field(None, max_length=200)
    imageBase64: Optional[str] = None


class UserOut(BaseModel):
    """User response model."""

    id: str
    username: str
    email: str
    userType: str
    speciality: Optional[str] = None
    imageBase64: Optional[str] = None
    introduction: Optional[str] = None
    facebook: Optional[str] = None
    instagram: Optional[str] = None
    telegram: Optional[str] = None
    number: Optional[str] = None
    city: Optional[str] = None


class TokenData(BaseModel):
    """JWT token data."""

    username: Optional[str] = None


# ==================== Service Models ====================
class ServiceCreate(BaseModel):
    """Model for creating a service."""

    name: str = Field(..., min_length=3, max_length=200)
    location: str = Field(..., min_length=3, max_length=200)
    price: float = Field(..., gt=0)
    imageBase64: Optional[str] = None
    description: Optional[str] = Field(None, max_length=1000)
    category: Optional[str] = Field(None, max_length=100)


class ServiceUpdate(BaseModel):
    """Model for updating a service."""

    name: Optional[str] = Field(None, min_length=3, max_length=200)
    location: Optional[str] = Field(None, min_length=3, max_length=200)
    price: Optional[float] = Field(None, gt=0)
    imageBase64: Optional[str] = None
    description: Optional[str] = Field(None, max_length=1000)
    category: Optional[str] = Field(None, max_length=100)


class ServiceOut(BaseModel):
    """Service response model."""

    _id: str
    name: str
    location: str
    price: float
    worker_email: str
    worker_username: str
    imageBase64: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None


# ==================== Post Models ====================
class PostCreate(BaseModel):
    """Model for creating a post."""

    title: str = Field(..., min_length=5, max_length=200)
    description: str = Field(..., min_length=10, max_length=2000)
    price_range: str = Field(..., pattern="^(0-100|100-500|500-1000|1000\\+)$")
    category: Optional[str] = Field(None, max_length=100)
    creator_username: str
    creator_email: EmailStr


class PostUpdate(BaseModel):
    """Model for updating a post."""

    title: Optional[str] = Field(None, min_length=5, max_length=200)
    description: Optional[str] = Field(None, min_length=10, max_length=2000)
    price_range: Optional[str] = None
    category: Optional[str] = Field(None, max_length=100)


class PostOut(BaseModel):
    """Post response model."""

    _id: str
    title: str
    description: str
    price_range: str
    creator_email: EmailStr
    creator_username: str
    category: Optional[str] = None
    created_at: datetime


# ==================== Offer Models ====================
class OfferStatus(str, Enum):
    """Offer status enumeration."""

    PENDING = "pending"
    ACCEPTED = "accepted"
    REJECTED = "rejected"


class OfferCreate(BaseModel):
    """Model for creating an offer."""

    content: str = Field(..., min_length=10, max_length=2000)
    price: float = Field(..., gt=0)
    status: OfferStatus = OfferStatus.PENDING


class OfferOut(BaseModel):
    """Offer response model."""

    _id: str
    content: str
    price: float
    worker_email: str
    status: OfferStatus
    created_at: datetime


# ==================== Service Request Models ====================
class RequestStatus(str, Enum):
    """Service request status enumeration."""

    PENDING = "pending"
    ACCEPTED = "accepted"
    REJECTED = "rejected"
    READY_FOR_DELIVERY = "ready_for_delivery"
    COMPLETED = "completed"


class ServiceRequest(BaseModel):
    """Model for service request."""

    service_id: str
    user_email: EmailStr
    user_name: str
    worker_email: EmailStr
    service_name: str
    created_at: datetime = Field(default_factory=datetime.utcnow)
    status: RequestStatus = RequestStatus.PENDING
    deadline: Optional[datetime] = None
    safe_area_active: bool = False


class ServiceRequestOut(BaseModel):
    """Service request response model."""

    _id: str
    service_id: str
    user_email: EmailStr
    user_name: str
    worker_email: EmailStr
    service_name: str
    status: RequestStatus
    deadline: Optional[str] = None
    safe_area_active: bool


# ==================== Message Models ====================
class MessageCreate(BaseModel):
    """Model for creating a message."""

    recipient_email: EmailStr
    message: str = Field(..., min_length=1, max_length=5000)


class MessageOut(BaseModel):
    """Message response model."""

    _id: str
    sender_email: EmailStr
    recipient_email: EmailStr
    message: str
    timestamp: datetime
    read: bool


# ==================== Review Models ====================
class ReviewCreate(BaseModel):
    """Model for creating a review."""

    rating: int = Field(..., ge=1, le=5)
    comment: Optional[str] = Field(None, max_length=1000)


class ReviewOut(BaseModel):
    """Review response model."""

    _id: str
    reviewer_email: EmailStr
    reviewer_username: str
    worker_email: EmailStr
    rating: int
    comment: Optional[str] = None
    created_at: datetime


# ==================== Report Models ====================
class Report(BaseModel):
    """Model for submitting a report."""

    user_email: EmailStr
    description: str = Field(..., min_length=10, max_length=5000)
    imageBase64: Optional[str] = None


class ReportOut(BaseModel):
    """Report response model."""

    _id: str
    user_email: EmailStr
    description: str
    status: str
    timestamp: datetime


# ==================== Payment Models ====================
class PaymentData(BaseModel):
    """Model for payment."""

    amount: int = Field(..., gt=0)


class PaymentOut(BaseModel):
    """Payment response model."""

    _id: str
    request_id: str
    worker_email: EmailStr
    amount: int
    timestamp: datetime
