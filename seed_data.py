"""
seed_data.py
────────────
Populates amarlo_db with realistic test data.
Run from the project root:
    python seed_data.py

Options:
    python seed_data.py          → wipe seeded data, then re-seed
    python seed_data.py --fresh  → drop ALL data in the DB, then seed

Passwords for ALL seeded accounts: Test@1234
"""

import sys
import uuid
from datetime import datetime, timezone, timedelta
from pymongo import MongoClient
from passlib.context import CryptContext

# ── Config ────────────────────────────────────────────────────────────────────
MONGO_URI  = "mongodb://localhost:27017"
DB_NAME    = "amarlo_db"
PLAIN_PASS = "Test@1234"

pwd_ctx     = CryptContext(schemes=["bcrypt"], deprecated="auto")
HASHED_PASS = pwd_ctx.hash(PLAIN_PASS)

# ── Image helpers (picsum) ─────────────────────────────────────────────────────
def picsum(seed: int, w: int = 600, h: int = 400) -> str:
    return f"https://picsum.photos/seed/{seed}/{w}/{h}"

def picsum_square(seed: int, size: int = 200) -> str:
    return f"https://picsum.photos/seed/{seed}/{size}/{size}"

# ── Helpers ───────────────────────────────────────────────────────────────────
def uid() -> str:
    return str(uuid.uuid4())

def now(offset_days: int = 0) -> datetime:
    return datetime.now(timezone.utc) - timedelta(days=offset_days)

# ── Master data ───────────────────────────────────────────────────────────────
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

WORKERS = [
    {"username": "ahmed_dev",      "email": "ahmed_dev@gmail.com",      "speciality": "Programming and Tech",    "city": "dubai",       "gender": "Male",
     "facebook": "ahmed.dev.official", "instagram": "ahmed_dev_code", "telegram": "ahmeddev", "linkedin": "ahmed-karimi-dev"},
    {"username": "sara_design",    "email": "sara_design@gmail.com",    "speciality": "Graphic Design",          "city": "riyadh",      "gender": "Female",
     "facebook": None, "instagram": "sara.designs", "telegram": None, "linkedin": "sara-design-portfolio"},
    {"username": "omar_writer",    "email": "omar_writer@gmail.com",    "speciality": "Writing and Translation", "city": "cairo",       "gender": "Male",
     "facebook": "omar.writer.eg", "instagram": None, "telegram": "omarwriter", "linkedin": None},
    {"username": "lina_video",     "email": "lina_video@gmail.com",     "speciality": "Video and Animation",     "city": "beirut",      "gender": "Female",
     "facebook": None, "instagram": "lina.video.lb", "telegram": None, "linkedin": "lina-rahhal-video"},
    {"username": "khaled_music",   "email": "khaled_music@gmail.com",   "speciality": "Music and Audio",         "city": "amman",       "gender": "Male",
     "facebook": "khaled.music.jo", "instagram": "khaled_beats", "telegram": "khaledmusic", "linkedin": None},
    {"username": "nour_marketing", "email": "nour_marketing@gmail.com", "speciality": "Digital Marketing",       "city": "doha",        "gender": "Female",
     "facebook": None, "instagram": "nour.marketing", "telegram": "nourmarketing", "linkedin": "nour-hussain-marketing"},
    {"username": "faris_biz",      "email": "faris_biz@gmail.com",      "speciality": "Business",                "city": "kuwait city", "gender": "Male",
     "facebook": "faris.business", "instagram": None, "telegram": None, "linkedin": "faris-al-rashid-biz"},
    {"username": "rana_photo",     "email": "rana_photo@gmail.com",     "speciality": "Photography",             "city": "muscat",      "gender": "Female",
     "facebook": None, "instagram": "rana.photo.om", "telegram": "ranaphoto", "linkedin": None},
    {"username": "tarek_finance",  "email": "tarek_finance@gmail.com",  "speciality": "Finance",                 "city": "dubai",       "gender": "Male",
     "facebook": "tarek.finance.ae", "instagram": None, "telegram": "tarekfinance", "linkedin": "tarek-nasser-cfa"},
    {"username": "hana_edu",       "email": "hana_edu@gmail.com",       "speciality": "Education",               "city": "riyadh",      "gender": "Female",
     "facebook": None, "instagram": "hana.teaches", "telegram": None, "linkedin": "hana-educational"},
]

