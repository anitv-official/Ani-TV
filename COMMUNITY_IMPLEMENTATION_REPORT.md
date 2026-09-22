# AniTV Community Implementation Report

## 1. Executive Summary

This iteration completes the real Community media path around the existing Appwrite identity, Supabase Community schema, and Backblaze B2 S3-compatible storage. Production Flutter builds now default to Supabase, while Mock remains an explicit `--dart-define=COMMUNITY_DATA_SOURCE=mock` option for tests and offline development. Media credentials are read only by Supabase Edge Functions; no B2 application key, service-role key, or hardcoded media URL is present in Flutter or the repository.

The media flow is a two-step presigned upload: Flutter requests a short-lived B2 PUT URL from `community-media-upload`, uploads the bytes directly to B2, then calls `community-media-complete`. Metadata is initially marked `pending` and is promoted to `backblaze_b2` only after an authenticated Edge Function verifies the object with a signed HEAD request. Reads use five-minute private URLs, and deletes remove the B2 object before deleting its metadata.

## 2. Architecture

Flutter remains the presentation and repository-contract layer. Appwrite remains the authentication authority. The client creates a short-lived Appwrite JWT through the existing account session and sends it in `X-Appwrite-JWT` to the Edge Functions. Each Edge Function validates that JWT against Appwrite's `/account` endpoint and derives the user ID from the validated response; no client-supplied user ID is trusted for authorization.

Supabase hosts the Community relational schema, RLS policies, Realtime tables, and Edge Functions. Edge Functions use the Supabase service role only server-side for narrowly scoped metadata operations after performing their own Appwrite identity and ownership checks. Backblaze B2 is accessed through its S3-compatible endpoint using AWS Signature Version 4. Realtime subscriptions remain behind the repository layer established in the previous backend iteration.

## 3. Database Changes

The existing Community migrations create and harden profiles, profile favorites, posts, post media, comments, likes, friend requests, friendships, conversations, conversation members, messages, message reads, and notifications. The media integration uses the existing `community_post_media` columns: `storage_provider`, `storage_key`, `file_name`, `mime_type`, `file_size`, `duration_ms`, `width`, and `height`. New application code does not alter notification tables or authentication tables.

The Flutter feed now supports a `created_at` keyset cursor (`before`) for production pagination. Offset remains available for compatibility with existing Mock tests and callers.

## 4. RLS

Public reads remain limited by the existing Community policies. Post authors can create, update, and delete their own posts. Media metadata is readable only through post visibility and writable through the post owner policy. Comments and likes use the validated Community identity helper. Conversation and message policies remain member-scoped. Edge Functions use service-role metadata access only after rechecking Appwrite identity and post ownership; this is not a client-side RLS bypass.

## 5. Identity Bridge

`AppwriteService.createCommunityJwt()` calls Appwrite `account.createJWT()` using the already authenticated Appwrite session. `AppwriteCommunityIdentity` exposes that operation to the media client. Each media Edge Function sends the JWT to Appwrite with the fixed public project ID and obtains the authoritative `$id`. The upload, completion, and delete functions compare that ID with the post author. The URL function permits an authenticated user to read media attached to a visible post, while private conversation authorization remains handled by the existing Supabase policies and repository layer.

## 6. Backblaze Integration

The storage implementation uses the existing secret names required by the specification: `B2_KEY_ID`, `B2_APPLICATION_KEY`, `B2_BUCKET_NAME`, `B2_S3_ENDPOINT`, and `B2_REGION`. The Edge Functions also use the platform-provided `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`. No secret values are stored in this repository.

Object keys are generated as `community/{validated-user-id}/{post-id}/{random-id}.{extension}`. PUT and GET access uses AWS Signature Version 4 presigned URLs. HEAD and DELETE use signed S3-compatible requests. Uploads accept image formats up to 10 MiB and audio formats up to 15 MiB. The Flutter client sends the exact signed content type and byte length, then waits for server-side completion validation before treating the media as ready.

## 7. Edge Functions

| Function | Purpose | Authentication and authorization | Main input/output |
|---|---|---|---|
| `community-media-upload` | Create pending metadata and a short-lived B2 PUT URL | Appwrite JWT; validated user must own `post_id` | Input: post and media metadata. Output: `media_id`, storage key, presigned URL, expiry |
| `community-media-complete` | Verify the uploaded object and promote metadata | Appwrite JWT; validated user must own the media's post | Input: `media_id`. Output: `ready` status |
| `community-media-url` | Return a short-lived private B2 GET URL | Appwrite JWT; visible post and authenticated profile checks | Input: `media_id`. Output: URL and 300-second expiry |
| `community-media-delete` | Delete B2 object and metadata | Appwrite JWT; validated user must own the media's post | Input: `media_id`. Output: deleted or already-deleted status |

