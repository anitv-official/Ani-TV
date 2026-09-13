# تقرير تدقيق Local Cache وCloud Sync قبل التنفيذ

## الخلاصة التنفيذية

يستخدم المشروع حاليًا `AppStateProvider` كمصدر حالة مركزي، ويستخدم `SharedPreferences` لتخزين بعض البيانات المحلية. توجد حماية جيدة من طلبات التهيئة المتزامنة داخل المزود عبر `_initializationFuture`، لكن هذه الحماية لا تمنع طلبات Appwrite المتكررة بين دورات التطبيق، ولا تجعل القراءة محلية أولًا للمستخدم المسجل. كما أن تهيئة الحساب تنتظر Appwrite قبل عرض البيانات المحلية.

أعلى نقطة مخاطرة هي `_syncAccountFromCloud()` في `lib/providers/app_state_provider.dart`. هذه الدالة تستدعي `ensureProfile()` ثم `getFavorites()` في كل تهيئة ناجحة للحساب. وتستدعي `ensureProfile()` بدورها `_listProfileRows()`، وهي قراءة لكل صفوف جدول Profiles ثم تصفية `userId` داخل التطبيق. لذلك فإن فتح Splash ثم Profile قد يعيد تشغيل مسار المصادقة أو ينتظر نفس Future بحسب دورة المزود، بينما إعادة تشغيل التطبيق تؤدي حتمًا إلى قراءة Profile وFavorites من السحابة قبل قراءة البيانات المحلية.

لن يتم تغيير Authentication أو Google Login أو Appwrite schema أو Permissions أو UI أو مصادر المحتوى. سيتم إضافة طبقة Cache مستقلة باستخدام `SharedPreferences` الموجود أصلًا، مع مفاتيح مرتبطة بـ`userId`، وقراءة محلية فورية، وطلب مزامنة واحد م deduplicated في الخلفية.

## جرد طلبات Appwrite الحالية

| الطلب | الملف والمصدر | متى يعمل | التكرار الحالي | قرار Cache |
|---|---|---|---|---|
| `account.get()` | `AppwriteService.getCurrentUser()` | كل `AppStateProvider.initialize()`، وبعد Login وUsername Login وGoogle Login والتحقق | متكرر عند بدء كل دورة تطبيق، ومحمي فقط داخل Future التهيئة الحالية | يبقى Cloud-first لتأكيد الجلسة، دون اختراع Session محلية |
| قراءة Profiles | `AppwriteService._listProfileRows()` عبر `getProfile()` و`ensureProfile()` | أثناء `_syncAccountFromCloud()` | يقرأ كل الصفوف في كل تهيئة مستخدم | Cache Profile محلي، مع مزامنة خلفية |
| فحص username | `checkUsernameAvailability()` عبر Function endpoint | Registration وتغيير Username وإنشاء Profile باسم مستخدم | يجب أن يبقى Server-side | لا Cache للـuniqueness |
| إنشاء/تحديث Profile | `ensureProfile()`, `updateProfile()` | Registration وتحديث الملف وتغيير username والصورة | كتابة مطلوبة عند التغيير فقط | تحديث Cache بعد نجاح الكتابة |
| `storage.getFileView()` | `profileImageBytes()` | عند بناء Avatar في Home/Profile | قد يتكرر عند إعادة بناء Widgets | Cache شبكة الصور الحالي يظل مسؤولًا عنه؛ لا تخزين بيانات حساسة جديدة |
| `databases.listDocuments()` Favorites | `getFavorites()` | أثناء `_syncAccountFromCloud()` | طلب كامل في كل تهيئة Cloud ناجحة | عرض Favorites المحلية أولًا، ثم مزامنة خلفية |
| `listDocuments()` Favorite واحد | `findFavorite()` | قبل إضافة أو إزالة Favorite | طلب لكل عملية | لا يمكن إلغاؤه دون تغيير سلوك التحقق؛ يظل Cloud-first للعملية نفسها |
| `createDocument()` Favorite | `createFavorite()` | إضافة Favorite | مرة لكل إضافة ناجحة | تحديث محلي فوري ثم Cloud، مع Queue عند الفشل |
| `deleteDocument()` Favorite | `deleteFavorite()` | إزالة Favorite | مرة لكل إزالة ناجحة | تحديث محلي فوري ثم Cloud، مع Queue عند الفشل |
| Username login Function | `loginWithUsername()` | تسجيل الدخول باسم المستخدم | حسب فعل المستخدم | لا Cache لكلمة المرور أو نتيجة uniqueness |
| Verification / Password / OAuth | `AppwriteService` | عمليات صريحة من المستخدم | ليست طلبات فتح التطبيق العادية | لا تغيير |
| History Cloud | لا يوجد طلب Appwrite حالي | History محلي فقط عبر SharedPreferences | لا يوجد Cloud sync حالي | يبقى محليًا ومفصولًا لكل userId |
| Settings | SharedPreferences في `AppStateProvider` و`ProfileScreen` | عند فتح Profile وحفظ التفضيلات | محلي، مع تكرار `initialize()` فقط | يبقى محليًا ومفصولًا لكل userId |

## أماكن التشغيل عند فتح التطبيق

`SplashScreen` يستدعي `AppStateProvider.initialize()` بعد أول إطار، ثم يستدعيه مرة أخرى بعد اكتمال Animation داخل `_checkAuthStatus()`. المزود يمنع تنفيذين متزامنين عبر `_initializationFuture`، ولذلك لا يتحول الاستدعاءان المتزامنان إلى طلبين مستقلين داخل نفس عمر المزود. بعد ذلك يجلب Splash بيانات Anime وManga، وهذه ليست Appwrite requests.