NORMAL_USERS = [
    {"username": "client_ali",     "email": "client_ali@gmail.com",     "city": "dubai",       "gender": "Male"},
    {"username": "client_mona",    "email": "client_mona@gmail.com",    "city": "riyadh",      "gender": "Female"},
    {"username": "client_youssef", "email": "client_youssef@gmail.com", "city": "cairo",       "gender": "Male"},
    {"username": "client_dina",    "email": "client_dina@gmail.com",    "city": "amman",       "gender": "Female"},
    {"username": "client_hassan",  "email": "client_hassan@gmail.com",  "city": "beirut",      "gender": "Male"},
    {"username": "client_nadia",   "email": "client_nadia@gmail.com",   "city": "doha",        "gender": "Female"},
    {"username": "client_rami",    "email": "client_rami@gmail.com",    "city": "kuwait city", "gender": "Male"},
    {"username": "client_sana",    "email": "client_sana@gmail.com",    "city": "muscat",      "gender": "Female"},
    {"username": "client_kareem",  "email": "client_kareem@gmail.com",  "city": "cairo",       "gender": "Male"},
    {"username": "client_layla",   "email": "client_layla@gmail.com",   "city": "dubai",       "gender": "Female"},
]

SERVICES_TEMPLATES = [
    # ── ahmed_dev — Programming and Tech (6 services) ─────────────────────────
    {"name": "Full-Stack Web Development",       "category": "Programming and Tech",    "price": 2500, "location": "dubai",
     "description": "Complete web app built with React + FastAPI. Responsive design, REST API, DB integration, and cloud deployment included.", "delivery_type": "online"},
    {"name": "Flutter Mobile App",               "category": "Programming and Tech",    "price": 3500, "location": "dubai",
     "description": "Cross-platform iOS & Android app using Flutter. Pixel-perfect UI, state management, and backend integration.", "delivery_type": "online"},
    {"name": "REST API Development",             "category": "Programming and Tech",    "price": 1500, "location": "dubai",
     "description": "Scalable RESTful API design with FastAPI or Node.js. Auth, documentation, and deployment included.", "delivery_type": "online"},
    {"name": "WordPress Website Setup",          "category": "Programming and Tech",    "price": 600,  "location": "dubai",
     "description": "Professional WordPress site with custom theme, plugins, SEO setup, and contact forms. Ready to launch.", "delivery_type": "online"},
    {"name": "Bug Fixing & Code Review",         "category": "Programming and Tech",    "price": 400,  "location": "dubai",
     "description": "I'll review your codebase, find bugs, fix issues, and improve code quality. Any language or framework.", "delivery_type": "online"},
    {"name": "Database Design & Optimization",   "category": "Programming and Tech",    "price": 900,  "location": "dubai",
     "description": "MongoDB or PostgreSQL schema design, indexing, query optimization, and migration scripts.", "delivery_type": "online"},

    # ── sara_design — Graphic Design (6 services) ────────────────────────────
    {"name": "Brand Identity Package",           "category": "Graphic Design",          "price": 1200, "location": "riyadh",
     "description": "Logo, color palette, typography, business card, and brand guidelines delivered as editable files.", "delivery_type": "online"},
    {"name": "Social Media Graphics Pack",       "category": "Graphic Design",          "price": 600,  "location": "riyadh",
     "description": "30 custom branded posts for Instagram, Facebook, and Twitter. Includes templates for future use.", "delivery_type": "online"},
    {"name": "UI/UX App Design",                 "category": "Graphic Design",          "price": 2000, "location": "riyadh",
     "description": "Full mobile or web app UI/UX in Figma. Wireframes, high-fidelity screens, prototype, and handoff file.", "delivery_type": "online"},
    {"name": "Logo Design",                      "category": "Graphic Design",          "price": 350,  "location": "riyadh",
     "description": "Unique, memorable logo with 3 initial concepts and 2 revision rounds. Delivered in SVG, PNG, and PDF.", "delivery_type": "online"},
    {"name": "Pitch Deck Design",                "category": "Graphic Design",          "price": 800,  "location": "riyadh",
     "description": "Investor-ready presentation design (up to 20 slides) in PowerPoint or Google Slides.", "delivery_type": "online"},
    {"name": "Product Label & Packaging",        "category": "Graphic Design",          "price": 550,  "location": "riyadh",
     "description": "Eye-catching product label and packaging design for physical or e-commerce products. Print-ready files.", "delivery_type": "online"},

    # ── omar_writer — Writing and Translation (6 services) ───────────────────
    {"name": "Arabic–English Translation",       "category": "Writing and Translation", "price": 400,  "location": "cairo",
     "description": "Native-quality translation per 1000 words. Legal, medical, and technical documents handled.", "delivery_type": "online"},
    {"name": "SEO Blog Articles (5 pack)",       "category": "Writing and Translation", "price": 300,  "location": "cairo",
     "description": "5 keyword-rich blog posts (800–1200 words each). Keyword research, meta descriptions, and formatting included.", "delivery_type": "online"},
    {"name": "Resume & Cover Letter",            "category": "Writing and Translation", "price": 250,  "location": "cairo",
     "description": "ATS-optimized resume and tailored cover letter. Designed to get interviews at top companies.", "delivery_type": "online"},
    {"name": "Copywriting for Ads",              "category": "Writing and Translation", "price": 350,  "location": "cairo",
     "description": "Compelling ad copy for Google Ads, Facebook, Instagram, or landing pages. A/B tested variants included.", "delivery_type": "online"},
    {"name": "Website Content Writing",          "category": "Writing and Translation", "price": 500,  "location": "cairo",
     "description": "Full website copy: homepage, about, services, contact, and FAQs. SEO-optimized and brand-aligned.", "delivery_type": "online"},
    {"name": "Proofreading & Editing",           "category": "Writing and Translation", "price": 150,  "location": "cairo",
     "description": "Grammar, clarity, and style editing for any document up to 5000 words. 24-hour turnaround.", "delivery_type": "online"},

    # ── lina_video — Video and Animation (6 services) ────────────────────────
    {"name": "Promotional Video Editing",        "category": "Video and Animation",     "price": 800,  "location": "beirut",
     "description": "Professional video editing with motion graphics, color grading, transitions, and background music.", "delivery_type": "online"},
    {"name": "2D Explainer Animation",           "category": "Video and Animation",     "price": 1800, "location": "beirut",
     "description": "60-second animated explainer video with script, voiceover, and custom illustrations.", "delivery_type": "online"},
    {"name": "YouTube Channel Intro",            "category": "Video and Animation",     "price": 450,  "location": "beirut",
     "description": "10–15 second animated channel intro with logo reveal, custom music, and your branding.", "delivery_type": "online"},
    {"name": "Social Media Reels Editing",       "category": "Video and Animation",     "price": 350,  "location": "beirut",
     "description": "5 short-form video reels edited for Instagram, TikTok, or YouTube Shorts with captions and effects.", "delivery_type": "online"},
    {"name": "Product Demo Video",               "category": "Video and Animation",     "price": 1200, "location": "beirut",
     "description": "60-second product demo video with screen recording, voiceover, and branded lower thirds.", "delivery_type": "online"},
    {"name": "Whiteboard Animation",             "category": "Video and Animation",     "price": 900,  "location": "beirut",
     "description": "Engaging whiteboard-style animated video (up to 90 seconds) perfect for tutorials or pitches.", "delivery_type": "online"},

    # ── khaled_music — Music and Audio (6 services) ──────────────────────────
    {"name": "Original Music Composition",       "category": "Music and Audio",         "price": 1200, "location": "amman",
     "description": "Custom royalty-free background music for your video, game, or project. Full commercial rights included.", "delivery_type": "online"},
    {"name": "Podcast Editing",                  "category": "Music and Audio",         "price": 350,  "location": "amman",
     "description": "Professional podcast editing: noise removal, EQ, compression, leveling, and intro/outro music.", "delivery_type": "online"},
    {"name": "Arabic Voice-Over",                "category": "Music and Audio",         "price": 500,  "location": "amman",
     "description": "Studio-quality Arabic voice-over for ads, documentaries, e-learning, or IVR. Fast delivery.", "delivery_type": "online"},
    {"name": "Sound Design for Videos",          "category": "Music and Audio",         "price": 600,  "location": "amman",
     "description": "Complete sound design for your video: sound effects, ambient audio, and music mixing.", "delivery_type": "online"},
    {"name": "Beat Production",                  "category": "Music and Audio",         "price": 400,  "location": "amman",
     "description": "Custom trap, hip-hop, or pop beat produced to your specs. BPM, key, and mood customized.", "delivery_type": "online"},
    {"name": "Audio Mastering",                  "category": "Music and Audio",         "price": 250,  "location": "amman",
     "description": "Professional mastering for your track: EQ, compression, limiting, and loudness normalization.", "delivery_type": "online"},

    # ── nour_marketing — Digital Marketing (6 services) ─────────────────────
    {"name": "Social Media Management",          "category": "Digital Marketing",       "price": 900,  "location": "doha",
     "description": "Full management of 3 platforms for 1 month: content creation, scheduling, community management, and monthly report.", "delivery_type": "online"},
    {"name": "Google Ads Campaign",              "category": "Digital Marketing",       "price": 700,  "location": "doha",
     "description": "Google Ads setup and management: keyword research, ad copy, audience targeting, and weekly performance reports.", "delivery_type": "online"},
    {"name": "Email Marketing Campaign",         "category": "Digital Marketing",       "price": 500,  "location": "doha",
     "description": "4 email newsletters designed, written, and sent via Mailchimp. Includes list segmentation and analytics.", "delivery_type": "online"},
    {"name": "Instagram Growth Strategy",        "category": "Digital Marketing",       "price": 650,  "location": "doha",
     "description": "30-day Instagram growth plan: content calendar, hashtag research, engagement strategy, and analytics review.", "delivery_type": "online"},
    {"name": "SEO Audit & Strategy",             "category": "Digital Marketing",       "price": 800,  "location": "doha",
     "description": "Full technical and on-page SEO audit with a 3-month action plan to improve your search rankings.", "delivery_type": "online"},
    {"name": "Facebook Ads Campaign",            "category": "Digital Marketing",       "price": 600,  "location": "doha",
     "description": "End-to-end Facebook & Instagram ads: audience setup, creative brief, campaign management, and reporting.", "delivery_type": "online"},

    # ── faris_biz — Business (6 services) ────────────────────────────────────
    {"name": "Business Plan Writing",            "category": "Business",                "price": 1500, "location": "kuwait city",
     "description": "Investor-ready business plan with executive summary, market analysis, financial projections, and pitch deck.", "delivery_type": "online"},
    {"name": "Market Research Report",           "category": "Business",                "price": 800,  "location": "kuwait city",
     "description": "In-depth market research: competitor analysis, target audience, pricing, and growth opportunities.", "delivery_type": "online"},
    {"name": "Business Strategy Consulting",     "category": "Business",                "price": 400,  "location": "kuwait city",
     "description": "2-hour strategy session via video call. Covers growth planning, problem-solving, and actionable next steps.", "delivery_type": "online"},
    {"name": "Startup Feasibility Study",        "category": "Business",                "price": 1200, "location": "kuwait city",
     "description": "Full feasibility study for your startup idea: market size, competition, financials, risks, and recommendations.", "delivery_type": "online"},
    {"name": "Company Registration Consulting",  "category": "Business",                "price": 700,  "location": "kuwait city",
     "description": "End-to-end guidance on registering your company in UAE, KSA, or Egypt. All legal steps covered.", "delivery_type": "in_person"},
    {"name": "Investor Pitch Coaching",          "category": "Business",                "price": 550,  "location": "kuwait city",
     "description": "3 coaching sessions to refine your investor pitch: story, slides, delivery, and Q&A practice.", "delivery_type": "online"},

    # ── rana_photo — Photography (6 services) ────────────────────────────────
    {"name": "E-commerce Product Photography",   "category": "Photography",             "price": 600,  "location": "muscat",
     "description": "20 professionally edited product photos on white or lifestyle backgrounds. Perfect for Amazon and Shopify.", "delivery_type": "in_person"},
    {"name": "Portrait Session",                 "category": "Photography",             "price": 450,  "location": "muscat",
     "description": "1-hour professional portrait session (indoor or outdoor). 15 fully retouched high-resolution images.", "delivery_type": "in_person"},
    {"name": "Event Photography",                "category": "Photography",             "price": 1200, "location": "muscat",
     "description": "Full event coverage up to 4 hours. 100+ edited photos delivered within 3 business days.", "delivery_type": "in_person"},
    {"name": "Food Photography",                 "category": "Photography",             "price": 500,  "location": "muscat",
     "description": "Mouth-watering food photography for restaurants, cafes, or delivery apps. 15 edited images per session.", "delivery_type": "in_person"},
    {"name": "Real Estate Photography",          "category": "Photography",             "price": 700,  "location": "muscat",
     "description": "Interior and exterior property photos optimized for listings. Wide-angle lens, HDR editing, and fast delivery.", "delivery_type": "in_person"},
    {"name": "Headshots for LinkedIn",           "category": "Photography",             "price": 300,  "location": "muscat",
     "description": "Professional headshot session (30 min, indoor). 5 retouched photos in formats ready for LinkedIn and CVs.", "delivery_type": "in_person"},

    # ── tarek_finance — Finance (6 services) ─────────────────────────────────
    {"name": "Personal Financial Plan",          "category": "Finance",                 "price": 1000, "location": "dubai",
     "description": "Comprehensive financial plan covering budgeting, savings, investments, insurance, and retirement goals.", "delivery_type": "online"},
    {"name": "Tax Filing Consultation",          "category": "Finance",                 "price": 600,  "location": "dubai",
     "description": "Expert guidance on individual or corporate tax filing in UAE, KSA, or Egypt. VAT and income tax covered.", "delivery_type": "online"},
    {"name": "Monthly Bookkeeping",              "category": "Finance",                 "price": 500,  "location": "dubai",
     "description": "Full monthly bookkeeping: income/expense tracking, bank reconciliation, invoicing, and financial summary.", "delivery_type": "online"},
    {"name": "Investment Portfolio Review",      "category": "Finance",                 "price": 750,  "location": "dubai",
     "description": "Detailed review of your investment portfolio with risk assessment and rebalancing recommendations.", "delivery_type": "online"},
    {"name": "Business Financial Analysis",      "category": "Finance",                 "price": 1200, "location": "dubai",
     "description": "Profit & loss, cash flow, balance sheet analysis with a 12-month financial forecast for your business.", "delivery_type": "online"},
    {"name": "Startup Funding Strategy",         "category": "Finance",                 "price": 900,  "location": "dubai",
     "description": "Funding roadmap for your startup: grants, angel investors, VCs, and crowdfunding options with action plan.", "delivery_type": "online"},

    # ── hana_edu — Education (6 services) ────────────────────────────────────
    {"name": "Arabic Language Tutoring",         "category": "Education",               "price": 200,  "location": "riyadh",
     "description": "10 one-on-one Arabic lessons for beginners to intermediate. Reading, writing, grammar, and conversation.", "delivery_type": "online"},
    {"name": "Math & Physics Coaching",          "category": "Education",               "price": 250,  "location": "riyadh",
     "description": "High school and university math/physics coaching. Exam preparation, past papers, and concept clarification.", "delivery_type": "online"},
    {"name": "English Conversation Practice",    "category": "Education",               "price": 180,  "location": "riyadh",
     "description": "10 one-hour conversational English sessions focused on fluency, pronunciation, and confidence.", "delivery_type": "online"},
    {"name": "IELTS / TOEFL Preparation",        "category": "Education",               "price": 400,  "location": "riyadh",
     "description": "8-session IELTS or TOEFL prep course covering all four skills. Practice tests and feedback included.", "delivery_type": "online"},
    {"name": "Python Programming for Beginners", "category": "Education",               "price": 350,  "location": "riyadh",
     "description": "12 structured lessons taking you from zero to writing real Python programs. Projects and exercises included.", "delivery_type": "online"},
    {"name": "Study Skills & Time Management",   "category": "Education",               "price": 150,  "location": "riyadh",
     "description": "4-session workshop on proven study techniques, note-taking, exam strategy, and productivity habits.", "delivery_type": "online"},
]

