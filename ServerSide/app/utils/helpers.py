"""
Utility functions and helpers.
"""

import base64
import uuid
from datetime import datetime
from typing import Dict, Any, Optional
import logging
from bson import ObjectId

logger = logging.getLogger(__name__)


def generate_id() -> str:
    """Generate a unique UUID."""
    return str(uuid.uuid4())


def generate_object_id() -> ObjectId:
    """Generate a MongoDB ObjectId."""
    return ObjectId()


def convert_object_id_to_string(obj: Dict[str, Any]) -> Dict[str, Any]:
    """Convert ObjectId to string in a dictionary."""
    if isinstance(obj, dict):
        result = {}
        for key, value in obj.items():
            if isinstance(value, ObjectId):
                result[key] = str(value)
            elif isinstance(value, datetime):
                result[key] = value.isoformat()
            elif isinstance(value, dict):
                result[key] = convert_object_id_to_string(value)
            elif isinstance(value, list):
                result[key] = [
                    (
                        convert_object_id_to_string(item)
                        if isinstance(item, dict)
                        else item
                    )
                    for item in value
                ]
            else:
                result[key] = value
        return result
    return obj


def convert_datetime_to_string(data: Dict[str, Any]) -> Dict[str, Any]:
    """Convert all datetime objects to ISO format strings."""
    if isinstance(data, dict):
        result = {}
        for key, value in data.items():
            if isinstance(value, datetime):
                result[key] = value.isoformat()
            elif isinstance(value, dict):
                result[key] = convert_datetime_to_string(value)
            elif isinstance(value, list):
                result[key] = [
                    convert_datetime_to_string(item) if isinstance(item, dict) else item
                    for item in value
                ]
            else:
                result[key] = value
        return result
    return data


def encode_file_to_base64(file_content: bytes) -> str:
    """Encode file content to base64 string."""
    try:
        return base64.b64encode(file_content).decode("utf-8")
    except Exception as e:
        logger.error(f"Error encoding file to base64: {str(e)}")
        raise ValueError("Failed to encode file")


def decode_base64_to_bytes(base64_string: str) -> bytes:
    """Decode base64 string to bytes."""
    try:
        return base64.b64decode(base64_string)
    except Exception as e:
        logger.error(f"Error decoding base64: {str(e)}")
        raise ValueError("Invalid base64 string")


def validate_base64_image(base64_string: str, max_size: int = 5242880) -> bool:
    """
    Validate base64 image string.

    Args:
        base64_string: Base64 encoded image
        max_size: Maximum file size in bytes (default 5MB)

    Returns:
        bool: True if valid, False otherwise
    """
    try:
        decoded = decode_base64_to_bytes(base64_string)
        return len(decoded) <= max_size
    except Exception:
        return False


def is_valid_object_id(id_string: str) -> bool:
    """Check if string is a valid MongoDB ObjectId."""
    try:
        ObjectId(id_string)
        return True
    except Exception:
        return False


def sanitize_email(email: str) -> str:
    """Sanitize and normalize email."""
    return email.lower().strip()


def sanitize_string(text: str, max_length: int = 1000) -> str:
    """Sanitize string input."""
    if not isinstance(text, str):
        return ""
    text = text.strip()
    if len(text) > max_length:
        text = text[:max_length]
    return text


def serialize_service(service: Dict[str, Any], users_collection) -> Dict[str, Any]:
    """
    Serialize service document for response.

    Args:
        service: Service document
        users_collection: MongoDB users collection

    Returns:
        dict: Serialized service
    """
    try:
        worker = users_collection.find_one({"email": service.get("worker_email")})
        worker_username = worker.get("username", "Unknown") if worker else "Unknown"

        return {
            "_id": str(service.get("_id", "")),
            "name": service.get("name", ""),
            "location": service.get("location", ""),
            "price": service.get("price", 0),
            "worker_email": service.get("worker_email", ""),
            "worker_username": worker_username,
            "imageBase64": service.get("imageBase64"),
            "description": service.get("description", ""),
            "category": service.get("category"),
        }
    except Exception as e:
        logger.error(f"Error serializing service: {str(e)}")
        return {}
