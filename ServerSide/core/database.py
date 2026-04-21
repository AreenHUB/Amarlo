from pymongo import MongoClient

MONGO_URL = "mongodb://localhost:27017/"
DB_NAME = "flutter-app2"

client = MongoClient(MONGO_URL)
db = client[DB_NAME]

# ─── Collections ─────────────────────────────────────────
users_collection        = db["users-register"]
sessions_collection     = db["user-sessions"]
services_collection     = db["services"]
posts_collection        = db["user-posts"]
requests_collection     = db["service-requests"]
messages_collection     = db["messages"]
users_block_collection  = db["users-block"]
users_reports_collection = db["reports"]
reviews_collection      = db["reviews"]
safe_area_collection    = db["safe_area"]
payments_collection     = db["payments"]
