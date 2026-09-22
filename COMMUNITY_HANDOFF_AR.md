# ملف تسليم مشروع AniTV Community

**التاريخ:** 22 سبتمبر 2026  
**المستودع:** `anitv-official/Ani-TV`  
**الفرع:** `main`  
**آخر Commit ناجح:** `87ee3b7 fix(community): close post menu and profile widget`

## 1. الهدف من هذا الملف

هذا الملف يلخص كل ما تم فحصه وتنفيذه وإصلاحه في نظام Community داخل تطبيق AniTV، مع توضيح البنية الحالية، الخدمات الخارجية المستخدمة، migrations وEdge Functions، commits المهمة، نتائج الاختبارات، والمراحل المتبقية التي يجب على المطور التالي إكمالها.

الملف مخصص للإرسال إلى Chat جديد حتى يستطيع متابعة المشروع من دون فقدان السياق السابق.

## 2. المشروع والبنية العامة

المشروع تطبيق Flutter يعتمد على Appwrite للمصادقة وملفات المستخدم الأساسية، وعلى Supabase لبيانات Community وعمليات القراءة والكتابة الموثوقة. يتم استخدام Edge Functions في Supabase كجسر موثوق بين هوية Appwrite وقاعدة بيانات Community.

المسارات المهمة:

| المسار | الغرض |
|---|---|
| `lib/community/models/community_models.dart` | نماذج المستخدم والمنشور والتعليق والصداقة والمحادثة والوسائط |
| `lib/community/repositories/community_repositories.dart` | عقود المستودعات العامة التي تعتمد عليها الواجهة |
| `lib/community/repositories/supabase_community_repositories.dart` | التطبيق الإنتاجي للمستودعات باستخدام Supabase وEdge Functions |
| `lib/community/mock/mock_community_repository.dart` | مستودع Mock المستخدم في اختبارات Flutter |
| `lib/community/state/community_feed_provider.dart` | حالة Feed، التحميل التدريجي، البحث، الإعجاب، والنشر والحذف |
| `lib/community/widgets/community_widgets.dart` | Avatar، Post Item، الوسائط، ومكونات العرض |
| `lib/screens/community_screen.dart` | شاشة المجتمع الرئيسية، النشر، المنشورات، التعليقات وشريط الأصدقاء |
| `lib/screens/community_social_screens.dart` | ملفات المستخدمين، الرسائل، المحادثات، وملف المستخدم العام |
| `lib/screens/community_notifications_screen.dart` | الإشعارات وطلبات الصداقة وقبولها أو رفضها |
| `lib/community/services/community_write_api.dart` | عميل استدعاء `community-write` مع JWT Appwrite |
| `lib/community/services/community_media_api.dart` | رفع وسائط المنشورات إلى B2 عبر Edge Functions |
| `lib/community/services/appwrite_community_identity.dart` | استخراج هوية Appwrite الحالية وإنشاء JWT |
| `lib/services/appwrite_service.dart` | بيانات Appwrite ورفع صور الحساب وصور المحادثات |
| `supabase/functions/community-write/index.ts` | عمليات الكتابة الحساسة وإدارة الصداقة والمحادثات والحذف |
| `supabase/functions/_shared/community_media.ts` | التحقق من JWT، Supabase REST، B2، وتنسيق الأخطاء |
| `supabase/migrations/` | مخطط قاعدة البيانات والسياسات والفهارس وإصلاحات Community |
| `.github/workflows/android.yml` | تحليل Flutter، الاختبارات، وبناء APK |
| `.github/workflows/function-quality.yml` | فحص Edge Functions واختباراتها |

## 3. الخدمات والهوية المستخدمة

### Appwrite

Appwrite هو المصدر الأساسي للهوية وملف المستخدم. يتم استخراج المستخدم الحالي من Appwrite، ثم إنشاء JWT خاص بـ Community وإرساله في الرأس:

```text
x-appwrite-jwt: <Appwrite Community JWT>
```

Edge Function تتحقق من JWT من خلال Appwrite API ثم تستخرج `$id` الحقيقي للمستخدم. لا يجب قبول `user_id` القادم من العميل باعتباره هوية موثوقة في العمليات الحساسة.

بيانات ملف Appwrite التي يجب استخدامها عند عرض مستخدم:

- `username`
- `displayname`
- `country`
- `birthdate`
- `profileImageId`

### Supabase

