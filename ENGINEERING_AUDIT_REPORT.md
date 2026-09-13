# تقرير الفحص والإصلاح الهندسي لتطبيق AniTV

## الخلاصة التنفيذية

تم فحص مشروع AniTV الحالي، وهو تطبيق Flutter يعتمد على Appwrite للمصادقة والملفات الشخصية والمفضلة والصور، وعلى محولات مستقلة لمصادر الأنمي والمانجا. تم تطبيق إصلاحات فعلية في التسجيل، وحفظ الملف الشخصي، والتحقق من Username، وتسجيل الدخول باسم المستخدم، وعرض البيانات الثابتة، وفتح صفحة المصدر والبحث داخلها. كما تم تحسين Home بإضافة حالة الحساب وصورة Profile أو زر الدخول مع الحفاظ على البيانات الحقيقية والمصادر الحالية. لم يتم تغيير مشغل الأنمي أو مصادر الأنمي العاملة.

## المشكلات المكتشفة والإصلاحات

| المجال | السبب الحقيقي | الملفات المسؤولة | الإصلاح المطبق | حالة الاختبار |
|---|---|---|---|---|
| Username في التسجيل | شاشة التسجيل لم تكن تحتوي Username أصلًا، وكان Provider يولّد اسمًا مشتقًا من الاسم الظاهر ومعرف المستخدم. | `lib/screens/register_screen.dart`, `lib/providers/app_state_provider.dart` | أضيف حقل Username صريح، وتطبيع lowercase، والتحقق من الصيغة، والتحقق المؤجل debounce، والتحقق النهائي قبل إنشاء الحساب. | تم التحقق من الاتساق النصي و`git diff --check`. اختبار Flutter الفعلي غير ممكن لأن Flutter غير مثبت في بيئة التنفيذ. |
| Username وDisplay Name | كان الاسم المشتق من `displayName` يستخدم كحل بديل لهوية Username. | `lib/providers/app_state_provider.dart` | فصل الحقلين منطقيًا. تسجيل الدخول يعتمد على Username فقط عبر Function، والاسم الظاهر يبقى اسم Appwrite المعروض. مستخدمو OAuth بلا Username لا يحصلون على اسم عشوائي تلقائي. | مراجعة مسارات login وprofile. |
| التفرد وحساسية الأحرف | الفحص السابق كان يبحث عن القيمة lowercase فقط، ولذلك كان يمكن ألا يلتقط سجلًا قديمًا مثل `Lord`. | `lib/services/appwrite_service.dart` | تتم مقارنة كل السجلات ضمن الحد المدعوم بعد التطبيع lowercase. ملفات Profiles الجديدة تستخدم Username المطبع كمعرف مستند، ما يجعل حجز الأسماء الجديدة ذريًا بين `Lord` و`lord` و`LORD`. | تمت مراجعة الاستعلام والمنطق. يلزم اختبار تكاملي على قاعدة Appwrite الفعلية. |
| تسجيل الدخول باسم المستخدم | التدفق الحالي يعتمد على Appwrite Function لتحويل Username إلى User ثم إنشاء session، لكن العميل لم يكن يطبع الاسم أو يعالج استجابة غير JSON بوضوح. | `lib/services/appwrite_service.dart`, `appwrite-functions/username-login/src/main.js` | طُبع Username قبل الإرسال، وأضيف تحقق آمن من الاستجابة وإنشاء session Appwrite، مع رسائل عامة للمستخدم وعدم تسريب بيانات الحساب. | `node --check` نجح للدالة. |
| بيانات Profile | كان Profile ينشئ `userId`, `username`, و`profileImageId` فقط. | `lib/services/appwrite_service.dart`, `lib/providers/app_state_provider.dart` | أضيف حفظ `displayName`, `email`, `birthDate`, `country`, `createdAt`, و`updatedAt`. وتمت إضافة تحميل `birthDate` و`country` من السحابة. | تمت مراجعة الاستدعاءات والحقول. يجب التأكد من وجود Attributes نفسها في Appwrite Console قبل النشر. |
| التسجيل غير المكتمل | بعد إنشاء User كان إنشاء Profile أو رفع الصورة يمكن أن يفشل دون تنظيف الجلسة. | `lib/services/appwrite_service.dart`, `lib/providers/app_state_provider.dart` | صار فشل إنشاء session ينظف الجلسة، وصار فشل إكمال التسجيل ينفذ cleanup للجلسة. فشل رفع الصورة الاختيارية لا يمنع إنشاء الحساب. | تمت مراجعة مسار النجاح والفشل. اختبار الشبكة الفعلي غير متاح دون حساب اختبار وصلاحيات Appwrite. |
| صورة Profile | لم تكن هناك إمكانية اختيار الصورة أثناء التسجيل. | `lib/screens/register_screen.dart`, `lib/providers/app_state_provider.dart` | أضيف اختيار صورة عبر File Picker، ومعاينة، وإعادة اختيار، ورفع اختياري إلى Bucket الحالي، وحفظ File ID. رفض الصلاحية أو الإلغاء أو فشل الرفع لا يمنع التسجيل. | تمت مراجعة imports ومسار الرفع. |
| تاريخ الميلاد والدولة | الحقلان غير موجودين في التسجيل أو Profile. | `lib/screens/register_screen.dart`, `lib/screens/profile_screen.dart`, `lib/providers/app_state_provider.dart` | أضيف Date Picker وقائمة الدول، ويحفظان في Profile. يظهران في بيانات الحساب دون أي أزرار أو دوال تعديل. طبقة updateProfile لا تقبل تعديلهما. | تمت مراجعة عدم وجود مسار تعديل. |
| صفحة المصدر | بطاقات المصادر المختصرة في Home كانت تنفذ callback يفتح قائمة المصادر بدل فتح المصدر المختار، وصفحة المصدر لم توفر بحثًا داخليًا. | `lib/screens/sources_screen.dart` | البطاقة تفتح `SourceContentScreen` للمصدر المحدد، وأضيف بحث المصدر مع pagination الحالية. | تمت مراجعة بنية FutureBuilder والأقواس و`git diff --check`. |
| Manga Slayer | API `https://api.mangaslayers.com` أعاد 401 بدون المفتاح و500 مع المفتاح الموجود، كما أن الموقع الحالي `mangaslayers.com` يعرض صفحة Next.js عامة بلا مسارات manga ظاهرة في HTML؛ هذا يثبت أن المشكلة خارج parser الحالي وحده. | `lib/sources/manga_slayer_source.dart` | لم يتم حذف المصدر أو إخفاؤه أو العبث بمصدر Team X. أبقيت adapter الحالي حفاظًا على البنية، ووثقت أن إصلاحًا حقيقيًا يتطلب API/مخططًا حاليًا من مالك المصدر أو reverse engineering إضافيًا. | اختُبرت نقاط API وموقع المصدر عبر curl. النتيجة: API 500 مع المفتاح، والموقع 200 لصفحة عامة. |