POSTS_TEMPLATES = [
    {"title": "Need a logo for my startup",            "description": "Looking for a minimalist logo for a tech startup. Prefer flat design with blue tones.",           "price_range": "300-600",   "category": "Graphic Design",          "creator_idx": 0},
    {"title": "Website needed for my restaurant",      "description": "I need a simple 5-page website for my restaurant with menu, gallery, and reservation form.",      "price_range": "1000-2000", "category": "Programming and Tech",    "creator_idx": 1},
    {"title": "Arabic to English translation needed",  "description": "Need 3000 words translated from Arabic to English. Legal document, accuracy is critical.",        "price_range": "200-400",   "category": "Writing and Translation", "creator_idx": 2},
    {"title": "Promo video for new product",           "description": "I launched a new skincare product and need a 60-second promotional video with music and text.",    "price_range": "500-1000",  "category": "Video and Animation",     "creator_idx": 3},
    {"title": "Social media management for 3 months",  "description": "Need someone to manage my Instagram and TikTok. Post 3x weekly with captions and hashtags.",     "price_range": "800-1500",  "category": "Digital Marketing",       "creator_idx": 4},
    {"title": "Business plan for investor pitch",      "description": "I have a startup idea and need a full business plan ready for investor meetings.",                 "price_range": "800-1500",  "category": "Business",                "creator_idx": 5},
    {"title": "Product photos for Amazon store",       "description": "I sell handmade products on Amazon and need professional white-background product photos.",        "price_range": "400-800",   "category": "Photography",             "creator_idx": 6},
    {"title": "Math tutoring for my daughter",         "description": "My daughter is in grade 10 and struggling with calculus. Need weekly sessions for 2 months.",     "price_range": "150-300",   "category": "Education",               "creator_idx": 7},
    {"title": "App UI design needed",                  "description": "I have a food delivery app idea. Need full UI/UX design before I find a developer.",              "price_range": "1000-2500", "category": "Graphic Design",          "creator_idx": 0},
    {"title": "Blog content writing (monthly)",        "description": "Need 8 blog articles per month for my health and wellness website. SEO-focused.",                 "price_range": "400-700",   "category": "Writing and Translation", "creator_idx": 1},
    {"title": "YouTube channel branding",              "description": "Starting a cooking channel. Need logo, thumbnail templates, banner, and channel intro video.",     "price_range": "300-600",   "category": "Video and Animation",     "creator_idx": 2},
    {"title": "Podcast production help",               "description": "I record weekly podcast episodes and need editing, intro music, and publishing help.",             "price_range": "200-500",   "category": "Music and Audio",         "creator_idx": 3},
    {"title": "Google Ads for my e-commerce store",   "description": "I run an online clothing store and want to run Google Ads. Need setup and ongoing management.",   "price_range": "500-1000",  "category": "Digital Marketing",       "creator_idx": 4},
    {"title": "Monthly bookkeeping for small biz",    "description": "I run a small café and need monthly bookkeeping and expense tracking.",                           "price_range": "300-600",   "category": "Finance",                 "creator_idx": 5},
    {"title": "English coaching for job interviews",  "description": "I have job interviews coming up at international companies and need English preparation help.",    "price_range": "100-250",   "category": "Education",               "creator_idx": 6},
]

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

