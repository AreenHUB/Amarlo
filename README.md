# 🚀 Amarlo v2.0.0 — Full Setup Guide

Amarlo is a **Freelance Marketplace** built with Flutter + FastAPI + MongoDB.  
It connects **Workers** (who offer services) with **Normal Users** (who request them).

---

## 📋 Prerequisites

| Tool    | Version | Link                        |
|---------|---------|-----------------------------|
| Python  | 3.10+   | https://python.org          |
| Flutter | 3.10+   | https://flutter.dev         |
| MongoDB | 6.0+    | https://mongodb.com         |
| Git     | Any     | https://git-scm.com         |

---

## 🗄️ Step 1 — Start MongoDB

```bash
# macOS (Homebrew)
brew services start mongodb-community

# Ubuntu / Debian
sudo systemctl start mongod
sudo systemctl enable mongod

# Windows
net start MongoDB

# Verify it's running
mongosh --eval "db.runCommand({ping:1})"
```

---

## ⚙️ Step 2 — Configure Backend

```bash
cd ServerSide
cp .env.example .env
```

Edit `.env` with your values:

```env
MONGO_URI=mongodb://localhost:27017
MONGO_DB_NAME=amarlo_db
SECRET_KEY=change-this-to-a-long-random-secret
ENVIRONMENT=development
```

---

## ▶️ Step 3 — Run Backend (FastAPI)

```bash
cd ServerSide

# Create virtual environment
python -m venv venv

# Activate — macOS/Linux:
source venv/bin/activate
# Activate — Windows:
venv\Scripts\activate

pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Server starts at → `http://0.0.0.0:8000`  
API Docs → `http://localhost:8000/docs`

---

## 📱 Step 4 — Run Flutter App

```bash
cd Amarlo
flutter pub get
```

### Android Emulator
```bash
flutter run --dart-define=API_HOST=10.0.2.2 --dart-define=API_PORT=8000
```

### iOS Simulator
```bash
flutter run --dart-define=API_HOST=127.0.0.1 --dart-define=API_PORT=8000
```

### Physical Device (same Wi-Fi network)
```bash
# Replace X with your machine's local IP
flutter run --dart-define=API_HOST=192.168.1.X --dart-define=API_PORT=8000
```

> Find your local IP:  
> macOS/Linux: `ifconfig | grep "inet "`  
> Windows: `ipconfig`

---

## 📁 Project Structure

```
Amarlo_v2.0.0/
├── ServerSide/                   ← FastAPI Backend
│   ├── main.py                   ← App entry point
│   ├── requirements.txt
│   ├── .env                      ← Your config (not in git)
│   ├── .env.example              ← Config template
│   └── app/
│       ├── api/
│       │   ├── dependencies.py   ← Auth guards
│       │   └── v1/
│       │       └── endpoints/    ← All route handlers
│       │           ├── auth.py
│       │           ├── services.py
│       │           ├── requests.py
│       │           ├── chat.py   ← WebSocket
│       │           ├── safe_area.py
│       │           ├── posts.py
│       │           ├── users.py
│       │           └── reports.py
│       ├── core/
│       │   ├── config.py         ← Settings from .env
│       │   └── security.py       ← JWT (access + refresh)
│       ├── db/
│       │   └── mongodb.py        ← Connection + indexes
│       ├── schemas/              ← Pydantic models
│       └── utils/
│           └── images.py         ← Upload handling
│
├── Amarlo/                       ← Flutter App
│   ├── lib/
│   │   ├── core/                 ← constants, theme, dialogs
│   │   ├── models/               ← app_models.dart
│   │   ├── providers/            ← auth, request state
│   │   ├── services/             ← API, WebSocket, notifications
│   │   ├── screens/              ← all app screens
│   │   └── widgets/              ← reusable components
│   └── pubspec.yaml
│
├── README.md
└── MIGRATION_GUIDE.md
```

---

## ✨ What's New in v2.0.0

### Backend
- ✅ Professional architecture: `app/api/v1/endpoints/`
- ✅ JWT Refresh Tokens — 30 min access + 30 day refresh with auto-rotation
- ✅ MongoDB indexes with fail-safe per-index initialization
- ✅ Fixed service request 404 bug (correct endpoint routing)
- ✅ Online/offline presence tracking via WebSocket registry
- ✅ Proper WebSocket ping/pong — no more silent dropped connections
- ✅ Backward-compatible: reads both old and new DB document schemas

### Flutter
- ✅ Auto token refresh on 401 — no forced logout
- ✅ Chat: fixed permanent "Connecting..." issue
- ✅ Chat: online/offline indicator per conversation
- ✅ Chat: optimistic message sending (appears instantly)
- ✅ Notifications: message toast opens chat directly
- ✅ Conversations list loads immediately on first open
- ✅ Register page: no more screen freeze
- ✅ Safe Area: visible as soon as worker accepts request
- ✅ Notification bell repositioned correctly

---

## 🔄 How the App Works

```
Normal User                          Worker
───────────                          ──────
Browse Services ──── Request ────→ Worker receives notification
                                     Worker accepts + sets deadline
                                     Worker uploads work to Safe Area
User sees preview (watermarked) ←─── 
User sends payment (escrow) ─────→  
Both confirm deal ───────────────→  File unlocked for download
User downloads + reviews
```

---

## ❓ Troubleshooting

| Problem | Solution |
|---------|----------|
| `Connection refused` | Ensure backend is running on port 8000 |
| `MongoDB not found` | Start MongoDB service |
| Images not loading | Check `API_HOST` matches your network |
| Flutter build errors | Run `flutter clean && flutter pub get` |
| 401 Unauthorized | Token expired — app refreshes automatically |
| Index build warning on startup | Normal if DB has old data — server continues |

---

## 📞 API Documentation

- Interactive: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

---

## 📦 Version History

| Version | Description |
|---------|-------------|
| v2.0.0  | Full backend rewrite, refresh tokens, chat overhaul |
| v1.0.1  | Image URL fix patch |
| v1.0.0  | Initial release |

---

## 📜 License

MIT License

---

**Built with ❤️ using FastAPI + Flutter + MongoDB**