## ما لم يتغير

لم يتم تعديل منطق مشغل الأنمي، ولم تتم إزالة أي مصدر، ولم يتم استبدال Appwrite، ولم تتغير IDs الحالية لقاعدة البيانات أو Collection أو Bucket. بقيت Function الخاصة بتسجيل الدخول باسم المستخدم موجودة، وبقي Team X/Olympus دون تعديل. كما لم تتم إضافة مصدر مانجا جديد.

## التحقق المنفذ

تم تنفيذ `git diff --check` بنجاح. وتم تنفيذ `node --check appwrite-functions/username-login/src/main.js` بنجاح. كما نجح GitHub Actions بعد آخر تعديل على commit `612b34c`: `flutter analyze`, و`flutter test`, و`flutter build apk --release`, ورفع ملف APK. تمت مراجعة جميع استدعاءات `register`, `ensureProfile`, `updateProfile`, وحقول `birthDate` و`country` بعد التعديل. لم يتوفر في بيئة التنفيذ المحلية Flutter، لذلك تم الاعتماد على CI للتحقق الفعلي من التحليل والاختبارات والبناء.

## متطلبات Appwrite قبل النشر

يجب أن تحتوي Collection Profiles الحالية على Attributes متوافقة مع الحقول الجديدة: `userId`, `username`, `displayName`, `email`, `birthDate`, `country`, `profileImageId`, `createdAt`, و`updatedAt`. يجب كذلك مراجعة Permissions للسماح للمستخدم الحالي بإنشاء وقراءة وتحديث Profile الخاص به، ومراجعة صلاحيات Bucket الحالي للقراءة والرفع والحذف وفق User ID. لم يتم إنشاء Database أو Bucket جديد ولم يتم حذف أي بيانات.

يجب نشر نسخة Function الموجودة مع متغيرات البيئة الحالية، وبالأخص `APPWRITE_ENDPOINT`, `APPWRITE_PROJECT_ID`, `APPWRITE_API_KEY`, `APPWRITE_DATABASE_ID`, و`APPWRITE_PROFILES_TABLE_ID`. لا تظهر مفاتيح أسرار جديدة في كود Flutter.

## الملفات المعدلة

| الملف | سبب التعديل |
|---|---|
| `lib/services/appwrite_service.dart` | فصل حقول Profile، تطبيع Username، فحص التفرد، إنشاء مستند Profile، وتنظيف أخطاء الجلسة. |
| `lib/providers/app_state_provider.dart` | تمرير بيانات التسجيل الجديدة، مزامنة الحقول الثابتة، رفع الصورة الاختياري، ومنع Username العشوائي لـ OAuth. |
| `lib/screens/register_screen.dart` | إضافة Username والتحقق debounce وتاريخ الميلاد والدولة والصورة والمعاينة. |
| `lib/screens/profile_screen.dart` | عرض تاريخ الميلاد والدولة كبيانات ثابتة غير قابلة للتعديل. |
| `lib/screens/sources_screen.dart` | فتح المصدر الصحيح من Home وإضافة البحث داخل صفحة المصدر. |
| `lib/screens/home_content.dart` | تحسين Header في Home لعرض حالة الحساب وصورة Profile أو زر الدخول دون تغيير مصادر البيانات. |
| `ENGINEERING_AUDIT_REPORT.md` | توثيق الفحص والإصلاحات والاختبارات والقيود. |

