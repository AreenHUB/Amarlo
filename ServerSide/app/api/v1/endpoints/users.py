"""
app/api/v1/endpoints/users.py
──────────────────────────────
GET    /users                      — بحث عن مستخدم بالـ email
GET    /users/{user_id}            — بروفايل مستخدم
PUT    /users/{user_id}            — تعديل البروفايل

Work Reviews (مرتبطة بـ request_id):
GET    /users/{email}/reviews      — تقييمات عامل (work reviews فقط)
POST   /users/{email}/reviews      — إضافة تقييم عمل مكتمل
DELETE /users/reviews/{review_id}  — حذف تقييم

Conduct Reports (بلاغات سلوكية):
POST   /users/conduct-report       — إبلاغ عن سلوك سيء (بعد أي تواصل)
GET    /users/{email}/conduct-summary — ملخص البلاغات (للعرض في البروفايل)

Review Eligibility:
GET    /users/{email}/can-review   — هل يمكن تقييم هذا الشخص الآن؟
"""
import uuid
from datetime import datetime, timezone
from typing import Optional

from fastapi import (APIRouter, Depends, File, Form,
                     HTTPException, Request, UploadFile, status)

from app.api.dependencies import get_current_user
from app.db import (conduct_reports_collection, requests_collection,
                    reviews_collection, users_collection)
from app.schemas.common import MessageResponse
from app.schemas.user import (CONDUCT_REASONS, ConductReportCreate,
                               ReviewCreate, ReviewOut,
                               WorkReviewCreate, WorkReviewOut, UserOut)
from app.utils.images import delete_image_file, save_upload_image

router = APIRouter(prefix="/users", tags=["Users"])


# ─── Helpers ─────────────────────────────────────────────
def _user_or_404(user_id: str) -> dict:
    user = users_collection.find_one({"_id": user_id})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


# ─── Endpoints ───────────────────────────────────────────

@router.get("", response_model=list[UserOut], summary="بحث عن مستخدم بالـ email")
async def search_users(
    email: Optional[str] = None,
    userType: Optional[str] = None,
    current_user: dict = Depends(get_current_user),
):
    query: dict = {}
    if email:
        query["email"] = email
    if userType:
        query["userType"] = userType
    docs = list(users_collection.find(query).limit(20))
    return [UserOut.from_doc(d) for d in docs]


@router.get("/{user_id}", response_model=UserOut, summary="بروفايل مستخدم")
async def get_user(user_id: str, current_user: dict = Depends(get_current_user)):
    return UserOut.from_doc(_user_or_404(user_id))


@router.put("/{user_id}", response_model=UserOut, summary="تعديل البروفايل")
async def update_user(
    user_id: str,
    username:     Optional[str] = Form(None),
    number:       Optional[str] = Form(None),
    city:         Optional[str] = Form(None),
    speciality:   Optional[str] = Form(None),
    introduction: Optional[str] = Form(None),
    facebook:     Optional[str] = Form(None),
    instagram:    Optional[str] = Form(None),
    telegram:     Optional[str] = Form(None),
    linkedin:     Optional[str] = Form(None),
    image:        Optional[UploadFile] = File(None),
    request:      Request = None,
    current_user: dict = Depends(get_current_user),
):
    if current_user["_id"] != user_id:
        raise HTTPException(status_code=403, detail="Not authorized")

    update: dict = {}
    for field, val in {
        "username": username, "number": number, "city": city,
        "speciality": speciality, "introduction": introduction,
        "facebook": facebook, "instagram": instagram,
        "telegram": telegram, "linkedin": linkedin,
    }.items():
        if val is not None:
            update[field] = val

    if image and image.filename:
        old = users_collection.find_one({"_id": user_id}, {"image_url": 1}) or {}
        delete_image_file(old.get("image_url"))
        update["image_url"] = await save_upload_image(image, "profiles", request)

    if update:
        users_collection.update_one({"_id": user_id}, {"$set": update})

    return UserOut.from_doc(users_collection.find_one({"_id": user_id}))


# ═══════════════════════════════════════════════════════
#  Work Reviews — مرتبطة بـ request_id مكتمل
# ═══════════════════════════════════════════════════════

def _calc_overall(q: int, p: int, c: int) -> float:
    return round((q + p + c) / 3, 1)


