# AniTV Community — Complete Handoff

> هذا الملف هو سجل تسليم كامل للعمل المنفذ على مشروع AniTV حتى هذه اللحظة، مع فصل واضح بين ما تم تنفيذه والتحقق منه فعليًا، وما لم يتم التحقق منه، وما يجب إكماله في المحادثة التالية.

## 1. معلومات المشروع الحالية

| العنصر | القيمة |
|---|---|
| Repository | `anitv-official/Ani-TV` |
| Branch | `main` |
| Local path | `/home/ubuntu/Ani-TV` |
| Current HEAD | `39d62d5e94bc352e806f6df2a3565e7e83c17773` |
| Current remote state | `main` مطابق لـ `origin/main`، working tree نظيف وقت إنشاء هذا الملف |
| App type | Flutter/Dart Android application |
| Existing authentication | Appwrite، مع Google/Facebook/Email/Password/Username flows |
| Existing backend | Supabase PostgreSQL/Realtime + existing notification infrastructure |
| Media backend | Backblaze B2 عبر S3-compatible API، من خلال Supabase Edge Functions |
| Package/application/signing | لم يتم تغيير package name أو applicationId أو signing configuration أو keystore أو SHA values |

لم يتم وضع أي B2 Application Key أو Supabase service-role key داخل Flutter أو GitHub repository أو هذا الملف. أسماء الأسرار فقط مستخدمة داخل Edge Functions.

## 2. طلب المستخدم الأصلي وقواعد التنفيذ

المطلوب كان تحويل Community من واجهة Mock إلى نظام حقيقي مرتبط بـ Supabase وBackblaze B2، مع الحفاظ على Appwrite كجهة المصادقة وعدم كسر أي نظام موجود.

القواعد الرئيسية التي تم اتباعها:

1. فحص بنية المشروع وCommunity وAppwrite وSupabase والإشعارات قبل التعديل.
2. عدم تغيير Appwrite Authentication أو Google/Facebook/Email/Password/Username login.
3. عدم تغيير package name أو applicationId أو Android signing.
4. عدم استخدام Supabase Storage للملفات.
5. عدم وضع B2 credentials في Flutter أو GitHub أو قاعدة البيانات.
6. عدم حذف notification infrastructure أو history أو deduplication أو retry behavior.
7. استخدام B2 للصور والصوت فقط، وحفظ metadata في Supabase.
8. عدم الثقة في `userId` القادم من Flutter وحده.
9. عدم تعطيل الأمن أو إنشاء fake success response.
10. عدم إعلان نجاح الاختبارات الحية التي لم تُنفذ فعليًا.

## 3. المعلومات الخارجية الصحيحة المستخدمة

تم استخدام معلومات B2 التي كانت موجودة في specification المرسل من المستخدم:

| العنصر | القيمة |
|---|---|
| Bucket name | `anitv-community-media` |
| Bucket ID | `ef6d616138bace82a30b091d` |
| S3 endpoint | `https://s3.eu-central-003.backblazeb2.com` |
| Region | `eu-central-003` |
| Secret names | `B2_KEY_ID`, `B2_APPLICATION_KEY`, `B2_BUCKET_NAME`, `B2_S3_ENDPOINT`, `B2_REGION` |
| Secret values | موجودة مسبقًا في Supabase Edge Function Secrets، ولم تتم قراءتها أو طلبها أو كتابتها في المشروع |

تم استخدام معلومات Appwrite العامة الموجودة أصلًا في التطبيق:

| العنصر | القيمة |
|---|---|
| Appwrite endpoint | `https://nyc.cloud.appwrite.io/v1` |
| Appwrite project ID | `6aa4295900094d600163` |

تم استخدام Supabase project المتصل أصلًا بالمشروع:

| العنصر | القيمة |
|---|---|
| Supabase project ref | `wmzeydetzfndkpgqwfjd` |
| Supabase public URL | `https://wmzeydetzfndkpgqwfjd.supabase.co` |
| Client key | Publishable/anon client key فقط داخل إعداد Flutter العام؛ لم يستخدم service-role key في Flutter |