`ProfileScreen` يستدعي `initialize()` في `initState` ثلاث مرات منطقيًا عبر `_loadUserData()` و`_loadPreferences()` و`addPostFrameCallback`. الحماية الحالية تمنع التوازي داخل المزود، لكن كل دورة جديدة بعد انتهاء Future يمكنها إعادة مزامنة الحساب.

`AnimeDetailsScreen` و`ComicDetailsScreen` يستدعيان `initialize()` قبل عمليات Favorite. غالبًا يحصلان على Future مكتمل، لكن التصميم يجعل كل شاشة مرتبطة بمسار التهيئة بدل الاعتماد على حالة جاهزة فقط.

## الحالة المحلية قبل التعديل

| البيانات | التخزين الحالي | النطاق الأمني |
|---|---|---|
| Favorites | `favorite_anime_<userId>` و`favorite_comics_<userId>` | مفصول لكل userId عند المستخدم المسجل |
| History | `anime_history_<userId>` و`comic_history_<userId>` | مفصول لكل userId |
| Theme | `dark_mode_<scope>` | guest أو userId |
| Settings Profile | مفاتيح `stream_cellular_`, `show_mature_content_`, `notifications_enabled_` مع scope | guest أو userId |
| Profile | حقول الذاكرة فقط، وبعض username/email المفردة القديمة | لا توجد Snapshot موحدة للملف |
| Session | Appwrite client session و`account.get()` | لا يتم استبداله بكاش محلي |
| Secrets | لا ينبغي أن تضاف إلى الكاش | ممنوع التخزين |

## التكرار المكتشف

1. `initialize()` يقرأ `account.get()` في كل دورة تهيئة.
2. المستخدم المسجل ينتظر `ensureProfile()` ثم `getFavorites()` قبل أن تصبح الحالة جاهزة.
3. `ensureProfile()` يقرأ جميع صفوف Profiles عبر endpoint TablesDB ثم يبحث عن userId محليًا.
4. Profile وHome وعمليات Favorite تعتمد على مزود الحالة نفسه، لكن لا توجد Snapshot محلية موحدة للـProfile.
5. History لا يطلب Appwrite، لكنه يقرأ SharedPreferences بعد التهيئة بدل أن يُحمّل ضمن أول Snapshot محلية مباشرة.
6. الفشل السحابي أثناء المزامنة يمكن أن يترك الحالة الحالية سليمة، لكن يجب منع أي مسار جديد من استبدال Favorites المحلية بقائمة فارغة.

## التصميم الأقل مخاطرة

سيتم إضافة `LocalCacheService` مستقل فوق `SharedPreferences`. سيخزن Profile وFavorites وHistory مع مفاتيح user-scoped وتواريخ تحديث. سيقرأ `AppStateProvider` Snapshot المحلية بعد نجاح `account.get()` وقبل بدء Cloud refresh. سيبقى `account.get()` هو مصدر الحقيقة للجلسة.

سيستخدم المزود Future مشتركة للمزامنة السحابية لمنع طلبات Profile/Favorites المتزامنة المكررة. سيستمر Appwrite في تنفيذ نفس العمليات ونفس المعرفات والصلاحيات. لن تُنشأ Database أو Table جديدة، ولن تتغير أسماء Attributes.

## البيانات Local-first والبيانات Cloud-first

Profile وFavorites وHistory وSettings مناسبة لقراءة محلية فورية. Username availability وSession validity وعمليات تسجيل الدخول وتغيير كلمة المرور وتأكيد البريد تبقى Cloud-first. لا يُخزّن Password أو OAuth secret أو Appwrite API secret أو Session secret في LocalCache.

## قياس خط الأساس

لا يحتوي المشروع حاليًا على instrumentation دائم لعد طلبات Appwrite، ولا يمكن ادعاء رقم runtime دقيق دون تشغيل التطبيق بحساب فعلي أو إضافة عداد اختباري حول Client. من الكود يمكن إثبات الحد الأدنى التالي لكل تهيئة مستخدم مسجل ناجحة بعد انتهاء Future: `account.get()` مرة، وقراءة Profile عبر `_listProfileRows()` مرة، و`getFavorites()` مرة. عند فتح Splash، استدعاءا `initialize()` المتزامنان يتشاركان Future واحدة. بعد التعديل سيبقى `account.get()` مرة لتأكيد الجلسة، بينما Profile وFavorites سيظهران محليًا فورًا ويجري Cloud refresh واحد في الخلفية بدل حجب العرض.

## حدود التنفيذ

لن يتم تعديل Google Login أو Email/Password Login أو Username Login أو Logout أو Appwrite schema أو Permissions أو UI أو مصادر Anime/Manga أو Player أو Reader. سيتم تعديل طبقة الحالة والكاش فقط، وإضافة اختبارات وحدات لسلوك Cache وعزل userId وعدم استبدال البيانات المحلية بالفارغ عند فشل Cloud.

## نقطة الرجوع

تم إنشاء tag قبل التعديل:

`pre-cache-sync-20260913` عند commit `199d9d3`.

يمكن الرجوع إليه مباشرة إذا ظهر Regression.

## مراجع المشروع

- `lib/providers/app_state_provider.dart`
- `lib/services/appwrite_service.dart`
- `lib/screens/splash_screen.dart`
- `lib/screens/profile_screen.dart`
- `lib/screens/anime_details_screen.dart`
- `lib/screens/comic_details_screen.dart`
- `pubspec.yaml`
