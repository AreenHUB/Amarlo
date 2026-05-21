"""
app/api/v1/endpoints/services.py
─────────────────────────────────
GET  /services           — قائمة الخدمات (pagination + filters)
POST /services           — إضافة خدمة (صورة إجبارية)
PUT  /services/{id}      — تعديل خدمة
DEL  /services/{id}      — حذف خدمة
GET  /worker-services    — خدمات العامل الحالي
GET  /categories         — قائمة التصنيفات
POST /services/{id}/request  — إرسال طلب على خدمة (الإصلاح الرئيسي)
"""
import logging
import re
import uuid
from datetime import datetime, timezone
from typing import Optional

from bson import ObjectId
from fastapi import (APIRouter, Depends, File, Form,
                     HTTPException, Query, Request, UploadFile, status)

from app.api.dependencies import get_current_user
from app.db import requests_collection, services_collection, users_collection
from app.schemas.common import MessageResponse, PagedResponse, PaginationParams
from app.schemas.service import ServiceOut
from app.utils.images import delete_image_file, save_upload_image

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Services"])


# ─── Helper ──────────────────────────────────────────────
def _normalize(doc: dict) -> dict:
    """
    يُعالج البيانات القديمة (worker_id/worker_name)
    والجديدة (worker_email/worker_username) معاً.
    """
    if "worker_email" not in doc:
        # بيانات قديمة — أضف الحقول الناقصة
        doc = dict(doc)
        doc["worker_email"] = doc.get("worker_email", "")

    # تأكد من وجود _id كـ string
    if "_id" in doc and not isinstance(doc["_id"], str):
        doc = dict(doc)
        doc["_id"] = str(doc["_id"])

    return doc


def _serialize(doc: dict) -> ServiceOut:
    doc = _normalize(doc)
    worker_email = doc.get("worker_email", "")

    # أولاً: جرّب الحصول على username من DB
    username = "Unknown"
    if worker_email:
        user = users_collection.find_one({"email": worker_email}, {"username": 1})
        if user:
            username = user.get("username", "Unknown")

    # ثانياً: fallback للبيانات القديمة (worker_name أو worker_username)
    if username == "Unknown":
        username = doc.get("worker_username") or doc.get("worker_name", "Unknown")

    return ServiceOut.from_doc(doc, username)


# ─── Endpoints ───────────────────────────────────────────

@router.get("/services", response_model=PagedResponse[ServiceOut], summary="قائمة الخدمات")
async def list_services(
    worker_email: Optional[str] = Query(None),
    category:     Optional[str] = Query(None),
    city:         Optional[str] = Query(None),
    min_price:    Optional[float] = Query(None),
    max_price:    Optional[float] = Query(None),
    search:       Optional[str] = Query(None),
    pagination:   PaginationParams = Depends(),
):
    query: dict = {}
    if worker_email:
        query["worker_email"] = worker_email
    if category:
        query["category"] = category
    if city:
        query["location"] = {"$regex": city, "$options": "i"}
    if min_price is not None or max_price is not None:
        query["price"] = {}
        if min_price is not None:
            query["price"]["$gte"] = min_price
        if max_price is not None:
            query["price"]["$lte"] = max_price
    if search:
        safe_search = re.escape(search.strip())
        query["$or"] = [
            {"name":        {"$regex": safe_search, "$options": "i"}},
            {"description": {"$regex": safe_search, "$options": "i"}},
            {"location":    {"$regex": safe_search, "$options": "i"}},
        ]

    total = services_collection.count_documents(query)
    docs = list(
        services_collection.find(query)
        .sort("created_at", -1)
        .skip(pagination.skip)
        .limit(pagination.size)
    )
    return PagedResponse.build([_serialize(d) for d in docs], total, pagination)


@router.get("/categories", summary="قائمة التصنيفات")
async def get_categories():
    return services_collection.distinct("category")


@router.get("/worker-services", response_model=list[ServiceOut], summary="خدمات العامل الحالي")
async def my_services(current_user: dict = Depends(get_current_user)):
    docs = list(
        services_collection.find({"worker_email": current_user["email"]}).sort("created_at", -1)
    )
    return [_serialize(d) for d in docs]


