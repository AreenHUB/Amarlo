# Amarlo — Freelance Marketplace

**v2.2.0** · Flutter + FastAPI + MongoDB

Amarlo connects **Workers** who offer services with **Normal Users** who need them. It covers the full freelance lifecycle: discovery, negotiation, safe delivery, payment escrow, and reviews.

---

## Features

### For Normal Users
- Browse and search services by category, city, price range
- Request services directly from the home screen
- Post job requests and receive offers from workers
- Real-time chat with workers
- Safe Area escrow — review watermarked work before paying
- Confirm delivery and leave a review
- Track all active and completed requests

### For Workers
- Publish services with images, pricing, and categories
- Receive and manage service requests
- Browse public job posts and submit offers
- Upload deliverables via Safe Area (watermark protection)
- Propose price changes before payment
- Wallet balance tracking
- Safe Area Session contracts — create formal agreements directly with clients

### Platform
- Real-time notifications via WebSocket (delivered even when offline via persistent queue)
- Haptic + sound feedback on notifications
- In-app notification inbox with toast alerts
- Screenshot protection in Safe Area (Android FLAG_SECURE)
- Rate limiting on auth endpoints
- JWT authentication with access + refresh token rotation

---

## Tech Stack

| Layer | Technology |
|---|---|
| Mobile | Flutter (Dart) |
| Backend | FastAPI (Python) |
| Database | MongoDB |
| Auth | JWT (access 30min + refresh 30 days) |
| Real-time | WebSocket |
| Images | Pillow (watermark), multipart upload |

---

## Project Structure

```
Amarlo/                        <- Flutter App
├── lib/
│   ├── core/
│   │   ├── constants.dart     <- All URLs + fixImageUrl()
│   │   ├── theme.dart         <- Design system
│   │   └── dialogs.dart       <- Shared dialog helpers
│   ├── models/app_models.dart <- Data models
│   ├── providers/             <- AuthProvider, RequestProvider
│   ├── services/
│   │   ├── api_service.dart         <- All API calls
│   │   ├── http_client.dart         <- HTTP + auto token refresh
│   │   ├── websocket_service.dart   <- Chat + Notification WebSockets
│   │   └── notification_service.dart <- In-app toasts + haptic feedback
│   └── screens/               <- All UI screens

ServerSide/                    <- FastAPI Backend
├── main.py
├── app/
│   ├── api/v1/endpoints/
│   │   ├── auth.py            <- Register, login, refresh, logout
│   │   ├── users.py           <- Profile, reviews, conduct reports
│   │   ├── services.py        <- Service CRUD + request
│   │   ├── posts.py           <- Posts + offers
│   │   ├── requests.py        <- Request lifecycle + deadline negotiation
│   │   ├── chat.py            <- WebSocket chat + notifications
│   │   ├── safe_area.py       <- Escrow + watermark + confirm
│   │   ├── safe_area_sessions.py <- Contract-based session flow
│   │   └── reports.py         <- User reports
│   ├── core/
│   │   ├── config.py          <- Settings from .env
│   │   └── security.py        <- JWT + bcrypt
│   ├── db/mongodb.py          <- Collections + indexes
│   ├── schemas/               <- Pydantic models
│   └── utils/
│       ├── images.py          <- Upload + save images
│       └── rate_limit.py      <- In-memory sliding window rate limiter
└── uploads/                   <- Runtime image storage (gitignored)
```

---

## Request Lifecycle

```
1. User requests a service  ->  status: pending
2. Worker accepts + sets deadline  ->  status: accepted
3. Worker uploads work to Safe Area (watermarked preview for images)
4. Worker marks ready  ->  status: ready_for_delivery
5. User reviews watermarked preview  ->  sends payment to escrow
6. Both parties confirm  ->  status: completed
7. User downloads original file + leaves review
8. Worker receives payment in wallet
```

## Post / Offer Lifecycle

```
1. User creates a post (title, description, price range)
2. Workers browse posts and submit offers (content + price)
3. User accepts an offer  ->  service request created automatically
4. Continues as Request Lifecycle above
```

---

## Running Locally

### Prerequisites
- Flutter SDK >= 3.0
- Python 3.10+
- MongoDB running locally

### Backend

```bash
cd ServerSide
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt

# Create .env with at minimum:
# JWT_SECRET_KEY=your-secret-key-at-least-32-chars
# MONGO_URI=mongodb://localhost:27017
# MONGO_DB_NAME=amarlo_db

uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Swagger docs available at `http://localhost:8000/docs` (development only, disabled in production).

