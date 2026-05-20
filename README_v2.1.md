# Amarlo v2.1.0 — Freelance Marketplace

**Flutter + FastAPI + MongoDB**

Amarlo connects **Workers** (service providers) with **Normal Users** (clients) in a full-featured freelance marketplace with real-time chat, escrow payments, watermarked previews, and a contract-based Safe Area system.

---

## Table of Contents

1. [What is Amarlo?](#what-is-amarlo)
2. [Features](#features)
3. [Tech Stack](#tech-stack)
4. [Prerequisites](#prerequisites)
5. [Setup & Running](#setup--running)
6. [Seeding Test Data](#seeding-test-data)
7. [Project Structure](#project-structure)
8. [How the App Works](#how-the-app-works)
9. [API Reference](#api-reference)
10. [Troubleshooting](#troubleshooting)
11. [Version History](#version-history)

---

## What is Amarlo?

Amarlo is a two-sided marketplace where:

- **Workers** publish services with prices, categories, and images. They receive requests from clients, communicate via chat, and deliver work through a secure escrow system.
- **Normal Users** browse services, request them directly, or post their own job requests and receive offers from workers.

Work can be delivered **online** (through the Safe Area with escrow + watermark protection) or **in-person** (coordinated through the app's chat).

---

## Features

### For Users (Clients)

| Feature | Description |
|---------|-------------|
| Browse Services | Filter by category, city, price range, and search by keyword |
| Request a Service | One-tap request directly from any service card |
| Post a Job | Publish a custom job post and receive offers from workers |
| Safe Area | Escrow-protected delivery — pay only after reviewing watermarked preview |
| Contract System | Sign a digital contract with deadline and price before Safe Area opens |
| Real-time Chat | Direct messaging with any worker |
| Notifications | Instant toast alerts for requests, offers, messages, and deals |
| Reviews | Rate workers after completed delivery |
| Reports | Report inappropriate users |

### For Workers

| Feature | Description |
|---------|-------------|
| Manage Services | Create, edit, and delete services with images and categories |
| Accept Requests | Accept or reject incoming requests; set delivery deadline |
| Offer on Posts | Browse client job posts and submit private price offers |
| Edit Offers | Update content and price while client hasn't accepted yet |
| Safe Area Upload | Upload work; it's shown with watermark until payment is confirmed |
| Deadline Negotiation | Propose a delivery deadline; client approves before Safe Area opens |
| Wallet | Accumulated earnings from completed deals |
| Contract Sessions | Create a formal Safe Area contract directly without a service listing |

### Platform Features

- **Real-time WebSocket** — Dual channels: chat messages + system notifications
- **JWT Auth** — 30-min access token + 30-day refresh with auto-rotation
- **Auto token refresh** — No forced logout when token expires
- **Screenshot prevention** — Android FLAG_SECURE active during Safe Area preview
- **Notification batching** — First offer: instant alert; subsequent offers: grouped every 5 minutes
- **Post TTL** — Job posts auto-delete after 7 days to keep listings fresh
- **Auth-required prompts** — Guests see a login/register prompt instead of silent failures

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Mobile | Flutter 3.41+ (iOS & Android) |
| Backend | FastAPI (Python 3.10+) |
| Database | MongoDB 6.0+ |
| Auth | JWT — python-jose, passlib/bcrypt |
| Real-time | WebSocket (web_socket_channel) |
| Images | Pillow (watermarking), CachedNetworkImage |
| State | Provider (ChangeNotifier) |
| Storage | SharedPreferences (tokens) |

---

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Python | 3.10+ | For FastAPI backend |
| Flutter | 3.10+ | For mobile app |
| MongoDB | 6.0+ | Local or Atlas |
| Git | Any | |
| Android Studio | Latest | For emulator (API 35 recommended) |

---

## Setup & Running

### 1 — Start MongoDB

```bash
# macOS (Homebrew)
brew services start mongodb-community

# Ubuntu / Debian
sudo systemctl start mongod

# Windows
net start MongoDB

# Verify
mongosh --eval "db.runCommand({ping:1})"
```

### 2 — Configure Backend

```bash
cd ServerSide
cp .env.example .env
```

Edit `.env`:

```env
MONGO_URI=mongodb://localhost:27017
MONGO_DB_NAME=amarlo_db
JWT_SECRET_KEY=change-this-to-a-long-random-secret-at-least-32-chars
ENVIRONMENT=development
```

Generate a secure key:
```bash
python -c "import secrets; print(secrets.token_urlsafe(64))"
```

### 3 — Run Backend

```bash
cd ServerSide

# Create virtual environment
python -m venv venv

# Activate — macOS/Linux
source venv/bin/activate

# Activate — Windows
venv\Scripts\activate

pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Backend starts at `http://0.0.0.0:8000`  
Swagger UI at `http://localhost:8000/docs`

### 4 — Run Flutter App

```bash
cd amarlo_app
flutter pub get
```

**Android Emulator (API 35 recommended):**
```bash
flutter run --dart-define=API_HOST=10.0.2.2 --dart-define=API_PORT=8000
```

**iOS Simulator:**
```bash
flutter run --dart-define=API_HOST=127.0.0.1 --dart-define=API_PORT=8000
```

**Physical Device (same Wi-Fi):**
```bash
# Find your IP: ipconfig (Windows) or ifconfig (macOS/Linux)
flutter run --dart-define=API_HOST=192.168.1.X --dart-define=API_PORT=8000
```

> **Tip:** Use `r` (hot reload) for UI changes. Use `R` (hot restart) for structural changes. Avoid hot restart on Android API 36 — it may drop the connection.

---

## Seeding Test Data

A seed script populates the database with realistic test accounts and data:

```bash
# From project root — run with the venv Python
cd ServerSide
PYTHONIOENCODING=utf-8 venv/Scripts/python.exe ../seed_data.py  # Windows
# or
python ../seed_data.py  # macOS/Linux
```

**What it creates:**

| Type | Count |
|------|-------|
| Worker accounts | 10 |
| Normal User accounts | 8 |
| Services | 30 (3 per worker, all categories) |
| Posts | 15 (with empty offers, ready for workers) |
| Reviews | 20 (2 per worker) |

**Test credentials:**
```
Worker:      ahmed_dev@gmail.com  /  Test@1234
Normal User: client_ali@gmail.com /  Test@1234
```

All seeded accounts share the password `Test@1234`.

> Service images use `picsum.photos` — internet connection required in the emulator.

---

## Project Structure

```
Amarlo_v1.0.0/
│
├── ServerSide/                          ← FastAPI Backend
│   ├── main.py                          ← App entry + middleware
│   ├── requirements.txt
│   ├── .env                             ← Your config (not in git)
│   ├── .env.example
│   ├── seed_data.py                     ← Test data seeder
│   └── app/
│       ├── api/
│       │   ├── dependencies.py          ← Auth guards (header + query param)
│       │   └── v1/
│       │       ├── api.py               ← Router aggregator
│       │       └── endpoints/
│       │           ├── auth.py          ← Register, login, refresh, logout
│       │           ├── services.py      ← Service CRUD + requests
│       │           ├── requests.py      ← Request lifecycle + deadline negotiation
│       │           ├── posts.py         ← Posts + offers (with TTL)
│       │           ├── chat.py          ← WebSocket chat + notifications
│       │           ├── safe_area.py     ← Escrow + watermark + file delivery
│       │           ├── safe_area_sessions.py  ← Contract sessions
│       │           ├── users.py         ← Profile + reviews
│       │           └── reports.py       ← User reports
│       ├── core/
│       │   ├── config.py               ← Pydantic settings
│       │   └── security.py             ← JWT create/decode, bcrypt
│       ├── db/
│       │   └── mongodb.py              ← Collections + indexes + TTL
│       ├── schemas/                    ← Pydantic response models
│       └── utils/
│           └── images.py              ← Image upload + watermark
│
├── amarlo_app/                         ← Flutter App
│   ├── lib/
│   │   ├── core/
│   │   │   ├── constants.dart          ← All API URLs
│   │   │   ├── theme.dart              ← Design system (Brown + Amber)
│   │   │   └── dialogs.dart            ← showAuthRequired, showConfirm, etc.
│   │   ├── models/
│   │   │   └── app_models.dart         ← All data models
│   │   ├── providers/
│   │   │   ├── auth_provider.dart      ← Login/logout/session
│   │   │   └── request_provider.dart   ← Request state
│   │   ├── services/
│   │   │   ├── api_service.dart        ← All API calls (130+ methods)
│   │   │   ├── http_client.dart        ← Auto token refresh on 401
│   │   │   ├── websocket_service.dart  ← Chat + notification WebSocket
│   │   │   └── notification_service.dart  ← Toast + batching + routing
│   │   ├── screens/
│   │   │   ├── home.dart               ← Service browsing + chat icon
│   │   │   ├── chat_screen.dart        ← Real-time chat
│   │   │   ├── safe_area_page.dart     ← Escrow + upload + confirm
│   │   │   ├── safe_area_session_screen.dart  ← Contract view
│   │   │   ├── worker_profile_view.dart       ← Public worker profile
│   │   │   ├── userScreen/
│   │   │   │   ├── user_dashboard.dart        ← Posts + offers (with toggle)
│   │   │   │   ├── offers_screen.dart         ← Offers per post
│   │   │   │   └── UserRequestsPage.dart      ← Requests + deadline approval
│   │   │   └── wrokerScreen/
│   │   │       ├── user_requests.dart         ← Public posts + send/edit offer
│   │   │       └── worker_request/
│   │   │           └── WorkerRequestsPage.dart ← Requests + deadline setting
│   │   └── widgets/
│   │       ├── navigation_bar.dart     ← Bottom nav + notification routing
│   │       ├── states.dart             ← NotificationIconButton + EmptyState
│   │       ├── skeletons.dart          ← Shimmer loading
│   │       └── user_avatar.dart        ← AppNetworkImage + UserAvatar
│   └── android/app/src/main/kotlin/
│       └── MainActivity.kt             ← FLAG_SECURE for screenshot prevention
│
├── README.md                           ← Original setup guide (v2.0.0)
├── README_v2.1.md                      ← This file
├── PROJECT_ANALYSIS.md                 ← Full code analysis + improvement notes
├── CLAUDE.md                           ← AI assistant context file
└── MIGRATION_GUIDE.md                  ← DB migration notes
```

---

## How the App Works

### Service Request Flow

```
User                                    Worker
────                                    ──────
Browse home screen
  → Tap "Request" on a service
  → Request created (pending)
                                        Receives notification
                                        → Accepts + sets deadline
Safe Area opens automatically
  → Worker uploads work (watermarked)
  → User sees preview
  → User sends payment (escrow)
  → User confirms delivery
                                        Confirms delivery
Work unlocked for download
User reviews worker
                                        Payment released to wallet
```

### Post / Offer Flow

```
User                                    Worker
────                                    ──────
Create a Post
  (title, desc, price range, category)
  → Enable Safe Area? Yes/No

                                        Sees post in "Client Requests"
                                        → Sends private offer (price + content)
                                        → Can edit offer while pending

Receives offer notification
  → Views offers per post
  → Accepts best offer

If Safe Area enabled:
  → Worker receives "Set Deadline" prompt
  → Worker proposes deadline
  → User approves deadline
  → Safe Area session opens at agreed price

If in-person:
  → Chat opens automatically
  → Coordinate offline
```

### Safe Area Contract (Direct Session)

For work not tied to any service listing, a Worker can create a formal contract directly:

```
Worker creates Safe Area Session:
  - Participant email (client)
  - Title, description, deliverables
  - Agreed price + deadline
  - Contract ref: SA-YYYY-XXXXX

Client receives invitation (valid 6 hours)
  → Reviews contract terms
  → Accepts → Session becomes "Active"
  → Rejects → Worker notified

Once active:
  → Worker uploads work
  → Client reviews + pays escrow
  → Both confirm → work unlocked
```

### Authentication Flow

```
Register → email + password + userType
Login    → access_token (30 min) + refresh_token (30 days)
           Both stored in SharedPreferences

Any 401  → Auto-refresh using refresh_token
           New tokens saved transparently
           User never sees a logout

Network error on startup → Session preserved
           (only 401 from server clears the session)
```

---

## API Reference

All endpoints are under `/api/v1/`.

| Prefix | Module | Description |
|--------|--------|-------------|
| `/auth` | auth.py | Register, login, refresh, logout, /me |
| `/services` | services.py | Service CRUD, categories, request service |
| `/requests` | requests.py | Request lifecycle, deadline negotiation |
| `/posts` | posts.py | Post CRUD, offer management, categories |
| `/conversations` | chat.py | Conversation list + message history |
| `/messages` | chat.py | Mark read, toggle block, presence |
| `/ws/chat/{email}` | chat.py | WebSocket — real-time messages |
| `/ws/notifications/{email}` | chat.py | WebSocket — system events |
| `/safe-area` | safe_area.py | Upload, preview, payment, confirm, download |
| `/safe-area-sessions` | safe_area_sessions.py | Contract sessions |
| `/users` | users.py | Profile CRUD, reviews |
| `/reports` | reports.py | Submit and view reports |
| `/categories` | services.py | Service categories list |
| `/post-categories` | posts.py | Post categories list (18 types) |

Interactive docs: `http://localhost:8000/docs`

---

## MongoDB Collections

| Collection | Purpose | TTL |
|-----------|---------|-----|
| `users` | User accounts | — |
| `services` | Worker services | — |
| `posts` | Job posts + embedded offers | 7 days (`expires_at`) |
| `service_requests` | Request lifecycle | — |
| `messages` | Chat messages | — |
| `reviews` | Worker ratings | — |
| `safe_area` | Uploaded work files | — |
| `safe_area_sessions` | Formal contracts | — |
| `payments` | Escrow payments | — |
| `reports` | User reports | — |
| `user_blocks` | Block list | — |
| `refresh_tokens` | JWT refresh tokens | 30 days (TTL index) |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `Connection refused` | Ensure backend is running: `uvicorn main:app --host 0.0.0.0 --port 8000` |
| `MongoDB not found` | Start MongoDB service |
| Images not loading | Check `API_HOST` matches your network setup |
| `flutter run` disconnects on hot restart | Use `r` (hot reload) instead of `R`; restart the process fully if needed |
| 401 Unauthorized on startup | Backend was unreachable during init — session is preserved, retry after server is up |
| Offers show 409 Conflict | Worker already sent an offer on this post — use "Edit Offer" instead |
| Post doesn't appear for Workers | Posts auto-delete after 7 days — create a new one |
| Safe Area preview shows 401 | Ensure backend is running and token is valid |
| Flutter build errors | `flutter clean && flutter pub get` |
| Android emulator storage full | Device Manager → Wipe Data on the emulator |

---

## Version History

| Version | Date | Highlights |
|---------|------|-----------|
| **v2.1.0** | 2026-05 | Post TTL (7 days), 18 post categories, safe_area_enabled toggle, deadline negotiation, Worker offer editing, Safe Area Contract sessions (SA-YYYY-XXXXX), notification batching, screenshot prevention, auth-required prompts, single notification WebSocket, stable session on network errors |
| v2.0.0 | 2026-04 | Full backend rewrite, JWT refresh tokens, chat overhaul, dual WebSocket, backward-compatible DB |
| v1.0.1 | — | Image URL cross-device fix |
| v1.0.0 | — | Initial release |

---

## What's New in v2.1.0

### Backend

- **Post TTL** — Posts auto-delete after 7 days via MongoDB TTL index; posts closed after offer acceptance are exempt
- **18 post categories** — Expanded from free-text to a structured list covering tech, design, home services, childcare, and more
- **`safe_area_enabled` on posts** — Users explicitly choose if their job can be delivered online before posting
- **Deadline negotiation** — Worker proposes delivery date; User must approve before Safe Area activates (`/propose-deadline`, `/confirm-deadline`)
- **Offer editing** — Workers can update offer content and price while it's still pending (`PUT /posts/{id}/offers/{oid}`)
- **Post status** — Posts move from `open` to `closed` when an offer is accepted; TTL removed automatically
- **Safe Area Sessions** — Formal digital contracts with unique reference numbers (`SA-YYYY-XXXXX`), 6-hour invitation window, and full party tracking
- **Flexible preview auth** — Safe Area preview and download accept token via both `Authorization` header and `?token=` query param

### Flutter

- **Single notification WebSocket** — Removed duplicate WebSocket in HomePage; all events route through NavigationBarPage
- **Offer notification batching** — First offer triggers instant notification; subsequent ones are grouped into a 5-minute summary
- **Stable session on network errors** — App no longer logs out if the server is temporarily unreachable on startup
- **Auth-required prompts** — Guests tapping Request or Chat see a bottom sheet with Login / Create Account options
- **Notification routing** — `new_offer` → Dashboard tab; `new_request` / status changes → Requests tab; tap-to-navigate works from any screen state
- **Instant request refresh** — RequestProvider reloads immediately on any incoming WebSocket event (no manual refresh needed)
- **Deadline approval UI** — Users see proposed deadline with Approve/Reject buttons directly in the Requests tab
- **Worker deadline UI** — "Set Deadline" button replaces "Accept" for Safe Area-enabled requests
- **Offer per post display** — Offers tab now shows each Post as a card with its own offers nested beneath it
- **Worker offer editing** — "Edit Offer" button appears on posts where the worker already sent a pending offer
- **SafeAreaSessionScreen** — Full contract view: parties, price, deliverables, deadline, accept/reject, countdown timer
- **Screenshot prevention** — Android `FLAG_SECURE` enabled while Safe Area page is open
- **`X days left` badge** — Worker's post list shows color-coded expiry countdown (green → orange → red)
- **Post category dropdown** — 18-item dropdown in post form replaces free-text category field
- **Post closed status** — Posts with accepted offers show "Closed" and no longer appear in Workers' public post feed

---

## License

MIT License

---

*Built with FastAPI + Flutter + MongoDB*
