# AniTV News Engine

هذا Appwrite Function يجلب موجزات RSS الرسمية، ويحوّلها إلى سجلات أخبار قصيرة، ويترجم العنوان والملخص server-side، ثم يخزنها في TablesDB. لا يخزن نص المقال الكامل ولا يضع أي مفتاح داخل Flutter.

## الجداول المستخدمة

يستخدم المحرك الجداول الموجودة مسبقًا داخل قاعدة البيانات `6aa58db9001a5f53312d`، ولا ينشئ أو يعدل Tables أو Columns أو Indexes:

| Table ID | الغرض |
|---|---|
| `community_news` | الأخبار |
| `news_likes` | إعجابات المستخدمين من Flutter |
| `news_comments` | تعليقات المستخدمين من Flutter |
| `news_reports` | بلاغات المستخدمين من Flutter |

Payload الأخبار لا يضيف `createdAt`؛ يرسل فقط الحقول التي يبنيها `index.js`. يجب أن تكون Schema الحالية متوافقة معها قبل النشر.

## التكرار والتحديث

يبحث المحرك أولًا باستخدام `canonicalUrl` الموجود، مع إزالة Fragment وtracking parameters الآمنة وتوحيد hostname وtrailing slash. لا يغيّر الرابط الأصلي المخزن في `sourceUrl` أو `sourceArticleId`.

عند إنشاء Row جديد، يستخدم ID حتميًا مشتقًا من SHA-256 للرابط المطبع بدل ID عشوائي. إذا حدث تعارض إنشاء بسبب تشغيل متزامن، يعيد قراءة Row نفسه ثم يحدثه. لا ينشئ المحرك Column أو Index جديدًا.

## الصلاحيات

لا يرسل المحرك صلاحيات Rows للأخبار. يجب أن تكون قراءة `community_news` عامة، وإنشاء/تحديث/حذف الأخبار محصورًا بمفتاح الوظيفة server-side. صلاحيات Likes وComments وReports يديرها Flutter وفق الكود الحالي.

## Environment Variables

`APPWRITE_ENDPOINT`, `APPWRITE_PROJECT_ID`, `APPWRITE_API_KEY`, `APPWRITE_DATABASE_ID`, `NEWS_TABLE_ID`, `TRANSLATION_API_URL`, و`TRANSLATION_API_KEY` تقرأ من Environment Variables. ويمكن تخصيص `ANN_FEED_URL`, `CRUNCHYROLL_FEED_URL`, `ORICON_FEED_URL`, `VARIETY_FEED_URL`, و`DEADLINE_FEED_URL`. لا تضع القيم السرية في Flutter أو المستودع.

## التشغيل

ارفع مجلد الوظيفة إلى Appwrite Function runtime Node.js 20 أو أحدث، واضبط نقطة الدخول وفق صيغة Appwrite Functions، ثم اضبط Scheduled Execution من Appwrite فقط. يمكن تشغيلها يدويًا من Appwrite عند الطلب.

## الترجمة

طبقة `translate` لا تعرف مزودًا بعينه. يجب أن تقبل خدمة الترجمة server-side طلبًا يحتوي `source`, `target`, `text`, و`instruction` وتعيد `translation` أو `text`. عند غياب الإعدادات أو فشل الطلب، يستخدم المحرك النص الأصلي المنظف والمقصوص بدل إيقاف بقية الأخبار.

## الاختبارات

```bash
npm run check
npm test
```

الاختبارات محلية ولا تتصل بـAppwrite أو مزود الترجمة.