Supabase هو مخزن بيانات Community. توجد جداول للملفات والمنشورات والتعليقات والإعجابات والصداقة والمحادثات والإشعارات. القراءات العامة تتم من خلال Supabase، أما عمليات الكتابة الحساسة فتستخدم `community-write` بعد تحقق Edge Function من هوية Appwrite.

### Backblaze B2

وسائط المنشورات، خصوصًا الصور والصوت، تستخدم تدفقًا آمنًا عبر:

1. طلب ticket من Edge Function.
2. رفع الملف إلى B2 عبر URL موقّع.
3. تأكيد الرفع.
4. طلب URL آمن للعرض.

لا توجد مفاتيح B2 داخل Flutter أو GitHub repository. يجب الحفاظ على ذلك.

## 4. ما تم إصلاحه وتنفيذه

### 4.1 نشر المنشورات وظهورها بين المستخدمين

تم إصلاح مشكلة كانت تمنع الحساب الثاني من رؤية المنشورات. السبب كان استعلام PostgREST يستخدم علاقة غير محددة:

```dart
community_profiles(*)
```

وكانت هناك أكثر من علاقة بين الجداول، مما أدى إلى خطأ PostgREST من نوع علاقة غير واضحة. تم تثبيت العلاقة الصحيحة:

```dart
community_profiles!community_posts_author_id_fkey(*)
```

وتم تطبيق ذلك على:

- Feed المجتمع.
- منشورات الملف الشخصي.
- مؤلفي المنشورات.
- استعلامات التعليقات.

تم التحقق من الاستعلام مباشرة عبر Supabase REST وكانت النتيجة HTTP 200 مع بيانات المنشورات.

### 4.2 هوية المستخدم واليوزر والصورة

تم ربط ملف المستخدم في Community ببيانات Appwrite بدل الاعتماد على بيانات Community قديمة أو مولدة تلقائيًا. عند تحميل ملف مستخدم، يتم إثراء البيانات من Appwrite وإظهار:

- اليوزر الحقيقي.
- الاسم الحقيقي.
- الدولة.
- تاريخ الميلاد.
- صورة الملف الشخصي الحقيقية.

تم أيضًا إضافة تخزين مؤقت للصور داخل `CommunityAvatar` عبر cache داخل الذاكرة حتى لا يتم طلب صورة Appwrite في كل إعادة بناء للعنصر.

### 4.3 صور الملف الشخصي

تم تعديل صلاحيات صور الملف الشخصي المرفوعة إلى Appwrite بحيث تكون قابلة للقراءة العامة، مع إبقاء التعديل والحذف لصاحب الصورة فقط.

أضيفت أيضًا ترقية تلقائية لصلاحية الصور القديمة أثناء مزامنة الحساب من خلال:

```dart
makeProfileImagePublic(...)
```

يجب على المستخدم فتح التطبيق مرة واحدة بعد التحديث حتى تتم معالجة صورة قديمة لم تكن عامة.

### 4.4 الصور في المنشورات والتعليقات

تم جعل `CommunityAvatar` يستخدم `avatarPath` تلقائيًا إذا لم يتم تمرير `avatarFuture`، مع cache للصور. تم إثراء مؤلفي المنشورات والتعليقات من Appwrite حتى تظهر صورة الشخص وبياناته الصحيحة في:

- المنشورات.
- التعليقات.
- شريط الأصدقاء.
- الملفات الشخصية.
- المحادثات.

### 4.5 الإعجاب والتعليقات

تم تطبيق تحديث متفائل للإعجاب داخل `CommunityFeedProvider`:

1. يتغير شكل القلب والعداد فورًا.
2. يتم تنفيذ الطلب في الخلفية.
3. عند الفشل يتم إرجاع الحالة السابقة.

تم تثبيت عدادات المنشورات في migration خاصة، وأصبح لكل منشور عداد إعجاب وعدّاد تعليقات.

تم تحسين عرض التعليقات إلى بطاقات أصغر وأكثر وضوحًا، مع صورة واسم وusername ووقت التعليق.

### 4.6 طلبات الصداقة

تم تنفيذ أو إصلاح المسارات التالية داخل `community-write`:

- `send_friend_request`
- `friend_status`
- `list_friend_requests`
- `respond_friend_request`
- `list_friends`

عند إرسال الطلب، يتم إنشاء سجل في `community_friend_requests` وإشعار في `community_notifications`.