def _serialize_review(d: dict) -> WorkReviewOut:
    q = d.get("quality_rating", d.get("rating", 0))
    p = d.get("punctuality_rating", d.get("rating", 0))
    c = d.get("communication_rating", d.get("rating", 0))
    return WorkReviewOut(
        id=str(d["_id"]),
        reviewer_username=d.get("reviewer_username", ""),
        reviewer_email=d.get("reviewer_email", ""),
        reviewee_email=d.get("reviewee_email", d.get("worker_email", "")),
        request_id=d.get("request_id", ""),
        quality_rating=q,
        punctuality_rating=p,
        communication_rating=c,
        overall_rating=_calc_overall(q, p, c),
        comment=d.get("comment"),
        created_at=d.get("created_at").isoformat()
            if hasattr(d.get("created_at"), "isoformat") else str(d.get("created_at", "")),
    )


@router.get("/{worker_email}/reviews", response_model=list[WorkReviewOut])
async def get_reviews(worker_email: str):
    """تقييمات عامل — يدعم الـ schema الجديد (reviewee_email) والقديم (worker_email)."""
    docs = list(
        reviews_collection.find({
            "$or": [
                {"reviewee_email": worker_email},
                {"worker_email": worker_email, "reviewee_email": {"$exists": False}},
            ]
        })
        .sort("created_at", -1)
        .limit(50)
    )
    return [_serialize_review(d) for d in docs]


@router.get("/{email}/can-review", summary="هل يمكن تقييم هذا الشخص؟")
async def can_review(
    email: str,
    current_user: dict = Depends(get_current_user),
):
    """
    يُعيد قائمة الطلبات المكتملة التي يمكن تقييمها.
    طلب مؤهل للتقييم إذا:
      1. status = completed
      2. كلا الطرفين مشاركان فيه
      3. لم يُقيَّم بعد بواسطة هذا المستخدم
    """
    me = current_user["email"]
    # الطلبات المكتملة بين الطرفين
    completed = list(requests_collection.find({
        "$or": [
            {"user_email": me, "worker_email": email},
            {"user_email": email, "worker_email": me},
        ],
        "status": "completed",
    }))

    # الطلبات التي قيّمها المستخدم بالفعل
    already_reviewed = {
        d["request_id"]
        for d in reviews_collection.find({"reviewer_email": me, "reviewee_email": email})
    }

    eligible = []
    for req in completed:
        req_id = str(req["_id"])
        if req_id not in already_reviewed:
            eligible.append({
                "request_id":    req_id,
                "service_name":  req.get("service_name", ""),
                "completed_at":  req.get("updated_at", req.get("created_at", "")),
                "delivery_type": req.get("delivery_type", "online"),
            })

    return {
        "can_review": len(eligible) > 0,
        "eligible_requests": eligible,
        "reviewee_email": email,
    }


@router.post(
    "/{reviewee_email}/reviews",
    status_code=201,
    response_model=WorkReviewOut,
    summary="إضافة تقييم عمل مكتمل",
)
async def create_work_review(
    reviewee_email: str,
    body: WorkReviewCreate,
    current_user: dict = Depends(get_current_user),
):
    """
    تقييم عمل مكتمل — الشروط:
    1. يوجد request مكتمل بين الطرفين بهذا الـ request_id
    2. لم يُقيَّم هذا الـ request بعد من هذا المستخدم
    """
    me = current_user["email"]

    if me == reviewee_email:
        raise HTTPException(status_code=400, detail="Cannot review yourself")

    # تحقق أن الـ request موجود ومكتمل وبين الطرفين
    from bson import ObjectId
    try:
        req = requests_collection.find_one({"_id": ObjectId(body.request_id)})
    except Exception:
        req = requests_collection.find_one({"_id": body.request_id})

    if not req:
        raise HTTPException(status_code=404, detail="Request not found")

    if req.get("status") != "completed":
        raise HTTPException(
            status_code=400,
            detail="Can only review after the request is completed"
        )

    # تحقق أن كلا الطرفين مشاركان
    parties = {req.get("user_email"), req.get("worker_email")}
    if me not in parties or reviewee_email not in parties:
        raise HTTPException(status_code=403, detail="Not a participant in this request")

    # منع التكرار على نفس الـ request
    if reviews_collection.find_one({
        "request_id":    body.request_id,
        "reviewer_email": me,
        "reviewee_email": reviewee_email,
    }):
        raise HTTPException(
            status_code=409,
            detail="You already reviewed this person for this request"
        )

    overall = _calc_overall(
        body.quality_rating, body.punctuality_rating, body.communication_rating)

    doc = {
        "_id":                  str(uuid.uuid4()),
        "request_id":           body.request_id,
        "reviewer_email":       me,
        "reviewer_username":    current_user.get("username", ""),
        "reviewee_email":       reviewee_email,
        "quality_rating":       body.quality_rating,
        "punctuality_rating":   body.punctuality_rating,
        "communication_rating": body.communication_rating,
        "overall_rating":       overall,
        "comment":              body.comment,
        "created_at":           datetime.now(timezone.utc),
    }
    reviews_collection.insert_one(doc)
    return _serialize_review(doc)


