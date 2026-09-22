# AniTV Community Backend Implementation

## Scope and safety boundary

Community now has a real Supabase PostgreSQL schema and production repository implementations while retaining Mock mode. Appwrite remains the only authentication system. Supabase Auth was not added, and the Flutter client contains no service-role key, database password, Backblaze credential, application key, or master key. Binary media is not uploaded to Supabase Storage; the current media implementation is a secure-server placeholder for future Backblaze B2 integration.

The app selects the data source through `COMMUNITY_DATA_SOURCE`:

```text
COMMUNITY_DATA_SOURCE=mock       # explicit Mock mode for tests/offline development; production defaults to Supabase
COMMUNITY_DATA_SOURCE=supabase   # requires SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY
```

Supabase is initialized only when all three values are supplied as `--dart-define` values. Without them, the existing UI automatically uses Mock repositories.

## Database schema

The migration files are under `supabase/migrations/`:

| Migration | Purpose |
|---|---|
| `20260918042700_create_notification_infrastructure.sql` | Existing server-side notification history, delivery deduplication, and scan-run tables. Preserved and applied without destructive changes. |
| `20260922112000_create_community_backend.sql` | Community schema, constraints, timestamps, indexes, RLS, and Realtime publication. |
| `20260922113000_harden_community_rls_and_indexes.sql` | Revokes public execution of the identity helper, removes media-policy overlap, and adds foreign-key indexes. |

The connected Supabase project is `AniTV` (`wmzeydetzfndkpgqwfjd`) and contains these Community tables:

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

`community_post_media` stores metadata only: provider, storage key, file metadata, dimensions, duration, and order. It stores no B2 secret or permanent credential.

## Relationships and integrity

Profiles use Appwrite user IDs as `text` external identities rather than pretending they are Supabase Auth UUIDs. Posts, comments, likes, friend requests, friendships, conversation membership, messages, reads, and notifications reference those identities or Community UUIDs through foreign keys.

The database enforces nonblank comments and messages, supported post/message/notification types, no self friend request, one like per `(post_id, user_id)`, canonical ordered friendship endpoints, unique conversation membership, timestamps, soft deletion where appropriate, and update timestamp triggers. Indexes cover feed ordering, authors, comments, likes, friend requests, friendships, members, messages, message reads, and notification lookup.

## Appwrite identity architecture

`CommunityIdentityProvider` and `AppwriteCommunityIdentity` read the current user through the existing `AppwriteService.getCurrentUser()`. The client does not send a user ID and ask RLS to trust it.

The SQL function `public.community_current_user_id()` reads `appwrite_user_id` only from a trusted JWT claim. Its execute permission is revoked from `anon` and `authenticated` after the hardening migration. A future trusted Appwrite → Supabase identity bridge or Edge Function must mint the claim. Until that bridge exists, protected writes correctly fail rather than accepting spoofable IDs. No Appwrite authentication flow, Google login, Facebook login, email/password login, username login, package name, application ID, or signing configuration was changed.

## RLS

Public reads are allowed only for public community content such as profiles and non-deleted posts/comments/media. Identity-sensitive writes require the trusted Appwrite claim:

- Profile insert/update and favorites: current profile owner only.
- Posts and post media: author only.
- Comments: authenticated Appwrite identity for create/update/delete ownership.
- Likes: current identity only for insert/delete; public read.
- Friend requests: participant read/update and requester-only create, with self-request database check.
- Friendships: participant read only; future acceptance logic belongs in trusted backend/admin logic.
- Conversations, members, messages, and message reads: membership and sender/owner checks.
- Community notifications: recipient read/update only.
- Verification: public read through profile fields; no client-side write policy exists.

The pre-existing `notification_history`, `notification_deliveries`, and `favorite_scan_runs` tables remain server-only and are not reused or renamed. Their RLS and delivery/deduplication behavior were preserved.

## Flutter repositories

Production implementations are in `lib/community/repositories/supabase_community_repositories.dart`:

- `SupabaseCommunityRepository`
- `SupabasePostRepository`
- `SupabaseCommentRepository`
- `SupabaseLikeRepository`
- `SupabaseProfileRepository`
- `SupabaseFriendRepository`
- `SupabaseChatRepository`
- `SupabaseNotificationRepository`
- `SupabaseVerificationRepository`
- `SupabaseMediaRepository`
- `SupabaseShareRepository`
- `SupabaseCommunityRealtimeRepository`

The existing interfaces remain in `community_repositories.dart`. The UI uses `CommunityRepositoryFactory`, so switching between Mock and Supabase does not require redesigning screens. Supabase errors are mapped to safe categories (`NetworkError`, `AuthenticationError`, `PermissionError`, `NotFoundError`, `ValidationError`, `DatabaseError`, and `StorageNotConfiguredError`) rather than exposing raw server messages.

## Realtime

The migration adds these tables to the `supabase_realtime` publication:

- messages
- message reads
- notifications
- friend requests
- comments
- likes

`SupabaseCommunityRealtimeRepository` exposes repository streams for messages, notifications, comments, and likes. Widgets do not create channels directly. The identity bridge and membership RLS remain prerequisites for protected production data.

## Notifications integration

The existing notification infrastructure is separate from `community_notifications`. The old `notification_history` table remains the source for server-side AniTV content notification history, delivery status, deduplication, retries, and scan logs. Community notifications use nullable references to posts, comments, conversations, messages, and friend requests and do not modify the old notification tables.

## Verification

`community_profiles.is_verified`, `verified_at`, and `verified_by` are present. The unified Flutter `VerifiedBadge` continues to render from `isVerified`. There is intentionally no ordinary-user update policy for verification. Administrative changes must be performed by a future trusted backend or admin workflow.

## Media and Backblaze B2

`community_media_storage.dart` defines `StorageProvider`, `StorageConfig`, `MediaUploadRequest`, `MediaUploadResult`, and `MediaDeleteRequest`. `SupabaseMediaRepository` now calls the deployed Community media Edge Functions for presigned upload, completion, private URL, and deletion. The legacy `BackblazeMediaRepository` remains only as a safe Mock-mode contract and never receives credentials.

The intended future flow is:

```text
Flutter
  → trusted Supabase Edge Function or backend
  → private Backblaze B2 bucket
  → secure upload/download authorization
  → storage_key metadata in Supabase
```

No B2 credentials, fake credentials, B2 API calls, public-bucket assumptions, or client-side privileged operations exist in this repository.

## Running the two modes

Mock mode is explicit and requires no network configuration:

```bash
flutter run
```

Supabase mode requires the project URL, safe publishable/anon key, and explicit mode selection. The key is supplied out of band and is not committed to source:

```bash
flutter run \
  --dart-define=COMMUNITY_DATA_SOURCE=supabase \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-key>
```

This does not create a Supabase Auth session. The Appwrite identity bridge must later provide the trusted JWT claim before protected writes are enabled.

## Tests and verification

The project passed Flutter analysis with only existing nonfatal style information and passed the full test suite with **31 tests** after backend tests were added. Tests cover the previous feed/profile/chat functionality plus Mock/Supabase mode defaults, safe error categories, migration credential audit, and B2 Edge Function contract and secret-name audit.

The Supabase project was inspected after migration: all Community tables exist with RLS enabled, foreign keys and primary keys are present, Community Realtime tables are published, and the old notification infrastructure tables are present. Supabase advisories identified and were addressed for Community: identity function execution, media policy overlap, and missing Community foreign-key indexes. Remaining advisory notices concern intentionally server-only legacy notification tables and unused indexes on an empty new database.
