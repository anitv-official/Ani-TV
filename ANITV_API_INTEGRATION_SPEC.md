# AniTV API Integration Specification

## Purpose

هذا الملف هو مواصفة تنفيذية لنقل مصادر البيانات وخدمات AniTV إلى تطبيق آخر. يجب على أي ذكاء اصطناعي أو مطور استخدام المسارات والقيم المذكورة هنا كما هي، وعدم اختراع endpoints بديلة. الكود الأصلي موجود في مستودع AniTV، وتُعد هذه الوثيقة وصفًا للعقود الموجودة في الكود وليست تصريحًا بأن كل مزود خارجي سيبقى متاحًا إلى الأبد.

> **قاعدة مهمة:** افصل بين `content source APIs` العامة وبين Appwrite. مصادر المحتوى تجلب الكتالوج والتفاصيل والروابط. Appwrite يدير الحسابات والمفضلة والخدمات السحابية. لا تضع مفاتيح Service Role أو مفاتيح Appwrite الإدارية داخل تطبيق الهاتف.

## 1. Source registry

المصادر المسجلة فعليًا في التطبيق هي:

| ID | الاسم | النوع | القدرات | صيغة الرابط الداخلي |
|---|---|---|---|---|
| `anime_slayer` | Anime Slayer | Anime | latest, search, details, streams | `https://anslayer.com/anime-details?anime_id={id}` للحالة، و`https://anslayer.com/episode-reference?anime_id={animeId}&episode_id={episodeId}` للحلقة |
| `animefy` | Animefy | Anime | latest, search, details, episodes, streams | `animefy://anime?id={id}` و`animefy://episode?anime={animeId}&episode={episodeId}` |
| `drama_slayer` | Drama | Drama | latest, search, details, episodes, streams | `https://drslayer.com/drama/public//drama-details?drama_id={id}` و`https://drslayer.com/drama/public//episode-reference?episode_id={id}` |
| `swat` | Manga Swat | Manga | latest, search, details, chapters, chapter images | `swat://series/{id}/{slug}` و`swat://chapter/{id}` |
| `mangatime` | MangaTime | Manga | latest, search, details, chapters, chapter images | `mangatime://series?slug={slug}` و`mangatime://chapter?id={chapterId}&number={number}` |
| `manga_mello` | MangaMello | Manga | latest, search, details, chapters, chapter images | `mellomello://manga/{id}` و`mellomello://chapter/{mangaId}/{chapterId}` |
| `fasel_hd` | FaselHD | Movie/Series | latest movies, latest series, search, details, episodes, streams | `{apiBase}movie/{id}/0`, `{apiBase}series/{id}/0`, `{apiBase}episode/{id}/0` |

طبقة `SourceRegistry` تدمج نتائج المصادر، تعيد المحاولة ثلاث مرات بمهلة 35 ثانية، وتخزن أحدث النتائج ثلاث دقائق. يجب أن يفشل مصدر واحد بدون إخفاء نتائج المصادر الأخرى.

## 2. Anime Slayer API

### Base URL and headers

```text
Base: https://anslayer.com/anime/public/
Client-Id: android-app2
Client-Secret: 7befba6263cc14c90d2f1d6da2c5cf9b251bfbbd
Accept: application/json
User-Agent: okhttp/3.12.12
```

القيمة المسماة `Client-Secret` مضمنة في العميل الحالي. تعامل معها كبيان قابل للتغيير ولا تعرضها في logs. إذا كان التطبيق الجديد يملك backend، ضعها في backend بدل APK.

### Latest and search

```http
GET https://anslayer.com/anime/public/animes/get-published-animes?json={URL_ENCODED_JSON}
```

للبحث:

```json
{
  "list_type": "anime_list",
  "anime_name": "QUERY",
  "_offset": 0,
  "_limit": 30
}
```

لأحدث الحلقات:

```json
{
  "list_type": "latest_episodes",
  "_offset": 0,
  "_limit": 30
}
```

الاستجابة المتوقعة تكون داخل `response.data` أو `data`. أهم الحقول: `anime_id`, `anime_name`, `anime_english_title`, `anime_description`, `anime_cover_image_url`, `anime_banner_image_url`, `anime_genres`, `anime_rating`, `anime_status`, `anime_release_year`.

### Details

```http
GET https://anslayer.com/anime/public/anime/get-anime-details?anime_id={id}&fetch_episodes=Yes&more_info=Yes
```

الحلقات قد توجد في `response.anime.episodes.data` أو `response.anime.episodes`. الحلقة تستخدم `episode_id`, `episode_number`, `episode_name`, و`episode_urls`.

