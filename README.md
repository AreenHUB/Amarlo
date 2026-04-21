# 🚀 Amarlo v1.0.0 --- Full Setup Guide

------------------------------------------------------------------------

## 📋 Prerequisites

  Tool      Version   Link
  --------- --------- ---------------------
  Python    3.10+     https://python.org
  Flutter   3.10+     https://flutter.dev
  MongoDB   6.0+      https://mongodb.com
  Git       Any       https://git-scm.com

------------------------------------------------------------------------

## 🗄️ Step 1 --- Start MongoDB

``` bash
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

------------------------------------------------------------------------

## ⚙️ Step 2 --- Run Backend (FastAPI)

``` bash
cd ServerSide
python -m venv venv

# Activate:
# macOS/Linux:
source venv/bin/activate
# Windows:
venv\Scripts\activate

pip install -r requirements.txt

uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

------------------------------------------------------------------------

## 📱 Step 3 --- Run Flutter

### Android Emulator

``` bash
cd Amarlo
flutter pub get
flutter run --dart-define=API_HOST=10.0.2.2 --dart-define=API_PORT=8000
```

### iOS Simulator

``` bash
flutter run --dart-define=API_HOST=127.0.0.1 --dart-define=API_PORT=8000
```

### Physical Device

``` bash
flutter run --dart-define=API_HOST=192.168.1.X --dart-define=API_PORT=8000
```

------------------------------------------------------------------------

## 📁 Project Structure

    Amarlo_v1.0.0/
    ├── ServerSide/
    ├── Amarlo/
    ├── README.md
    └── MIGRATION_GUIDE.md

------------------------------------------------------------------------

## ❓ Troubleshooting

-   Ensure backend is running on port 8000
-   Ensure MongoDB is started
-   Run `flutter clean` if issues occur

------------------------------------------------------------------------

## 📞 API Docs

-   http://localhost:8000/docs
-   http://localhost:8000/redoc

------------------------------------------------------------------------

## 📦 Version

v1.0.0

------------------------------------------------------------------------

## 📜 License

MIT License

------------------------------------------------------------------------

**Built with FastAPI + Flutter**

# Amarlo
Flutter + FastAPI full-stack app
