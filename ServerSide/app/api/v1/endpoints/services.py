"""
Services API router.
Handles service CRUD operations.
"""

import logging
import base64
from fastapi import APIRouter, HTTPException, status
from bson import ObjectId

from app.schemas import ServiceCreate, ServiceUpdate, ServiceOut
from app.db import get_database, CollectionNames
from app.utils import serialize_service, generate_object_id
from fastapi import Depends
from app.api.v1.dependencies import get_current_user


logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/services", tags=["Services"])


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_service(
    service: ServiceCreate, current_user: dict = Depends(get_current_user)
):
    """Create a new service."""
    try:
        db = get_database()
        services_collection = db[CollectionNames.SERVICES]

        service_doc = {
            "_id": ObjectId(),
            **service.dict(),
            "worker_email": current_user["email"],
        }

        # Validate base64 image if provided
        if service.imageBase64:
            try:
                base64.b64decode(service.imageBase64)
            except Exception as e:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Invalid base64 image",
                )

        services_collection.insert_one(service_doc)
        service_doc["_id"] = str(service_doc["_id"])

        logger.info(f"Service created by {current_user['email']}")
        return service_doc

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating service: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to create service",
        )


@router.get("")
async def get_services(worker_email: str = None):
    """Get services, optionally filtered by worker email."""
    try:
        db = get_database()
        services_collection = db[CollectionNames.SERVICES]
        users_collection = db[CollectionNames.USERS]

        query = {}
        if worker_email:
            query["worker_email"] = worker_email

        services = list(services_collection.find(query))
        return [serialize_service(service, users_collection) for service in services]

    except Exception as e:
        logger.error(f"Error fetching services: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch services",
        )


@router.get("/worker/my-services")
async def get_worker_services(current_user: dict = Depends(get_current_user)):
    """Get services for current worker."""
    try:
        db = get_database()
        services_collection = db[CollectionNames.SERVICES]
        users_collection = db[CollectionNames.USERS]

        services = list(
            services_collection.find({"worker_email": current_user["email"]})
        )
        return [serialize_service(service, users_collection) for service in services]

    except Exception as e:
        logger.error(f"Error fetching worker services: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch services",
        )


@router.put("/{service_id}")
async def update_service(
    service_id: str,
    service: ServiceUpdate,
    current_user: dict = Depends(get_current_user),
):
    """Update a service."""
    try:
        db = get_database()
        services_collection = db[CollectionNames.SERVICES]

        try:
            object_id = ObjectId(service_id)
        except Exception:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid service ID"
            )

        # Check authorization
        existing_service = services_collection.find_one(
            {"_id": object_id, "worker_email": current_user["email"]}
        )

        if not existing_service:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Service not found or not authorized",
            )

        update_data = service.dict(exclude_unset=True)

        if update_data:
            services_collection.update_one({"_id": object_id}, {"$set": update_data})

        updated_service = services_collection.find_one({"_id": object_id})
        updated_service["_id"] = str(updated_service["_id"])

        logger.info(f"Service updated: {service_id}")
        return updated_service

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error updating service: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update service",
        )


@router.delete("/{service_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_service(
    service_id: str, current_user: dict = Depends(get_current_user)
):
    """Delete a service."""
    try:
        db = get_database()
        services_collection = db[CollectionNames.SERVICES]

        try:
            object_id = ObjectId(service_id)
        except Exception:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid service ID"
            )

        result = services_collection.delete_one(
            {"_id": object_id, "worker_email": current_user["email"]}
        )

        if result.deleted_count == 0:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Service not found or not authorized",
            )

        logger.info(f"Service deleted: {service_id}")

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deleting service: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to delete service",
        )


@router.get("/categories")
async def get_categories():
    """Get all available service categories."""
    try:
        db = get_database()
        services_collection = db[CollectionNames.SERVICES]

        categories = services_collection.distinct("category")
        return {"categories": [cat for cat in categories if cat]}

    except Exception as e:
        logger.error(f"Error fetching categories: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to fetch categories",
        )
