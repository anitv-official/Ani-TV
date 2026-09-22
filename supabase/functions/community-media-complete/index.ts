import { errorResponse, json, MediaFunctionError, requirePostRequest, readJson, serviceConfig, signedB2Request, supabaseGet, supabaseUpdate, validateAppwriteIdentity } from "../_shared/community_media.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-appwrite-jwt", "Access-Control-Allow-Methods": "POST, OPTIONS" } });
  try {
    requirePostRequest(req);
    const identity = await validateAppwriteIdentity(req);
    const config = serviceConfig();
    const body = await readJson(req);
    const mediaId = typeof body?.media_id === "string" ? body.media_id.trim() : "";
    if (!mediaId) throw new MediaFunctionError("invalid_input", 400, "Invalid media id.");
    const rows = await supabaseGet(config, `community_post_media?id=eq.${encodeURIComponent(mediaId)}&select=id,post_id,storage_key,storage_provider,file_size,mime_type&limit=1`);
    const media = rows[0];
    if (!media) throw new MediaFunctionError("not_found", 404, "Media was not found.");
    await (async () => { const posts = await supabaseGet(config, `community_posts?id=eq.${encodeURIComponent(media.post_id)}&author_id=eq.${encodeURIComponent(identity.id)}&deleted_at=is.null&select=id&limit=1`); if (!posts.length) throw new MediaFunctionError("forbidden", 403, "You do not have permission for this media."); })();
    const head = await signedB2Request(config, "HEAD", media.storage_key, media.mime_type || undefined);
    if (!head.ok) throw new MediaFunctionError(head.status === 404 ? "upload_missing" : "storage_error", head.status === 404 ? 409 : 502, head.status === 404 ? "The upload was not found in storage." : "Storage validation failed.");
    const length = Number(head.headers.get("content-length") || 0);
    if (length > 0 && media.file_size && length !== Number(media.file_size)) throw new MediaFunctionError("upload_size_mismatch", 400, "The uploaded file size does not match.");
    await supabaseUpdate(config, "community_post_media", `id=eq.${encodeURIComponent(mediaId)}`, { storage_provider: "backblaze_b2" });
    return json({ media_id: mediaId, status: "ready", storage_provider: "backblaze_b2" });
  } catch (error) {
    if (error instanceof MediaFunctionError && error.status === 204) return new Response(null, { status: 204 });
    return errorResponse(error);
  }
});