### Flutter

```bash
cd amarlo_app
flutter pub get

# iOS Simulator
flutter run --dart-define=API_HOST=127.0.0.1

# Android Emulator
flutter run --dart-define=API_HOST=10.0.2.2

# Physical device (same WiFi)
flutter run --dart-define=API_HOST=192.168.1.X
```

---

## API Overview

| Endpoint | Description |
|---|---|
| `POST /api/v1/auth/register` | Create account |
| `POST /api/v1/auth/login` | Login -> access + refresh tokens |
| `POST /api/v1/auth/refresh` | Rotate refresh token |
| `GET /api/v1/services` | Browse services (public) |
| `POST /api/v1/services/{id}/request` | Request a service |
| `GET /api/v1/posts/public` | Browse job posts (workers) |
| `POST /api/v1/posts/{id}/offers` | Submit an offer on a post |
| `GET /api/v1/requests/worker/{email}` | Worker's active requests |
| `GET /api/v1/requests/user/{id}` | User's active requests |
| `WS /api/v1/ws/chat/{email}` | Real-time chat |
| `WS /api/v1/ws/notifications/{email}` | Real-time notifications |
| `POST /api/v1/safe-area/{id}/upload` | Worker uploads work file |
| `POST /api/v1/safe-area/{id}/send-payment` | User pays into escrow |
| `POST /api/v1/safe-area/{id}/confirm` | Confirm delivery |
| `GET /api/v1/safe-area/balance/{email}` | Worker wallet balance |
| `POST /api/v1/safe-area-sessions` | Create a contract session |
| `PUT /api/v1/safe-area-sessions/{id}/accept` | Accept a session invite |

---

## Security

- JWT with short-lived access tokens (30 min) and rotating refresh tokens (30 days)
- Rate limiting: 10 login attempts / 5 min · 5 registrations / hour · 20 refresh calls / 5 min
- File upload validation: 50 MB size limit, extension whitelist, magic-byte MIME detection
- Regex injection prevention on all search fields
- CORS restricted to defined methods and headers
- Swagger UI disabled in production
- Screenshot prevention in Safe Area (Android FLAG_SECURE)
- Payment amount enforced server-side — client cannot manipulate price

---

## Changelog

### v2.2.0
- Fixed Safe Area Sessions — `accept_session` now creates a linked `service_request` so the upload/payment/confirm flow works end-to-end
- Notification persistence — missed notifications stored in DB, delivered on reconnect
- All `push_notification` calls properly awaited (was `asyncio.create_task` — silent failures)
- Rate limiting on auth endpoints (login, register, refresh) with `Retry-After` header
- Payment $0 bypass fixed — server rejects mismatched or unset prices
- Deadline timezone bug fixed (naive vs aware datetime comparison in requests.py)
- In-person requests blocked from Safe Area deadline negotiation endpoints
- 4 missing MongoDB indexes added: `payments.request_id`, `safe_area.request_id`, `messages.(recipient+read)`, `pending_notifications.recipient`
- Conversation endpoint paginated (was loading all conversations into memory)
- Message fetch capped at 200 server-side
- File size checked client-side before upload (50 MB guard, prevents OOM crash)
- `ServiceRequest` model includes `workerUsername` field
- Review sheet shows worker display name instead of raw email
- `WorkReviewCreate.comment` capped at 2000 characters server-side
- `userType` validated as `Worker` or `Normal` on register
- `delivery_type`, `agreed_price`, `safe_area_enabled`, `worker_username` now present on all request document types consistently
- Haptic + sound feedback on in-app notifications (heavy double-pulse for important events, light tap for messages)
- Session complete endpoint added (`PUT /safe-area-sessions/{id}/complete`), auto-triggered on `confirm_deal`
- LinkedIn added to worker profile (view + edit)
- Social links (Facebook, Instagram, Telegram, LinkedIn) are now tappable — open native app or browser
- Home screen redesigned: live stats, top workers row, category pills from real backend data, 2-column service grid
- Search debounced (180ms), categories from server, filter sheet

### v2.1.0
- Work reviews with 3 axes: quality, punctuality, communication
- Safe Area page: watermark preview, escrow payment, dual-confirm flow
- In-app notification inbox with animated toast alerts
- Post lifecycle: TTL expiry, open/closed status, offer management
- Conduct report system

### v2.0.0
- Full backend rewrite to FastAPI clean architecture
- Real-time chat via WebSocket with reconnection logic
- Safe Area escrow system foundation
- Refresh token rotation with JTI validation
- MongoDB connection pooling and indexes
