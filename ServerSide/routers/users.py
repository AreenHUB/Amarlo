from typing import Optional

from bson import ObjectId
from fastapi import APIRouter, Depends, HTTPException, Request, UploadFile, File, Form, status
from pydantic import BaseModel

from core.database import reviews_collection, users_collection
from core.images import delete_image_file, save_upload_image
from core.schemas import MessageResponse, UserOut
from core.security import get_current_user

router = APIRouter(prefix="/users", tags=["Users"])


# ─── Schemas ─────────────────────────────────────────────
class ReviewOut(BaseModel):
    id: str
    reviewer_username: str
    reviewer_email: str
    rating: int
    comment: Optional[str] = None

    @classmethod
    def from_doc(cls, doc: dict) -> "ReviewOut":
        return cls(
            id=str(doc["_id"]),
            reviewer_username=doc.get("reviewer_username", "Unknown"),
            reviewer_email=doc.get("reviewer_email", ""),
            rating=doc["rating"],
            comment=doc.get("comment"),
        )


# ─── Helper ──────────────────────────────────────────────
def _get_user_or_404(user_id: str) -> dict:
    user = users_collection.find_one({"_id": user_id})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


# ─── Endpoints ───────────────────────────────────────────

@router.get("/{user_id}", response_model=UserOut)
async def get_user(user_id: str):
    return UserOut.from_doc(_get_user_or_404(user_id))


@router.put("/{user_id}", response_model=UserOut)
async def update_user(
    user_id: str,
    username: Optional[str] = Form(None),
    number: Optional[str] = Form(None),
    city: Optional[str] = Form(None),
    speciality: Optional[str] = Form(None),
    introduction: Optional[str] = Form(None),
    facebook: Optional[str] = Form(None),
    instagram: Optional[str] = Form(None),
    telegram: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None),
    request: Request = None,
    current_user: dict = Depends(get_current_user),
):
    if current_user["_id"] != user_id:
        raise HTTPException(status_code=403, detail="Unauthorized")

    update_data: dict = {}
    fields = dict(
        username=username, number=number, city=city,
        speciality=speciality, introduction=introduction,
        facebook=facebook, instagram=instagram, telegram=telegram,
    )
    for k, v in fields.items():
        if v is not None:
            update_data[k] = v

    # Handle image upload
    if image and image.filename:
        old_url = current_user.get("image_url")
        delete_image_file(old_url)
        update_data["image_url"] = await save_upload_image(image, "profiles", request)

    if update_data:
        users_collection.update_one({"_id": user_id}, {"$set": update_data})

    return UserOut.from_doc(users_collection.find_one({"_id": user_id}))


# ─── Search by email ─────────────────────────────────────
@router.get("", response_model=UserOut)
async def get_user_by_email(email: str):
    user = users_collection.find_one({"email": email})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return UserOut.from_doc(user)


# ─── Reviews ─────────────────────────────────────────────
import uuid
from datetime import datetime
from pydantic import BaseModel as PydanticBase


class ReviewCreate(PydanticBase):
    rating: int
    comment: Optional[str] = None


@router.get("/{worker_email}/reviews", response_model=list[ReviewOut])
async def get_reviews(worker_email: str):
    docs = list(reviews_collection.find({"worker_email": worker_email}))
    return [ReviewOut.from_doc(d) for d in docs]


@router.post("/{worker_email}/reviews", status_code=201, response_model=MessageResponse)
async def add_review(
    worker_email: str,
    review: ReviewCreate,
    current_user: dict = Depends(get_current_user),
):
    if current_user["email"] == worker_email:
        raise HTTPException(status_code=400, detail="Cannot review yourself")

    if not users_collection.find_one({"email": worker_email}):
        raise HTTPException(status_code=404, detail="Worker not found")

    reviews_collection.insert_one({
        "_id": str(uuid.uuid4()),
        "reviewer_email": current_user["email"],
        "reviewer_username": current_user.get("username", ""),
        "worker_email": worker_email,
        "rating": review.rating,
        "comment": review.comment,
        "created_at": datetime.utcnow(),
    })
    return {"message": "Review added successfully"}


@router.put("/reviews/{review_id}", response_model=MessageResponse)
async def update_review(
    review_id: str,
    review: ReviewCreate,
    current_user: dict = Depends(get_current_user),
):
    doc = reviews_collection.find_one({"_id": review_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Review not found")
    if doc["reviewer_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    reviews_collection.update_one(
        {"_id": review_id},
        {"$set": {"rating": review.rating, "comment": review.comment}},
    )
    return {"message": "Review updated"}


@router.delete("/reviews/{review_id}", status_code=204)
async def delete_review(review_id: str, current_user: dict = Depends(get_current_user)):
    doc = reviews_collection.find_one({"_id": review_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Review not found")
    if doc["reviewer_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    reviews_collection.delete_one({"_id": review_id})
