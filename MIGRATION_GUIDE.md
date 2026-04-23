# Migration Guide: v1.x → v2.0.0

This guide explains what changed between v1.x and v2.0.0 and what you need to do when upgrading.

---

## TL;DR — Do I need to do anything?

| Scenario | Action needed |
|----------|--------------|
| Fresh install | Nothing — follow README |
| Existing DB from v1.x | Nothing — v2 reads old data |
| Custom Flutter client | Update API base URL (see below) |
| Custom Backend fork | See backend changes section |

---

## 1. API Base URL Changed

All endpoints now require the `/api/v1/` prefix.

```
# v1.x
POST http://host:8000/auth/login
GET  http://host:8000/services
WS   ws://host:8000/ws/chat/{email}

# v2.0.0
POST http://host:8000/api/v1/auth/login
GET  http://host:8000/api/v1/services
WS   ws://host:8000/api/v1/ws/chat/{email}
```

---

## 2. Authentication Response Changed

Login and register now return an additional `refresh_token`.

```json
// v1.x response
{
  "access_token": "eyJ...",
  "token_type": "bearer",
  "user_id": "...",
  "user_type": "Worker",
  "email": "..."
}

// v2.0.0 response
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "expires_in": 1800,
  "token_type": "bearer",
  "user_id": "...",
  "user_type": "Worker",
  "email": "...",
  "username": "..."
}
```

### New endpoint: Refresh Token

```
POST /api/v1/auth/refresh
Content-Type: application/x-www-form-urlencoded

refresh_token=eyJ...
```

Returns a new `access_token` + `refresh_token` pair.  
The old refresh token is invalidated (rotation).

---

## 3. Image URL Path Changed

| Version | Upload path | URL |
|---------|-------------|-----|
| v1.x    | `/static/`  | `http://host:8000/static/services/file.jpg` |
| v2.0.0  | `/uploads/` | `http://host:8000/uploads/services/file.jpg` |

**Old images still work** — the Flutter app's `fixImageUrl()` function automatically converts `/static/` paths to `/uploads/` at runtime.

---

## 4. Backend File Structure Changed

```
# v1.x structure
ServerSide/
├── main.py
└── routers/
    ├── auth.py
    ├── services.py
    └── ...

# v2.0.0 structure
ServerSide/
├── main.py
└── app/
    └── api/
        └── v1/
            └── endpoints/
                ├── auth.py
                ├── services.py
                └── ...
```

---

## 5. Service Request Endpoint Fixed

In v1.x, requesting a service incorrectly routed to the posts/offers endpoint causing a 404 error.

```
# v1.x (broken)
POST /posts/{service_id}/offers

# v2.0.0 (correct)
POST /api/v1/services/{service_id}/request
```

---

## 6. WebSocket Changes

The chat WebSocket now:
- Sends `{"type": "connected"}` immediately on connect
- Responds to `{"type": "ping"}` with `{"type": "pong"}`
- Does **not** close after inactivity timeout (v1.x closed after 120s)

```
# Connect confirmation (new in v2.0.0)
← {"type": "connected", "email": "user@example.com"}

# Ping/pong
→ {"type": "ping"}
← {"type": "pong"}
```

---

## 7. Database — No Migration Required

The v2.0.0 backend is backward compatible with v1.x data.

- Old documents with `worker_name`/`worker_id` fields are handled automatically
- Index creation is fail-safe — duplicate data in old DB won't stop the server
- New documents use `worker_email`/`worker_username` fields

---

## 8. Environment Variables

v2.0.0 requires a `.env` file (copy from `.env.example`).

```bash
cd ServerSide
cp .env.example .env
# Edit .env with your values
```

New variables in v2.0.0:

```env
# New in v2.0.0
REFRESH_TOKEN_EXPIRE_DAYS=30
ACCESS_TOKEN_EXPIRE_MINUTES=30
ENVIRONMENT=development
APP_NAME=Amarlo API
APP_VERSION=2.0.0
```

---

## 9. Checklist for Upgrading

```
[ ] Copy new ServerSide/ folder
[ ] Run: cp .env.example .env
[ ] Edit .env with your MONGO_URI and SECRET_KEY
[ ] Run: pip install -r requirements.txt
[ ] Copy new Amarlo/lib/ folder
[ ] Run: flutter pub get
[ ] Start MongoDB
[ ] Start backend: uvicorn main:app --host 0.0.0.0 --port 8000
[ ] Run Flutter with correct API_HOST
```

---

## Questions?

Check the API docs at `http://localhost:8000/docs` after starting the server.
