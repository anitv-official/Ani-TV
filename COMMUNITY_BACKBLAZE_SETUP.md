# AniTV Community — Manual Backblaze B2 Setup Later

This document is a future manual setup guide only. Backblaze B2 is **not connected** in the current implementation, and no B2 credential belongs in Flutter, GitHub, Supabase public tables, assets, or `.env` files shipped to the application.

## 1. What will be needed

When the secure backend flow is ready, obtain from Backblaze:

1. A private B2 bucket name.
2. The bucket region/endpoint details.
3. An Application Key ID.
4. An Application Key with the narrowest possible bucket and prefix permissions.
5. Optional lifecycle/retention settings appropriate for community media.

Do not send these values through chat, do not paste them into Dart source, and do not commit them to Git.

## 2. Bucket design

Create a **private** bucket dedicated to AniTV Community media. Use predictable, non-user-controlled prefixes such as:

```text
community/{post-id}/{media-id}/{generated-file-name}
community/profile/{user-id}/{media-id}/{generated-file-name}
```

The server must generate IDs and keys. Never use a raw user filename as the authoritative storage key.

## 3. Where credentials belong

Store the Application Key ID and Application Key only in a server-side secret manager or Supabase Edge Function secret store. They must be accessible only to the trusted upload/download service. They must never be included in:

- Flutter `--dart-define` values.
- Android resources or manifests.
- GitHub repository files or Actions logs.
- Supabase public tables.
- Public URLs or client analytics.

Flutter only receives a short-lived, scoped upload authorization or a secure download URL/reference.

## 4. Supabase Edge Function flow

A future `community-media-upload` Edge Function should:

1. Validate the Appwrite-authenticated identity through the Appwrite → Supabase identity bridge.
2. Validate media type, size, dimensions, duration, post ownership, and rate limits.
3. Generate the B2 storage key server-side.
4. Use server-only B2 credentials to create a short-lived upload authorization or signed upload request.
5. Return only the temporary authorization and generated metadata to Flutter.
6. After upload, validate completion and persist `storage_provider`, `storage_key`, filename, MIME type, size, duration, width, and height in `community_post_media`.
7. Never persist the Application Key or a privileged token in Supabase public data.

A separate secure download function should authorize the current user and return a short-lived download URL or stream. Do not assume the bucket is public.

## 5. Flutter upload flow

Flutter will call a future repository implementation, not B2 directly:

```text
Flutter MediaRepository
  → trusted Edge Function
  → temporary upload authorization
  → direct scoped upload or server-mediated upload
  → storage metadata saved in Supabase
```

The existing `BackblazeMediaRepository` placeholder in `lib/community/services/community_media_storage.dart` is the integration boundary. Replace its `StorageNotConfiguredError` behavior only after the secure endpoint exists.

## 6. Secure download flow

For every requested image or audio item:

1. Flutter sends the metadata/reference to the trusted backend.
2. The backend checks post visibility, ownership, deletion state, and authorization.
3. The backend creates a short-lived B2 download URL or streams the file.
4. Flutter uses the returned URL for the limited lifetime only.
5. The database retains the storage key, not a permanent privileged URL.

This prevents a user from changing a URL or storage key and reading another user's private media.

## 7. Deletion flow

When a post or media item is deleted:

1. Flutter requests deletion through `MediaRepository`.
2. The trusted backend verifies ownership or moderation authority.
3. The backend deletes or marks the B2 object for lifecycle cleanup.
4. The database metadata is soft-deleted or removed according to retention policy.
5. The operation is idempotent and logged without exposing credentials.

## 8. Images

For images, the backend should validate MIME type and actual file signature, enforce a size limit, optionally normalize dimensions, and reject unsafe formats. Store only metadata in `community_post_media`. Use a private, short-lived download URL and client-side caching with an expiration policy.

## 9. Audio clips

For audio, enforce an allowlist of MIME types, a duration limit, and a file-size limit. Validate the container server-side, store duration metadata, and return a short-lived secure URL. Do not trust client-supplied duration or MIME type without validation.

## 10. Preventing cross-user access

Authorization must be checked on every upload, download, and delete operation. The backend should derive the Appwrite identity from a trusted claim, look up the related Community record, and verify one of:

- The user owns the post/media.
- The item is public and the user is allowed to view it.
- The user is a permitted conversation member.
- The caller is an authorized moderator/admin.

A client-supplied `user_id` or `storage_key` is never sufficient authorization.

## 11. Connecting to the existing MediaRepository

The implementation sequence will be:

1. Configure the private bucket and server secret store.
2. Implement secure Edge Functions and identity verification.
3. Add server-side integration tests for authorization and expiry.
4. Implement `BackblazeMediaRepository` against those functions.
5. Keep the existing `MediaRepository` interface unchanged.
6. Switch the factory from placeholder to the real repository only after tests pass.
7. Keep Mock mode available for offline development.

Do not perform these steps in the Flutter repository alone. The current project intentionally stops before credentials, B2 API calls, and production upload behavior.
