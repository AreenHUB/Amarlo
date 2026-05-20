"""
seed_data.py
────────────
Populates amarlo_db with realistic test data.
Run from the project root:
    python seed_data.py

Keeps existing users (user1, user2) and existing service/post.
Adds: 10 Workers + 8 Normal Users + 30 Services + 15 Posts + Reviews + Requests
Passwords for ALL seeded users: Test@1234
"""

import uuid
from datetime import datetime, timezone, timedelta
from pymongo import MongoClient
from passlib.context import CryptContext

# ── Config ────────────────────────────────────────────────────────────────────
MONGO_URI   = "mongodb://localhost:27017"
DB_NAME     = "amarlo_db"
BASE_URL    = "http://10.0.2.2:8000"   # Android emulator → localhost
PLAIN_PASS  = "Test@1234"

pwd_ctx = CryptContext(schemes=["bcrypt"], deprecated="auto")
HASHED_PASS = pwd_ctx.hash(PLAIN_PASS)

# ── Picsum image helpers ───────────────────────────────────────────────────────
# picsum.photos delivers a different photo for every seed value — no account needed
def picsum(seed: int, w: int = 400, h: int = 300) -> str:
    return f"https://picsum.photos/seed/{seed}/{w}/{h}"

def picsum_square(seed: int, size: int = 200) -> str:
    return f"https://picsum.photos/seed/{seed}/{size}/{size}"

# ── Helpers ───────────────────────────────────────────────────────────────────
def uid() -> str:
    return str(uuid.uuid4())

def now(offset_days: int = 0) -> datetime:
    return datetime.now(timezone.utc) - timedelta(days=offset_days)

# ── Categories (must match what the app expects) ───────────────────────────────
CATEGORIES = [
    "Programming and Tech",
    "Graphic Design",
    "Writing and Translation",
    "Video and Animation",
    "Music and Audio",
    "Digital Marketing",
    "Business",
    "Photography",
    "Finance",
    "Education",
]

CITIES = ["dubai", "riyadh", "cairo", "amman", "beirut", "doha", "kuwait city", "muscat"]

# ── Workers ────────────────────────────────────────────────────────────────────
WORKERS = [
    {"username": "ahmed_dev",      "email": "ahmed_dev@gmail.com",      "speciality": "Programming and Tech",    "city": "dubai",       "gender": "Male"},
    {"username": "sara_design",    "email": "sara_design@gmail.com",    "speciality": "Graphic Design",          "city": "riyadh",      "gender": "Female"},
    {"username": "omar_writer",    "email": "omar_writer@gmail.com",    "speciality": "Writing and Translation", "city": "cairo",       "gender": "Male"},
    {"username": "lina_video",     "email": "lina_video@gmail.com",     "speciality": "Video and Animation",     "city": "beirut",      "gender": "Female"},
    {"username": "khaled_music",   "email": "khaled_music@gmail.com",   "speciality": "Music and Audio",         "city": "amman",       "gender": "Male"},
    {"username": "nour_marketing", "email": "nour_marketing@gmail.com", "speciality": "Digital Marketing",       "city": "doha",        "gender": "Female"},
    {"username": "faris_biz",      "email": "faris_biz@gmail.com",      "speciality": "Business",                "city": "kuwait city", "gender": "Male"},
    {"username": "rana_photo",     "email": "rana_photo@gmail.com",     "speciality": "Photography",             "city": "muscat",      "gender": "Female"},
    {"username": "tarek_finance",  "email": "tarek_finance@gmail.com",  "speciality": "Finance",                 "city": "dubai",       "gender": "Male"},
    {"username": "hana_edu",       "email": "hana_edu@gmail.com",       "speciality": "Education",               "city": "riyadh",      "gender": "Female"},
]

# ── Normal Users ───────────────────────────────────────────────────────────────
NORMAL_USERS = [
    {"username": "client_ali",    "email": "client_ali@gmail.com",    "city": "dubai",       "gender": "Male"},
    {"username": "client_mona",   "email": "client_mona@gmail.com",   "city": "riyadh",      "gender": "Female"},
    {"username": "client_youssef","email": "client_youssef@gmail.com","city": "cairo",       "gender": "Male"},
    {"username": "client_dina",   "email": "client_dina@gmail.com",   "city": "amman",       "gender": "Female"},
    {"username": "client_hassan", "email": "client_hassan@gmail.com", "city": "beirut",      "gender": "Male"},
    {"username": "client_nadia",  "email": "client_nadia@gmail.com",  "city": "doha",        "gender": "Female"},
    {"username": "client_rami",   "email": "client_rami@gmail.com",   "city": "kuwait city", "gender": "Male"},
    {"username": "client_sana",   "email": "client_sana@gmail.com",   "city": "muscat",      "gender": "Female"},
]