## 4. التسلسل الزمني للتنفيذ

### 4.1 الفحص الأولي

تم clone المشروع من GitHub وفحص:

- `lib/main.dart` وbootstrap وproviders.
- `lib/screens/home_screen.dart` وnavigation.
- Community screens/services/models القديمة.
- Appwrite service وcurrent-user behavior.
- Supabase migration history وnotification infrastructure.
- Android configuration وCI workflows.
- جميع Dart files ومصادر الأنمي الحالية.

تم التأكد أن المشروع Flutter وأن Community كان مبنيًا جزئيًا على Mock repository، مع وجود Appwrite auth وتكامل Supabase سابق للإشعارات.

### 4.2 Phase 1 — Community feed والـcomposer

Commit:

- `2033d51 feat(community): add community feed and post composer`

تم إنشاء/تطوير:

- Community models للـposts والـmedia والـcomments والـnotifications.
- Repository interfaces.
- Mock repository واقعي للاختبارات والـUI.
- Feed provider مع loading/search/publish/like/comment state.
- Community widgets للـauthor/media/audio/empty states.
- Community screen مع composer وprofile strip.
- إضافة Community إلى navigation drawer و`AppSection`.
- Unit tests للـpagination/search/publish/likes/comments.

### 4.3 Phase 2 — Profiles/friends/private chat

Commits:

- `109b93a feat(community): add profiles friends and private chat UI`
- `74fc4a5 feat(community): complete community UI architecture`

تم إنشاء/تطوير:

- Community profiles وfavorites وfriend requests.
- Friend status transitions.
- Conversations/messages/message status.
- Public profile screen.
- Messages list screen.
- Private conversation screen.
- Keyboard-safe message composer.
- Mock profile/friend/chat repositories.
- Tests للـprofiles/friends/conversations/message sending.

### 4.4 Phase 3 — notifications/verification/share

Commit:

- `6ca4540 docs(community): add implementation summary`

تم إضافة/توصيل:

- Verification status models/repository.
- Share receipt abstractions.
- Community notification screen.
- Localized notification/empty-state strings.
- Notification route من Community top bar.
- Tests للـverification/share/notifications.

### 4.5 Supabase Community backend

Commit:

- `3a43a08 feat(community): connect community backend to supabase`

تم إنشاء وتطبيق migrations في Supabase:

1. `supabase/migrations/20260922112000_create_community_backend.sql`
2. `supabase/migrations/20260922113000_harden_community_rls_and_indexes.sql`
3. `supabase/migrations/20260922113500_harden_community_functions.sql`

مع الحفاظ على migration الإشعارات:

- `supabase/migrations/20260918042700_create_notification_infrastructure.sql`

الجداول الرئيسية:

- `community_profiles`
- `community_profile_favorites`
- `community_posts`
- `community_post_media`
- `community_comments`
- `community_post_likes`
- `community_friend_requests`
- `community_friendships`
- `community_conversations`
- `community_conversation_members`
- `community_messages`
- `community_message_reads`
- `community_notifications`

تمت إضافة constraints/indexes وRLS وupdated-at triggers وRealtime-related schema حسب المigrations السابقة.

تمت مراجعة advisors الخاصة بـ Supabase خلال مراحل التنفيذ، مع إضافة hardening للـfunctions والـindexes وRLS.

### 4.6 B2 media integration

Commit الرئيسي:

- `77f07eb feat: complete community backend and b2 media integration`

إصلاح CI:

- `39d62d5 fix: type community media signing helper`

تم تنفيذ AWS Signature Version 4 يدويًا بطريقة متوافقة مع Deno/Supabase Edge Functions بدل إضافة SDK غير ضروري.

Upload architecture:

