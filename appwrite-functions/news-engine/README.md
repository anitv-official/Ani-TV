# AniTV News Engine

هذا Appwrite Function يجلب موجزات RSS الرسمية، ويحوّلها إلى سجلات أخبار قصيرة، ويترجم العنوان والملخص server-side، ثم يخزنها في TablesDB. لا يخزن نص المقال الكامل ولا يضع أي مفتاح داخل Flutter.

## الجداول المطلوبة

أنشئ الجداول التالية داخل قاعدة البيانات الحالية `6aa58db9001a5f53312d` قبل تفعيل الوظيفة. أبقِ جداول Community القديمة كما هي.

| Table ID | الغرض | الحقول الأساسية |
|---|---|---|
| `community_news` | الأخبار | `source`, `sourceArticleId`, `sourceUrl`, `canonicalUrl`, `titleOriginal`, `titleArabic`, `summaryOriginal`, `summaryArabic`, `imageUrl`, `category`, `tags`, `relatedType`, `relatedItemId`, `publishedAt`, `fetchedAt`, `translatedAt`, `createdAt`, `updatedAt`, `likeCount`, `commentCount`, `engagementScore`, `searchText` |
| `news_likes` | الإعجاب | `userId`, `newsId`, `createdAt` |
| `news_comments` | التعليقات | `userId`, `username`, `displayName`, `profileImageId`, `newsId`, `text`, `createdAt`, `updatedAt` |
| `news_reports` | البلاغات | `userId`, `newsId`, `reason`, `details`, `createdAt` |

أضف فهرسًا فريدًا مركبًا على `news_likes(userId, newsId)`. وأضف فهرسًا فريدًا على `community_news(canonicalUrl)`. أضف فهرس بحث على `community_news.searchText` إذا كان متاحًا في إعداد TablesDB.

## الصلاحيات

اجعل قراءة `community_news` عامة، وإنشاء/تحديث/حذف الأخبار محصورًا بمفتاح الوظيفة. اجعل قراءة `news_likes` و`news_comments` عامة، وإنشاءها للمستخدم المسجل، وحذف الصف للمستخدم صاحب `userId` فقط. اجعل `news_reports` قابلة للإنشاء للمستخدم المسجل فقط وغير قابلة للقراءة العامة.

## Environment Variables

`APPWRITE_ENDPOINT`, `APPWRITE_PROJECT_ID`, `APPWRITE_API_KEY`, `APPWRITE_DATABASE_ID`, `NEWS_TABLE_ID`, `TRANSLATION_API_URL`, و`TRANSLATION_API_KEY` مطلوبة. ويمكن تخصيص `ANN_FEED_URL`, `CRUNCHYROLL_FEED_URL`, `ORICON_FEED_URL`, `VARIETY_FEED_URL`, و`DEADLINE_FEED_URL`. لا تضع هذه القيم السرية في Flutter أو المستودع العام.

## التشغيل

ارفع مجلد الوظيفة إلى Appwrite Function runtime Node.js 20، واضبط نقطة الدخول وفق صيغة Appwrite Functions، ثم اضبط Scheduled execution كل ساعة أو عدة ساعات حسب حدود الخطة. يمكن تشغيلها يدويًا من Appwrite عند الطلب. إذا لم يتوفر feed رسمي لمصدر، اترك متغيره فارغًا بدل استخدام scraping هش.

## الترجمة

طبقة `translate` لا تعرف مزودًا بعينه. يجب أن تقبل خدمة الترجمة server-side طلبًا يحتوي `source`, `target`, `text`, و`instruction` وتعيد `translation` أو `text`. يمكن تغيير المزود دون تعديل Flutter أو نموذج الخبر.