تم فحص قاعدة الإنتاج ووجد طلب صداقة حقيقي موجودًا، كما وُجد إشعار الطلب في قاعدة البيانات. المشكلة السابقة كانت في طبقة عرض الإشعار، حيث كان النوع يظهر خامًا بدل اسم المرسل. تم تعديل الاستجابة لإرجاع `actor_profile` وإظهار عبارات مثل:

```text
طلب صداقة من <اسم المستخدم>
```

مع أزرار قبول ورفض.

### 4.7 المحادثات

كانت صفحة الملف الشخصي تفتح محادثة بمعرف وهمي مثل:

```text
conversation-<userId>
```

وهذا المعرف لم يكن موجودًا في قاعدة البيانات، لذلك كان إرسال الرسائل يفشل. تم إضافة مسار حقيقي:

```text
open_conversation
```

يقوم بالآتي:

1. البحث عن محادثة مشتركة موجودة.
2. إذا لم توجد، إنشاء `community_conversations`.
3. إضافة المستخدم الحالي كعضو.
4. إضافة المستخدم الآخر كعضو.
5. إرجاع `conversation_id` الحقيقي.

تم ربط زر المحادثة في ملف المستخدم بهذا المسار بدل المعرف الوهمي.

### 4.8 إرسال الصور في المحادثات

تمت إضافة دعم إرسال الصور في المحادثات:

- اختيار صورة من الجهاز عبر `FilePicker`.
- رفع الصورة إلى Appwrite عبر `uploadChatImage`.
- حفظ `media_reference` داخل `community_messages`.
- ضبط `message_type` إلى `image`.
- عرض الصورة داخل فقاعة الرسالة.

تم تحديث `CommunityMessage` ليحتوي على:

```dart
String? mediaReference
```

وتم تحديث عقد `ChatRepository` وMock وSupabase Repository لدعم رسالة نصية أو صورة.

### 4.9 حذف المحتوى الشخصي

تمت إضافة حذف المنشور والتعليق مع التحقق من الملكية داخل Edge Function:

- `delete_post`
- `delete_comment`

الحذف Soft Delete من خلال `deleted_at`، ولا يسمح للمستخدم بحذف محتوى مستخدم آخر.

تمت إضافة قائمة حذف المنشور داخل `CommunityPostItem`، ولا تظهر إلا إذا كان المنشور يخص المستخدم الحالي.

### 4.10 عنوان الملف الشخصي

تم إصلاح العنوان ليصبح:

- `ملفي الشخصي` للمستخدم الحالي.
- `ملف المستخدم` عند فتح ملف مستخدم آخر.

كما تم إخفاء إجراءات إضافة الصديق والمحادثة عن الملف الذاتي.

## 5. قاعدة البيانات وmigrations المهمة

المigrations التي أُنشئت أو عُدلت خلال العمل:

| Migration | الغرض |
|---|---|
| `20260922112000_create_community_backend.sql` | إنشاء جداول Community الأساسية وسياسات RLS وTriggers |
| `20260922113000_harden_community_rls_and_indexes.sql` | تقوية RLS وإضافة فهارس ودوال مساعدة |
| `20260922113500_harden_community_functions.sql` | تقوية وظائف Community والتحقق من الهوية والملكية |
| `20260922141000_fix_community_conversation_rls_recursion.sql` | إزالة recursion في سياسات المحادثات |
| `20260922150000_add_community_post_counters.sql` | تثبيت عدادات الإعجاب والتعليقات |
| `20260922150500_fix_community_rls_function_grants.sql` | تصحيح صلاحيات دوال RLS للمحادثات |

الجداول الرئيسية:

- `community_profiles`
- `community_posts`
- `community_post_media`
- `community_comments`
- `community_post_likes`
- `community_friend_requests`
- `community_friendships`
- `community_notifications`
- `community_conversations`
- `community_conversation_members`
- `community_messages`
- `community_message_reads`

## 6. Edge Functions

الوظيفة الأساسية:

```text
community-write
```

تم نشرها عدة مرات أثناء الإصلاح، وآخر نسخة معلنة في Supabase هي **version 9**.

المسارات الرئيسية الموجودة في النسخة الإنتاجية الأخيرة:

- `ensure_profile`
- `list_friends`
- `list_notifications`
- `list_friend_requests`
- `friend_status`
- `send_friend_request`
- `respond_friend_request`
- `create_post`
- `create_comment`
- `toggle_like`
- `update_profile`
- `open_conversation`
- `send_message` مع النص أو `media_reference`
- `delete_comment`
- `delete_post`

