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


class ReviewCreate(BaseModel):
    rating:  int = Field(..., ge=1, le=5)
    comment: Optional[str] = None


class ReviewOut(BaseModel):
    id:                str
    reviewer_username: str
    reviewer_email:    str
    rating:            int
    comment:           Optional[str] = None
