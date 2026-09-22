import { errorResponse, json, MediaFunctionError, requirePostRequest, readJson, serviceConfig, signedB2Request, supabaseDelete, supabaseGet, validateAppwriteIdentity } from "../_shared/community_media.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-appwrite-jwt", "Access-Control-Allow-Methods": "POST, OPTIONS" } });
  try {
    requirePostRequest(req);
    const identity = await validateAppwriteIdentity(req);
    const config = serviceConfig();
    const body = await readJson(req);
    const mediaId = typeof body?.media_id === "string" ? body.media_id.trim() : "";
    if (!mediaId) throw new MediaFunctionError("invalid_input", 400, "Invalid media id.");
    const rows = await supabaseGet(config, `community_post_media?id=eq.${encodeURIComponent(mediaId)}&select=id,post_id,storage_key,storage_provider&limit=1`);
    const media = rows[0];
    if (!media) return json({ media_id: mediaId, status: "already_deleted" });
    const posts = await supabaseGet(config, `community_posts?id=eq.${encodeURIComponent(media.post_id)}&author_id=eq.${encodeURIComponent(identity.id)}&select=id&limit=1`);
    if (!posts.length) throw new MediaFunctionError("forbidden", 403, "You do not have permission to delete this media.");
    if (media.storage_provider === "backblaze_b2") {
      const response = await signedB2Request(config, "DELETE", media.storage_key);
      if (!response.ok && response.status !== 404) throw new MediaFunctionError("storage_error", 502, "The media could not be removed from storage.");
    }
    await supabaseDelete(config, "community_post_media", `id=eq.${encodeURIComponent(mediaId)}`);
    return json({ media_id: mediaId, status: "deleted" });
  } catch (error) {
    if (error instanceof MediaFunctionError && error.status === 204) return new Response(null, { status: 204 });
    return errorResponse(error);
  }
});
