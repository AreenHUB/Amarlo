"""
app/api/v1/api.py
──────────────────
Aggregates all v1 endpoint routers into a single router.
"""
from fastapi import APIRouter

from app.api.v1.endpoints import (
    auth, chat, posts, reports, requests,
    safe_area, safe_area_sessions, services, users,
)

api_router = APIRouter(prefix="/api/v1")

api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(services.router)
api_router.include_router(posts.router)
api_router.include_router(requests.router)
api_router.include_router(chat.router)
api_router.include_router(safe_area.router)
api_router.include_router(safe_area_sessions.router)
api_router.include_router(reports.router)