# Emails inserted by this script — used for targeted wipe
SEEDED_WORKER_EMAILS = [w["email"] for w in WORKERS]
SEEDED_USER_EMAILS   = [u["email"] for u in NORMAL_USERS]
ALL_SEEDED_EMAILS    = SEEDED_WORKER_EMAILS + SEEDED_USER_EMAILS


# ─────────────────────────────────────────────────────────────────────────────
#  WIPE — remove only data that was inserted by this script
# ─────────────────────────────────────────────────────────────────────────────
def wipe(db, fresh: bool = False):
    if fresh:
        print("\n[WIPE] Dropping ALL collections...")
        for col in ["users", "services", "posts", "reviews",
                    "service_requests", "payments", "messages",
                    "conduct_reports", "safe_area", "user_sessions"]:
            db[col].drop()
            print(f"  dropped: {col}")
        return

    print("\n[WIPE] Removing seeded data...")
    users_col    = db["users"]
    services_col = db["services"]
    posts_col    = db["posts"]
    reviews_col  = db["reviews"]
    requests_col = db["service_requests"]

    # Remove seeded users
    r = users_col.delete_many({"email": {"$in": ALL_SEEDED_EMAILS}})
    print(f"  deleted {r.deleted_count} users")

    # Remove services owned by seeded workers
    r = services_col.delete_many({"worker_email": {"$in": SEEDED_WORKER_EMAILS}})
    print(f"  deleted {r.deleted_count} services")

    # Remove posts created by seeded normal users
    r = posts_col.delete_many({"creator_email": {"$in": SEEDED_USER_EMAILS}})
    print(f"  deleted {r.deleted_count} posts")

    # Remove reviews involving seeded users
    r = reviews_col.delete_many({
        "$or": [
            {"reviewer_email": {"$in": ALL_SEEDED_EMAILS}},
            {"reviewee_email": {"$in": ALL_SEEDED_EMAILS}},
        ]
    })
    print(f"  deleted {r.deleted_count} reviews")

    # Remove requests involving seeded users
    r = requests_col.delete_many({
        "$or": [
            {"user_email":   {"$in": ALL_SEEDED_EMAILS}},
            {"worker_email": {"$in": SEEDED_WORKER_EMAILS}},
        ]
    })
    print(f"  deleted {r.deleted_count} service requests")

    # Collect request IDs that were deleted (by worker/user email) then clean payments + safe_area
    payments_col  = db["payments"]
    safe_area_col = db["safe_area"]
    r = payments_col.delete_many({"worker_email": {"$in": SEEDED_WORKER_EMAILS}})
    print(f"  deleted {r.deleted_count} payments")
    # safe_area docs are linked by request_id strings — cleaned up naturally when requests go


