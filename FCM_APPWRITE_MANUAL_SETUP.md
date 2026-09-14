# AniTV Push Notifications — Manual Setup

هذه الوثيقة تكمل كود Flutter وحزمة Function. لا تحتوي أي Secret أو API key.

## ما تم تنفيذه في المشروع

يستخدم التطبيق الآن Firebase Messaging للحصول على FCM token، ثم يسجل الجهاز في Appwrite Messaging عبر `Account.createPushTarget`. عند تحديث token يستخدم `updatePushTarget`. عند تسجيل الخروج أو حذف الحساب يحذف Push Target، وعند تسجيل الدخول ينشئ الاشتراك في Topic عبر `Messaging.createSubscriber`. Appwrite Authentication وProfile وFunction المصادقة الحالية لم يتم استبدالها.

الإشعارات في foreground تظهر عبر قناة Android باسم `AniTV Notifications`. إشعارات background وterminated تعتمد على FCM/Appwrite payload، وفتح الإشعار يدعم `data.type` و`data.url` عبر طبقة URI الحالية.

## Firebase Console

1. افتح Firebase project المرتبط بالتطبيق `anitv-b98d5`.
2. تأكد أن Android app هو `com.anitv.app` وأن `google-services.json` المستخدم هو الملف المرفق للمشروع.
3. لا تضف SHA-1. استخدم إعداد SHA-256 الموجود فعليًا كما طلب المشروع.
4. في إعدادات Service Account/Cloud Messaging جهّز credential الخاص بـFCM Provider في Appwrite Console. لا تضع credential داخل Git أو Flutter أو Function source.

## Appwrite Messaging

المشروع الحالي:

- Endpoint: `https://nyc.cloud.appwrite.io/v1`
- Appwrite Project ID: `6aa4295900094d600163`
- Firebase Project ID: `anitv-b98d5`

في Appwrite Console:

1. افتح **Messaging → Providers**.
2. أنشئ أو فعّل Android FCM provider باستخدام credential السري من Firebase. سجّل **Provider ID** الناتج؛ لا تخمّنه.
3. افتح **Messaging → Topics** وأنشئ Topic عامًا بالاسم `anitv_all`.
4. سجّل **Topic ID** الناتج؛ الاسم ليس بالضرورة هو الـID.
5. اضبط Subscription access بحيث يسمح للمستخدمين المسجلين بالاشتراك.
6. لا تغيّر Function الحالية ذات المعرف `6aa5ed04000f66117651`.

## Function deployment

الحزمة الجاهزة:

`anitv-notifications-function.tar.gz`

أنشئ Function جديدة:

- Name: `AniTV Notifications`
- Runtime: Node.js 22
- Entrypoint: `src/main.js`
- Execute access: `Any` مع إبقاء authorization الداخلي فعالًا

Environment Variables داخل Function:

| Variable | Value |
|---|---|
| `APPWRITE_ENDPOINT` | `https://nyc.cloud.appwrite.io/v1` |
| `APPWRITE_PROJECT_ID` | `6aa4295900094d600163` |
| `APPWRITE_API_KEY` | Secret API key جديد مخصص للـFunction |
| `ANITV_ADMIN_USER_IDS` | Appwrite User IDs للمشرفين، مفصولة بفواصل |
| `ANITV_BROADCAST_TOPIC_ID` | Topic ID الفعلي من Appwrite |

أقل صلاحية مطلوبة للـAPI key: `messages.write`. لا تمنح Users/Databases/Storage permissions لهذه Function.

## Flutter build configuration

Provider ID وTopic ID ليسا أسرارًا، لكن يجب استخدام القيم الفعلية من Appwrite فقط:

```bash
flutter build apk --release \
  --dart-define=ANITV_FCM_PROVIDER_ID=<APPWRITE_FCM_PROVIDER_ID> \
  --dart-define=ANITV_FCM_TOPIC_ID=<APPWRITE_TOPIC_ID>
```

إذا لم يتم تمريرهما، يظل Firebase مهيأً لكن لن ينشئ التطبيق Push Target/Topic subscription، وهذا مقصود لمنع استخدام IDs مفترضة.

## Function API

User notification:

```json
{
  "type": "user",
  "userId": "APPWRITE_USER_ID",
  "title": "AniTV",
  "message": "لديك تحديث جديد",
  "data": {
    "type": "new_content",
    "url": "https://example.invalid/anime/123"
  }
}
```

Broadcast (admin only):

```json
{
  "type": "broadcast",
  "title": "AniTV",
  "message": "تمت إضافة محتوى جديد",
  "data": {
    "type": "new_content",
    "url": "https://example.invalid/anime/123"
  }
}
```

Function لا تقبل token في الطلب، ولا تقبل Topic ID من العميل، ولا تسمح للمستخدم العادي بإرسال إشعار إلى مستخدم آخر.

## Required manual tests

| Test | Status before manual Appwrite/Firebase setup |
|---|---|
| Authentication | PASS — existing Appwrite flow preserved |
| FCM initialization | PASS in GitHub Android build; runtime delivery requires provider setup |
| Push Target | NOT TESTED — REQUIRES Provider ID and signed-in device |
| Topic subscription | NOT TESTED — REQUIRES Topic ID and Appwrite access |
| User notification | NOT TESTED — REQUIRES deployed Function, admin/user IDs, and provider |
| Broadcast | NOT TESTED — REQUIRES deployed Function and admin allowlist |
| Foreground | Code path implemented; device delivery NOT TESTED |
| Background | Code path implemented; device delivery NOT TESTED |
| Terminated | Code path implemented; device delivery NOT TESTED |
| Notification tap | Code path implemented for `data.type` + `data.url`; device test required |
| Logout cleanup | Code path implemented; Appwrite target cleanup requires runtime test |
| Account deletion | Existing deletion Function preserved; target cleanup added before it; runtime test required |

## Security notes

لا توجد Service Account credentials أو Firebase Admin credentials أو Appwrite API keys داخل التطبيق أو Function source أو archive. Function logs لا تسجل FCM tokens أو secrets أو message content.
