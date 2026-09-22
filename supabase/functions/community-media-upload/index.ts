import { errorResponse, getEnv, json, MediaFunctionError, objectKey, ownedPost, presign, readJson, requireMediaType, requireMime, requirePostRequest, requireSize, requireString, serviceConfig, supabaseInsert, validateAppwriteIdentity } from "../_shared/community_media.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-appwrite-jwt", "Access-Control-Allow-Methods": "POST, OPTIONS" } });
  try {
    requirePostRequest(req);
    const identity = await validateAppwriteIdentity(req);
    const config = serviceConfig();
    const body = await readJson(req);
    const postId = requireString(body?.post_id, "post id", 80);
    await ownedPost(config, postId, identity.id);
    const mediaType = requireMediaType(body?.media_type);
    const mimeType = requireMime(mediaType, body?.mime_type);
    const fileSize = requireSize(body?.file_size, mediaType);
    const fileName = body?.file_name == null ? null : requireString(body.file_name, "file name", 180).replace(/[^a-zA-Z0-9._-]/g, "_");
    const durationMs = mediaType === "audio" && Number.isInteger(body?.duration_ms) ? Math.max(0, Math.min(body.duration_ms, 15 * 60 * 1000)) : null;
    const width = Number.isInteger(body?.width) ? Math.max(1, Math.min(body.width, 12000)) : null;
    const height = Number.isInteger(body?.height) ? Math.max(1, Math.min(body.height, 12000)) : null;
    const storageKey = objectKey(identity.id, postId, mediaType, mimeType);
    const metadata = await supabaseInsert(config, "community_post_media", { post_id: postId, media_type: mediaType, storage_provider: "pending", storage_key: storageKey, file_name: fileName, mime_type: mimeType, file_size: fileSize, duration_ms: durationMs, width, height });
    const uploadUrl = await presign(config, "PUT", storageKey, mimeType, 600);
    return json({ media_id: metadata.id, storage_provider: "backblaze_b2", storage_key: storageKey, upload_url: uploadUrl, expires_in: 600, content_type: mimeType, file_size: fileSize });
  } catch (error) {
    if (error instanceof MediaFunctionError && error.status === 204) return new Response(null, { status: 204 });
    return errorResponse(error);
  }
});
