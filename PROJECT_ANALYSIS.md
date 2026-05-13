# تحليل مشروع Amarlo — فهم شامل

> تاريخ التحليل: 2026-05-13  
> الإصدار المحلَّل: v2.0.0

---

## ما هو Amarlo؟

Amarlo منصة سوق للعمل الحر (Freelance Marketplace) تربط بين:
- **Workers (عمال):** يقدمون خدمات رقمية بأسعار وتصنيفات محددة
- **Normal Users (مستخدمون عاديون):** يبحثون عن هذه الخدمات ويطلبونها

المنصة مبنية بثلاثة تقنيات رئيسية:
- **Flutter** — تطبيق موبايل (iOS + Android)
- **FastAPI (Python)** — خادم API
- **MongoDB** — قاعدة البيانات

---

## ما الذي يفعله المشروع؟

### الوظائف الأساسية

| الوظيفة | الوصف |
|---------|-------|
| **تصفح الخدمات** | المستخدم يبحث في خدمات العمال حسب التصنيف والمدينة والسعر |
| **طلب خدمة** | المستخدم يطلب خدمة مباشرة من Worker |
| **نشر Post** | إذا لم يجد المستخدم خدمة مناسبة، ينشر "طلب" ويستقبل عروضاً من العمال |
| **Safe Area** | منطقة تسليم آمنة بـ watermark للمعاينة وescrow للدفع |
| **المحادثة الفورية** | دردشة مباشرة بين المستخدم والعامل عبر WebSocket |
| **التقييمات** | المستخدم يُقيّم العامل بعد اكتمال الطلب |
| **الإبلاغ** | إمكانية الإبلاغ عن مستخدمين مسيئين |

### دورة حياة الطلب (Request Lifecycle)

```
1. User يطلب خدمة       → status: pending
2. Worker يقبل + deadline  → status: accepted
3. Worker يرفع الملف      → Safe Area مُفعَّلة (watermark للمعاينة)
4. User يرى المعاينة      → يرسل الدفع (escrow)
5. Worker يضغط Ready      → status: ready_for_delivery
6. كلاهما يؤكد            → status: completed
7. User يحمّل الأصل        → يُقيّم Worker
8. Worker يستلم المال في Wallet
```

---

## الأشياء الجيدة في المشروع ✅

### 1. بنية المشروع — منظمة وقابلة للتوسع
- الفصل الواضح بين الطبقات: `core / models / providers / services / screens / widgets`
- Backend منظم: `api / core / db / schemas / utils`
- CLAUDE.md يوثّق كل شيء بوضوح — مفيد جداً للفريق

### 2. نظام المصادقة — قوي ومحكم
- JWT مع access_token (30 دقيقة) + refresh_token (30 يوم)
- JTI الفريد لكل refresh token — يمنع إعادة الاستخدام
- Auto-refresh في Flutter (HttpClient يُعيد المحاولة بعد 401)
- المستخدم لا يُجبر على تسجيل الدخول كل نصف ساعة

### 3. Safe Area — فكرة ذكية ومنفذة جيداً
- Watermark يحمي حقوق العامل حتى اكتمال الدفع
- Escrow يحمي المستخدم حتى يتأكد من الجودة
- كلا الطرفين يحتاجان للتأكيد — لا أحد يستطيع الغش

### 4. نظام الصور — حُلَّت مشكلة صعبة
- `fixImageUrl()` تُصحح روابط الصور تلقائياً بغض النظر عن الـ host
- معالجة المسارات القديمة (`/static/` → `/uploads/`)
- `AppNetworkImage` + `CachedNetworkImage` = تحميل ذكي مع Cache

### 5. WebSocket مزدوج — تصميم صحيح
- قناة للمحادثة (`/ws/chat/`)
- قناة للإشعارات (`/ws/notifications/`)
- Connection registry يدعم تعدد الأجهزة
- Ping كل 30 ثانية للحفاظ على الاتصال

### 6. التوافق مع قاعدة البيانات القديمة
- `_normalize()` + `_serialize()` في Backend تتعامل مع الوثائق القديمة والجديدة
- لا كسر في البيانات القديمة عند الترقية

### 7. Pagination عام وقابل لإعادة الاستخدام
- `Paged<T>` في Flutter يعمل مع أي نوع بيانات
- Backend يطبق PaginationParams على كل endpoint يعيد قائمة

### 8. Design System متسق
- ألوان ثابتة (Brown + Amber)
- Skeletons للتحميل بدل CircularProgressIndicator المجرد
- EmptyState / ErrorState / LoadingButton — تجربة مستخدم احترافية

### 9. نمط مركزية الـ API
- كل الطلبات تمر عبر `ApiService` — لا `http.get()` مباشرة في الـ screens
- سهل التعديل والاختبار والصيانة

### 10. Font Awesome مُعالَج صح
- التوثيق يُنبه: `FaIcon(...)` وليس `Icon(...)` — تجنّب خطأ شائع

---

## الأشياء التي تحتاج إلى تحسين ⚠️

### 🔴 مشاكل حرجة (تؤثر على الأمان أو الاستقرار)

#### 1. غياب Rate Limiting على الـ API
**المشكلة:** لا يوجد حد لعدد الطلبات — الـ API مفتوح للـ brute force على `/auth/login`  
**الحل:** إضافة `slowapi` أو middleware بسيط يحد من الطلبات لكل IP

```python
# مثال: max 5 محاولات login كل دقيقة لكل IP
from slowapi import Limiter
from slowapi.util import get_remote_address
limiter = Limiter(key_func=get_remote_address)

@router.post("/login")
@limiter.limit("5/minute")
async def login(request: Request, ...):
    ...
```

