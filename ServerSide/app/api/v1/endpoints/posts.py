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
import logging
import re
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from bson import ObjectId

from app.api.dependencies import get_current_user
from app.db import posts_collection, requests_collection, users_collection
from app.schemas.common import MessageResponse, PagedResponse, PaginationParams

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Posts & Offers"])

# ─── Post categories ──────────────────────────────────────
POST_CATEGORIES = [
    "Programming and Tech",
    "Graphic Design",
    "Writing and Translation",
    "Video and Animation",
    "Music and Audio",
    "Digital Marketing",
    "Business",
    "Photography",
    "Finance",
    "Education and Tutoring",
    "Home Services",
    "Electrical and Plumbing",
    "Cleaning and Maintenance",
    "Childcare and Elderly Care",
    "Gardening and Landscaping",
    "Delivery and Moving",
    "Cooking and Catering",
    "Other",
]


# ─── Schemas ─────────────────────────────────────────────
class PostCreate(BaseModel):
    title:              str
    description:        str
    price_range:        str
    category:           Optional[str] = None
    delivery_type:      str = "online"   # "online" | "in_person"
    safe_area_enabled:  bool = False


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

@router.get("/post-categories", summary="تصنيفات البوستات")
async def get_post_categories():
    return POST_CATEGORIES


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
    # فقط البوستات المفتوحة (open) — المغلقة (closed) لا تُعرض للـ Workers
    query: dict = {"status": {"$ne": "closed"}}
    if category:
        query["category"] = category
    if search:
        safe_search = re.escape(search.strip())
        query["$or"] = [
            {"title":       {"$regex": safe_search, "$options": "i"}},
            {"description": {"$regex": safe_search, "$options": "i"}},
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


POST_TTL_DAYS = 7

@router.post("/posts", status_code=201, summary="نشر post جديد")
async def create_post(body: PostCreate, current_user: dict = Depends(get_current_user)):
    post_id = str(uuid.uuid4())
    if body.delivery_type not in ("online", "in_person"):
        raise HTTPException(status_code=400, detail="delivery_type must be 'online' or 'in_person'")
    now = datetime.now(timezone.utc)
    # safe_area_enabled منطقي فقط إذا كان delivery_type = online
    safe_area = body.safe_area_enabled and body.delivery_type == "online"
    doc = {
        "_id":               post_id,
        "title":             body.title,
        "description":       body.description,
        "price_range":       body.price_range,
        "category":          body.category,
        "delivery_type":     body.delivery_type,
        "safe_area_enabled": safe_area,
        "creator_email":     current_user["email"],
        "creator_username":  current_user.get("username", ""),
        "offers":            [],
        "status":            "open",
        "created_at":        now,
        "expires_at":        now + timedelta(days=POST_TTL_DAYS),
    }
    posts_collection.insert_one(doc)
    return _serialize_post(doc)


class PostUpdate(BaseModel):
    title:             Optional[str] = None
    description:       Optional[str] = None
    price_range:       Optional[str] = None
    category:          Optional[str] = None
    safe_area_enabled: Optional[bool] = None


@router.put("/posts/{post_id}", response_model=dict, summary="تعديل post")
async def update_post(
    post_id: str,
    body: PostUpdate,
    current_user: dict = Depends(get_current_user),
):
    doc = _post_or_404(post_id)
    if doc["creator_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    if doc.get("status") == "closed":
        raise HTTPException(status_code=400, detail="Cannot edit a closed post")

    update: dict = {}
    if body.title        is not None: update["title"]        = body.title
    if body.description  is not None: update["description"]  = body.description
    if body.price_range  is not None: update["price_range"]  = body.price_range
    if body.category     is not None: update["category"]     = body.category
    if body.safe_area_enabled is not None:
        # يُسمح فقط إذا delivery_type = online
        if body.safe_area_enabled and doc.get("delivery_type") != "online":
            raise HTTPException(
                status_code=400,
                detail="safe_area_enabled requires delivery_type=online",
            )
        update["safe_area_enabled"] = body.safe_area_enabled

    if update:
        posts_collection.update_one({"_id": post_id}, {"$set": update})
    return _serialize_post(posts_collection.find_one({"_id": post_id}))


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

    # منع الـ offer على بوست مغلق (تم الاتفاق مع عامل آخر)
    if doc.get("status") == "closed":
        raise HTTPException(
            status_code=400,
            detail="This post is closed. The client has already agreed with another worker."
        )

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
        await push_notification(doc["creator_email"], {
            "type":            "new_offer",
            "worker_username": current_user.get("username", ""),
            "worker_email":    current_user["email"],
            "price":           body.price,
            "post_title":      doc.get("title", ""),
            "post_id":         post_id,
        })
    except Exception as e:
        logger.warning("Failed to notify user %s of new offer: %s", doc["creator_email"], e)

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

    # تحقق أن الـ offer موجودة
    offer = next((o for o in doc.get("offers", []) if o["_id"] == offer_id), None)
    if not offer:
        raise HTTPException(status_code=404, detail="Offer not found")

    # لا تقبل مرتين
    if offer.get("status") == "accepted":
        raise HTTPException(status_code=400, detail="Offer already accepted")

    # قبول هذا الـ offer ورفض الباقي + إغلاق البوست + إزالة TTL
    # ($unset لـ expires_at يمنع MongoDB من حذف البوست بعد قبول العرض)
    posts_collection.update_one(
        {"_id": post_id, "offers._id": offer_id},
        {"$set": {"offers.$.status": "accepted"}},
    )
    posts_collection.update_one(
        {"_id": post_id},
        {
            "$set":   {"offers.$[other].status": "rejected", "status": "closed"},
            "$unset": {"expires_at": ""},
        },
        array_filters=[{"other._id": {"$ne": offer_id}}],
    )

    worker_email      = offer["worker_email"]
    safe_area_enabled = doc.get("safe_area_enabled", False)
    agreed_price      = offer.get("price", 0)

    # إنشاء ServiceRequest
    existing_req = requests_collection.find_one({
        "user_email":   current_user["email"],
        "worker_email": worker_email,
        "post_id":      post_id,
        "status":       {"$nin": ["completed", "rejected"]},
    })
    if not existing_req:
        req_doc = {
            "service_id":       post_id,
            "service_name":     doc.get("title", ""),
            "post_id":          post_id,
            "offer_id":         offer_id,
            "user_email":       current_user["email"],
            "user_name":        current_user.get("username", ""),
            "worker_email":     worker_email,
            "worker_username":  offer.get("worker_username", ""),
            "agreed_price":     agreed_price,
            "safe_area_enabled": safe_area_enabled,
            # Safe area تُفعَّل لاحقاً بعد موافقة الطرفين على الـ deadline
            "safe_area_active": False,
            "status":           "pending",
            "created_at":       datetime.now(timezone.utc),
        }
        result = requests_collection.insert_one(req_doc)
        request_id = str(result.inserted_id)

        try:
            from app.api.v1.endpoints.chat import push_notification
            if safe_area_enabled:
                # Worker: حدد deadline — لديك 6 ساعات
                await push_notification(worker_email, {
                    "type":         "offer_accepted_set_deadline",
                    "service_name": doc.get("title", ""),
                    "user_name":    current_user.get("username", ""),
                    "request_id":   request_id,
                    "agreed_price": agreed_price,
                })
                # User: تم قبول عرضك — انتظر تحديد موعد التسليم
                await push_notification(current_user["email"], {
                    "type":            "offer_you_accepted_confirmed",
                    "service_name":    doc.get("title", ""),
                    "worker_username": offer.get("worker_username", ""),
                    "agreed_price":    agreed_price,
                    "request_id":      request_id,
                })
            else:
                # in-person
                await push_notification(worker_email, {
                    "type":         "offer_accepted_inperson",
                    "service_name": doc.get("title", ""),
                    "user_name":    current_user.get("username", ""),
                    "request_id":   request_id,
                })
                await push_notification(current_user["email"], {
                    "type":            "offer_you_accepted_confirmed",
                    "service_name":    doc.get("title", ""),
                    "worker_username": offer.get("worker_username", ""),
                    "agreed_price":    agreed_price,
                    "request_id":      request_id,
                })
        except Exception as e:
            logger.warning("Failed to send offer-accepted notifications (req=%s): %s", request_id, e)

    msg = (
        "Offer accepted! Worker will set a deadline for Safe Area delivery."
        if safe_area_enabled
        else "Offer accepted! Connect with the worker via chat to coordinate."
    )
    return {"message": msg, "safe_area_enabled": safe_area_enabled}


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


class OfferUpdate(BaseModel):
    content: Optional[str] = None
    price:   Optional[float] = None


@router.put(
    "/posts/{post_id}/offers/{offer_id}",
    response_model=MessageResponse,
    summary="تعديل offer — فقط قبل قبوله",
)
async def update_offer(
    post_id:  str,
    offer_id: str,
    body:     OfferUpdate,
    current_user: dict = Depends(get_current_user),
):
    doc = _post_or_404(post_id)
    offer = next((o for o in doc.get("offers", []) if o["_id"] == offer_id), None)
    if not offer:
        raise HTTPException(status_code=404, detail="Offer not found")
    if offer["worker_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    if offer.get("status") != "pending":
        raise HTTPException(status_code=400, detail="Cannot edit an accepted or rejected offer")

    update: dict = {}
    if body.content is not None: update["offers.$.content"] = body.content
    if body.price   is not None: update["offers.$.price"]   = body.price

    if update:
        posts_collection.update_one(
            {"_id": post_id, "offers._id": offer_id},
            {"$set": update},
        )
    return {"message": "Offer updated"}


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