1. Flutter يتحقق مبدئيًا من وجود الملف.
2. Flutter يرسل metadata إلى `community-media-upload`.
3. Edge Function تتحقق من Appwrite JWT ومن post ownership.
4. Edge Function تتحقق من MIME وsize وتنشئ random object key.
5. Edge Function تحفظ metadata بحالة `pending` في Supabase.
6. Edge Function تعيد presigned PUT URL قصيرة العمر.
7. Flutter يرفع bytes إلى B2 مع Content-Type مطابق للتوقيع.
8. Flutter يستدعي `community-media-complete`.
9. Edge Function تعمل signed HEAD على B2 وتتحقق من الحجم.
10. تتحول metadata إلى `backblaze_b2` وحالة `ready`.
11. Flutter يستخدم presigned GET URL قصيرة العمر لعرض الملف.

حدود الملفات في Edge Function:

- Image: حتى 10 MiB.
- Audio: حتى 15 MiB.
- MIME محصور في image/jpeg/png/webp/gif وaudio/mpeg/mp4/aac/ogg/wav/webm/x-m4a.

### 4.7 Production default وaudio playback

تم تغيير production Community mode ليكون Supabase افتراضيًا:

```text
COMMUNITY_DATA_SOURCE=supabase
```

وللاختبارات/offline Mock يجب استخدام define صريح:

```text
--dart-define=COMMUNITY_DATA_SOURCE=mock
```

تمت إضافة `just_audio` وتشغيل audio media عبر secure URL أو local file. الصور غير المحلية لا تتعامل مع `storage_key` كأنه local file؛ بل تطلب private URL من Edge Function.

## 5. الملفات المهمة الحالية

### Flutter Community

- `lib/community/models/community_models.dart`
- `lib/community/repositories/community_repositories.dart`
- `lib/community/repositories/supabase_community_repositories.dart`
- `lib/community/mock/mock_community_repository.dart`
- `lib/community/services/appwrite_community_identity.dart`
- `lib/community/services/community_backend_config.dart`
- `lib/community/services/community_media_api.dart`
- `lib/community/services/community_media_storage.dart`
- `lib/community/services/community_repository_factory.dart`
- `lib/community/state/community_feed_provider.dart`
- `lib/community/widgets/community_widgets.dart`

### Appwrite/Auth integration

- `lib/services/appwrite_service.dart`

تمت إضافة `createCommunityJwt()` فقط، ولم تتغير login flows.

### Edge Functions

- `supabase/functions/_shared/community_media.ts`
- `supabase/functions/community-media-upload/index.ts`
- `supabase/functions/community-media-complete/index.ts`
- `supabase/functions/community-media-url/index.ts`
- `supabase/functions/community-media-delete/index.ts`
- `supabase/functions/deno.json`

### Tests

- `test/community_phase1_test.dart`
- `test/community_phase2_test.dart`
- `test/community_phase3_test.dart`
- `test/community_backend_test.dart`

### Documentation

- `COMMUNITY_IMPLEMENTATION_SUMMARY.md`
- `COMMUNITY_BACKEND_IMPLEMENTATION.md`
- `COMMUNITY_BACKBLAZE_SETUP.md`
- `COMMUNITY_IMPLEMENTATION_REPORT.md`
- هذا الملف: `COMMUNITY_HANDOFF.md`

### CI

- `.github/workflows/function-quality.yml`
- Android Build workflow الموجود أصلًا في repository.

## 6. Edge Functions المنشورة فعليًا

تم التحقق عبر Supabase MCP أن الوظائف التالية `ACTIVE` في project `wmzeydetzfndkpgqwfjd`:

| Function | Status | JWT setting | Purpose |
|---|---|---|---|
| `community-media-upload` | ACTIVE | `verify_jwt=false` | Custom Appwrite JWT validation ثم pending metadata + presigned PUT |
| `community-media-complete` | ACTIVE | `verify_jwt=false` | Signed HEAD ثم promotion إلى ready/backblaze_b2 |
| `community-media-url` | ACTIVE | `verify_jwt=false` | Custom Appwrite JWT validation ثم private GET URL |
| `community-media-delete` | ACTIVE | `verify_jwt=false` | Ownership check ثم B2 DELETE ثم metadata DELETE |

سبب `verify_jwt=false`: Supabase JWT verification لا يعرف Appwrite session، لذلك الوظائف تستخدم custom Appwrite JWT validation بنفسها. هذا ليس تعطيلًا للأمن؛ الوظائف ترفض الطلب دون Appwrite JWT بـ401.

