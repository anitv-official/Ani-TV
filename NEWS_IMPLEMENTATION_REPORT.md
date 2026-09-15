# تقرير تنفيذ AniTV News

## النتيجة

تم تحويل واجهة Community في AniTV إلى واجهة أخبار عربية داخل التطبيق، مع فصل نموذج الخبر، حالة الأخبار، خدمة TablesDB، واجهة البطاقات، صفحة التفاصيل، البحث المحلي على البيانات المحملة، التصنيفات، الترقيم، التخزين المؤقت، الحالة غير المتصلة، الإعجاب، التعليقات، ورابط المقال الأصلي.

تم دفع التغييرات مباشرة إلى فرع `main` في commit `549e559`. نجحت فحوصات GitHub التالية: Flutter Analyze، Flutter Tests، وRelease Android APK Build.

## الملفات الجديدة والمعدلة

| المسار | الدور |
|---|---|
| `lib/models/news_model.dart` | نموذج الخبر وحقوله وتصنيفاته |
| `lib/services/news_service.dart` | القراءة والتفاعل مع TablesDB Rows للأخبار والإعجابات والتعليقات والبلاغات |
| `lib/providers/news_provider.dart` | الحالة، الترقيم، البحث، التصنيف، التخزين المؤقت، والعمل دون اتصال |
| `lib/screens/community_screen.dart` | واجهة AniTV News وصفحة تفاصيل الخبر والتعليقات والرابط الأصلي |
| `appwrite-functions/news-engine/index.js` | محرك server-side لجلب RSS والتصنيف والترجمة ومنع التكرار |
| `appwrite-functions/news-engine/README.md` | مخطط الجداول والصلاحيات والمتغيرات وطريقة النشر |
| `appwrite-functions/news-engine/package.json` | تعريف Function runtime Node.js 20 |

## مصادر الأخبار

تم تجهيز adapters للمصادر الخمسة التالية. يستخدم المحرك RSS الرسمي حيث تم التحقق من وجوده: Anime News Network، Crunchyroll News، Variety، وDeadline. لم يُثبت وجود RSS أو API رسمي واضح لـ ORICON في الفحص الحالي؛ لذلك بقي متغير `ORICON_FEED_URL` فارغًا بدل استخدام scraping غير موثق.

| المصدر | طريقة الوصول |
|---|---|
| Anime News Network | `https://www.animenewsnetwork.com/news/rss.xml` |
| Crunchyroll News | `https://cr-news-api-service.prd.crunchyrollsvc.com/v1/en-US/rss` |
| ORICON | يحتاج feed أو تصريح syndication رسمي قبل التفعيل |
| Variety | `https://variety.com/feed/` |
| Deadline | `https://deadline.com/feed/` |

المحرك يحفظ العنوان والملخص المختصر والرابط الأصلي فقط، ولا يحفظ نص المقال كاملًا. كما لا يعيد استضافة الصور دون ترخيص مناسب.

## Appwrite Tables المطلوبة

يستخدم التطبيق قاعدة البيانات الحالية `6aa58db9001a5f53312d` ولا ينشئ مشروعًا جديدًا. يلزم إنشاء الجداول التالية قبل التشغيل الإنتاجي:

| Table ID | الاستخدام |
|---|---|
| `community_news` | سجلات الأخبار |
| `news_likes` | إعجابات المستخدمين |
| `news_comments` | التعليقات |
| `news_reports` | البلاغات |

يلزم إنشاء فهرس فريد مركب على `news_likes(userId, newsId)` وفهرس فريد على `community_news(canonicalUrl)`. يجب أن تكون الأخبار للقراءة العامة، وأن تكون الكتابة عليها محصورة بالوظيفة server-side.

## المتغيرات السرية المطلوبة

يحتاج Appwrite Function إلى `APPWRITE_ENDPOINT`, `APPWRITE_PROJECT_ID`, `APPWRITE_API_KEY`, `APPWRITE_DATABASE_ID`, `NEWS_TABLE_ID`, `TRANSLATION_API_URL`, و`TRANSLATION_API_KEY`. ويمكن تخصيص روابط feeds عبر `ANN_FEED_URL`, `CRUNCHYROLL_FEED_URL`, `ORICON_FEED_URL`, `VARIETY_FEED_URL`, و`DEADLINE_FEED_URL`.

لم تُضف أي أسرار إلى Flutter أو GitHub source. ولم تكن صلاحية Appwrite server API أو بيانات مزود الترجمة متاحة في جلسة التنفيذ، لذلك لم يتم إنشاء الجداول أو نشر الوظيفة فعليًا.

## طريقة الترجمة

طبقة الترجمة منفصلة داخل `appwrite-functions/news-engine/index.js`. تستقبل مزود الترجمة server-side العنوان أو الملخص مع تعليمات عربية، وتحافظ على أسماء الأعمال والشخصيات. يمكن تغيير المزود بتغيير `TRANSLATION_API_URL` دون تعديل Flutter. إذا لم تُضبط متغيرات الترجمة، يحتفظ المحرك بالنص الأصلي كـ fallback؛ لذلك يجب ضبط مزود الترجمة قبل اعتبار الأخبار العربية مفعلة إنتاجيًا.

## ما تم اختباره

نجح `git diff --check` محليًا، ونجح فحص صياغة JavaScript لمحرك الأخبار. وعلى GitHub نجح Flutter Analyze، وFlutter Tests، وRelease Android APK Build في التشغيل `34930568789`. كما نجح Function Quality في التشغيل `34930568824`.

تم الحفاظ على Appwrite Authentication، Profiles، Favorites، Player، Global Search، والإشعارات دون تعديل وظيفي مقصود. بقيت جداول Community القديمة دون حذف.

## ما لم يُنفذ فعليًا بعد

لا يستطيع الإصدار الحالي جلب أخبار حقيقية وعرضها تلقائيًا في بيئة الإنتاج حتى يتم إنشاء TablesDB المطلوبة، ضبط صلاحياتها، نشر Appwrite Function، ضبط متغيرات الترجمة، وضبط Scheduled execution. هذه ليست مشكلة Flutter أو Build، بل إعدادات خارجية تحتاج صلاحية Appwrite server ومفتاح مزود ترجمة.

## المراجع

[1]: https://www.animenewsnetwork.com/news/rss.xml "Anime News Network official news RSS"
[2]: https://cr-news-api-service.prd.crunchyrollsvc.com/v1/en-US/rss "Crunchyroll News official RSS"
[3]: https://variety.com/feed/ "Variety official RSS"
[4]: https://deadline.com/feed/ "Deadline official RSS"
[5]: https://www.animenewsnetwork.com/newsfeed/terms-of-use.php "Anime News Network Newsfeed terms"
