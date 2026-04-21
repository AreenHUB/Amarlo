"""
Amarlo Backend — v1.0.0
========================
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from core.config import UPLOAD_DIR
from routers import auth, chat, posts, reports, requests, safe_area, services, users

# ─── App ─────────────────────────────────────────────────
app = FastAPI(
    title="Amarlo API",
    description="""
## 🚀 Amarlo — Freelance Marketplace API

### كيفية استخدام التوثيق:

**الخطوة 1:** أرسل طلب إلى **POST /auth/login** مع بيانات دخولك  
**الخطوة 2:** انسخ `access_token` من الرد  
**الخطوة 3:** اضغط زر **🔒 Authorize** أعلى الصفحة  
**الخطوة 4:** في حقل **Value** اكتب: `Bearer <access_token>` ثم اضغط Authorize  

الآن جميع الطلبات المحمية ستعمل تلقائياً ✅

---
للتسجيل السريع عبر Swagger: استخدم **/auth/token** (OAuth2 form)
""",
    version="1.0.0",
    openapi_tags=[
        {"name": "Auth",             "description": "تسجيل دخول وخروج وإنشاء حساب"},
        {"name": "Users",            "description": "الملفات الشخصية والتقييمات"},
        {"name": "Services",         "description": "الخدمات المقدّمة من العمال"},
        {"name": "Posts & Offers",   "description": "منشورات المستخدمين والعروض"},
        {"name": "Service Requests", "description": "طلبات الخدمة ودورة حياتها"},
        {"name": "Chat",             "description": "المراسلة الفورية وإدارة المحادثات"},
        {"name": "Safe Area",        "description": "منطقة التسليم الآمن والدفع"},
        {"name": "Reports",          "description": "البلاغات"},
        {"name": "Health",           "description": "فحص حالة السيرفر"},
    ],
)


# ─── OpenAPI security scheme (Authorize button) ──────────
def _add_security(openapi_schema: dict) -> dict:
    """يُضيف BearerAuth لكل الـ endpoints المحمية."""
    comps = openapi_schema.setdefault("components", {})
    comps.setdefault("securitySchemes", {})["BearerAuth"] = {
        "type": "http",
        "scheme": "bearer",
        "bearerFormat": "JWT",
        "description": "أدخل التوكن: **Bearer &lt;token&gt;**",
    }

    for path_item in openapi_schema.get("paths", {}).values():
        for operation in path_item.values():
            if not isinstance(operation, dict):
                continue
            responses = operation.get("responses", {})
            # كل endpoint يُعيد 401 يحتاج auth
            if "401" in responses or "403" in responses:
                operation.setdefault("security", [{"BearerAuth": []}])

    return openapi_schema


# monkey-patch openapi() بعد بناء الـ schema
_original_openapi = app.openapi


def _custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema
    schema = _original_openapi()
    app.openapi_schema = _add_security(schema)
    return app.openapi_schema


app.openapi = _custom_openapi


# ─── CORS ────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Static files ────────────────────────────────────────
app.mount("/uploads", StaticFiles(directory=str(UPLOAD_DIR)), name="uploads")

# ─── Routers ─────────────────────────────────────────────
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(services.router)
app.include_router(posts.router)
app.include_router(requests.router)
app.include_router(chat.router)
app.include_router(safe_area.router)
app.include_router(reports.router)


# ─── Health ──────────────────────────────────────────────
@app.get("/", tags=["Health"], summary="Root")
async def root():
    return {"status": "ok", "app": "Amarlo API", "version": "1.0.0"}


@app.get("/health", tags=["Health"], summary="Health check")
async def health():
    return {"status": "healthy"}