### Episode streams

```http
POST https://anslayer.com/anime/public/episodes/get-episodes-new
Content-Type: application/x-www-form-urlencoded

json={"anime_id":123,"episode_ids":[456],"limit":1}
```

كل عنصر في `episode_urls` يحتوي عادة على `episode_server_name` و`episode_url`. إذا كان اسم الخادم `cdn` يستخدم التطبيق مسار CDN المشفر. إذا كان `muilt` يحاول قراءة JSON من الرابط نفسه أو من نفس host. لا تحذف `Referer: https://anslayer.com/` عند تشغيل روابط تحتاجه.

### CDN resolution

```http
GET https://anslayer.com/anime/public/google.php
POST {episode_url path with /vq.php replaced by /v-qs.php}
Content-Type: application/x-www-form-urlencoded

f={source query f}&e={source query e}&inf={encrypted JSON}
```

الـ`inf` يبنى من:

```json
{"uhy":"com.anslayer","dma":47,"mvd":"1.5.10","vko":"44D8B79265DDBB9C887320F64521A76D72F6D7D4"}
```

هذا المسار يستخدم AES/RNCryptor في التطبيق الحالي. لا تعِد تنفيذ فك التشفير في الواجهة إذا أمكن وضعه في backend.

## 3. Animefy API

### Base URL and headers

```text
Base: https://animeify.net/animeify/apis_v4
Thumbnail base: https://animeify.net/animeify/files/thumbnails/
Method: POST
User-Agent: AniTV/1.0 (Android)
Referer: https://animeify.net/
Content-Type: application/x-www-form-urlencoded; charset=UTF-8
```

### Catalog and search

```http
POST https://animeify.net/animeify/apis_v4/anime/load_anime_list_v2.php
```

Form fields للبحث:

```text
FilterType=Search
FilterData=
AnimeListMode=NAME
SearchText={query}
```

Form fields للكتالوج:

```text
FilterType=
FilterData=
AnimeListMode=NAME
SearchText=
```

التطبيق يجلب الكتالوج الكامل ثم يقسمه محليًا إلى صفحات من 50 عنصرًا.

### Details and episodes

```http
POST https://animeify.net/animeify/apis_v4/anime/load_anime_details.php
AnimeID={id}

POST https://animeify.net/animeify/apis_v4/episodes/load_episodes.php
AnimeID={id}
```

### Streams

```http
POST https://animeify.net/animeify/apis_v4/anime/load_servers.php
AnimeID={animeId}
Episode={episodeId}
```

ابحث داخل الاستجابة عن المفاتيح: `server_a` إلى `server_g`, `server_hd`, `server_sd`, `server_fhd`, `WatchLink`, `StreamLink`, `DownloadLink`. نظف الروابط واحتفظ فقط بروابط HTTP/HTTPS.

## 4. Drama Slayer API

### Base URL and headers

```text
Base: https://drslayer.com/drama/public/
Client-Id: drama-android-app
Client-Secret: 7befba6263cc14c90d2f1d6da2c5cf9b251bfbbd
Accept: application/json
Accept-Language: ar,en;q=0.8
User-Agent: okhttp/3.12.12
```

قد تعيد بعض endpoints حقلًا مشفرًا باسم `result`. الاستجابة المشفرة تستخدم RNCryptor/AES، ولا ينبغي اعتبار النص المشفر JSON صالحًا قبل فكّه في backend.

### Search and latest

```http
GET https://drslayer.com/drama/public/drama-app-api/get-all-published-drama
```

Query parameters:

```text
json={URL_ENCODED_JSON}
offset=0
list_type=all أو latest_series
limit=30
```

جسم JSON:

```json
{"list_type":"latest_series","_offset":0,"_limit":30}
```

### Details and episodes

```http
GET https://drslayer.com/drama/public/drama-app-api/get-published-drama-info?drama_id={id}
POST https://drslayer.com/drama/public/drama-app-api/get-episodes-auth
Content-Type: application/x-www-form-urlencoded

inf={GET google.php result}&json={"drama_id":"{id}"}
```

Token seed:

```http
GET https://drslayer.com/drama/public/google.php
```

### Episode streams

```http
POST https://drslayer.com/drama/public/drama-app-api/get-episodes-auth
Content-Type: application/x-www-form-urlencoded

inf={GET google.php result}&json={"episode_id":"{episodeId}"}
```

استعمل `episode_urls[*].episode_server_name` و`episode_urls[*].episode_url`. لا تعرض HTML player pages على أنها ملفات فيديو مباشرة.

## 5. FaselHD API