اختبار endpoints الذي تم فعليًا:

- `OPTIONS` لكل function: HTTP 204.
- `POST` بدون JWT لكل function: HTTP 401 مع JSON آمن.

## 7. Identity bridge الحالي

`AppwriteService.createCommunityJwt()` يستدعي `account.createJWT()` من الجلسة الحالية.

`CommunityMediaApi` يرسل:

```http
X-Appwrite-JWT: <short-lived Appwrite JWT>
```

Edge Function ترسل الـJWT إلى:

```text
https://nyc.cloud.appwrite.io/v1/account
```

ثم تستخرج `$id` من استجابة Appwrite، ولا تستخدم user ID المرسل في body كهوية.

هذه الهوية مطبقة فعليًا في media functions.

## 8. الاختبارات التي نجحت فعليًا

| الاختبار | النتيجة | التفاصيل |
|---|---|---|
| Flutter tests محليًا | PASS | 31 tests passed |
| GitHub Android Analyze and test | PASS | Run `35710496489`، commit `39d62d5` |
| GitHub Android APK build | PASS | Universal release APK built and uploaded، run `35710496489` |
| GitHub Function Quality بعد الإصلاح | PASS | Run `35710496417`، commit `39d62d5` |
| Deno checks | PASS | جميع Community media functions checked في CI |
| Edge Function deployment | PASS | الوظائف الأربع ACTIVE |
| Edge OPTIONS smoke test | PASS | الأربع أعادت 204 |
| Edge unauthenticated smoke test | PASS | الأربع أعادت 401 |
| Secret scan | PASS | لا توجد قيم B2/service-role في source |
| Android signing preservation | PASS | CI استخدم signing configuration protected existing في workflow ولم يتم تغييرها |
| Working tree | CLEAN | `main` مطابق لـ`origin/main` بعد آخر commit |

## 9. ما لم يتم اختباره فعليًا

لم يتم تنفيذ اختبار authenticated end-to-end بحساب Appwrite حقيقي، ولذلك لا يجب الادعاء بأن النتائج التالية نجحت:

1. Login حقيقي من واجهة AniTV.
2. فتح Community بجلسة حقيقية.
3. تحميل profile حقيقي.
4. إنشاء text post على Supabase production.
5. إنشاء image post حقيقي.
6. وصول image bytes إلى B2.
7. حفظ metadata الحقيقي بعد upload.
8. ظهور image عبر private URL لمستخدم مصادق.
9. Like حقيقي.
10. Comment حقيقي.
11. Friend request حقيقي.
12. Profile navigation حقيقي مع بيانات production.
13. Conversation حقيقية.
14. إرسال message حقيقي.
15. وصول Realtime event حقيقي.
16. Notification production event.
17. حذف post production.
18. حذف B2 object والتأكد من cleanup.
19. محاولة مستخدم آخر الوصول إلى private conversation.
20. اختبار retry/orphan cleanup عند فشل جزء من العملية.

السبب: هذه الخطوات تحتاج جلسة Appwrite حقيقية ومستخدمًا/مستخدمين فعليين وملف media حقيقي. لم يتم طلب credentials أو التحايل على auth.

## 10. النقص التقني الأهم قبل إعلان Community مكتملًا

### 10.1 الكتابات الأخرى لا تستخدم نفس Edge identity bridge بالكامل

في `lib/community/repositories/supabase_community_repositories.dart` ما زالت بعض العمليات تكتب مباشرة إلى Supabase بعد استدعاء:

```dart
final userId = await requireUser();
```

ثم تستخدم هذا الـID في insert/update.

المسارات المتأثرة تشمل:

- `SupabasePostRepository.create`
- `SupabaseCommentRepository.create`
- `SupabaseLikeRepository.toggle`
- `SupabaseFriendRepository.sendRequest`
- `SupabaseProfileRepository.updateBio`
- `SupabaseChatRepository.sendMessage`
- بعض عمليات conversation/friend state
- notification-related writes إذا كانت موجودة في repository الحالي

