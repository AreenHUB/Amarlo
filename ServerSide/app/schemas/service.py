"""
app/schemas/service.py
──────────────────────
Service-related schemas.
"""
from typing import Optional

from pydantic import BaseModel, Field


class ServiceOut(BaseModel):
    id:              str
    name:            str
    location:        str
    price:           float
    worker_email:    str
    worker_username: str
    image_url:       Optional[str] = None
    description:     str
    category:        Optional[str] = None
    delivery_type:   str = "online"   # "online" | "in_person"

    @classmethod
    def from_doc(cls, doc: dict, worker_username: str = "Unknown") -> "ServiceOut":
        worker_email = (
            doc.get("worker_email") or
            doc.get("worker_id", "")
        )
        final_username = (
            worker_username
            if worker_username != "Unknown"
            else doc.get("worker_username") or doc.get("worker_name", "Unknown")
        )
        return cls(
            id=              str(doc.get("_id") or doc.get("id", "")),
            name=            doc.get("name", ""),
            location=        doc.get("location", ""),
            price=           float(doc.get("price", 0)),
            worker_email=    worker_email,
            worker_username= final_username,
            image_url=       doc.get("image_url"),
            description=     doc.get("description", ""),
            category=        doc.get("category"),
            delivery_type=   doc.get("delivery_type", "online"),
        )