### Dynamic API base

يجب أولًا جلب إعداد النطاق:

```http
GET https://abcdefegh.watchit.tn/api_urls.json
Accept: application/json
```

يبحث التطبيق عن `backupApiUrlNoureddine` ثم `backupApiUrlhadr`. إذا تعذر الإعداد يستخدم fallback التالي:

```text
https://kahitdgku.com/faselhd15/public/api/
```

User-Agent:

```text
okhttp/4.10.0
```

احتفظ بالـslash النهائي في `apiBase`.

### Catalog

```http
GET {apiBase}movies/latestadded/0?page={page}
GET {apiBase}series/latestadded/0?page={page}
GET {apiBase}search/{URL_ENCODED_QUERY}/0
GET {apiBase}media/homecontent/0
```

المخرجات قد تكون في `data`, `search`, `results`, أو `items`. الحقول المهمة: `id`, `title` أو `name`, `type`, `poster_path` أو `poster`, `overview` أو `description`, `vote_average`.

### Details

```http
GET {apiBase}media/detail/{movieId}/0
GET {apiBase}series/showplayer/{seriesId}/0
```

للمسلسل تُقرأ المواسم من `seasons[*].episodes[*]`. الحلقة تُحوّل إلى:

```text
{apiBase}episode/{episodeId}/0
```

### Streams

```http
GET {apiBase}media/detail/{movieId}/0
GET {apiBase}series/episode/{episodeId}/0
GET {apiBase}stream/show/{id}/0
```

تُقرأ الروابط من `videos`, `episode_stream`, `data`, `streams`, أو `servers`. الحقول المعتادة للرابط هي `link`, `url`, `file`, واسم الخادم من `server`, `name`, `video_name`. التطبيق يحول بعض الروابط إلى embed آمن:

```text
https://down.vidtube.one/{id}.html -> https://vidtube.one/embed-{id}.html
https://uqload.{tld}/{id}.html -> https://uqload.{tld}/embed-{id}.html
https://streamwish.{tld}/{id} -> https://streamwish.fun/e/{id}
```

المجموعة المسموح بها داخل طبقة تشغيل movie تشمل `vidtube.one`, `down.vidtube.one`, `uqload.*`, `streamtape.cc`, `streamwish.*`, `topcinemaa.*`, و`updown.icu`. يجب منع popups وredirects في WebView وعدم اعتبار أزرار login أو Facebook مصادر فيديو.

## 6. Manga Swat API

```text
Base: https://appswat.com/v2/api/v2
Accept: application/json
```

```http
GET {base}/series/?page={page}
GET {base}/series/?search={URL_ENCODED_QUERY}
GET {base}/series/{seriesId}/
GET {base}/series/{seriesId}/chapters/
GET {next URL returned by pagination}
GET {base}/chapters/{chapterId}/images/
```

الاستجابة القائمة تستخدم `results` و`next`. تفاصيل العمل تستخدم `title`, `poster.medium` أو `poster.thumbnail`, `genres`, `story`, `rating`, و`type`. الصور قد تستخدم `image`, `url`, أو `src`.

## 7. MangaTime API

```text
Site: https://mangatime.org
Base: https://mangatime.org/api/trpc
X-MT-Platform: app
X-MT-App-Version: 1.5.45
X-MT-UIMode: dark
```

كل الطلبات GET إلى tRPC مع `input` كـURL-encoded JSON:

```http
GET https://mangatime.org/api/trpc/search.searchSeries?input={URL_ENCODED_{"json":{"query":"QUERY","page":1,"limit":30}}}
GET https://mangatime.org/api/trpc/homepage.getLatestReleases?input={URL_ENCODED_{"json":{"page":1,"limit":30}}}
GET https://mangatime.org/api/trpc/content.getSeriesBySlug?input={URL_ENCODED_{"json":{"slug":"SLUG"}}}
GET https://mangatime.org/api/trpc/content.getChapters?input={URL_ENCODED_{"json":{"seriesId":"ID","limit":-1}}}
GET https://mangatime.org/api/trpc/content.getChapterPages?input={URL_ENCODED_{"json":{"chapterId":"ID"}}}
```

الاستجابة قد تتداخل داخل `result.data.json` أو `result.data`. افحص `pages`, `pageDimensions`, `prevChapter`, و`nextChapter`.

## 8. MangaMello API

```text
API: https://api.mangamello.com/nx/v3n
Site: https://mangamello.com
Accept: application/json
Origin: https://mangamello.com
Referer: https://mangamello.com/
User-Agent: Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/128.0 Mobile Safari/537.36
X-Requested-With: com.wael.mangamello
```