# ── Services (3 per worker) ────────────────────────────────────────────────────
SERVICES_TEMPLATES = [
    # Programming and Tech — ahmed_dev
    {"name": "Full-Stack Web Development",    "category": "Programming and Tech",    "price": 2500, "description": "Professional full-stack development using React + FastAPI. Includes responsive design, API integration, and deployment.", "location": "dubai"},
    {"name": "Mobile App Development",        "category": "Programming and Tech",    "price": 3500, "description": "Cross-platform mobile apps built with Flutter. Clean UI, fast performance, and backend integration.", "location": "dubai"},
    {"name": "API Development & Integration", "category": "Programming and Tech",    "price": 1500, "description": "RESTful API design and integration with any platform. Documentation included.", "location": "dubai"},
    # Graphic Design — sara_design
    {"name": "Brand Identity Design",         "category": "Graphic Design",          "price": 1200, "description": "Complete brand identity: logo, color palette, typography, and brand guidelines.", "location": "riyadh"},
    {"name": "Social Media Graphics Pack",    "category": "Graphic Design",          "price": 600,  "description": "30 custom social media posts designed for your brand — ready to publish.", "location": "riyadh"},
    {"name": "UI/UX Design for Apps",         "category": "Graphic Design",          "price": 2000, "description": "Full app UI/UX design with Figma. Includes wireframes, prototypes, and handoff files.", "location": "riyadh"},
    # Writing and Translation — omar_writer
    {"name": "Arabic–English Translation",    "category": "Writing and Translation", "price": 400,  "description": "Professional translation per 1000 words. Native-level quality, fast turnaround.", "location": "cairo"},
    {"name": "SEO Blog Writing",              "category": "Writing and Translation", "price": 300,  "description": "5 SEO-optimized blog articles on any topic. Keyword research included.", "location": "cairo"},
    {"name": "Resume & Cover Letter",         "category": "Writing and Translation", "price": 250,  "description": "Professional resume and tailored cover letter that gets interviews.", "location": "cairo"},
    # Video and Animation — lina_video
    {"name": "Promotional Video Editing",     "category": "Video and Animation",     "price": 800,  "description": "Professional video editing with motion graphics, color grading, and music.", "location": "beirut"},
    {"name": "2D Animation Explainer",        "category": "Video and Animation",     "price": 1800, "description": "60-second animated explainer video for your product or service.", "location": "beirut"},
    {"name": "YouTube Channel Intro",         "category": "Video and Animation",     "price": 450,  "description": "Catchy animated intro (10–15 sec) for your YouTube channel.", "location": "beirut"},
    # Music and Audio — khaled_music
    {"name": "Original Music Composition",   "category": "Music and Audio",         "price": 1200, "description": "Custom background music composed for your project. Full rights included.", "location": "amman"},
    {"name": "Podcast Editing",               "category": "Music and Audio",         "price": 350,  "description": "Professional podcast editing: noise removal, leveling, intro/outro.", "location": "amman"},
    {"name": "Voice-Over Recording",          "category": "Music and Audio",         "price": 500,  "description": "Professional Arabic/English voice-over for ads, explainers, or e-learning.", "location": "amman"},
    # Digital Marketing — nour_marketing
    {"name": "Social Media Management",       "category": "Digital Marketing",       "price": 900,  "description": "Full management of 3 social platforms for 1 month. Content + scheduling + analytics.", "location": "doha"},
    {"name": "Google Ads Campaign",           "category": "Digital Marketing",       "price": 700,  "description": "Setup and manage a Google Ads campaign. Includes keyword research and weekly reports.", "location": "doha"},
    {"name": "Email Marketing Campaign",      "category": "Digital Marketing",       "price": 500,  "description": "Design and send 4 email campaigns. Includes templates and performance tracking.", "location": "doha"},
    # Business — faris_biz
    {"name": "Business Plan Writing",         "category": "Business",                "price": 1500, "description": "Professional business plan with market analysis, financial projections, and pitch deck.", "location": "kuwait city"},
    {"name": "Market Research Report",        "category": "Business",                "price": 800,  "description": "In-depth market research report for your target industry and competitors.", "location": "kuwait city"},
    {"name": "Consulting Session (2 hours)",  "category": "Business",                "price": 400,  "description": "1-on-1 business consulting session. Strategy, problem-solving, and action plan.", "location": "kuwait city"},
    # Photography — rana_photo
    {"name": "Product Photography",           "category": "Photography",             "price": 600,  "description": "Professional product photos (20 images, edited). Perfect for e-commerce.", "location": "muscat"},
    {"name": "Portrait Session",              "category": "Photography",             "price": 450,  "description": "Professional portrait session (1 hour, 15 edited photos).", "location": "muscat"},
    {"name": "Event Photography",             "category": "Photography",             "price": 1200, "description": "Full event coverage (up to 4 hours, 100+ edited photos).", "location": "muscat"},
    # Finance — tarek_finance
    {"name": "Financial Planning Report",     "category": "Finance",                 "price": 1000, "description": "Personal or business financial plan with budgeting, goals, and investment advice.", "location": "dubai"},
    {"name": "Tax Consultation",              "category": "Finance",                 "price": 600,  "description": "Expert tax consultation and filing assistance for individuals and businesses.", "location": "dubai"},
    {"name": "Bookkeeping (Monthly)",         "category": "Finance",                 "price": 500,  "description": "Monthly bookkeeping service: tracking income/expenses, invoices, and reports.", "location": "dubai"},
    # Education — hana_edu
    {"name": "Arabic Language Tutoring",      "category": "Education",               "price": 200,  "description": "10 hours of Arabic language tutoring for beginners and intermediate learners.", "location": "riyadh"},
    {"name": "Math & Physics Coaching",       "category": "Education",               "price": 250,  "description": "High school and university math/physics coaching. Exam preparation included.", "location": "riyadh"},
    {"name": "English Conversation Practice", "category": "Education",               "price": 180,  "description": "10 one-hour sessions for English conversation improvement and fluency.", "location": "riyadh"},
]

