import uuid
from datetime import datetime
from enum import Enum
from typing import Optional

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr

from core.database import posts_collection
from core.schemas import MessageResponse, PagedResponse, PaginationParams
from core.security import get_current_user

router = APIRouter(prefix="/posts", tags=["Posts & Offers"])


# ─── Schemas ─────────────────────────────────────────────
class OfferStatus(str, Enum):
    PENDING  = "pending"
    ACCEPTED = "accepted"
    REJECTED = "rejected"


class PostCreate(BaseModel):
    title: str
    description: str
    price_range: str
    category: Optional[str] = None


class PostUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    price_range: Optional[str] = None
    category: Optional[str] = None


class OfferCreate(BaseModel):
    content: str
    price: float


class PostOut(BaseModel):
    id: str
    title: str
    description: str
    price_range: str
    category: Optional[str]
    creator_username: str
    creator_email: str
    offers: list = []
    created_at: Optional[str] = None

    @classmethod
    def from_doc(cls, doc: dict) -> "PostOut":
        return cls(
            id=str(doc["_id"]),
            title=doc["title"],
            description=doc["description"],
            price_range=doc.get("price_range", ""),
            category=doc.get("category"),
            creator_username=doc.get("creator_username", ""),
            creator_email=doc.get("creator_email", ""),
            offers=doc.get("offers", []),
            created_at=doc.get("created_at", datetime.utcnow()).isoformat()
            if isinstance(doc.get("created_at"), datetime)
            else doc.get("created_at"),
        )


# ─── My posts ────────────────────────────────────────────

@router.get("", response_model=PagedResponse[PostOut])
async def get_my_posts(
    pagination: PaginationParams = Depends(),
    current_user: dict = Depends(get_current_user),
):
    query = {"user_email": current_user["email"]}
    total = posts_collection.count_documents(query)
    docs = list(
        posts_collection.find(query)
        .sort("created_at", -1)
        .skip(pagination.skip)
        .limit(pagination.size)
    )
    return PagedResponse.build([PostOut.from_doc(d) for d in docs], total, pagination)


@router.post("", status_code=201, response_model=PostOut)
async def create_post(
    post: PostCreate,
    current_user: dict = Depends(get_current_user),
):
    doc = {
        "_id": str(uuid.uuid4()),
        "user_email": current_user["email"],
        "creator_username": current_user.get("username", ""),
        "creator_email": current_user["email"],
        "created_at": datetime.utcnow(),
        **post.dict(),
        "offers": [],
    }
    posts_collection.insert_one(doc)
    return PostOut.from_doc(doc)


@router.put("/{post_id}", response_model=PostOut)
async def update_post(
    post_id: str,
    post: PostUpdate,
    current_user: dict = Depends(get_current_user),
):
    data = post.dict(exclude_unset=True)
    result = posts_collection.update_one(
        {"_id": post_id, "user_email": current_user["email"]},
        {"$set": data},
    )
    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Post not found or not authorized")
    return PostOut.from_doc(posts_collection.find_one({"_id": post_id}))


@router.delete("/{post_id}", response_model=MessageResponse)
async def delete_post(post_id: str, current_user: dict = Depends(get_current_user)):
    result = posts_collection.delete_one(
        {"_id": post_id, "user_email": current_user["email"]}
    )
    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Post not found or not authorized")
    return {"message": "Post deleted"}


# ─── Public posts ─────────────────────────────────────────

@router.get("/public", response_model=PagedResponse[PostOut])
async def get_public_posts(
    category: Optional[str] = None,
    search: Optional[str] = None,
    pagination: PaginationParams = Depends(),
    current_user: dict = Depends(get_current_user),
):
    query: dict = {}
    if category:
        query["category"] = category
    if search:
        query["$or"] = [
            {"title": {"$regex": search, "$options": "i"}},
            {"description": {"$regex": search, "$options": "i"}},
        ]

    total = posts_collection.count_documents(query)
    docs = list(
        posts_collection.find(query)
        .sort("created_at", -1)
        .skip(pagination.skip)
        .limit(pagination.size)
    )
    return PagedResponse.build([PostOut.from_doc(d) for d in docs], total, pagination)