```http
GET {api}/mangas?search={query}&page=1&per_page=30
GET {api}/mangas?page={page}&per_page=30
GET {api}/mangas/{mangaId}
GET {api}/mangas/{mangaId}/chapters?page={page}&per_page=100
GET {api}/chapters/{chapterId}/refresh-images-json
GET {api}/chapters/{chapterId}/refresh-images
```

الحقول المهمة: `id`, `title`, `cover`, `image`, `poster`, `thumbnail`, `description`, `genres`, `author`, `artist`, `status`, و`chapter_count`. صفحات الصور قد تكون في `images`, `pages`, `data`, أو `results`.

## 9. Appwrite: authentication, favorites, storage, functions

### Project constants

```text
Endpoint: https://nyc.cloud.appwrite.io/v1
Project ID: 6aa4295900094d600163
Database ID: 6aa58db9001a5f53312d
Profiles table/collection ID: 6aa58dec001acc5ce962
Favorites table/collection ID: 6aa58e3a003b23556872
Profile images bucket ID: 6aa592fc0003195a524b
Username login function ID: 6aa5ed04000f66117651
Username login endpoint: https://anitv-username-login.nyc.appwrite.run
Email verification URL: https://anitv-tau.vercel.app/verify-email
```

في Flutter يستخدم Appwrite SDK بدل بناء REST يدويًا:

```dart
Client()
  ..setEndpoint('https://nyc.cloud.appwrite.io/v1')
  ..setProject('6aa4295900094d600163');
```

### Account operations

العمليات المستخدمة هي `Account.create`, `Account.createEmailPasswordSession`, `Account.get`, `Account.deleteSession`, `Account.createOAuth2Session`, وإجراءات verification وpassword recovery. لا تستخدم Admin API key في الهاتف.

### Favorites

المفضلة مخزنة في Appwrite Database/TablesDB في:

```text
Database: 6aa58db9001a5f53312d
Table: 6aa58e3a003b23556872
```

الحقول التي يعتمد عليها scanner الحالي:

```text
userId
itemId
source
title
type أو contentType
lastNotifiedEpisode
lastCheckedAt
```

العمليات: list rows/documents مع filter على `userId`, create favorite, find favorite, delete favorite. لا تنقل هذه البيانات إلى Supabase في التطبيق الجديد إذا كان المطلوب إبقاء Appwrite مصدر Favorites.

### Username login Function

```http
POST https://anitv-username-login.nyc.appwrite.run
Content-Type: application/json

{"username":"USER","password":"PASSWORD"}
```

هذه Function تنفذ login أو username flow حسب contract الموجود في المشروع. احتفظ بكلمات المرور داخل HTTPS request فقط ولا تسجلها.

## 10. Push notifications

Flutter يستخدم Firebase Messaging للحصول على FCM token ثم Appwrite Messaging لتسجيل Push Target. القيم غير السرية تُمرر وقت build:

```text
ANITV_FCM_PROVIDER_ID={actual Appwrite FCM provider ID}
ANITV_FCM_TOPIC_ID={actual Appwrite topic ID}
```

Appwrite methods:

```text
Account.createPushTarget(targetId, identifier, providerId)
Account.updatePushTarget(targetId, identifier)
Account.deletePushTarget(targetId)
Messaging.createSubscriber(topicId, subscriberId, targetId)
Messaging.createPush(messageId, users, title, body, data, priority)
```

Payload الصحيح للمحتوى:

```json
{
  "type": "episode",
  "itemId": "https://example.invalid/item/123",
  "url": "https://example.invalid/item/123",
  "source": "anime_slayer",
  "title": "Example",
  "episode": "12"
}
```

الأنواع المعتمدة: `episode`, `chapter`, `movie`, `series`, `drama`, `broadcast`, `update`, `news`. لا تستخدم `new_content` في التكامل الجديد إلا عند دعم legacy payload.

## 11. Supabase notification layer

مشروع Supabase المستخدم:

```text
Project ref: wvbgvbkvcainvpguxgif
Region: ap-southeast-1
```

Supabase لا يستبدل Appwrite Authentication أو Favorites. الجداول الحالية هي:

```text
public.notification_history
public.notification_deliveries
public.favorite_scan_runs
```

الغرض من كل جدول:

- `notification_history`: سجل إشعارات المستخدم مع `user_id`, `title`, `body`, `type`, `item_id`, `source`, `url`, `payload`, `created_at`, `read_at`.
- `notification_deliveries`: مفتاح idempotency بصيغة `userId|source|itemId|type|contentNumber` مع status وattempts.
- `favorite_scan_runs`: ملخص تشغيل الفحص.

