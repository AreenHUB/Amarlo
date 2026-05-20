"""
app/db/mongodb.py
─────────────────
MongoDB connection + indexes for performance.

Indexes added for:
  - users.email (unique)
  - services.worker_email
  - services.category
  - requests.user_email, worker_email
  - messages.sender_email + recipient_email
  - refresh_tokens.jti (unique)
  - refresh_tokens.user_email
"""
import logging
from pymongo import ASCENDING, MongoClient, IndexModel

from app.core.config import settings

logger = logging.getLogger(__name__)

# ─── Client singleton ────────────────────────
_client: MongoClient = MongoClient(
    settings.MONGO_URI,
    maxPoolSize=100,        # مهم للأداء مع آلاف المستخدمين
    minPoolSize=10,
    serverSelectionTimeoutMS=5000,
    connectTimeoutMS=5000,
)

_db = _client[settings.MONGO_DB_NAME]

# ─── Collections ─────────────────────────────
users_collection          = _db["users"]
services_collection       = _db["services"]
posts_collection          = _db["posts"]
requests_collection       = _db["service_requests"]
messages_collection       = _db["messages"]
reviews_collection        = _db["reviews"]
safe_area_collection          = _db["safe_area"]
safe_area_sessions_collection = _db["safe_area_sessions"]
conduct_reports_collection    = _db["conduct_reports"]
payments_collection           = _db["payments"]
reports_collection            = _db["reports"]
blocks_collection             = _db["user_blocks"]
refresh_tokens_collection     = _db["refresh_tokens"]


# ─── Indexes for performance ─────────────────
def _try_index(collection, indexes: list, label: str) -> None:
    """يُنشئ indexes بشكل آمن — يتجاهل الأخطاء ولا يوقف السيرفر."""
    for idx in indexes:
        try:
            collection.create_indexes([idx])
        except Exception as e:
            # DuplicateKey = بيانات قديمة موجودة - نتجاهل ونكمل
            err_str = str(e)
            if "DuplicateKey" in err_str or "11000" in err_str:
                logger.warning(f"Skipping unique index on {label}: duplicate data exists in DB")
            else:
                logger.warning(f"Index {label}: {e}")


def ensure_indexes() -> None:
    """يُنشئ الـ indexes بشكل آمن. يُستدعى عند startup."""
    _try_index(users_collection, [
        IndexModel([("email", ASCENDING)], unique=True, name="uniq_email"),
        IndexModel([("userType", ASCENDING)], name="idx_userType"),
    ], "users")

    _try_index(services_collection, [
        IndexModel([("worker_email", ASCENDING)], name="idx_worker_email"),
        IndexModel([("category", ASCENDING)], name="idx_category"),
        IndexModel([("location", ASCENDING)], name="idx_location"),
    ], "services")

    _try_index(posts_collection, [
        IndexModel([("creator_email", ASCENDING)], name="idx_creator"),
        IndexModel([("created_at", ASCENDING)], name="idx_created_at"),
        # TTL: حذف تلقائي بعد 7 أيام من expires_at
        # البوستات المغلقة (closed) لا تُحذف لأننا نُزيل expires_at عنها
        IndexModel(
            [("expires_at", ASCENDING)],
            expireAfterSeconds=0,
            name="ttl_expires_at",
        ),
    ], "posts")

    _try_index(requests_collection, [
        IndexModel([("user_email", ASCENDING)], name="idx_user"),
        IndexModel([("worker_email", ASCENDING)], name="idx_worker"),
        IndexModel([("status", ASCENDING)], name="idx_status"),
    ], "requests")

    _try_index(messages_collection, [
        IndexModel(
            [("sender_email", ASCENDING), ("recipient_email", ASCENDING)],
            name="idx_conversation",
        ),
        IndexModel([("timestamp", ASCENDING)], name="idx_timestamp"),
    ], "messages")

    _try_index(reviews_collection, [
        IndexModel([("worker_email", ASCENDING)], name="idx_worker"),
    ], "reviews")

    _try_index(refresh_tokens_collection, [
        IndexModel([("jti", ASCENDING)], unique=True, name="uniq_jti"),
        IndexModel([("user_email", ASCENDING)], name="idx_user"),
        IndexModel(
            [("expires_at", ASCENDING)],
            expireAfterSeconds=0,
            name="ttl_expires",
        ),
    ], "refresh_tokens")

    _try_index(blocks_collection, [
        IndexModel(
            [("blocker_email", ASCENDING), ("blocked_email", ASCENDING)],
            unique=True,
            name="uniq_block",
        ),
    ], "blocks")

    _try_index(conduct_reports_collection, [
        IndexModel([("reporter_email", ASCENDING)], name="idx_reporter"),
        IndexModel([("reported_email", ASCENDING)], name="idx_reported"),
        IndexModel([("status",         ASCENDING)], name="idx_status"),
    ], "conduct_reports")

    _try_index(safe_area_sessions_collection, [
        IndexModel([("initiator_email",   ASCENDING)], name="idx_initiator"),
        IndexModel([("participant_email", ASCENDING)], name="idx_participant"),
        IndexModel([("contract_ref",      ASCENDING)], unique=True, name="uniq_contract_ref"),
        IndexModel([("status",            ASCENDING)], name="idx_status"),
        # TTL: احذف الدعوات المنتهية تلقائياً بعد 7 أيام من انتهاء صلاحيتها
        IndexModel(
            [("invitation_expires_at", ASCENDING)],
            expireAfterSeconds=604800,  # 7 days after expiry
            name="ttl_invitation",
            sparse=True,
        ),
    ], "safe_area_sessions")

    logger.info("✅ MongoDB indexes ready")


def close_db() -> None:
    """يُغلق اتصال MongoDB (يُستدعى عند shutdown)."""
    _client.close()


# تشغيل الـ indexes عند الاستيراد
try:
    ensure_indexes()
except Exception:
    pass  # قد لا يكون MongoDB متاحاً وقت الاستيراد - سيُحاول عند startup
