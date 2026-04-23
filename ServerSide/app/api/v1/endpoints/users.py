"""
app/api/v1/endpoints/users.py
──────────────────────────────
GET    /users              — بحث عن مستخدم بالـ email
GET    /users/{user_id}    — بروفايل مستخدم
PUT    /users/{user_id}    — تعديل البروفايل
GET    /users/{email}/reviews
POST   /users/{email}/reviews
PUT    /users/reviews/{review_id}
DELETE /users/reviews/{review_id}
"""
import uuid
from typing import Optional

from fastapi import (APIRouter, Depends, File, Form,
                     HTTPException, Request, UploadFile, status)

from app.api.dependencies import get_current_user
from app.db import reviews_collection, users_collection
from app.schemas.common import MessageResponse
from app.schemas.user import ReviewCreate, ReviewOut, UserOut
from app.utils.images import delete_image_file, save_upload_image

router = APIRouter(prefix="/users", tags=["Users"])


# ─── Helpers ─────────────────────────────────────────────
def _user_or_404(user_id: str) -> dict:
    user = users_collection.find_one({"_id": user_id})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


# ─── Endpoints ───────────────────────────────────────────

@router.get("", response_model=list[UserOut], summary="بحث عن مستخدم بالـ email")
async def search_users(
    email: Optional[str] = None,
    userType: Optional[str] = None,
    current_user: dict = Depends(get_current_user),
):
    query: dict = {}
    if email:
        query["email"] = email
    if userType:
        query["userType"] = userType
    docs = list(users_collection.find(query).limit(20))
    return [UserOut.from_doc(d) for d in docs]


@router.get("/{user_id}", response_model=UserOut, summary="بروفايل مستخدم")
async def get_user(user_id: str, current_user: dict = Depends(get_current_user)):
    return UserOut.from_doc(_user_or_404(user_id))


@router.put("/{user_id}", response_model=UserOut, summary="تعديل البروفايل")
async def update_user(
    user_id: str,
    username:     Optional[str] = Form(None),
    number:       Optional[str] = Form(None),
    city:         Optional[str] = Form(None),
    speciality:   Optional[str] = Form(None),
    introduction: Optional[str] = Form(None),
    facebook:     Optional[str] = Form(None),
    instagram:    Optional[str] = Form(None),
    telegram:     Optional[str] = Form(None),
    image:        Optional[UploadFile] = File(None),
    request:      Request = None,
    current_user: dict = Depends(get_current_user),
):
    if current_user["_id"] != user_id:
        raise HTTPException(status_code=403, detail="Not authorized")

    update: dict = {}
    for field, val in {
        "username": username, "number": number, "city": city,
        "speciality": speciality, "introduction": introduction,
        "facebook": facebook, "instagram": instagram, "telegram": telegram,
    }.items():
        if val is not None:
            update[field] = val

    if image and image.filename:
        old = users_collection.find_one({"_id": user_id}, {"image_url": 1}) or {}
        delete_image_file(old.get("image_url"))
        update["image_url"] = await save_upload_image(image, "profiles", request)

    if update:
        users_collection.update_one({"_id": user_id}, {"$set": update})

    return UserOut.from_doc(users_collection.find_one({"_id": user_id}))


# ─── Reviews ─────────────────────────────────────────────

@router.get("/{worker_email}/reviews", response_model=list[ReviewOut])
async def get_reviews(worker_email: str, current_user: dict = Depends(get_current_user)):
    docs = list(reviews_collection.find({"worker_email": worker_email}).sort("created_at", -1))
    return [
        ReviewOut(
            id=str(d["_id"]),
            reviewer_username=d.get("reviewer_username", ""),
            reviewer_email=d.get("reviewer_email", ""),
            rating=d.get("rating", 0),
            comment=d.get("comment"),
        )
        for d in docs
    ]


@router.post(
    "/{worker_email}/reviews",
    status_code=201,
    response_model=ReviewOut,
    summary="إضافة تقييم لعامل",
)
async def create_review(
    worker_email: str,
    body: ReviewCreate,
    current_user: dict = Depends(get_current_user),
):
    if current_user["email"] == worker_email:
        raise HTTPException(status_code=400, detail="Cannot review yourself")

    # منع التكرار
    if reviews_collection.find_one({
        "worker_email": worker_email,
        "reviewer_email": current_user["email"],
    }):
        raise HTTPException(status_code=409, detail="Already reviewed this worker")

    review_id = str(uuid.uuid4())
    doc = {
        "_id": review_id,
        "worker_email": worker_email,
        "reviewer_email": current_user["email"],
        "reviewer_username": current_user.get("username", ""),
        "rating": body.rating,
        "comment": body.comment,
    }
    reviews_collection.insert_one(doc)
    return ReviewOut(
        id=review_id,
        reviewer_username=doc["reviewer_username"],
        reviewer_email=doc["reviewer_email"],
        rating=doc["rating"],
        comment=doc.get("comment"),
    )


@router.put("/reviews/{review_id}", response_model=ReviewOut, summary="تعديل تقييم")
async def update_review(
    review_id: str,
    body: ReviewCreate,
    current_user: dict = Depends(get_current_user),
):
    doc = reviews_collection.find_one({"_id": review_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Review not found")
    if doc["reviewer_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    reviews_collection.update_one(
        {"_id": review_id},
        {"$set": {"rating": body.rating, "comment": body.comment}},
    )
    updated = reviews_collection.find_one({"_id": review_id})
    return ReviewOut(
        id=review_id,
        reviewer_username=updated["reviewer_username"],
        reviewer_email=updated["reviewer_email"],
        rating=updated["rating"],
        comment=updated.get("comment"),
    )


@router.delete("/reviews/{review_id}", response_model=MessageResponse)
async def delete_review(review_id: str, current_user: dict = Depends(get_current_user)):
    doc = reviews_collection.find_one({"_id": review_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Review not found")
    if doc["reviewer_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    reviews_collection.delete_one({"_id": review_id})
    return {"message": "Review deleted"}
