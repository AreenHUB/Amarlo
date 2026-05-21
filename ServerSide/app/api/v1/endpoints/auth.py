"""
app/api/v1/endpoints/auth.py
────────────────────────────
POST /auth/register       — إنشاء حساب
POST /auth/login          — تسجيل دخول (JSON)
POST /auth/token          — تسجيل دخول للـ Swagger /docs
POST /auth/refresh        — تجديد access token
POST /auth/logout         — تسجيل خروج
GET  /auth/me             — بيانات المستخدم الحالي
"""
import uuid
from datetime import datetime, timezone
from typing import Optional

from fastapi import (APIRouter, Depends, File, Form, HTTPException,
                     Request, UploadFile, status)
from fastapi.security import OAuth2PasswordRequestForm
from jose import JWTError
from pydantic import BaseModel, EmailStr

from app.api.dependencies import get_current_user
from app.core.security import (create_token_pair, decode_token,
                                hash_password, verify_password)
from app.db import refresh_tokens_collection, users_collection
from app.schemas.common import LoginResponse, MessageResponse
from app.schemas.user import UserOut
from app.utils.images import save_upload_image

router = APIRouter(prefix="/auth", tags=["Auth"])


# ─── Helpers ─────────────────────────────────────────────
class LoginRequest(BaseModel):
    email: EmailStr
    password: str


def _get_user_by_email(email: str) -> Optional[dict]:
    return users_collection.find_one({"email": email})


def _verify_user(email: str, password: str) -> dict:
    user = _get_user_by_email(email)
    if not user or not verify_password(password, user.get("password", "")):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )
    return user


def _save_refresh_token(email: str, jti: str) -> None:
    from datetime import timedelta
    from app.core.config import settings
    expires_at = datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    # Upsert — يُبطل القديم ويحفظ الجديد
    refresh_tokens_collection.update_one(
        {"user_email": email},
        {"$set": {"jti": jti, "user_email": email, "expires_at": expires_at}},
        upsert=True,
    )


def _build_response(user: dict, email: str) -> LoginResponse:
    tokens = create_token_pair(subject=email)
    _save_refresh_token(email, tokens["refresh_jti"])
    return LoginResponse(
        access_token=tokens["access_token"],
        refresh_token=tokens["refresh_token"],
        expires_in=tokens["expires_in"],
        user_id=str(user["_id"]),
        user_type=user.get("userType", ""),
        email=email,
        username=user.get("username", ""),
    )


# ─── Endpoints ───────────────────────────────────────────

@router.post(
    "/register",
    status_code=status.HTTP_201_CREATED,
    response_model=MessageResponse,
    summary="إنشاء حساب جديد",
)
async def register(
    username:   str           = Form(..., min_length=2, max_length=50),
    email:      EmailStr      = Form(...),
    password:   str           = Form(..., min_length=6),
    number:     str           = Form(...),
    gender:     str           = Form(...),
    city:       str           = Form(default=""),
    userType:   str           = Form(...),
    speciality: Optional[str] = Form(None),
    image:      Optional[UploadFile] = File(None),
    request:    Request = None,
):
    if userType not in ("Worker", "Normal"):
        raise HTTPException(status_code=400, detail="userType must be 'Worker' or 'Normal'")

    if _get_user_by_email(email):
        raise HTTPException(status_code=409, detail="Email already registered")

    image_url: Optional[str] = None
    if image and image.filename:
        image_url = await save_upload_image(image, "profiles", request)

    users_collection.insert_one({
        "_id":        str(uuid.uuid4()),
        "username":   username,
        "email":      str(email),
        "password":   hash_password(password),
        "number":     number,
        "gender":     gender,
        "city":       city,
        "userType":   userType,
        "speciality": speciality,
        "image_url":  image_url,
        "created_at": datetime.now(timezone.utc),
    })
    return {"message": "User registered successfully"}


@router.post("/login", response_model=LoginResponse, summary="تسجيل دخول")
async def login(data: LoginRequest):
    user = _verify_user(str(data.email), data.password)
    return _build_response(user, str(data.email))


@router.post(
    "/token",
    response_model=LoginResponse,
    summary="تسجيل دخول للـ Swagger UI (OAuth2 form)",
)
async def login_swagger(form: OAuth2PasswordRequestForm = Depends()):
    user = _verify_user(form.username, form.password)
    return _build_response(user, form.username)


@router.post("/refresh", response_model=LoginResponse, summary="تجديد access token")
async def refresh_token(refresh_token_str: str = Form(..., alias="refresh_token")):
    """
    يُجدّد الـ access_token باستخدام refresh_token صالح.
    يُبطل الـ refresh token القديم ويُعطي زوجاً جديداً (rotation).
    """
    try:
        payload = decode_token(refresh_token_str, expected_type="refresh")
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )

    email = payload.get("sub")
    jti = payload.get("jti")

    # تحقق أن الـ JTI موجود في DB (لم يُبطَل)
    stored = refresh_tokens_collection.find_one({"user_email": email, "jti": jti})
    if not stored:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token has been revoked",
        )

    user = _get_user_by_email(email)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    return _build_response(user, email)


@router.post("/logout", response_model=MessageResponse, summary="تسجيل خروج")
async def logout(current_user: dict = Depends(get_current_user)):
    # إبطال كل refresh tokens للمستخدم
    refresh_tokens_collection.delete_many({"user_email": current_user["email"]})
    return {"message": "Logged out successfully"}


@router.get("/me", response_model=UserOut, summary="بيانات المستخدم الحالي")
async def get_me(current_user: dict = Depends(get_current_user)):
    return UserOut.from_doc(current_user)