> عند تعديل `community-write` يجب نشر الوظيفة مرة أخرى. تعديل الملف المحلي وحده لا يغير الوظيفة المنشورة على Supabase.

## 7. Commits المهمة

| Commit | الوصف |
|---|---|
| `333213c` | إصلاح import الخاص بـ Provider لملف المستخدم |
| `b6039cd` | تدقيق التفاعلات والملفات وطلبات الصداقة |
| `81e1963` | إصلاح ظهور المنشورات والملفات والتعليقات بين المستخدمين |
| `34b6689` | إصلاح nullable في ترقية صلاحية صورة Appwrite |
| `a6b3335` | إصلاح التواصل بين المستخدمين والهوية والحذف |
| `2b47397` | إضافة صور المحادثات والتخزين المؤقت والحذف المملوك |
| `2c111c5` | إظهار حذف المنشورات الشخصية في Feed |
| `87ee3b7` | إصلاح أقواس قائمة المنشور وProfileHeader |

المستودع نظيف حاليًا:

```text
## main...origin/main
```

## 8. نتائج التحقق

آخر تحقق ناجح:

- **Android Build and Verify:** run `35724203708`
- **Function Quality:** run `35724203711`
- Flutter Analyze: ناجح.
- Flutter Tests: ناجح.
- Android universal release APK: ناجح.
- رفع APK artifact: ناجح.
- فحوصات Edge Functions: ناجحة.
- فحص عدم وجود مفاتيح B2 داخل المستودع: ناجح.

كان هناك فشل سابق بسبب أقواس ناقصة في:

- `community_widgets.dart`
- `community_social_screens.dart`

تم إصلاحها في `87ee3b7`، ثم نجح التحليل والاختبارات وبناء APK.

## 9. الأشياء التي يجب إكمالها لاحقًا

### أولوية عالية

1. **إعادة اختبار حسابين حقيقيين على APK الأخير**:
   - حساب A يرسل طلب صداقة إلى حساب B.
   - حساب B يفتح الإشعارات ويقبل الطلب.
   - التأكد من ظهور الصديق في الشريط العلوي للحسابين.
   - فتح ملف المستخدم الآخر والتأكد من البيانات والصورة والمنشورات.

2. **اختبار المحادثة فعليًا**:
   - فتح محادثة من ملف مستخدم آخر.
   - إرسال نص من الحساب A إلى B.
   - إرسال صورة من A إلى B.
   - التأكد من ظهور الصورة عند الطرفين وعدم اعتمادها على جلسة المرسل فقط.

3. **مراجعة تطابق النسخة المنشورة مع المصدر المحلي**:
   - يجب التأكد أن `community-write` المنشورة تحتوي جميع المسارات الموجودة في `supabase/functions/community-write/index.ts`.
   - بعد أي نشر مختصر أو يدوي يجب تشغيل اختبار smoke لكل action.

4. **إكمال تنظيف وسائط المنشور عند الحذف**:
   - الحذف الحالي Soft Delete للمنشور.
   - يجب لاحقًا استدعاء حذف ملف B2 وحذف metadata أو وضعها في دورة تنظيف حتى لا تبقى ملفات يتيمة.

### أولوية متوسطة

5. **الردود المتداخلة على التعليقات**:
   - إضافة `parent_comment_id` إلى `community_comments`.
   - تعديل `CommunityComment` ليحمل `parentCommentId`.
   - إضافة مسار `create_comment` يقبل parent.
   - بناء Threaded Comments.
   - دعم السحب يمينًا ويسارًا للرد.
   - إظهار خط أو سهم يربط الرد بالتعليق الأصلي.
   - دعم مستويات رد متعددة مع حد منطقي للعمق.

6. **تحسين واجهة التعليقات**:
   - استخدام Bottom Sheet مخصص بدل Dialog في ملف المستخدم أيضًا.
   - إضافة placeholder أثناء التحميل.
   - زر حذف للتعليق الشخصي.
   - تحديث العداد فور إضافة أو حذف تعليق.
   - منع تكرار الطلب عند الضغط السريع على إرسال.

7. **Animations كاملة**:
   - Animation للقلب عند الإعجاب.
   - Animation لظهور المنشور الجديد.
   - Animation لإرسال طلب الصداقة وتغير الحالة.
   - Animation لقبول الطلب.
   - Animation لإرسال الرسائل والصور.
   - استخدام `AnimatedSwitcher` و`AnimatedSize` و`Hero` للصور عند الحاجة.

