# AniTV Notifications Function

Function مستقلة لإرسال Push Notifications عبر **Appwrite Messaging → FCM**. لا تعدّل Function تسجيل الدخول/حذف الحساب الحالية.

## Runtime and entrypoint

- Runtime: **Node.js 22**
- Entrypoint: `src/main.js` (with root `index.js` retained for compatibility)
- Package manager: `npm install`
- Execute access: يمكن جعله `Any` لأن التحقق من هوية المستخدم والصلاحيات يتم داخل Function. لا تترك `ANITV_ADMIN_USER_IDS` فارغًا إذا كان Broadcast مطلوبًا.

## Environment variables داخل Appwrite Function

| Variable | Required | Description |
|---|---:|---|
| `APPWRITE_ENDPOINT` | Yes | نفس Endpoint المشروع الحالي، مثل `https://nyc.cloud.appwrite.io/v1` |
| `APPWRITE_PROJECT_ID` | Yes | Project ID الخاص بـAppwrite، وليس Firebase Project ID |
| `APPWRITE_FUNCTION_API_KEY` | Automatically provided | Dynamic API key supplied by Appwrite for each Function execution; do not create or store it manually |
| `ANITV_ADMIN_USER_IDS` | Yes for broadcast | قائمة Appwrite User IDs للمشرفين مفصولة بفواصل |
| `ANITV_BROADCAST_TOPIC_ID` | Yes for broadcast | Topic ID الفعلي الذي أنشأته في Appwrite Messaging |
| `SUPABASE_URL` | Yes for history/deduplication | Project URL لمشروع AniTV في Supabase |
| `SUPABASE_SERVICE_ROLE_KEY` | Yes for history/deduplication | مفتاح Service Role داخل Function فقط؛ لا تضعه في Flutter أو Git |

يظل Appwrite هو مصدر Authentication وFavorites وPush Targets وFCM delivery في هذه المرحلة، بينما Supabase يدير Notification History وDeduplication وScan summaries. لا تضع أي قيمة سرية في Git أو Flutter. Appwrite يمرر Dynamic API Key تلقائيًا عبر `APPWRITE_FUNCTION_API_KEY` و`x-appwrite-key`. لا تسجل المفتاح أو FCM token أو محتوى بيانات حساس.

## أقل صلاحيات API key

امنح المفتاح صلاحيات `rows.read` و`rows.write` لقراءة وتحديث Favorites، و`messages.write` لإرسال Push، مع `targets.read` و`topics.read` كما هو مضبوط في المشروع.

## Request body

### Health check (safe, no notification sent)

For an Appwrite Console smoke test, use **POST** with this JSON body:

```json
{ "type": "health" }
```

It returns HTTP `200` and only confirms that the deployment entrypoint loaded. It does not bypass the authentication checks for real notification requests.

### Favorite scan (administrative)

Use **POST** with this body:

```json
{ "type": "favorite_scan", "dryRun": true }
```

Pass the secret only through this header; never place it in the body or logs:

```text
x-anitv-favorite-scan-secret: <value configured in Appwrite>
```

`dryRun: true` checks Favorites without sending Push notifications or changing scan state. The first real scan initializes `lastNotifiedEpisode` for supported items without sending historical notifications. The scan reads all rows with cursor pagination (100 rows per page), retries transient source/delivery failures once, and continues after an individual Favorite fails. The adapters currently support Anime4Up and FaselHD URL Favorites; unsupported sources are reported and do not stop the scan.

### مستخدم محدد

```json
{
  "type": "user",
  "userId": "APPWRITE_USER_ID",
  "title": "AniTV",
  "message": "لديك تحديث جديد",
  "data": {
    "type": "episode",
    "url": "https://example.invalid/anime/123"
  }
}
```

المستخدم العادي لا يستطيع الإرسال إلى مستخدم آخر؛ يمكنه الإرسال إلى نفسه فقط. المشرف الموجود في `ANITV_ADMIN_USER_IDS` يمكنه الإرسال لأي مستخدم.

### Broadcast

```json
{
  "type": "broadcast",
  "title": "AniTV",
  "message": "تمت إضافة محتوى جديد",
  "data": {
    "type": "broadcast",
    "url": "https://example.invalid/anime/123"
  }
}
```

Broadcast للمشرفين فقط، ويستخدم `ANITV_BROADCAST_TOPIC_ID` ولا يقبل Topic ID من الطلب.

## Appwrite Console setup

1. في **Messaging → Providers** أنشئ/فعّل FCM Android Provider باستخدام إعداد Firebase الرسمي. لا تضع Service Account JSON في المستودع.
2. أنشئ Topic عام، مثل الاسم `anitv_all`. احتفظ بالـTopic ID الناتج وضعه في `ANITV_BROADCAST_TOPIC_ID`.
3. اضبط صلاحية الاشتراك في Topic بحيث يسمح للمستخدمين المسجلين بالاشتراك.
4. أنشئ Function جديدة باسم `AniTV Notifications`، Runtime Node.js 22، ثم ارفع محتويات هذا المجلد.
5. أضف Environment Variables السابقة، وأنشئ Deployment جديدًا.
6. لا تغيّر Function الحالية `6aa5ed04000f66117651`.
7. من إعدادات Function نفسها اضبط **Schedule** واحدًا فقط لـ`favorite_scan` (مثل `0 */30 * * *`)، واستدعِها بالـsecret header. لا تنشئ Scheduler ثانيًا في Supabase أو جهاز العميل.
8. أضف `SUPABASE_URL` و`SUPABASE_SERVICE_ROLE_KEY` إلى متغيرات Function السرية. لا تستخدم Service Role Key في Flutter.

## Flutter build variables

يحتاج التطبيق إلى تمرير القيم غير السرية التالية عند البناء:

```bash
flutter build apk --release \
  --dart-define=ANITV_FCM_PROVIDER_ID=<APPWRITE_FCM_PROVIDER_ID> \
  --dart-define=ANITV_FCM_TOPIC_ID=<APPWRITE_TOPIC_ID>
```

لا تضع Provider ID أو Topic ID عشوائيين. يجب نسخهما من Appwrite Console بعد إنشائهما.

## Function deployment archive

من جذر المشروع:

```bash
cd appwrite-functions/anitv-notifications
npm install --omit=dev
cd ../..
tar -czf anitv-notifications-function.tar.gz \
  --exclude='*/node_modules/.cache' \
  appwrite-functions/anitv-notifications
```

استخدم الملف الناتج للرفع في Appwrite Console. يحتوي الأرشيف على `package.json` و`src/main.js` ونسخة توافقية من `index.js` ولا يحتوي أي Secret.