الجداول server-only حاليًا؛ تم تفعيل RLS وسحب الصلاحيات من `anon` و`authenticated`. لا تستخدم `SUPABASE_SERVICE_ROLE_KEY` في Flutter. تستعمله Function server-side فقط عبر متغيرات بيئة:

```text
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
```

## 12. Server architecture to reproduce

```text
Flutter app
  ├── Appwrite Auth / Favorites / Storage
  ├── Firebase Messaging token
  └── Appwrite Push Target + Topic subscription

Scheduled server scan
  ├── Read Favorites from Appwrite TablesDB
  ├── Call the matching content adapter
  ├── Claim dedupe key in Supabase
  ├── Send Push through Appwrite Messaging
  ├── Save notification history in Supabase
  └── Update lastNotifiedEpisode in Appwrite
```

كل عنصر Favorite يجب أن يعالج مستقلًا. استخدم cursor pagination بحجم 100، retry محدودًا، وسجل الخطأ دون إيقاف بقية العناصر. يجب وجود Scheduler واحد فقط لتشغيل `favorite_scan`.

## 13. Security and portability rules

لا تضع في تطبيق الهاتف أيًا من Appwrite API keys الإدارية أو Supabase Service Role Key أو Firebase Service Account JSON. مفاتيح العميل الموجودة في بعض APIs العامة ليست بديلًا عن حماية backend، ويجب عدم طباعتها في logs. استخدم HTTPS، تحقق من status code، تحقق من JSON، ضع timeout، وطبّق allowlist للنطاقات وروابط التشغيل.

لا تمرر HTML player pages إلى native video player. لا تثق في أي `url` من API قبل التحقق من البروتوكول والنطاق أو امتداد media. افصل روابط الصور عن روابط الفيديو وعن روابط صفحات التفاصيل.

## 14. Minimum implementation sequence for another AI

1. أنشئ طبقة `ContentSource` بواجهات `latest`, `search`, `details`, `streams`, و`chapterImages`.
2. نفّذ كل adapter باستخدام endpoints أعلاه، مع إبقاء parsing داخل adapter وليس في الشاشة.
3. اجعل كل نتيجة موحدة بالحقول `title`, `url`, `image_url`, `type`, `description`, `source_id`.
4. أضف Appwrite SDK بنفس endpoint وProject ID إذا كان التطبيق الجديد سيستخدم نفس الحسابات والمفضلة.
5. أضف FCM ثم Appwrite Push Target بعد تسجيل الدخول، ونظف Target عند logout.
6. نفّذ notification tap من `onMessage`, `onMessageOpenedApp`, `getInitialMessage`, وlocal notification response.
7. اجعل Supabase server-only لتاريخ الإشعارات وdeduplication.
8. اختبر latest/search/details/streams لكل مصدر على حدة قبل دمج النتائج.

## 15. Known limitations

- النطاقات الخارجية قد تتغير أو تحجب أو تتطلب headers إضافية.
- Anime Slayer وDrama يستخدمان قيم client credentials مضمنة في العميل الحالي؛ الأفضل نقل الطلبات الحساسة إلى backend.
- FaselHD يغير API base عبر `api_urls.json`؛ لا تثبت fallback واحدًا إلى الأبد.
- ليست كل مصادر المانجا توفر نفس شكل pagination أو نفس أسماء حقول الصور.
- Appwrite Provider ID وTopic ID لا يمكن استنتاجهما من Project ID؛ يجب أخذهما من Appwrite Console.
- Supabase لا يستطيع إرسال FCM وحده دون إعداد server-side credentials. في البنية الحالية، Appwrite Messaging هو قناة الإرسال وSupabase هو طبقة history/deduplication.

## References

[1]: https://nyc.cloud.appwrite.io/v1 "AniTV Appwrite endpoint"
[2]: https://anslayer.com/anime/public/ "Anime Slayer API base"
[3]: https://animeify.net/animeify/apis_v4 "Animefy API base"
[4]: https://drslayer.com/drama/public/ "Drama Slayer API base"
[5]: https://appswat.com/v2/api/v2 "Manga Swat API base"
[6]: https://mangatime.org/api/trpc "MangaTime tRPC API"
[7]: https://api.mangamello.com/nx/v3n "MangaMello API base"
[8]: https://abcdefegh.watchit.tn/api_urls.json "FaselHD dynamic API configuration"
[9]: https://supabase.com/docs/guides/database/postgres/row-level-security "Supabase Row Level Security documentation"