# ── Posts from Normal Users ────────────────────────────────────────────────────
POSTS_TEMPLATES = [
    {"title": "Need a logo for my startup",           "description": "Looking for a minimalist logo for a tech startup. Prefer flat design with blue tones.",            "price_range": "300-600",   "category": "Graphic Design",          "creator_idx": 0},
    {"title": "Website needed for my restaurant",     "description": "I need a simple 5-page website for my restaurant with menu, gallery, and reservation form.",       "price_range": "1000-2000", "category": "Programming and Tech",    "creator_idx": 1},
    {"title": "Arabic to English translation needed", "description": "Need 3000 words translated from Arabic to English. Legal document, accuracy is critical.",         "price_range": "200-400",   "category": "Writing and Translation", "creator_idx": 2},
    {"title": "Promo video for new product",          "description": "I launched a new skincare product and need a 60-second promotional video with music and text.",     "price_range": "500-1000",  "category": "Video and Animation",     "creator_idx": 3},
    {"title": "Social media management for 3 months", "description": "Need someone to manage my Instagram and TikTok. Post 3x weekly with captions and hashtags.",      "price_range": "800-1500",  "category": "Digital Marketing",       "creator_idx": 4},
    {"title": "Business plan for investor pitch",     "description": "I have a startup idea and need a full business plan ready for investor meetings.",                  "price_range": "800-1500",  "category": "Business",                "creator_idx": 5},
    {"title": "Product photos for Amazon store",      "description": "I sell handmade products on Amazon and need professional white-background product photos.",         "price_range": "400-800",   "category": "Photography",             "creator_idx": 6},
    {"title": "Math tutoring for my daughter",        "description": "My daughter is in grade 10 and struggling with calculus. Need weekly sessions for 2 months.",      "price_range": "150-300",   "category": "Education",               "creator_idx": 7},
    {"title": "App UI design needed",                 "description": "I have a food delivery app idea. Need full UI/UX design before I find a developer.",               "price_range": "1000-2500", "category": "Graphic Design",          "creator_idx": 0},
    {"title": "Blog content writing (monthly)",       "description": "Need 8 blog articles per month for my health and wellness website. SEO-focused.",                  "price_range": "400-700",   "category": "Writing and Translation", "creator_idx": 1},
    {"title": "YouTube channel branding",             "description": "Starting a cooking channel. Need logo, thumbnail templates, banner, and channel intro video.",      "price_range": "300-600",   "category": "Video and Animation",     "creator_idx": 2},
    {"title": "Podcast production help",              "description": "I record weekly podcast episodes and need editing, intro music, and publishing help.",              "price_range": "200-500",   "category": "Music and Audio",         "creator_idx": 3},
    {"title": "Google Ads for my e-commerce store",  "description": "I run an online clothing store and want to run Google Ads. Need setup and ongoing management.",    "price_range": "500-1000",  "category": "Digital Marketing",       "creator_idx": 4},
    {"title": "Monthly bookkeeping for small biz",   "description": "I run a small café and need monthly bookkeeping and expense tracking.",                            "price_range": "300-600",   "category": "Finance",                 "creator_idx": 5},
    {"title": "English coaching for job interviews", "description": "I have job interviews coming up at international companies and need English preparation help.",     "price_range": "100-250",   "category": "Education",               "creator_idx": 6},
]