#### 2. لا يوجد حماية CSRF للـ WebSocket
**المشكلة:** Token في query param (`?token=...`) يظهر في server logs  
**الحل:** إرسال التوكن في أول رسالة بعد الاتصال بدل query param

#### 3. الصور لا تُتحقق منها بعمق كافٍ
**المشكلة:** `imghdr` مهجور في Python 3.13+، والتحقق من magic bytes وحده غير كافٍ  
**الحل:** استخدام `python-magic` أو `Pillow.verify()` للتحقق من صحة الصورة فعلياً

---

### 🟠 مشاكل متوسطة (تؤثر على الجودة)

#### 4. RequestProvider يُحمّل البيانات مرتين
**المشكلة:** `getWorkerRequests` و `getUserRequests` يُشغَّلان عند كل navigation
**الحل:** إضافة cache بسيط مع timestamp — لا تُعد التحميل إذا مضى أقل من 30 ثانية

#### 5. خطأ إملائي في اسم المجلد
**المشكلة:** المجلد اسمه `wrokerScreen` بدل `workerScreen` (حرف مفقود)
**الحل:** إعادة تسمية المجلد وتحديث كل الـ imports (تحتاج دقة)

#### 6. غياب Offline Mode أو Error Recovery
**المشكلة:** إذا انقطع الإنترنت، التطبيق لا يحتفظ بأي بيانات مؤقتة  
**الحل:** حفظ آخر response في SharedPreferences أو استخدام `hive` للـ caching

#### 7. WebSocket لا يُعيد الاتصال بشكل تدريجي
**المشكلة:** عند انقطاع الاتصال، قد يحدث إغراق بمحاولات إعادة الاتصال (exponential backoff مفقود)  
**الحل:** إضافة تأخير متزايد: 1s → 2s → 4s → 8s → max 30s

#### 8. Wallet ليس له endpoint مخصص للسحب
**المشكلة:** العامل يرى رصيده في Wallet لكن لا يوجد آلية لسحب الأموال  
**الحل:** إضافة `/wallet/withdraw` endpoint مع validation

#### 9. لا يوجد admin panel أو dashboard
**المشكلة:** لا يوجد طريقة لإدارة المنصة (حذف محتوى مسيء، مراجعة البلاغات)  
**الحل:** إضافة admin role وendpoints مخصصة أو واجهة ويب بسيطة

---

### 🟡 تحسينات بسيطة (تحسين تجربة المستخدم)

#### 10. Search غير متطور
**المشكلة:** البحث في الخدمات بسيط جداً (exact match)  
**الحل:** استخدام MongoDB text index مع `$text: { $search: ... }` للبحث الجزئي

#### 11. الإشعارات لا تُحفظ (لا يوجد Notification History)
**المشكلة:** الإشعارات Push تختفي إذا كان التطبيق مغلقاً  
**الحل:** حفظ الإشعارات في collection خاصة، وإضافة شاشة "Notification Center"

#### 12. لا يوجد Dark Mode
**المشكلة:** التطبيق يدعم Light Mode فقط  
**الحل:** استخدام `ThemeMode.system` مع نسخة dark من AppTheme

#### 13. تحميل الصور في Register بطيء
**المشكلة:** لا يوجد compression للصور قبل الرفع — قد ترفع المستخدم 10MB+  
**الحل:** استخدام `flutter_image_compress` لتقليص الصورة قبل الإرسال

#### 14. لا يوجد Skeleton للمحادثات
**المشكلة:** شاشة chat تعرض فراغاً أثناء التحميل  
**الحل:** إضافة ChatSkeleton مماثل للـ skeletons الموجودة

#### 15. Post category غير مُقيَّد
**المشكلة:** المستخدم يدخل التصنيف كـ free text — قد ينشر بتصنيفات غير موحدة  
**الحل:** استخدام نفس قائمة `categories` من الـ services endpoint

---

## ملخص نقاط القوة والضعف

### نقاط القوة
| المجال | التقييم |
|--------|---------|
| البنية المعمارية | ⭐⭐⭐⭐⭐ ممتازة |
| نظام المصادقة | ⭐⭐⭐⭐⭐ محكم |
| Safe Area | ⭐⭐⭐⭐⭐ مبتكر |
| Real-time (WebSocket) | ⭐⭐⭐⭐ جيد جداً |
| Design System | ⭐⭐⭐⭐ متسق |
| التوثيق (CLAUDE.md) | ⭐⭐⭐⭐⭐ مثالي |

### نقاط الضعف
| المجال | التقييم |
|--------|---------|
| الأمان (Rate Limiting) | ⭐⭐ يحتاج تحسين |
| Offline Support | ⭐⭐ غائب |
| Admin Panel | ⭐ غائب كلياً |
| إشعارات Push حقيقية | ⭐⭐ محدودة |
| Wallet / Payments | ⭐⭐⭐ ناقص |

---

## الخلاصة

Amarlo مشروع **ناضج ومنظم جيداً** يطبق أنماطاً احترافية نادرة في المشاريع المشابهة:
- Escrow + Watermark في Safe Area
- JWT Rotation مع JTI
- Auto-refresh للتوكن في الـ client
- نظام توحيد URLs للصور

أبرز ما يحتاج العمل عليه فوراً:
1. **Rate Limiting** على `/auth/login` (أمان)
2. **Exponential Backoff** في WebSocket (استقرار)
3. **Image Compression** قبل الرفع (أداء + تجربة مستخدم)
4. **تصحيح اسم المجلد** `wrokerScreen` → `workerScreen`

المشروع قابل للتطوير بشكل كبير ويحتاج إلى:
- Admin Dashboard
- Push Notifications حقيقية (FCM)
- Wallet Withdrawal Flow
- Dark Mode

---

*تحليل من Claude Code — مبني على قراءة كاملة للكود المصدري*