8. **تحسين أداء الملفات الشخصية**:
   - إضافة cache دائم للصور باستخدام `flutter_cache_manager` أو حل تخزين مناسب.
   - cache لبيانات Profile والمنشورات مع مدة صلاحية.
   - إلغاء الطلبات القديمة عند مغادرة الشاشة.
   - استخدام pagination لمنشورات الملف بدل تحميل 50 منشورًا دفعة واحدة.

9. **تحسين المحادثات**:
   - إضافة Realtime listener لرسائل الطرف الآخر.
   - تحديث read receipts فعليًا.
   - إضافة unread count حقيقي.
   - إضافة retry للرسائل الفاشلة.
   - ضغط الصور قبل رفعها.
   - استخدام bucket مخصص للمحادثات بدل إعادة استخدام bucket صور الحساب، إذا كانت سياسة المشروع تتطلب ذلك.

10. **تحسين الإشعارات**:
    - تعليم الإشعار كمقروء عند فتحه.
    - تحديث عداد الإشعارات في AppBar بدل النقطة الثابتة الحالية.
    - جلب صورة actor من Appwrite بشكل موحد.
    - التعامل مع `friend_request_accepted` كنوع مستقل بدل اعتباره إعجابًا.

### أولوية منخفضة

11. إضافة الإبلاغ عن المنشورات والتعليقات إلى Backend فعلي.
12. إضافة حظر المستخدمين.
13. إضافة تعديل المنشور والتعليق.
14. إضافة مشاركة داخلية مع مستخدم محدد بدل المشاركة الخارجية فقط.
15. إضافة اختبارات Integration بحسابين حقيقيين أو بيئة staging.
16. تحديث GitHub Actions من Node 20 إلى الإصدارات الجديدة عندما تصبح متطلبات المشروع جاهزة.
17. إضافة migration لسجل أحداث أو Audit Log للعمليات الحساسة.

## 10. ملاحظات تشغيل مهمة

- لا تستخدم Supabase Auth كبديل عن Appwrite في هوية Community الحالية.
- لا تثق في `user_id` القادم من Flutter للعمليات الحساسة؛ يجب اشتقاق الهوية من Appwrite JWT داخل Edge Function.
- لا تضع `SUPABASE_SERVICE_ROLE_KEY` أو مفاتيح B2 داخل Flutter أو Git.
- بعد تعديل TypeScript يجب فحص:

```bash
git diff --check
gh run list --branch main
```

- لا تعتمد على نجاح `flutter analyze` فقط؛ يجب انتظار `Run Flutter tests` و`Build one universal release APK`.
- عند فشل CI، استخدم:

```bash
gh run view <RUN_ID> --log-failed
```

- البناء المحلي قد لا يكون متاحًا في كل Sandbox؛ GitHub Actions هو المرجع النهائي للبناء في هذا المشروع.

## 11. طريقة متابعة العمل في Chat جديد

ابدأ بقراءة هذا الملف ثم نفذ الخطوات التالية:

1. افحص `git status` و`git log`.
2. اقرأ `community_repositories.dart` و`supabase_community_repositories.dart`.
3. اقرأ `community-write/index.ts` وmigrations الخاصة بالمحادثات والإشعارات.
4. تحقق من نسخة Edge Function المنشورة قبل تعديلها.
5. نفذ اختبارًا حقيقيًا بحسابين قبل إضافة ميزات جديدة.
6. أكمل أولًا Realtime للمحادثات، ثم Threaded Comments، ثم animations، ثم cache دائم.
7. لا تدفع أي commit قبل نجاح Flutter tests وAndroid Build.

## 12. الخلاصة

تم إصلاح الأساس الأكبر لنظام Community: ظهور المنشورات بين الحسابات، هوية Appwrite، صور المستخدمين، الصداقة، إنشاء المحادثات، الرسائل النصية والصورية، الإعجاب المتفائل، الحذف المملوك، والتخزين المؤقت للصور داخل الذاكرة. آخر نسخة من الكود موجودة على فرع `main`، وقد نجحت اختبارات Flutter وتحليل Dart وبناء APK.

العمل المتبقي الأساسي ليس إصلاحًا لنشر المنشورات أو هوية المستخدم، بل تطوير طبقات أعلى: الردود المتداخلة، السحب للرد، Realtime chat، cache دائم، animations الكاملة، تنظيف ملفات B2 عند الحذف، واختبارات حقيقية بين حسابين.
