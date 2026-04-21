"""
routers/auth.py
───────────────
/auth/register  — إنشاء حساب (multipart/form-data)
/auth/login     — تسجيل دخول (JSON)
/auth/token     — تسجيل دخول للـ /docs Authorize (form-data OAuth2)
/auth/logout    — تسجيل خروج
/auth/me        — بيانات المستخدم الحالي
"""
import uuid
from datetime import timedelta
from typing import Optional

from fastapi import (
    APIRouter, Depends, File, Form,
    HTTPException, Request, UploadFile, status,
)
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel, EmailStr

from core.config import TOKEN_EXPIRATION_MINUTES
from core.database import sessions_collection, users_collection
from core.images import save_upload_image
from core.schemas import MessageResponse, UserOut
from core.security import (
    authenticate_user,
    create_access_token,
    get_current_user,
    hash_password,
)

router = APIRouter(prefix="/auth", tags=["Auth"])


# ─── Response schemas ─────────────────────────────────────
class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    user_type: str
    email: str


# ─── Register ─────────────────────────────────────────────
@router.post(
    "/register",
    status_code=status.HTTP_201_CREATED,
    response_model=MessageResponse,
    summary="إنشاء حساب جديد",
)
async def register(
    username:   str           = Form(...),
    email:      EmailStr      = Form(...),
    password:   str           = Form(..., min_length=6),
    number:     str           = Form(...),
    gender:     str           = Form(...),
    city:       str           = Form(...),
    userType:   str           = Form(...),
    speciality: Optional[str] = Form(None),
    image:      Optional[UploadFile] = File(None),
    request:    Request = None,
):
    if users_collection.find_one({"email": email}):
        raise HTTPException(status_code=409, detail="Email already registered")

    image_url: Optional[str] = None
    if image and image.filename:
        image_url = await save_upload_image(image, "profiles", request)

    users_collection.insert_one({
        "_id":        str(uuid.uuid4()),
        "username":   username,
        "email":      email,
        "password":   hash_password(password),
        "number":     number,
        "gender":     gender,
        "city":       city,
        "userType":   userType,
        "speciality": speciality,
        "image_url":  image_url,
    })
    return {"message": "User registered successfully"}


# ─── Login (JSON) ─────────────────────────────────────────
@router.post(
    "/login",
    response_model=LoginResponse,
    summary="تسجيل دخول (JSON)",
)
async def login(data: LoginRequest):
    user = await authenticate_user(data.email, data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )
    return _build_login_response(user, data.email)


# ─── Login (OAuth2 form) — للـ /docs Authorize ────────────
@router.post(
    "/token",
    response_model=LoginResponse,
    summary="تسجيل دخول للـ Swagger UI",
    include_in_schema=True,
)
async def login_for_docs(form: OAuth2PasswordRequestForm = Depends()):
    """
    يُستخدم تلقائياً من زر Authorize في /docs.
    username = email
    """
    user = await authenticate_user(form.username, form.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )
    return _build_login_response(user, form.username)


def _build_login_response(user: dict, email: str) -> LoginResponse:
    token = create_access_token(
        data={"sub": email},
        expires_delta=timedelta(minutes=TOKEN_EXPIRATION_MINUTES),
    )
    sessions_collection.insert_one({
        "_id": str(uuid.uuid4()),
        "email": email,
        "token": token,
    })
    return LoginResponse(
        access_token=token,
        user_id=str(user["_id"]),
        user_type=user.get("userType", ""),
        email=email,
    )


# ─── Logout ───────────────────────────────────────────────
@router.post("/logout", response_model=MessageResponse, summary="تسجيل خروج")
async def logout(current_user: dict = Depends(get_current_user)):
    sessions_collection.delete_many({"email": current_user["email"]})
    return {"message": "Logged out successfully"}


# ─── Me ───────────────────────────────────────────────────
@router.get("/me", response_model=UserOut, summary="بيانات المستخدم الحالي")
async def get_me(current_user: dict = Depends(get_current_user)):
    return UserOut.from_doc(current_user)