@router.post(
    "/services",
    status_code=201,
    response_model=ServiceOut,
    summary="إضافة خدمة جديدة",
)
async def add_service(
    name:          str    = Form(..., min_length=2),
    location:      str    = Form(...),
    price:         float  = Form(..., gt=0),
    description:   str    = Form(..., min_length=10),
    category:      Optional[str] = Form(None),
    delivery_type: str    = Form("online"),   # "online" | "in_person"
    image:         UploadFile = File(...),
    request:       Request = None,
    current_user:  dict   = Depends(get_current_user),
):
    if not image or not image.filename:
        raise HTTPException(status_code=400, detail="Service image is required")
    if delivery_type not in ("online", "in_person"):
        raise HTTPException(status_code=400, detail="delivery_type must be 'online' or 'in_person'")

    image_url = await save_upload_image(image, "services", request)

    doc = {
        "_id":           str(uuid.uuid4()),
        "name":          name,
        "location":      location,
        "price":         price,
        "description":   description,
        "category":      category,
        "delivery_type": delivery_type,
        "image_url":     image_url,
        "worker_email":  current_user["email"],
        "created_at":    datetime.now(timezone.utc),
    }
    services_collection.insert_one(doc)
    return _serialize(doc)


@router.put("/services/{service_id}", response_model=ServiceOut, summary="تعديل خدمة")
async def update_service(
    service_id:    str,
    name:          Optional[str]   = Form(None),
    location:      Optional[str]   = Form(None),
    price:         Optional[float] = Form(None),
    description:   Optional[str]   = Form(None),
    category:      Optional[str]   = Form(None),
    delivery_type: Optional[str]   = Form(None),
    image:         Optional[UploadFile] = File(None),
    request:       Request = None,
    current_user:  dict    = Depends(get_current_user),
):
    doc = services_collection.find_one({"_id": service_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Service not found")
    if doc["worker_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    if delivery_type and delivery_type not in ("online", "in_person"):
        raise HTTPException(status_code=400, detail="delivery_type must be 'online' or 'in_person'")

    update: dict = {}
    for field, val in {
        "name": name, "location": location, "price": price,
        "description": description, "category": category,
        "delivery_type": delivery_type,
    }.items():
        if val is not None:
            update[field] = val

    if image and image.filename:
        delete_image_file(doc.get("image_url"))
        update["image_url"] = await save_upload_image(image, "services", request)

    if update:
        services_collection.update_one({"_id": service_id}, {"$set": update})

    return _serialize(services_collection.find_one({"_id": service_id}))


@router.delete("/services/{service_id}", response_model=MessageResponse)
async def delete_service(
    service_id: str,
    current_user: dict = Depends(get_current_user),
):
    doc = services_collection.find_one({"_id": service_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Service not found")
    if doc["worker_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    delete_image_file(doc.get("image_url"))
    services_collection.delete_one({"_id": service_id})
    return {"message": "Service deleted"}


# ══════════════════════════════════════════════════════
#  FIX: إرسال طلب على خدمة من الـ Home screen
#  كان الـ Flutter يُرسل إلى /posts/{id}/offers وهذا خطأ
#  الـ endpoint الصحيح هو /services/{id}/request
# ══════════════════════════════════════════════════════

@router.post(
    "/services/{service_id}/request",
    status_code=201,
    summary="إرسال طلب خدمة من بطاقة الـ Home screen",
)
async def request_service(
    service_id:  str,
    current_user: dict = Depends(get_current_user),
):
    """
    المستخدم يضغط زر Request على بطاقة الخدمة في الـ Home screen.
    يُنشئ service request تلقائياً بدون حقول إضافية.
    """
    service = services_collection.find_one({"_id": service_id})
    if not service:
        raise HTTPException(status_code=404, detail="Service not found")

    if service["worker_email"] == current_user["email"]:
        raise HTTPException(status_code=400, detail="Cannot request your own service")

    # منع الطلبات المتكررة
    existing = requests_collection.find_one({
        "service_id":  service_id,
        "user_email":  current_user["email"],
        "status":      {"$in": ["pending", "accepted"]},
    })
    if existing:
        raise HTTPException(status_code=409, detail="You already have an active request for this service")

    # جلب بيانات العامل
    worker = users_collection.find_one({"email": service["worker_email"]}) or {}

    delivery_type = service.get("delivery_type", "online")
    doc = {
        "service_id":    service_id,
        "service_name":  service["name"],
        "service_price": service.get("price", 0),
        "user_email":    current_user["email"],
        "user_name":     current_user.get("username", ""),
        "worker_email":  service["worker_email"],
        "status":        "pending",
        "created_at":    datetime.now(timezone.utc),
        "safe_area_active": False,
        "delivery_type": delivery_type,
    }
    result = requests_collection.insert_one(doc)
    doc["_id"] = result.inserted_id

    # إشعار العامل
    try:
        from app.api.v1.endpoints.chat import push_notification
        await push_notification(service["worker_email"], {
            "type":         "new_request",
            "service_name": service["name"],
            "user_name":    current_user.get("username", ""),
            "user_email":   current_user["email"],
            "request_id":   str(result.inserted_id),
        })
    except Exception as e:
        logger.warning("Failed to notify worker %s of new request: %s", service["worker_email"], e)

    return {
        "message":    "Request sent successfully",
        "request_id": str(result.inserted_id),
    }