@router.delete("/reviews/{review_id}", response_model=MessageResponse)
async def delete_review(review_id: str, current_user: dict = Depends(get_current_user)):
    doc = reviews_collection.find_one({"_id": review_id})
    if not doc:
        raise HTTPException(status_code=404, detail="Review not found")
    if doc["reviewer_email"] != current_user["email"]:
        raise HTTPException(status_code=403, detail="Not authorized")
    reviews_collection.delete_one({"_id": review_id})
    return {"message": "Review deleted"}


# ═══════════════════════════════════════════════════════
#  Conduct Reports — بلاغات سلوكية (بعد أي تواصل)
# ═══════════════════════════════════════════════════════

@router.post("/conduct-report", status_code=201, response_model=MessageResponse,
             summary="إبلاغ عن سلوك سيء")
async def submit_conduct_report(
    body: ConductReportCreate,
    current_user: dict = Depends(get_current_user),
):
    """
    بلاغ سلوكي — لا يحتاج عملاً مكتملاً، يكفي وجود محادثة.
    يذهب للـ Admin للمراجعة. يظهر كتحذير في البروفايل إذا تراكم.
    """
    me = current_user["email"]

    if me == body.reported_email:
        raise HTTPException(status_code=400, detail="Cannot report yourself")

    # تحقق أن المُبلَّغ عنه موجود
    if not users_collection.find_one({"email": body.reported_email}):
        raise HTTPException(status_code=404, detail="User not found")

    # تحقق أن الأسباب صحيحة
    invalid = [r for r in body.reasons if r not in CONDUCT_REASONS]
    if invalid:
        raise HTTPException(status_code=400, detail=f"Invalid reasons: {invalid}")

    # منع البلاغ المتكرر من نفس الشخص في أقل من 7 أيام
    from datetime import timedelta
    recent = conduct_reports_collection.find_one({
        "reporter_email": me,
        "reported_email": body.reported_email,
        "created_at": {"$gte": datetime.now(timezone.utc) - timedelta(days=7)},
    })
    if recent:
        raise HTTPException(
            status_code=429,
            detail="You already submitted a report for this user recently"
        )

    conduct_reports_collection.insert_one({
        "_id":            str(uuid.uuid4()),
        "reporter_email": me,
        "reporter_username": current_user.get("username", ""),
        "reported_email": body.reported_email,
        "reasons":        body.reasons,
        "details":        body.details,
        "status":         "pending",   # pending | reviewed | dismissed
        "created_at":     datetime.now(timezone.utc),
    })
    return {"message": "Report submitted. Our team will review it shortly."}


@router.get("/{email}/conduct-summary", summary="ملخص البلاغات السلوكية")
async def conduct_summary(email: str):
    """
    يُعيد عدد البلاغات المقبولة ضد هذا المستخدم.
    يظهر كتحذير في البروفايل إذا تجاوز الحد.
    """
    # فقط البلاغات المقبولة (reviewed, not dismissed)
    confirmed = conduct_reports_collection.count_documents({
        "reported_email": email,
        "status": "reviewed",
    })
    return {
        "email":           email,
        "conduct_warnings": confirmed,
        "has_warning":     confirmed >= 3,  # يظهر تحذير عند 3 بلاغات مقبولة
    }