المشكلة: الحصول على Appwrite user ID في Flutter وحده لا يجعل Supabase JWT يحتوي على claim `appwrite_user_id`. وسياسات RLS تعتمد على `community_current_user_id()` المبني على claim موثوق. لذلك قد ترفض Supabase هذه direct writes أو لا تكون identity boundary متسقة.

الحل الموصى به:

1. إنشاء Edge Functions للعمليات الحساسة، مثل:
   - `community-post-create`
   - `community-comment-create`
   - `community-like-toggle`
   - `community-friend-request`
   - `community-message-send`
   - `community-profile-update`
2. كل function تتحقق من Appwrite JWT بنفس media functions.
3. كل function ترفض user ID من client كهوية.
4. كل function تستخدم service-role داخليًا فقط بعد authorization.
5. أو تنفيذ Appwrite-to-Supabase trusted JWT bridge موحد، ثم إعادة direct writes لاستخدام JWT claim فعلي.
6. يجب اختيار طريقة واحدة وتطبيقها على كل write path، لا ترك نظام مختلط غير موثق.

الأفضل والأوضح للمشروع الحالي هو Edge Functions للـwrites الحساسة، مع إبقاء direct reads وRealtime تحت Supabase client/RLS عند ملاءمتها.

### 10.2 Post deletion cleanup

Media delete function موجودة وتعمل على media ID، لكن يجب ربط حذف الـPost نفسه بحيث:

- يتم تحديد owner من Appwrite JWT.
- يتم جمع media metadata المرتبطة بالpost.
- يتم حذف B2 objects بأمان.
- يتم حذف أو soft-delete post حسب سياسة المشروع.
- يتم الاحتفاظ بـcleanup retry metadata إذا فشل B2.
- لا يتم حذف metadata بصمت قبل نجاح storage cleanup أو تسجيل orphan cleanup state.

### 10.3 Realtime end-to-end

Repository-level Realtime abstractions موجودة من backend iteration السابقة، لكن يجب اختبار:

- message insert event.
- notification event.
- like/comment event إذا كان مطلوبًا.
- إلغاء الاشتراك عند dispose.
- عدم تسريب channel إلى conversation غير مصرح بها.

### 10.4 UI verification

يجب فتح Community على emulator/device ومراجعة:

- overflow وclipping.
- feed infinite scroll.
- pull-to-refresh.
- loading أكثر من مرة وعدم duplicate posts.
- empty/error/retry states.
- composer مع keyboard وbottom sheet.
- image loading عبر signed URL.
- audio loading/play/pause/error.
- link opening الآمن.
- profile strip وplus button.
- messages/conversation keyboard behavior.
- notifications button.
- dark theme consistency.
- Arabic labels والنصوص.
- عدم ظهور storage keys أو backend errors للمستخدم.

### 10.5 Flutter analyzer

GitHub Android workflow نجح في Analyze and test. محليًا توجد diagnostics قديمة كثيرة في المشروع، أغلبها info/warnings، لكن لا توجد compile errors في الملفات الجديدة بعد الإصلاح. يجب عدم تحويل كل legacy warnings إلى blocking ما لم يقرر maintainers ذلك.

## 11. خطة الإكمال المقترحة للمحادثة التالية

### Step A — تثبيت identity write architecture

- مراجعة كل `Supabase...Repository` methods التي تنفذ insert/update/delete.
- إنشاء shared Edge Function identity helper أو نقل كل writes الحساسة إلى functions.
- عدم إرسال user ID كـauthority من Flutter.
- إضافة tests لكل function لغياب JWT وuser mismatch وownership failure.

### Step B — إضافة Edge Functions للـCommunity writes

لكل function:

- Appwrite JWT authentication.
- input validation.
- authorization check.
- safe error mapping.
- no secret in response/logs.
- idempotency/unique constraint handling.
- deploy إلى Supabase.
- add Deno check إلى CI.

### Step C — ربط Flutter repositories

استبدال direct writes بالـEdge Function API clients، مع الحفاظ على نفس repository interfaces حتى لا تتغير الشاشات غير الضرورية.

### Step D — post/media transaction cleanup

