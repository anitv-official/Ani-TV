# AniTV Favorite Notifications

هذا التنفيذ يجهز كود الماسح والإشعارات فقط، ولا يتصل بـ Appwrite ولا ينشر Function تلقائيًا. Appwrite Favorites هو مصدر الحقيقة، بينما تستخدم Supabase لتاريخ الإشعارات، ومنع التكرار، وحالات التسليم، وأخطاء الفحص.

## ما تم تجهيزه

- `appwrite-functions/anitv-notifications/src/main.js`: وظيفة Appwrite الجديدة. تقرأ جدول Favorites باستخدام `TablesDB`، تفحص أحدث إصدار، تمنع التكرار بمفتاح ذري في `notification_deliveries`، ترسل عبر Appwrite Messaging المرتبط بمزود Firebase FCM، وتحدث `lastNotifiedEpisode` أو `lastNotifiedChapter` و`lastCheckedAt`.
- `appwrite-functions/anitv-notifications/src/adapters/anime4up.js`: محول Anime4Up الموجود.
- `appwrite-functions/anitv-notifications/src/adapters/anime3rb.js`: محول Anime3rb يقرأ روابط `/episode/...` من HTML العام، ويستخدم نفس قارئ `r.jina.ai` العام الموجود في تطبيق AniTV كـ fallback فقط. لا يحل Cloudflare Challenge ولا يتجاوزه؛ عند استمرار الحجب يسجل الخطأ ولا يرسل إشعارًا.
- `appwrite-functions/anitv-notifications/src/adapters/generic-page.js`: محول محافظ للصفحات التي تحتوي على مؤشرات الحلقة/الفصل أو تاريخ الإصدار، لأن أسماء المصادر الأخرى وبنيتها غير معروفة من الكود وحده.
- `supabase/migrations/20260918042700_create_notification_infrastructure.sql`: جداول التاريخ والتسليمات وملخصات التشغيل الموجودة.
- `supabase/migrations/20260922170000_add_favorite_scan_errors.sql`: سجل مستقل لأخطاء مصادر Favorites لإعادة المحاولة في التشغيل التالي.
- `lib/main.dart`: إصلاح فتح deep-link من إشعارات الحلقة والفصل؛ الرابط يستخدم مسارًا مثل `anitv:///episode` بدل وضع النوع في host.
- شاشتا تفاصيل الأنمي والكوميكس تمرران `source_id` و`source` عند إنشاء Favorite، ويستخدم `AppStateProvider` المصدر الثابت `source_id` أولًا.

## متطلبات Appwrite اليدوية

أنشئ Function باسم `AniTV Favorite Notifications`، Runtime Node.js 22، وارفَع محتويات `appwrite-functions/anitv-notifications`. لا تستخدم Function تسجيل الدخول ولا Function قديمة باسم News Engine.

أضف المتغيرات السرية التالية داخل Function:

```text
APPWRITE_ENDPOINT=https://nyc.cloud.appwrite.io/v1
APPWRITE_PROJECT_ID=6aa4295900094d600163
ANITV_FAVORITE_SCAN_SECRET=<value chosen in Appwrite Console>
SUPABASE_URL=<AniTV Supabase project URL>
SUPABASE_SERVICE_ROLE_KEY=<Supabase service role key>
ANITV_ADMIN_USER_IDS=<optional comma-separated admin IDs>
ANITV_BROADCAST_TOPIC_ID=<only for broadcast path>
```

لا تضع `SUPABASE_SERVICE_ROLE_KEY` أو `FIREBASE_SERVICE_ACCOUNT_JSON` في Git أو Flutter. Secret `FIREBASE_SERVICE_ACCOUNT_JSON` الموجود في Supabase لا يصبح متاحًا تلقائيًا داخل Appwrite Function. التنفيذ الحالي يستخدم Appwrite Messaging، لذلك يجب إعداد Firebase Android Provider في Appwrite Console يدويًا؛ لا يتم إرسال Service Account JSON إلى المستودع.

امنح مفتاح Function صلاحيات قراءة وكتابة Rows على Favorites، وقراءة Targets، وكتابة Messages.

## تشغيل الفحص

الوظيفة لا تحتوي Scheduler داخليًا. استدعاؤها يكون عبر Cron/Scheduler خارجي واحد فقط:

```http
POST <APPWRITE_FUNCTION_URL>
x-anitv-favorite-scan-secret: <configured secret>
Content-Type: application/json

{"type":"favorite_scan","dryRun":true}
```

ابدأ بـ `dryRun: true`. بعد التأكد من قراءة الصفوف والمصادر، استخدم:

```json
{"type":"favorite_scan","dryRun":false}
```

الجدولة المقترحة هي كل 30 دقيقة للأنمي والمانجا، وكل 6 ساعات للأفلام والمسلسلات والدراما. إذا كان Scheduler واحدًا يشغل كل الأنواع، يمكن تشغيله كل 30 دقيقة؛ الأنواع الأبطأ لا ترسل إلا عند وجود إصدار جديد.

## منع التكرار والتسليم

مفتاح التكرار هو:

```text
userId|source|itemId|notificationType|releaseKey
```

ويُحفظ في `notification_deliveries`. الحالات المستخدمة هي `pending` و`sent` و`failed`. عند وجود تشغيلين متزامنين، يمنع قيد `dedupe_key` إرسال الإصدار نفسه للمستخدم أكثر من مرة. فشل المصدر لا يرسل إشعارًا، ويسجل في `favorite_scan_errors` مع سبب الخطأ، ثم يُعاد فحصه في التشغيل اللاحق.

## Payload الإشعار

يحتوي payload على:

```json
{
  "userId": "APPWRITE_USER_ID",
  "contentType": "anime",
  "notificationType": "episode",
  "itemId": "https://example.test/anime/1",
  "title": "Example",
  "source": "anime4up",
  "episode": "12",
  "releaseKey": "12",
  "url": "https://example.test/anime/1",
  "deepLink": "anitv:///episode?url=...&source=anime4up"
}
```

الضغط على الإشعار يمر عبر FCM ثم `FcmService` و`lib/main.dart`، ويفتح شاشة الأنمي أو المانجا أو القارئ حسب النوع.

## اختبارات محلية وCI

داخل مجلد الوظيفة:

```bash
npm ci --ignore-scripts
npm test
node --check src/main.js
```

يتم تشغيل اختبارات الوظيفة ضمن GitHub Actions في job باسم `favorite-notifications-quality`. لا تتطلب الاختبارات أسرارًا ولا اتصالًا بـ Appwrite أو Firebase.

## نقاط يدوية متبقية

1. تطبيق migration الجديدة على Supabase.
2. إنشاء/نشر Function من Appwrite Console أو CLI.
3. ضبط Firebase FCM Provider داخل Appwrite Messaging باستخدام إعداد Firebase الرسمي.
4. ضبط متغيرات Function والصلاحيات.
5. إنشاء Cron واحد واستدعاء `favorite_scan` بالـ secret header.
6. تجربة `dryRun` ثم تشغيل حقيقي بعد التأكد من الصفوف.
7. إضافة محولات خاصة للمصادر التي لا تعرض رقم الحلقة/الفصل بطريقة يمكن اكتشافها من HTML العام؛ المحول العام متعمد أن يكون محافظًا ولا يخمّن إصدارًا عند غياب مؤشر واضح.
