import uuid
from typing import Optional

from bson import ObjectId
from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, Request, UploadFile, status
from pydantic import BaseModel

from core.database import services_collection, users_collection
from core.images import delete_image_file, save_upload_image
from core.schemas import MessageResponse, PagedResponse, PaginationParams, ServiceOut
from core.security import get_current_user

router = APIRouter(tags=["Services"])


# ─── Helper ──────────────────────────────────────────────
def _serialize(doc: dict) -> ServiceOut:
    worker = users_collection.find_one({"email": doc["worker_email"]})
    username = worker["username"] if worker else "Unknown"
    return ServiceOut.from_doc(doc, username)


# ─── Public endpoints ────────────────────────────────────

@router.get("/services", response_model=PagedResponse[ServiceOut])
async def get_services(
    worker_email: Optional[str] = Query(None),
    category: Optional[str] = Query(None),
    city: Optional[str] = Query(None),
    min_price: Optional[float] = Query(None),
    max_price: Optional[float] = Query(None),
    search: Optional[str] = Query(None),
    pagination: PaginationParams = Depends(),
):
    """
    عرض الخدمات مع فلاتر و Pagination.
    """
    query: dict = {}
    if worker_email:
        query["worker_email"] = worker_email
    if category:
        query["category"] = category
    if city:
        query["location"] = city
    if min_price is not None or max_price is not None:
        query["price"] = {}
        if min_price is not None:
            query["price"]["$gte"] = min_price
        if max_price is not None:
            query["price"]["$lte"] = max_price
    if search:
        query["$or"] = [
            {"name": {"$regex": search, "$options": "i"}},
            {"description": {"$regex": search, "$options": "i"}},
        ]

    total = services_collection.count_documents(query)
    docs = list(
        services_collection.find(query)
        .skip(pagination.skip)
        .limit(pagination.size)
    )
    return PagedResponse.build(
        items=[_serialize(d) for d in docs],
        total=total,
        params=pagination,
    )


@router.get("/categories")
async def get_categories():
    return services_collection.distinct("category")


# ─── Worker endpoints ────────────────────────────────────

@router.get("/worker-services", response_model=list[ServiceOut])
async def get_my_services(current_user: dict = Depends(get_current_user)):
    docs = list(services_collection.find({"worker_email": current_user["email"]}))
    return [_serialize(d) for d in docs]


@router.post("/services", status_code=201, response_model=ServiceOut)
async def add_service(
    name: str = Form(...),
    location: str = Form(...),
    price: float = Form(...),
    description: str = Form(...),
    category: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None),
    request: Request = None,
    current_user: dict = Depends(get_current_user),
):
    image_url: Optional[str] = None
    if image and image.filename:
        image_url = await save_upload_image(image, "services", request)

    doc = {
        "_id": str(uuid.uuid4()),
        "name": name,
        "location": location,
        "price": price,
        "description": description,
        "category": category,
        "image_url": image_url,
        "worker_email": current_user["email"],
    }
    services_collection.insert_one(doc)
    return _serialize(doc)


@router.put("/services/{service_id}", response_model=ServiceOut)
async def update_service(
    service_id: str,
    name: Optional[str] = Form(None),
    location: Optional[str] = Form(None),
    price: Optional[float] = Form(None),
    description: Optional[str] = Form(None),
    category: Optional[str] = Form(None),
    image: Optional[UploadFile] = File(None),
    request: Request = None,
    current_user: dict = Depends(get_current_user),
):
    doc = services_collection.find_one({"_id": service_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Service not found")
    if doc["worker_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")

    update: dict = {}
    for field, val in dict(name=name, location=location, price=price,
                           description=description, category=category).items():
        if val is not None:
            update[field] = val

    if image and image.filename:
        delete_image_file(doc.get("image_url"))
        update["image_url"] = await save_upload_image(image, "services")

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
