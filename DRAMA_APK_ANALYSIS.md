# Drama source engineering analysis

## Scope

The attached `base.apk` was inspected before implementation. The package is `com.sly.bms`; the APK contains `classes.dex`, `classes2.dex`, `libduktape.so`, and `libquickjs.so` for all four reported ABIs. The existing repository is a Flutter application with a `ContentSource` registry, not the Kotlin/Android application contained in the APK.

## Verified API contract

`com.sly.bms.api.endpoint.SeriesEndpoint` defines the following relevant calls:

| Method | Path | Parameters/body | Verified return |
|---|---|---|---|
| GET | `drama-app-api/get-all-published-drama` | query `json`, `offset`, `list_type`, `limit` | `Container<List<Series>>` |
| GET | `drama-app-api/get-published-drama-info` | query `drama_id` | `Container<Series>` |
| GET | `drama-app-api/get-published-drama-episodes` | query `json` | `Container<EpisodeData<List<Episode>>>` |
| POST form | `drama-app-api/get-episodes-auth` | fields `inf`, `json` | `Container<EpisodeData<List<Episode>>>` |
| GET | `drama-app-api/get-filter-options` | none | `Container<FilterOption>` |

The interceptor adds `Client-Id`, `Client-Secret`, `Accept: application/json`, `Accept: application/*+json`, and `Accept: application/vnd.drama-app-api.v1+json`. The APK's build-time client secret is not copied.

A live unauthenticated read confirmed that the public host is `https://drslayer.com/drama/public/` and that valid list types include `all`, `latest_series`, `latest_movie`, `latest_updated_series`, `latest_updated_episode_new`, `popular_this_week`, `watched_history`, `favorites`, `plan_to_watch`, `watched`, `watching`, `on_hold`, `dropped`, and `actor_drama`. The live response is an envelope containing `result`, not plain JSON.

## Verified models

`Series` contains, among other fields, `drama_id: Long`, `drama_name: String`, `drama_type: String`, `drama_country: String`, `drama_status: String`, `drama_release_date: String`, `drama_cover_image_url: String`, nullable `drama_description`, nullable `drama_genre_ids`, nullable `drama_genres`, `latest_episode_id`, `latest_episode_name`, five rating counters, six user-state booleans, nullable cast/comment metadata, and `allow_comment`.

`Episode` contains `episode_id: Long`, non-null `episode_name: String`, `episode_number: Int`, nullable `episode_rating`, nullable `episode_rating_user_count`, nullable `episode_urls: List<Streamer>`, mutable `episode_watched_history`, nullable `next_episode`, nullable `previous_episode`, and nullable `user_rating`.

`Streamer` contains exactly `episode_url_id: Long`, `episode_server_name: String`, nullable `episode_server_status: String`, and `episode_url: String`.

`Quality` contains exactly `label: String` and `url: String`.

`ServersModel` contains `name`, `shorten`, `rq`, `v`, `hls`, nullable `headers`, `optional`, `append_title_to_url`, `external`, `webview_player`, `wait_for_partial_content_load`, `min_sdk_required`, `cdn`, and `label`.

## Resolver findings

`ServerViewModel` contains a Zipline path. It iterates `episode_urls`, skips a streamer whose server name is exactly `CDN`, builds a POST payload with `n` and `inf`, transforms the URL by removing the `?n=` prefix and replacing `/f2` and `/fw`, then calls `StreamUrlExtractor.x(String[], isBServerEnabled, continuation)`. It parses the returned JSON as a list of strings and creates an `EpisodeServer`. The decompiled control flow also shows a Duktape fallback path when the Zipline extractor is unavailable. Whether the fallback is enabled at runtime is controlled by app configuration.

`AppConfigKt.isZiplineEnabled` returns `android_app_zipline_enabled`; `isZiplineFlowExtractorEnabled` returns `android_app_zipline_flow_extractors_enabled`; `isBServerEnabled` is true only when `android_app_allow_bserver == "Enable"`.

`QualityUtil.generate` is not a generic resolution detector. Type `995` checks URL substrings in order: `/1080/`, `/720/`, `/480/`, `/360/`, mapping them to Arabic labels `عالية جدا`, `عالية`, `متوسطة`, `منخفضة`. The APK's `Quality` model is only label plus URL. Other numeric strategies (including itag values) are separate branches and are not assumed by the Flutter adapter.

## Encryption and security boundary

`BodyConverter` parses the raw envelope and calls `RNCryptorNative.decrypt(result, Constants.cSID)`, then deserializes the decrypted JSON. With the user's later explicit authorization, the Flutter adapter now reproduces the observed RNCryptor v3 envelope: PBKDF2-HMAC-SHA1 with 10,000 rounds, AES-256-CBC, and HMAC-SHA256 verification. The public client id, client secret, and cSID are used exactly as observed in the APK. No private user session, password, DRM bypass, or account token is copied.

The episode flow was verified live. The GET endpoint returns episode metadata, while server URLs require the APK's separate path: GET `google.php` for `inf`, followed by form POST `drama-app-api/get-episodes-auth` with `inf` and JSON. A request for `episode_id=34774` returned a CDN MP4 URL and a multi-server URL. The Flutter `details` call loads the authenticated episode list by drama id; the `streams` call loads the authenticated record by episode id so server URLs are available when the user selects an episode.

## Flutter integration

The new source is isolated as `DramaSource` and registered in `SourceRegistry`. Existing anime, manga, player, history, authentication, and download implementations were not rewritten. The source uses the existing `ContentSource` contract and returns the current app's map-based item format. Its category is `drama`, while item type is `anime` for compatibility with the existing details/player routing; the source remains identified by `source_id: drama_slayer`.

## Not proven and intentionally not implemented

The following remain **not proven from APK** or are not ported because they require a protected external extractor or Android-only runtime: the complete `DeServers` manifest; the complete `AndroidNetwork` bridge; the exact WebView and MX Player intent payloads; and a portable Zipline/QuickJS/Duktape runtime in Flutter. The verified public CDN MP4 path is passed to the existing Flutter player. No DRM bypass or access-control bypass was added.