All four functions are deployed and active in the AniTV Supabase project with platform JWT verification disabled intentionally because they perform their own Appwrite JWT validation. They reject unauthenticated requests with HTTP 401 and respond to CORS preflight with HTTP 204.

## 8. Flutter Changes

`CommunityMediaApi` invokes the Edge Functions, obtains Appwrite JWTs, uploads bytes with `http`, completes uploads, obtains private read URLs, and deletes media. `SupabaseCommunityRepository.publishPost` now creates the post, uploads an optional image or audio asset through this API, attaches verified media metadata, and removes the post if the media transaction fails. MIME detection is restricted to supported image and audio extensions.

Community image rendering now resolves non-local media through a secure URL Future instead of treating a B2 storage key as a local file. The former simulated audio control now uses `just_audio` and resolves secure URLs before playback. The feed provider and repository contracts support keyset cursor pagination.

## 9. Screens Created

No new top-level screen was required in this iteration. The previously created Community feed, social, notification, and conversation screens continue to use repository contracts.

## 10. Screens Updated

Community post media rendering and audio playback were updated in `community_widgets.dart`. Production data-source selection is updated in `community_backend_config.dart`; the default is Supabase, and Mock requires an explicit build define.

## 11. Realtime

The existing repository-level Realtime abstractions remain the boundary for messages, notifications, comments, and likes. This iteration does not expose Supabase channels directly to Widgets and does not change the existing Realtime schema.

## 12. Notifications

The existing Community notification tables and notification screen are preserved. Media actions do not fabricate notifications. Existing notification repository behavior remains responsible for friend, comment, reaction, message, and verification events.

## 13. Security

Secrets are server-only environment lookups. Flutter contains only the Supabase publishable client key and public project URL. Object URLs are presigned and short-lived rather than hardcoded. User IDs are derived from an Appwrite JWT validated by the Edge Function. Upload, completion, and delete operations perform ownership checks. Completion checks the object exists and matches the expected byte size. Service-role access is never exposed to the client. The repository uses a random object component to avoid predictable collisions, and the CI workflow scans for committed B2 or service-role values.

## 14. Testing

| Test | Result | Notes |
|---|---|---|
| Flutter unit/widget suite | PASS | 31 tests passed after the media integration fixes |
| Edge Function CORS smoke test | PASS | All four deployed functions returned HTTP 204 to OPTIONS |
| Edge Function unauthenticated smoke test | PASS | All four returned HTTP 401 with a safe JSON error |
| Supabase Edge Function deployment | PASS | All four functions are ACTIVE in the connected project |
| Secret scan | PASS | No B2 values or service-role values committed; only environment variable names appear in server code |
| Flutter analyzer | PASS with non-fatal legacy diagnostics | The repository still reports pre-existing informational/warning diagnostics; no changed-file analyzer errors remain |
| Authenticated B2 upload | NOT RUN | Requires an interactive AniTV/Appwrite account session and a real media file; no claim of success is made here |
| Authenticated metadata, image visibility, delete cleanup, and cross-user access | NOT RUN | These require the same authenticated session and real B2 objects |
| Android APK | PENDING | Must be verified by the GitHub Actions run triggered by the final push |

## 15. Build

The local Flutter test suite is passing. Analyzer diagnostics are non-fatal legacy project diagnostics; the changed Community and Appwrite files have no compile errors. The final Android build is delegated to the repository's GitHub Actions workflow after push. The new Function Quality workflow also runs `deno check` for all four functions and rejects committed credential assignments.

## 16. Git

The final commit hash and GitHub Actions run URLs are added to this section after the final commit and remote verification. The branch is `main`; no force push or history rewrite is used.

## 17. Known Limitations

The sandbox cannot perform the real authenticated end-to-end flow without taking over a logged-in Appwrite browser/session or receiving a test account session. Therefore this report deliberately does not claim that an actual image reached B2, that a second user was denied a private conversation, or that a Realtime event was observed. The deployed functions are structurally and smoke-tested, but the authenticated B2 path remains an external verification gate.

## 18. Manual Steps Required

No secret values need to be supplied to the repository. The Supabase project must retain the configured Edge Function secrets under the exact names listed in Section 6. A maintainer with an AniTV/Appwrite session should perform one authenticated text post, image upload, image display, delete, and cross-user authorization test, then record the results in this report if desired.

## 19. Future Improvements

Future work may add resumable multipart uploads for larger media, server-side media scanning and image dimension validation, signed thumbnail generation, automatic orphan cleanup for pending rows, and an authenticated device-level integration test harness that can run without exposing user credentials.