# ─────────────────────────────────────────────────────────────────────────────
#  SEED
# ─────────────────────────────────────────────────────────────────────────────
def seed(db):
    users_col    = db["users"]
    services_col = db["services"]
    posts_col    = db["posts"]
    reviews_col  = db["reviews"]
    requests_col = db["service_requests"]

    # ── 1. Workers ────────────────────────────────────────────────────────────
    print("\n[1/5] Inserting Workers...")
    worker_emails = []
    for i, w in enumerate(WORKERS):
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
            "image_url":  picsum_square(seed=200 + i),
            "introduction": (
                f"Hi! I'm {w['username'].replace('_', ' ').title()}, "
                f"a professional specializing in {w['speciality']}. "
                f"I deliver high-quality work on time and love what I do."
            ),
            "facebook":   w.get("facebook"),
            "instagram":  w.get("instagram"),
            "telegram":   w.get("telegram"),
            "linkedin":   w.get("linkedin"),
            "created_at": now(offset_days=30 - i),
        }
        users_col.insert_one(doc)
        worker_emails.append(w["email"])
        print(f"  + Worker: {w['email']}")

    # ── 2. Normal Users ───────────────────────────────────────────────────────
    print("\n[2/5] Inserting Normal Users...")
    normal_emails        = []
    normal_usernames_map = {}
    for i, u in enumerate(NORMAL_USERS):
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
            "image_url":  picsum_square(seed=300 + i),
            "introduction": None,
            "facebook":   None,
            "instagram":  None,
            "telegram":   None,
            "linkedin":   None,
            "created_at": now(offset_days=25 - i),
        }
        users_col.insert_one(doc)
        normal_emails.append(u["email"])
        normal_usernames_map[u["email"]] = u["username"]
        print(f"  + User:   {u['email']}")

    # ── 3. Services ───────────────────────────────────────────────────────────
    print("\n[3/5] Inserting Services...")
    for i, svc in enumerate(SERVICES_TEMPLATES):
        worker_email = worker_emails[i // 6]
        worker_uname = WORKERS[i // 6]["username"]
        doc = {
            "_id":             uid(),
            "name":            svc["name"],
            "description":     svc["description"],
            "price":           svc["price"],
            "category":        svc["category"],
            "location":        svc["location"],
            "delivery_type":   svc.get("delivery_type", "online"),
            "worker_email":    worker_email,
            "worker_username": worker_uname,
            "image_url":       picsum(seed=100 + i),
            "created_at":      now(offset_days=20 - i % 20),
        }
        services_col.insert_one(doc)
        print(f"  + Service: [{svc['category']}] {svc['name']}")

    # ── 4. Posts ──────────────────────────────────────────────────────────────
    print("\n[4/5] Inserting Posts...")
    for i, post in enumerate(POSTS_TEMPLATES):
        creator_email    = normal_emails[post["creator_idx"] % len(normal_emails)]
        creator_username = normal_usernames_map.get(creator_email, "client")
        doc = {
            "_id":              uid(),
            "title":            post["title"],
            "description":      post["description"],
            "price_range":      post["price_range"],
            "category":         post["category"],
            "delivery_type":    "online",
            "safe_area_enabled": False,
            "status":           "open",
            "creator_email":    creator_email,
            "creator_username": creator_username,
            "offers":           [],
            "created_at":       now(offset_days=15 - i),
        }
        posts_col.insert_one(doc)
        print(f"  + Post: {post['title']}")

    # ── 5. Completed Requests + Payments + Safe Area ─────────────────────────
    # Each entry creates:
    #   - service_request  (status=completed, linked to a real service)
    #   - safe_area doc    (both parties confirmed, payment confirmed)
    #   - payment doc      (amount = service price, counted by balance endpoint)
    # Reviews in step 6 are then linked to these same request IDs.
    print("\n[5/6] Inserting Completed Requests & Payments...")

    payments_col  = db["payments"]
    safe_area_col = db["safe_area"]

    # (worker_idx, svc_offset_within_worker, client_idx, days_ago_created, days_ago_completed)
    # svc_offset 0 = first service of that worker, 1 = second, etc.
    # ahmed_dev gets 5 completions for a strong wallet balance.
    COMPLETED_PLAN = [
        # ahmed_dev  (worker 0) -- 5 jobs
        (0, 0, 0, 60, 55),   # Full-Stack Web Dev    $2500
        (0, 1, 1, 50, 45),   # Flutter Mobile App    $3500
        (0, 2, 2, 40, 36),   # REST API Dev          $1500
        (0, 3, 3, 30, 27),   # WordPress Setup        $600
        (0, 4, 4, 20, 17),   # Bug Fixing             $400
        # sara_design (worker 1) -- 3 jobs
        (1, 0, 1, 45, 40),   # Brand Identity        $1200
        (1, 2, 3, 35, 30),   # UI/UX Design          $2000
        (1, 1, 5, 25, 21),   # Social Media Pack      $600
        # omar_writer (worker 2) -- 3 jobs
        (2, 0, 2, 42, 38),   # Translation            $400
        (2, 1, 4, 32, 28),   # SEO Blog Articles      $300
        (2, 4, 6, 22, 19),   # Website Content        $500
        # lina_video (worker 3) -- 2 jobs
        (3, 0, 0, 38, 34),   # Promo Video Edit       $800
        (3, 1, 3, 28, 24),   # 2D Explainer          $1800
        # khaled_music (worker 4) -- 2 jobs
        (4, 0, 5, 36, 32),   # Music Composition     $1200
        (4, 1, 7, 26, 22),   # Podcast Editing        $350
        # nour_marketing (worker 5) -- 2 jobs
        (5, 0, 1, 33, 29),   # Social Media Mgmt      $900
        (5, 2, 8, 23, 19),   # Email Marketing        $500
        # faris_biz (worker 6) -- 2 jobs
        (6, 0, 9, 31, 27),   # Business Plan         $1500
        (6, 1, 0, 21, 17),   # Market Research        $800
        # rana_photo (worker 7) -- 2 jobs
        (7, 0, 6, 29, 25),   # Product Photography    $600
        (7, 2, 2, 19, 15),   # Event Photography     $1200
        # tarek_finance (worker 8) -- 2 jobs
        (8, 0, 4, 27, 23),   # Financial Plan        $1000
        (8, 2, 7, 17, 13),   # Bookkeeping            $500
        # hana_edu (worker 9) -- 2 jobs
        (9, 0, 3, 25, 21),   # Arabic Tutoring        $200
        (9, 2, 9, 15, 11),   # English Conversation   $180
    ]

    # Build lookup: worker_idx -> sorted list of their service docs
    worker_services = {}
    for idx, w in enumerate(WORKERS):
        svcs = list(services_col.find({"worker_email": w["email"]}).sort("created_at", 1))
        worker_services[idx] = svcs

    # Maps (worker_idx, svc_offset) -> request_id so reviews can link to real requests
    completed_request_ids = {}

    for plan in COMPLETED_PLAN:
        w_idx, svc_offset, client_idx, days_created, days_completed = plan

        worker  = WORKERS[w_idx]
        svcs    = worker_services.get(w_idx, [])
        if svc_offset >= len(svcs):
            continue
        svc          = svcs[svc_offset]
        client_email = normal_emails[client_idx % len(normal_emails)]
        client_uname = normal_usernames_map.get(client_email, "client")
        price        = int(svc["price"])
        delivery     = svc.get("delivery_type", "online")

        req_doc = {
            "service_id":       svc["_id"],
            "service_name":     svc["name"],
            "service_price":    price,
            "agreed_price":     price,
            "user_email":       client_email,
            "user_name":        client_uname,
            "worker_email":     worker["email"],
            "status":           "completed",
            "delivery_type":    delivery,
            "safe_area_active": delivery == "online",
            "created_at":       now(offset_days=days_created),
            "updated_at":       now(offset_days=days_completed),
        }
        req_result = requests_col.insert_one(req_doc)
        request_id = str(req_result.inserted_id)
        completed_request_ids[(w_idx, svc_offset)] = request_id

        if delivery == "online":
            safe_area_col.insert_one({
                "request_id":        request_id,
                "payment_confirmed": True,
                "worker_confirmed":  True,
                "user_confirmed":    True,
                "file_path":         f"/seed/placeholder_{request_id}.pdf",
                "content_type":      "application/pdf",
                "is_image":          False,
                "uploaded_at":       now(offset_days=days_completed + 2),
            })

        payments_col.insert_one({
            "request_id":   request_id,
            "worker_email": worker["email"],
            "user_email":   client_email,
            "amount":       price,
            "timestamp":    now(offset_days=days_completed),
        })

        print(f"  + [{worker['username']}] {svc['name']} ${price} <- {client_uname}")

    # ── 6. Reviews linked to completed requests ───────────────────────────────
    print("\n[6/6] Inserting Reviews...")
    for i, worker_email in enumerate(worker_emails):
        for j in range(2):
            reviewer_email    = normal_emails[(i + j) % len(normal_emails)]
            reviewer_username = normal_usernames_map.get(reviewer_email, "client")
            comment, rating   = REVIEW_COMMENTS[(i * 2 + j) % len(REVIEW_COMMENTS)]

            # Prefer linking to a real completed request for this worker
            real_key = (i, j)
            if real_key in completed_request_ids:
                request_id = completed_request_ids[real_key]
            else:
                stub = requests_col.insert_one({
                    "service_id":       uid(),
                    "service_name":     f"Service by {worker_email.split('@')[0]}",
                    "service_price":    100,
                    "user_email":       reviewer_email,
                    "user_name":        reviewer_username,
                    "worker_email":     worker_email,
                    "status":           "completed",
                    "delivery_type":    "online",
                    "safe_area_active": False,
                    "created_at":       now(offset_days=10 - j),
                    "updated_at":       now(offset_days=8  - j),
                })
                request_id = str(stub.inserted_id)

            q = rating
            p = max(1, rating - (1 if j % 3 == 0 else 0))
            c = max(1, rating - (1 if j % 2 == 0 else 0))
            overall = round((q + p + c) / 3, 1)

            reviews_col.insert_one({
                "_id":                  uid(),
                "request_id":           request_id,
                "reviewee_email":       worker_email,
                "reviewer_email":       reviewer_email,
                "reviewer_username":    reviewer_username,
                "quality_rating":       q,
                "punctuality_rating":   p,
                "communication_rating": c,
                "overall_rating":       overall,
                "rating":               rating,
                "worker_email":         worker_email,
                "comment":              comment,
                "created_at":           now(offset_days=5 - j),
            })
        print(f"  + 2 reviews for: {worker_email}")

    # ── Summary ───────────────────────────────────────────────────────────────
    # Calculate ahmed_dev actual wallet balance
    ahmed_req_ids = {
        str(r["_id"])
        for r in requests_col.find({"worker_email": "ahmed_dev@gmail.com", "status": "completed"})
    }
    ahmed_payments = list(payments_col.find({"worker_email": "ahmed_dev@gmail.com"}))
    ahmed_balance  = sum(p["amount"] for p in ahmed_payments if p["request_id"] in ahmed_req_ids)

    print("\n" + "=" * 55)
    print("SEED COMPLETE")
    print("=" * 55)
    print(f"  Users:     {users_col.count_documents({})}")
    print(f"  Services:  {services_col.count_documents({})}")
    print(f"  Posts:     {posts_col.count_documents({})}")
    print(f"  Reviews:   {reviews_col.count_documents({})}")
    print(f"  Requests:  {requests_col.count_documents({})}")
    print(f"  Payments:  {payments_col.count_documents({})}")
    print(f"  ahmed_dev wallet: ${ahmed_balance}")
    print()
    print("Sample logins (password for all: Test@1234)")
    print("  Worker:      ahmed_dev@gmail.com")
    print("  Normal User: client_ali@gmail.com")
    print()
    print("Service images: picsum.photos -- internet required.")
    print("=" * 55)


# ─────────────────────────────────────────────────────────────────────────────
#  Entry point
# ─────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    fresh = "--fresh" in sys.argv
    client = MongoClient(MONGO_URI)
    db = client[DB_NAME]
    print(f"Connected to MongoDB >> {DB_NAME}")
    wipe(db, fresh=fresh)
    seed(db)
    client.close()
