# Amarlo v1.0.0 — دليل التغييرات

## ما الذي تغيّر؟

---

## 1. Backend (FastAPI)

### هيكل الملفات الجديد
```
ServerSide/
├── main.py                  ← نقطة الدخول (نظيفة)
├── requirements.txt
├── core/
│   ├── config.py            ← الإعدادات المركزية
│   ├── database.py          ← اتصال MongoDB
│   ├── security.py          ← JWT + auth dependencies
│   ├── images.py            ← رفع وحذف الصور
│   └── schemas.py           ← Pydantic models مشتركة
├── routers/
│   ├── auth.py              ← /auth/*
│   ├── users.py             ← /users/*
│   ├── services.py          ← /services/*
│   ├── posts.py             ← /posts/*
│   ├── requests.py          ← /requests/*
│   ├── chat.py              ← /ws/* + /messages/* + /conversations/*
│   ├── safe_area.py         ← /safe-area/*
│   └── reports.py           ← /reports/*
└── uploads/
    ├── profiles/
    ├── services/
    └── safe_area/
```

### تغييرات الـ API

#### الصور
| قبل | بعد |
|-----|-----|
| `imageBase64: "data:image..."` في JSON | `image_url: "http://server/uploads/..."` |
| POST مع base64 string في body | POST multipart/form-data مع file |
| حجم طلب ضخم (MBs في JSON) | طلب خفيف + ملف منفصل |

#### Auth endpoints
| قبل | بعد |
|-----|-----|
| `POST /login` | `POST /auth/login` |
| `POST /register` | `POST /auth/register` (multipart) |
| `GET /user-info` | `GET /auth/me` |

#### Services
| قبل | بعد |
|-----|-----|
| `POST /add-service` | `POST /services` (multipart) |
| `PUT /update-service/{id}` | `PUT /services/{id}` (multipart) |
| `DELETE /delete-service/{id}` | `DELETE /services/{id}` |
| بدون pagination | `?page=1&size=20` |

#### Requests
| قبل | بعد |
|-----|-----|
| `GET /user-requests/{user_id}` | `GET /requests/user/{user_id}` |
| `GET /worker-requests/{email}` | `GET /requests/worker/{email}` |
| `DELETE /requests/{id}` (reject/delete) | `DELETE /requests/{id}` (نفس الـ endpoint، يتحقق من الـ role تلقائياً) |

#### Safe Area — تغيير جوهري
| قبل | بعد |
|-----|-----|
| رفع base64 في DB | رفع ملف على disk + URL في DB |
| عرض الصورة كـ base64 | `GET /safe-area/{id}/preview` (مع watermark) |
| تأكيد من طرف واحد | `POST /safe-area/{id}/confirm` من الطرفين |
| تحميل فوري | تحميل بعد تأكيد الطرفين فقط |

---

## 2. Flutter

### هيكل الملفات الجديد
```
lib/
├── core/
│   └── constants.dart       ← جميع URLs في مكان واحد
├── models/
│   └── app_models.dart      ← جميع الموديلات
├── services/
│   ├── http_client.dart     ← HTTP client موحّد
│   ├── api_service.dart     ← جميع API calls
│   └── websocket_service.dart ← WebSocket للـ chat والإشعارات
├── providers/
│   ├── auth_provider.dart   ← إدارة حالة المستخدم
│   └── request_provider.dart ← إدارة الطلبات
└── ...
```

### تغييرات في Flutter

#### الصور
```dart
// ❌ قبل
Image.memory(base64Decode(service.imageBase64!))

// ✅ بعد
CachedNetworkImage(
  imageUrl: service.imageUrl ?? '',
  placeholder: (_, __) => const CircularProgressIndicator(),
  errorWidget: (_, __, ___) => const Icon(Icons.image),
)
```

#### API calls
```dart
// ❌ قبل (في كل screen بشكل مختلف)
final response = await http.get(
  Uri.parse('http://10.0.2.2:8000/services'),
  headers: {'Authorization': 'Bearer $accessToken'},
);

// ✅ بعد (موحّد)
final paged = await ApiService.getServices(category: 'Design');
```

#### Auth
```dart
// ❌ قبل
SharedPreferences.getInstance() في كل مكان

// ✅ بعد
context.read<AuthProvider>().user
context.read<AuthProvider>().isWorker
context.read<AuthProvider>().login(email, password)
```

---

## 3. خطوات التشغيل

### Backend
```bash
cd ServerSide
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Flutter (Android)
```bash
flutter run --dart-define=API_HOST=10.0.2.2
```

### Flutter (iOS Simulator)
```bash
flutter run --dart-define=API_HOST=127.0.0.1
```

### Flutter (جهاز حقيقي)
```bash
flutter run --dart-define=API_HOST=192.168.1.X  # IP جهازك
```

---

## 4. قاعدة البيانات

لا تحتاج إلى migration — MongoDB schema-less.
لكن السجلات القديمة ستحتوي على `imageBase64` وليس `image_url`.
للتحويل، شغّل هذا الـ script:

```python
# migration_script.py (شغّله مرة واحدة فقط)
import base64, uuid, os
from pymongo import MongoClient

client = MongoClient("mongodb://localhost:27017/")
db = client["flutter-app2"]

for col_name in ["users-register", "services"]:
    col = db[col_name]
    for doc in col.find({"imageBase64": {"$exists": True}}):
        # احفظ الصورة على disk
        folder = "profiles" if col_name == "users-register" else "services"
        filename = f"{uuid.uuid4().hex}.jpg"
        path = f"uploads/{folder}/{filename}"
        os.makedirs(f"uploads/{folder}", exist_ok=True)
        with open(path, "wb") as f:
            f.write(base64.b64decode(doc["imageBase64"]))
        # حدّث السجل
        col.update_one(
            {"_id": doc["_id"]},
            {
                "$set": {"image_url": f"http://10.0.2.2:8000/uploads/{folder}/{filename}"},
                "$unset": {"imageBase64": ""}
            }
        )
        print(f"Migrated {doc['_id']}")
```
