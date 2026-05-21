"""
app/schemas/user.py
───────────────────
User-related Pydantic schemas.
"""
from typing import Optional

from pydantic import BaseModel, EmailStr, Field


class UserBase(BaseModel):
    username:   str       = Field(..., min_length=2, max_length=50)
    email:      EmailStr
    number:     Optional[str]  = None
    gender:     Optional[str]  = None
    city:       Optional[str]  = None
    userType:   str
    speciality: Optional[str]  = None


class UserOut(BaseModel):
    id:           str
    username:     str
    email:        str
    userType:     str
    speciality:   Optional[str] = None
    image_url:    Optional[str] = None
    introduction: Optional[str] = None
    facebook:     Optional[str] = None
    instagram:    Optional[str] = None
    telegram:     Optional[str] = None
    linkedin:     Optional[str] = None
    number:       Optional[str] = None
    city:         Optional[str] = None

    @classmethod
    def from_doc(cls, doc: dict) -> "UserOut":
        return cls(
            id=          str(doc.get("_id") or doc.get("id", "")),
            username=    doc.get("username", ""),
            email=       doc.get("email", ""),
            userType=    doc.get("userType", ""),
            speciality=  doc.get("speciality"),
            image_url=   doc.get("image_url"),
            introduction=doc.get("introduction"),
            facebook=    doc.get("facebook"),
            instagram=   doc.get("instagram"),
            telegram=    doc.get("telegram"),
            linkedin=    doc.get("linkedin"),
            number=      doc.get("number"),
            city=        doc.get("city"),
        )


class UserUpdate(BaseModel):
    username:     Optional[str] = None
    number:       Optional[str] = None
    city:         Optional[str] = None
    speciality:   Optional[str] = None
    introduction: Optional[str] = None
    facebook:     Optional[str] = None
    instagram:    Optional[str] = None
    telegram:     Optional[str] = None
    linkedin:     Optional[str] = None


class WorkReviewCreate(BaseModel):
    """تقييم عمل مكتمل — 3 محاور + تعليق"""
    request_id:        str
    quality_rating:    int = Field(..., ge=1, le=5, description="جودة العمل")
    punctuality_rating: int = Field(..., ge=1, le=5, description="الالتزام بالموعد")
    communication_rating: int = Field(..., ge=1, le=5, description="التواصل والاستجابة")
    comment:           Optional[str] = None


class WorkReviewOut(BaseModel):
    id:                   str
    reviewer_username:    str
    reviewer_email:       str
    reviewee_email:       str    # Worker أو User
    request_id:           str
    quality_rating:       int
    punctuality_rating:   int
    communication_rating: int
    overall_rating:       float  # متوسط الثلاثة
    comment:              Optional[str] = None
    created_at:           Optional[str] = None


class ConductReportCreate(BaseModel):
    """بلاغ سلوكي — لا يرتبط بعمل مكتمل"""
    reported_email: str
    reasons:        list[str]                          # قائمة من CONDUCT_REASONS
    details:        Optional[str] = Field(None, max_length=1000)


CONDUCT_REASONS = [
    "Unprofessional language",
    "Harassment or threats",
    "Scam attempt",
    "Ghosted after agreement",
    "Misleading information",
    "Inappropriate content",
    "Other",
]


# ─── Legacy (للتوافق مع الكود القديم) ───────────────────
class ReviewCreate(BaseModel):
    rating:  int = Field(..., ge=1, le=5)
    comment: Optional[str] = None


class ReviewOut(BaseModel):
    id:                str
    reviewer_username: str
    reviewer_email:    str
    rating:            int
    comment:           Optional[str] = None