# ── Reviews templates ─────────────────────────────────────────────────────────
REVIEW_COMMENTS = [
    ("Amazing work! Delivered on time and exceeded expectations.", 5),
    ("Very professional and communicative throughout the project.", 5),
    ("Great quality, will definitely hire again.", 5),
    ("Good work overall, minor revisions needed but handled quickly.", 4),
    ("Solid results, happy with the final output.", 4),
    ("Decent work but communication could be better.", 3),
    ("Delivered as promised, nothing more nothing less.", 3),
    ("Excellent attention to detail and very responsive.", 5),
    ("Highly recommend! Best freelancer I've worked with.", 5),
    ("Good value for money. Will consider for future projects.", 4),
]

# ─────────────────────────────────────────────────────────────────────────────
# MAIN SEEDING LOGIC
# ─────────────────────────────────────────────────────────────────────────────

def seed():
    client = MongoClient(MONGO_URI)
    db = client[DB_NAME]

    users_col    = db["users"]
    services_col = db["services"]
    posts_col    = db["posts"]
    reviews_col  = db["reviews"]
    requests_col = db["service_requests"]

    print(f"Connected to MongoDB >> {DB_NAME}")

    # ── 1. Insert Workers ─────────────────────────────────────────────────────
    worker_docs = []
    worker_emails = []
    print("\n[1/5] Inserting Workers...")
    for i, w in enumerate(WORKERS):
        if users_col.find_one({"email": w["email"]}):
            print(f"  SKIP (exists): {w['email']}")
            worker_emails.append(w["email"])
            continue
        doc = {
            "_id":        uid(),
            "username":   w["username"],
            "email":      w["email"],
            "password":   HASHED_PASS,
            "number":     f"05{50000000 + i:08d}",
            "gender":     w["gender"],
            "city":       w["city"],
            "userType":   "Worker",
            "speciality": w["speciality"],
            "image_url":  None,
            "introduction": f"Hi! I'm {w['username'].replace('_', ' ').title()}, a professional specializing in {w['speciality']}. I deliver high-quality work on time.",
            "facebook":   None,
            "instagram":  None,
            "telegram":   None,
            "created_at": now(offset_days=30 - i),
        }
        users_col.insert_one(doc)
        worker_emails.append(w["email"])
        print(f"  + Worker: {w['email']}")

    # Also track usernames for workers
    worker_usernames = {w["email"]: w["username"] for w in WORKERS}

    # ── 2. Insert Normal Users ────────────────────────────────────────────────
    normal_user_docs = []
    normal_emails = []
    normal_usernames_map = {}
    print("\n[2/5] Inserting Normal Users...")
    for i, u in enumerate(NORMAL_USERS):
        if users_col.find_one({"email": u["email"]}):
            print(f"  SKIP (exists): {u['email']}")
            normal_emails.append(u["email"])
            normal_usernames_map[u["email"]] = u["username"]
            continue
        doc = {
            "_id":        uid(),
            "username":   u["username"],
            "email":      u["email"],
            "password":   HASHED_PASS,
            "number":     f"05{60000000 + i:08d}",
            "gender":     u["gender"],
            "city":       u["city"],
            "userType":   "Normal User",
            "speciality": None,
            "image_url":  None,
            "introduction": None,
            "facebook":   None,
            "instagram":  None,
            "telegram":   None,
            "created_at": now(offset_days=25 - i),
        }
        users_col.insert_one(doc)
        normal_emails.append(u["email"])
        normal_usernames_map[u["email"]] = u["username"]
        print(f"  + User:   {u['email']}")

    # ── 3. Insert Services ────────────────────────────────────────────────────
    print("\n[3/5] Inserting Services...")
    worker_email_list = [w["email"] for w in WORKERS]

    for i, svc in enumerate(SERVICES_TEMPLATES):
        # Map service to the correct worker by specialty
        worker_email = worker_email_list[i // 3]   # 3 services per worker
        worker_uname = WORKERS[i // 3]["username"]

        if services_col.find_one({"name": svc["name"], "worker_email": worker_email}):
            print(f"  SKIP (exists): {svc['name']}")
            continue

        doc = {
            "_id":          uid(),
            "name":         svc["name"],
            "description":  svc["description"],
            "price":        svc["price"],
            "category":     svc["category"],
            "location":     svc["location"],
            "worker_email": worker_email,
            "worker_username": worker_uname,
            # picsum seed = 100 + i gives 30 unique landscape photos
            "image_url":    picsum(seed=100 + i, w=600, h=400),
            "created_at":   now(offset_days=20 - i % 20),
        }
        services_col.insert_one(doc)
        print(f"  + Service: [{svc['category']}] {svc['name']}")

    # ── 4. Insert Posts ───────────────────────────────────────────────────────
    print("\n[4/5] Inserting Posts...")
    for i, post in enumerate(POSTS_TEMPLATES):
        creator_email    = normal_emails[post["creator_idx"] % len(normal_emails)]
        creator_username = normal_usernames_map.get(creator_email, "client")

        if posts_col.find_one({"title": post["title"], "creator_email": creator_email}):
            print(f"  SKIP (exists): {post['title']}")
            continue

        # لا نُضيف offers من السكريبت — يُرسلها Workers عبر التطبيق
        # (إضافتها مباشرة تُسبب 409 Conflict عند محاولة الإرسال الحقيقي)
        doc = {
            "_id":             uid(),
            "title":           post["title"],
            "description":     post["description"],
            "price_range":     post["price_range"],
            "category":        post["category"],
            "creator_email":   creator_email,
            "creator_username": creator_username,
            "offers":          [],
            "created_at":      now(offset_days=15 - i),
        }
        posts_col.insert_one(doc)
        print(f"  + Post: {post['title']}")

    # ── 5. Insert Reviews (new schema — linked to fake completed requests) ────────
    print("\n[5/5] Inserting Reviews...")

    # أنشئ طلبات وهمية مكتملة لكل Worker حتى يمكن ربط التقييمات بها
    requests_col = db["service_requests"]
    from bson import ObjectId

    for i, worker_email in enumerate(worker_email_list):
        for j in range(2):
            reviewer_email    = normal_emails[(i + j) % len(normal_emails)]
            reviewer_username = normal_usernames_map.get(reviewer_email, "client")
            comment, rating   = REVIEW_COMMENTS[(i * 2 + j) % len(REVIEW_COMMENTS)]

            # تحقق: هل يوجد review بالـ schema الجديد لهذا الـ Worker والـ reviewer؟
            if reviews_col.find_one({"reviewee_email": worker_email, "reviewer_email": reviewer_email}):
                print(f"  SKIP (exists): review for {worker_email}")
                continue

            # أنشئ طلب مكتمل وهمي لربط التقييم به
            req_doc = {
                "service_id":   uid(),
                "service_name": f"Seed Service by {worker_email.split('@')[0]}",
                "user_email":   reviewer_email,
                "user_name":    reviewer_username,
                "worker_email": worker_email,
                "status":       "completed",
                "delivery_type": "online",
                "created_at":   now(offset_days=10 - j),
            }
            req_result = requests_col.insert_one(req_doc)
            request_id = str(req_result.inserted_id)

            # التقييم بالـ schema الجديد
            q = rating
            p = max(1, rating - (1 if j % 3 == 0 else 0))
            c = max(1, rating - (1 if j % 2 == 0 else 0))
            overall = round((q + p + c) / 3, 1)

            doc = {
                "_id":                  uid(),
                "request_id":           request_id,
                "reviewee_email":       worker_email,
                "reviewer_email":       reviewer_email,
                "reviewer_username":    reviewer_username,
                "quality_rating":       q,
                "punctuality_rating":   p,
                "communication_rating": c,
                "overall_rating":       overall,
                "rating":               rating,   # legacy fallback
                "worker_email":         worker_email,  # legacy fallback
                "comment":              comment,
                "created_at":           now(offset_days=5 - j),
            }
            reviews_col.insert_one(doc)
        print(f"  + 2 reviews for: {worker_email}")

    # ── Summary ───────────────────────────────────────────────────────────────
    print("\n" + "=" * 50)
    print("SEED COMPLETE")
    print("=" * 50)
    print(f"  Users (total):    {users_col.count_documents({})}")
    print(f"  Services (total): {services_col.count_documents({})}")
    print(f"  Posts (total):    {posts_col.count_documents({})}")
    print(f"  Reviews (total):  {reviews_col.count_documents({})}")
    print()
    print("Login with any seeded account:")
    print(f"  Email:    ahmed_dev@gmail.com  (Worker)")
    print(f"  Email:    client_ali@gmail.com (Normal User)")
    print(f"  Password: {PLAIN_PASS}  (for all seeded accounts)")
    print()
    print("Note: Service images use picsum.photos -- internet required to display.")
    print("=" * 50)

    client.close()


if __name__ == "__main__":
    seed()
