"""
app/api/v1/endpoints/posts.py
──────────────────────────────
GET    /posts              — منشورات المستخدم الحالي
POST   /posts              — نشر post جديد
GET    /posts/public       — كل المنشورات (للعمال)
GET    /posts/me/offers    — العروض الواردة على منشوراتي
DELETE /posts/{id}
POST   /posts/{id}/offers        — إرسال offer من عامل
PUT    /posts/{id}/offers/{oid}/accept
PUT    /posts/{id}/offers/{oid}/reject
DELETE /posts/{id}/offers/{oid}
"""
import uuid
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.api.dependencies import get_current_user
from app.db import posts_collection, users_collection
from app.schemas.common import MessageResponse, PagedResponse, PaginationParams

router = APIRouter(tags=["Posts & Offers"])


# ─── Schemas ─────────────────────────────────────────────
class PostCreate(BaseModel):
    title:       str
    description: str
    price_range: str
    category:    Optional[str] = None


class OfferCreate(BaseModel):
    content: str
    price:   float


# ─── Helpers ─────────────────────────────────────────────
def _post_or_404(post_id: str) -> dict:
    doc = posts_collection.find_one({"_id": post_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Post not found")
    return doc


def _serialize_post(doc: dict) -> dict:
    d = dict(doc)
    d["id"] = str(d.pop("_id"))
    created = d.get("created_at")
    if isinstance(created, datetime):
        d["created_at"] = created.isoformat()
    return d


# ─── Post endpoints ───────────────────────────────────────

@router.get("/posts", summary="منشورات المستخدم الحالي")
async def my_posts(
    pagination: PaginationParams = Depends(),
    current_user: dict = Depends(get_current_user),
):
    query = {"creator_email": current_user["email"]}
    total = posts_collection.count_documents(query)
    docs = list(
        posts_collection.find(query)
        .sort("created_at", -1)
        .skip(pagination.skip)
        .limit(pagination.size)
    )
    return PagedResponse.build([_serialize_post(d) for d in docs], total, pagination)


@router.get("/posts/public", summary="كل المنشورات للعمال")
async def public_posts(
    category: Optional[str] = None,
    search:   Optional[str] = None,
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
    return PagedResponse.build([_serialize_post(d) for d in docs], total, pagination)


@router.get("/posts/me/offers", summary="العروض الواردة على منشوراتي")
async def my_offers(current_user: dict = Depends(get_current_user)):
    docs = list(posts_collection.find(
        {"creator_email": current_user["email"], "offers": {"$exists": True, "$ne": []}}
    ).sort("created_at", -1))
    return [_serialize_post(d) for d in docs]


@router.post("/posts", status_code=201, summary="نشر post جديد")
async def create_post(body: PostCreate, current_user: dict = Depends(get_current_user)):
    post_id = str(uuid.uuid4())
    doc = {
        "_id":              post_id,
        "title":            body.title,
        "description":      body.description,
        "price_range":      body.price_range,
        "category":         body.category,
        "creator_email":    current_user["email"],
        "creator_username": current_user.get("username", ""),
        "offers":           [],
        "created_at":       datetime.now(timezone.utc),
    }
    posts_collection.insert_one(doc)
    return _serialize_post(doc)


@router.delete("/posts/{post_id}", response_model=MessageResponse)
async def delete_post(post_id: str, current_user: dict = Depends(get_current_user)):
    doc = _post_or_404(post_id)
    if doc["creator_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    posts_collection.delete_one({"_id": post_id})
    return {"message": "Post deleted"}


# ─── Offer endpoints ──────────────────────────────────────

@router.post("/posts/{post_id}/offers", status_code=201, summary="إرسال offer من عامل")
async def create_offer(
    post_id: str,
    body: OfferCreate,
    current_user: dict = Depends(get_current_user),
):
    doc = _post_or_404(post_id)

    if doc["creator_email"] == current_user["email"]:
        raise HTTPException(status_code=400, detail="Cannot offer on your own post")

    # منع التكرار
    existing = next(
        (o for o in doc.get("offers", []) if o.get("worker_email") == current_user["email"]),
        None,
    )
    if existing:
        raise HTTPException(status_code=409, detail="Already submitted an offer")

    offer_id = str(uuid.uuid4())
    offer = {
        "_id":            offer_id,
        "content":        body.content,
        "price":          body.price,
        "worker_email":   current_user["email"],
        "worker_username": current_user.get("username", ""),
        "status":         "pending",
        "created_at":     datetime.now(timezone.utc).isoformat(),
    }
    posts_collection.update_one({"_id": post_id}, {"$push": {"offers": offer}})

    # إشعار صاحب المنشور
    try:
        from app.api.v1.endpoints.chat import push_notification
        import asyncio
        asyncio.create_task(push_notification(doc["creator_email"], {
            "type":            "new_offer",
            "worker_username": current_user.get("username", ""),
            "price":           body.price,
            "post_title":      doc.get("title", ""),
        }))
    except Exception:
        pass

    return {"message": "Offer submitted", "offer_id": offer_id}


@router.put(
    "/posts/{post_id}/offers/{offer_id}/accept",
    response_model=MessageResponse,
    summary="قبول offer",
)
async def accept_offer(
    post_id: str,
    offer_id: str,
    current_user: dict = Depends(get_current_user),
):
    doc = _post_or_404(post_id)
    if doc["creator_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    posts_collection.update_one(
        {"_id": post_id, "offers._id": offer_id},
        {"$set": {"offers.$.status": "accepted"}},
    )
    # رفض باقي العروض
    posts_collection.update_one(
        {"_id": post_id},
        {"$set": {
            "offers.$[other].status": "rejected",
        }},
        array_filters=[{"other._id": {"$ne": offer_id}}],
    )
    return {"message": "Offer accepted"}


@router.put(
    "/posts/{post_id}/offers/{offer_id}/reject",
    response_model=MessageResponse,
)
async def reject_offer(
    post_id: str,
    offer_id: str,
    current_user: dict = Depends(get_current_user),
):
    doc = _post_or_404(post_id)
    if doc["creator_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    posts_collection.update_one(
        {"_id": post_id, "offers._id": offer_id},
        {"$set": {"offers.$.status": "rejected"}},
    )
    return {"message": "Offer rejected"}


@router.delete("/posts/{post_id}/offers/{offer_id}", response_model=MessageResponse)
async def delete_offer(
    post_id: str,
    offer_id: str,
    current_user: dict = Depends(get_current_user),
):
    doc = _post_or_404(post_id)
    offer = next((o for o in doc.get("offers", []) if o["_id"] == offer_id), None)
    if not offer:
        raise HTTPException(status_code=404, detail="Offer not found")
    if offer["worker_email"] != current_user["email"] and \
       doc["creator_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    posts_collection.update_one(
        {"_id": post_id},
        {"$pull": {"offers": {"_id": offer_id}}},
    )
    return {"message": "Offer deleted"}