## النتيجة النهائية

أصبح مسار Email login وUsername login منفصلين منطقيًا، وأصبح التسجيل يجمع البيانات المطلوبة ويخزنها عبر Appwrite، وأصبح Session persistence يعتمد على جلسة Appwrite الحالية، وأصبحت بيانات الحساب مرتبطة بمعرف المستخدم. أما Manga Slayer فلا يمكن إعلان إصلاحه دون نقطة API عاملة أو بنية مصدر حقيقية؛ وقد تم إثبات عطل الخدمة الحالية بدل إخفائه أو تقديم parser غير قابل للتحقق.

لم يوجد في الكود الحالي أي تدفق Google OAuth قابل للتنفيذ؛ لذلك لم يتم حذف Google Login، بل تم توثيق أن الاختبار غير منطبق على النسخة الحالية. كما لا يمكن اعتماد اختبار Appwrite تكاملي كامل للمستخدمين والمفضلة والصورة من بيئة CI دون حسابات اختبار وAttributes وPermissions صحيحة في مشروع Appwrite الفعلي.

## References

[1]: https://appwrite.io/docs "Appwrite Documentation"
[2]: https://docs.flutter.dev "Flutter Documentation"
[3]: https://github.com/lo-oord/Ani-TV "AniTV GitHub Repository"


## تدقيق متابعة وتنفيذ إضافي — 2026-09-13

أظهر التدقيق المتوازي أن النسخة السابقة كانت تحتاج إلى إصلاحات إضافية في حدود الجلسة والبيانات المحلية والروابط العميقة. تم إصلاح سباق استعادة الجلسة بجعل `initialize()` يعيد نفس `Future` لجميع الاستدعاءات المتزامنة، وإضافة تحميل سجل المشاهدة بعد تسجيل الدخول بالبريد واسم المستخدم وGoogle. كما تم توحيد شاشة الدخول في حقل واحد بعنوان «البريد الإلكتروني أو اسم المستخدم»، مع كشف نوع المُعرّف تلقائيًا.

تم عزل إعدادات الوضع الداكن وإعدادات الملف الشخصي حسب `userId`، وتم منع حذف مفضلة من مصدر مختلف عند تطابق `itemId` عبر تمرير `source` إلى الاستعلام. أضيف تحقق من أن عمليات المفضلة تستخدم جلسة المستخدم الحالية بدل الاعتماد على `userId` المرسل من الواجهة فقط. كذلك قُيّدت معالجة الروابط العميقة بحيث لا تُفسّر روابط OAuth كروابط استرداد كلمة مرور، ولا تُقبل روابط الاسترداد إلا من schemes/hosts/paths المعروفة.

أزيلت الأسرار الثابتة الخاصة بمصدر Anime Slayer من كود Flutter. أصبحت القيم الحساسة اختيارية وتُمرر عبر `--dart-define` أو، ويفضل، عبر proxy خادمي؛ لا توجد الآن قيمة سرية صريحة في الشفرة. كما عُطلت اتصالات HTTP الصريحة في Android Manifest، وأضيف إلى GitHub Actions فحص syntax وتثبيت dependencies وتدقيق `npm audit` لوظيفة username-login.

تبقى قيود تتطلب إعدادًا خارج المستودع: صلاحيات Appwrite على مستوى الصفوف والملفات، endpoint خادمي ذري لتوفر username، تدفق حذف الحساب server-side، واختبارات تكامل بحسابين حقيقيين. لم تُنفذ تغييرات مدمرة أو حذف لبيانات Appwrite، ولم يتغير مشغل الأنمي أو المانجا أو مصادر المحتوى.

## تدقيق مخطط Appwrite المؤكد — 2026-09-13

تمت مواءمة طبقة Profiles مع الحقول التي أكدها مخطط Appwrite فقط: `userId`, `username`, `profileImageId`, و`updatedAt`. أزيل إرسال الحقول غير المؤكدة `displayName`, `email`, `birthDate`, `country`, و`createdAt` إلى TablesDB، كما أزيلت من واجهة `ensureProfile` حتى لا يوحي الكود بأنها مدعومة في الجدول الحالي. بقي `displayName` و`email` مصدرهما Account الحالي، ولم تتم إضافة تخزين محلي للحقول غير المؤكدة.

كما تم تشديد حذف Favorites بحيث يتحقق من جلسة المستخدم الحالية قبل تنفيذ الحذف، مع الحفاظ على Table IDs وBucket ID وFunction ID الحالية دون تغيير. لم يتم إنشاء Table لـHistory أو Settings لأن الملف المقدم يؤكد عدم وجودهما.

لم يتم التحقق من Permissions أو تنفيذ اختبارات تكامل فعلية على حسابين لأن الملف لا يحتوي على تصدير صلاحيات Appwrite أو بيانات اختبار إضافية. لذلك لا تُعد هذه النقاط مثبتة بمجرد نجاح البناء.