- إنشاء post + media lifecycle واضح.
- pending metadata timeout/orphan cleanup.
- delete post cleanup.
- retryable storage failure state.
- test object/metadata mismatch.

### Step E — authenticated E2E

بجلسة Appwrite حقيقية:

1. login.
2. open Community.
3. create text post.
4. create image post.
5. upload to B2.
6. verify metadata.
7. render image.
8. like/comment.
9. friend request.
10. private conversation.
11. message.
12. Realtime event.
13. notification.
14. delete post.
15. verify B2 cleanup.
16. use second user to test private conversation denial.
17. verify no B2 secret appears in app/logs/network responses.

يجب تسجيل نتيجة كل خطوة، لا كتابة PASS قبل تنفيذها.

### Step F — UI and device verification

- تشغيل APK الناتج من artifact.
- فتح Community على جهاز/محاكي.
- تسجيل نتائج overflow/loading/navigation/audio/image.
- إصلاح أي UI issue ثم إعادة GitHub build.

### Step G — تحديث التقرير

بعد إكمال الخطوات:

- تحديث `COMMUNITY_IMPLEMENTATION_REPORT.md`.
- تحديث هذا الملف إذا تغيرت architecture أو commit.
- إضافة run IDs النهائية.
- فصل PASS عن NOT RUN بدقة.
- commit واضح ثم push.

## 12. أوامر مفيدة للمتابعة

```bash
cd /home/ubuntu/Ani-TV

git status --short --branch
git log --oneline --decorate -12

export PATH=/home/ubuntu/flutter/bin:/home/ubuntu/flutter/bin/cache/dart-sdk/bin:$PATH
flutter test --reporter expanded
flutter analyze --no-fatal-infos --no-fatal-warnings

gh run list --branch main --limit 10
```

فحص functions عبر Supabase MCP:

- `list_edge_functions(project_id=wmzeydetzfndkpgqwfjd)`
- `get_advisors(project_id=wmzeydetzfndkpgqwfjd)`
- `list_tables(project_id=wmzeydetzfndkpgqwfjd, schema=public)`
- `list_migrations(project_id=wmzeydetzfndkpgqwfjd)`

Smoke test الحالي:

```bash
BASE='https://wmzeydetzfndkpgqwfjd.supabase.co/functions/v1'
curl -i -X OPTIONS "$BASE/community-media-upload"
curl -i -X POST "$BASE/community-media-upload" \
  -H 'Content-Type: application/json' \
  --data '{}'
```

المتوقع بدون Appwrite JWT:

- OPTIONS: `204`
- POST: `401`

## 13. الملفات المرجعية للتسليم

- التقرير التفصيلي السابق: [`COMMUNITY_IMPLEMENTATION_REPORT.md`](COMMUNITY_IMPLEMENTATION_REPORT.md)
- هذا التسليم الشامل: [`COMMUNITY_HANDOFF.md`](COMMUNITY_HANDOFF.md)
- توثيق backend: [`COMMUNITY_BACKEND_IMPLEMENTATION.md`](COMMUNITY_BACKEND_IMPLEMENTATION.md)
- إعداد B2 اليدوي: [`COMMUNITY_BACKBLAZE_SETUP.md`](COMMUNITY_BACKBLAZE_SETUP.md)

## 14. خلاصة نهائية صريحة

تم تنفيذ وفحص بنية Community، مراحل الواجهة، profiles/friends/chat/notifications، Supabase schema وRLS، B2 media API، Appwrite JWT validation، Flutter media upload/playback، keyset pagination، CI Deno checks، والـAndroid build.

الاختبارات الآلية والـCI ناجحة، والـEdge Functions منشورة ونشطة. لكن اكتمال Community الوظيفي النهائي يحتاج توحيد identity bridge لكل عمليات الكتابة غير المتعلقة بالوسائط، ثم اختبار authenticated end-to-end بمستخدمين فعليين ومراجعة UI على جهاز. لا ينبغي اعتبار ذلك مكتملًا قبل تنفيذ هاتين المرحلتين وتسجيل نتائجهما.