# ─── Offers on a post ────────────────────────────────────

@router.post("/{post_id}/offers", response_model=MessageResponse)
async def add_offer(
    post_id: str,
    offer: OfferCreate,
    background_tasks: BackgroundTasks,
    current_user: dict = Depends(get_current_user),
):
    post = posts_collection.find_one({"_id": post_id})
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")

    # منع المستخدم من تقديم عرض على منشوره
    if post["user_email"] == current_user["email"]:
        raise HTTPException(status_code=400, detail="Cannot offer on your own post")

    offer_doc = {
        "_id": str(uuid.uuid4()),
        "content": offer.content,
        "price": offer.price,
        "worker_email": current_user["email"],
        "worker_username": current_user.get("username", ""),
        "status": OfferStatus.PENDING.value,
        "created_at": datetime.utcnow().isoformat(),
    }
    posts_collection.update_one({"_id": post_id}, {"$push": {"offers": offer_doc}})
    return {"message": "Offer submitted"}


@router.put("/{post_id}/offers/{offer_id}", response_model=MessageResponse)
async def edit_offer(
    post_id: str,
    offer_id: str,
    offer: OfferCreate,
    current_user: dict = Depends(get_current_user),
):
    post = posts_collection.find_one({"_id": post_id})
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")

    offers = post.get("offers", [])
    for i, o in enumerate(offers):
        if o["_id"] == offer_id:
            if o["worker_email"] != current_user["email"]:
                raise HTTPException(status_code=403, detail="Not authorized")
            offers[i].update({"content": offer.content, "price": offer.price})
            posts_collection.update_one({"_id": post_id}, {"$set": {"offers": offers}})
            return {"message": "Offer updated"}

    raise HTTPException(status_code=404, detail="Offer not found")


@router.delete("/{post_id}/offers/{offer_id}", response_model=MessageResponse)
async def delete_offer(
    post_id: str,
    offer_id: str,
    current_user: dict = Depends(get_current_user),
):
    post = posts_collection.find_one({"_id": post_id})
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")

    offers = [o for o in post.get("offers", []) if o["_id"] != offer_id]
    if len(offers) == len(post.get("offers", [])):
        raise HTTPException(status_code=404, detail="Offer not found")

    posts_collection.update_one({"_id": post_id}, {"$set": {"offers": offers}})
    return {"message": "Offer deleted"}


def _update_offer_status(post_id: str, offer_id: str, new_status: OfferStatus, user_email: str):
    post = posts_collection.find_one({"_id": post_id})
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    if post["user_email"] != user_email:
        raise HTTPException(status_code=403, detail="Not authorized")

    offers = post.get("offers", [])
    for i, o in enumerate(offers):
        if o["_id"] == offer_id:
            if o.get("status") != OfferStatus.PENDING.value:
                raise HTTPException(status_code=400, detail="Offer is not pending")
            offers[i]["status"] = new_status.value
            posts_collection.update_one({"_id": post_id}, {"$set": {"offers": offers}})
            return
    raise HTTPException(status_code=404, detail="Offer not found")


@router.put("/{post_id}/offers/{offer_id}/accept", response_model=MessageResponse)
async def accept_offer(
    post_id: str, offer_id: str, current_user: dict = Depends(get_current_user)
):
    _update_offer_status(post_id, offer_id, OfferStatus.ACCEPTED, current_user["email"])
    return {"message": "Offer accepted"}


@router.put("/{post_id}/offers/{offer_id}/reject", response_model=MessageResponse)
async def reject_offer(
    post_id: str, offer_id: str, current_user: dict = Depends(get_current_user)
):
    _update_offer_status(post_id, offer_id, OfferStatus.REJECTED, current_user["email"])
    return {"message": "Offer rejected"}


@router.get("/me/offers")
async def get_my_received_offers(current_user: dict = Depends(get_current_user)):
    """الـ offers التي وصلت للمستخدم على منشوراته."""
    offers = []
    for post in posts_collection.find({"user_email": current_user["email"]}):
        for o in post.get("offers", []):
            o["post_title"] = post.get("title")
            o["post_id"] = str(post["_id"])
            offers.append(o)
    return offers
