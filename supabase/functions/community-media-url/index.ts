import { errorResponse, json, MediaFunctionError, requirePostRequest, readJson, serviceConfig, presign, supabaseGet, validateAppwriteIdentity } from "../_shared/community_media.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-appwrite-jwt", "Access-Control-Allow-Methods": "POST, OPTIONS" } });
  try {
    requirePostRequest(req);
    const identity = await validateAppwriteIdentity(req);
    const config = serviceConfig();
    const body = await readJson(req);
    const mediaId = typeof body?.media_id === "string" ? body.media_id.trim() : "";
    if (!mediaId) throw new MediaFunctionError("invalid_input", 400, "Invalid media id.");
    const rows = await supabaseGet(config, `community_post_media?id=eq.${encodeURIComponent(mediaId)}&storage_provider=eq.backblaze_b2&select=id,post_id,storage_key&limit=1`);
    const media = rows[0];
    if (!media) throw new MediaFunctionError("not_found", 404, "Media was not found.");
    const posts = await supabaseGet(config, `community_posts?id=eq.${encodeURIComponent(media.post_id)}&deleted_at=is.null&select=id,author_id&limit=1`);
    if (!posts.length) throw new MediaFunctionError("not_found", 404, "The post was not found.");
    const post = posts[0];
    if (post.author_id !== identity.id) {
      // Public Community posts may be viewed by authenticated Appwrite users.
      const actor = await supabaseGet(config, `community_profiles?user_id=eq.${encodeURIComponent(identity.id)}&select=user_id&limit=1`);
      if (!actor.length) throw new MediaFunctionError("forbidden", 403, "You do not have permission for this media.");
    }
    return json({ media_id: mediaId, url: await presign(config, "GET", media.storage_key, undefined, 300), expires_in: 300 });
  } catch (error) {
    if (error instanceof MediaFunctionError && error.status === 204) return new Response(null, { status: 204 });
    return errorResponse(error);
  }
});
