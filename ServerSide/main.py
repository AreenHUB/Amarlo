"""
Amarlo Backend — v2.0.0
========================
Professional FastAPI application with clean architecture:

  app/
  ├── api/v1/endpoints/  ← All route handlers
  ├── core/              ← Config + Security
  ├── db/                ← MongoDB + Indexes
  ├── schemas/           ← Pydantic models
  └── utils/             ← Images + Helpers

Run:
  uvicorn main:app --host 0.0.0.0 --port 8000 --reload
"""
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.openapi.utils import get_openapi
from fastapi.staticfiles import StaticFiles

from app.api.v1.api import api_router
from app.core.config import settings
from app.db.mongodb import close_db, ensure_indexes

logging.basicConfig(
    level=logging.INFO if not settings.DEBUG else logging.DEBUG,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
logger = logging.getLogger(__name__)


# ─── App ─────────────────────────────────────────────────
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="""
## Amarlo — Freelance Marketplace API v2.0.0

### Authentication
1. **POST /api/v1/auth/login** — JSON body → returns `access_token` + `refresh_token`
2. زر **🔒 Authorize** أعلى الصفحة → أدخل: `Bearer <access_token>`
3. **POST /api/v1/auth/refresh** — جدّد الـ access token (يستخدم refresh_token)

### Rate Limits
- access_token  : 30 دقيقة
- refresh_token : 30 يوم (auto-rotation عند كل refresh)
""",
    # Swagger UI and ReDoc are disabled in production to avoid exposing the API schema.
    # Set ENVIRONMENT=development in .env to enable them locally.
    openapi_url="/openapi.json" if not settings.is_production else None,
    docs_url="/docs"            if not settings.is_production else None,
    redoc_url="/redoc"          if not settings.is_production else None,
)


# ─── Security scheme for /docs ───────────────────────────
def _custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema
    schema = get_openapi(
        title=app.title,
        version=app.version,
        description=app.description,
        routes=app.routes,
    )
    schema.setdefault("components", {}).setdefault("securitySchemes", {})
    schema["components"]["securitySchemes"]["BearerAuth"] = {
        "type": "http",
        "scheme": "bearer",
        "bearerFormat": "JWT",
    }
    for path_item in schema.get("paths", {}).values():
        for op in path_item.values():
            if isinstance(op, dict) and ("401" in op.get("responses", {})):
                op.setdefault("security", [{"BearerAuth": []}])
    app.openapi_schema = schema
    return app.openapi_schema


app.openapi = _custom_openapi


# ─── Middleware ───────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    # Restrict to only the HTTP methods the app actually uses
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    # Restrict to only the headers the app sends
    allow_headers=["Authorization", "Content-Type", "Accept"],
)
app.add_middleware(GZipMiddleware, minimum_size=1000)


# ─── Static files (uploaded images) ─────────────────────
app.mount(
    "/uploads",
    StaticFiles(directory=str(settings.UPLOAD_PATH)),
    name="uploads",
)


# ─── Routers ─────────────────────────────────────────────
app.include_router(api_router)


# ─── Lifecycle ───────────────────────────────────────────
@app.on_event("startup")
async def startup():
    logger.info(f"Starting {settings.APP_NAME} v{settings.APP_VERSION}")
    logger.info(f"Environment: {settings.ENVIRONMENT}")
    try:
        ensure_indexes()
        logger.info("✅ MongoDB indexes ready")
    except Exception as e:
        logger.warning(f"Could not ensure indexes: {e}")


@app.on_event("shutdown")
async def shutdown():
    close_db()
    logger.info("MongoDB connection closed")


# ─── Health ──────────────────────────────────────────────
@app.get("/", tags=["Health"])
async def root():
    return {
        "status": "ok",
        "app":    settings.APP_NAME,
        "version": settings.APP_VERSION,
        "docs":   "/docs",
    }


@app.get("/health", tags=["Health"])
async def health():
    return {"status": "healthy", "environment": settings.ENVIRONMENT}
