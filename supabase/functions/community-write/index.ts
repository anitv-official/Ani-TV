import {
  corsHeaders,
  errorResponse,
  MediaFunctionError,
  readJson,
  requirePostRequest,
  requireString,
  serviceConfig,
  supabaseGet,
  supabaseInsert,
  supabaseUpdate,
  validateAppwriteIdentity,
  json,
} from "../_shared/community_media.ts";

function text(value: unknown, name: string, max = 5000): string {
  return requireString(value, name, max);
}

async function ensureProfile(config: ReturnType<typeof serviceConfig>, identity: { id: string; name?: string; email?: string }) {
  const rows = await supabaseGet(config, `community_profiles?user_id=eq.${encodeURIComponent(identity.id)}&select=user_id,username,display_name,bio,is_verified&limit=1`);
  if (rows.length) return rows[0];
  const username = (identity.email?.split("@")[0] || identity.id).replace(/[^a-zA-Z0-9_.-]/g, "_").slice(0, 40) || identity.id;
  return await supabaseInsert(config, "community_profiles", {
    user_id: identity.id,
    username: `${username}_${identity.id.slice(-6)}`.slice(0, 64),
    display_name: identity.name || username,
  });
}

async function ownedPost(config: ReturnType<typeof serviceConfig>, postId: string, userId: string) {
  const rows = await supabaseGet(config, `community_posts?id=eq.${encodeURIComponent(postId)}&author_id=eq.${encodeURIComponent(userId)}&deleted_at=is.null&select=id,author_id&limit=1`);
  if (!rows.length) throw new MediaFunctionError("forbidden", 403, "You do not have permission for this post.");
  return rows[0];
}

async function member(config: ReturnType<typeof serviceConfig>, conversationId: string, userId: string) {
  const rows = await supabaseGet(config, `community_conversation_members?conversation_id=eq.${encodeURIComponent(conversationId)}&user_id=eq.${encodeURIComponent(userId)}&select=conversation_id&limit=1`);
  if (!rows.length) throw new MediaFunctionError("forbidden", 403, "You are not a member of this conversation.");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });
  try {
    requirePostRequest(req);
    const identity = await validateAppwriteIdentity(req);
    const config = serviceConfig();
    const body = await readJson(req);
    const action = requireString(body?.action, "action", 64);
    const profile = await ensureProfile(config, identity);

    switch (action) {
      case "ensure_profile":
        return json(profile);
      case "list_friends": {
        const friendships = await supabaseGet(config, `community_friendships?or=(user_low_id.eq.${encodeURIComponent(identity.id)},user_high_id.eq.${encodeURIComponent(identity.id)})&select=user_low_id,user_high_id&limit=100`);
        const ids = friendships.map((row) => row.user_low_id === identity.id ? row.user_high_id : row.user_low_id).filter((id) => typeof id === "string" && id.length > 0);
        if (!ids.length) return json({ friends: [] });
        const profiles = await supabaseGet(config, `community_profiles?user_id=in.(${ids.map((id) => encodeURIComponent(id)).join(",")})&select=user_id,username,display_name,bio,is_verified,profile_image_reference&limit=100`);
        return json({ friends: profiles });
      }
      case "friend_status": {
        const otherUserId = requireString(body.user_id, "user id", 128);
        if (otherUserId === identity.id) return json({ status: "none" });
        const requests = await supabaseGet(config, `community_friend_requests?or=(and(requester_id.eq.${encodeURIComponent(identity.id)},recipient_id.eq.${encodeURIComponent(otherUserId)}),and(requester_id.eq.${encodeURIComponent(otherUserId)},recipient_id.eq.${encodeURIComponent(identity.id)}))&status=in.(pending,accepted)&select=id,requester_id,recipient_id,status&order=created_at.desc&limit=1`);
        if (!requests.length) return json({ status: "none" });
        const request = requests[0];
        if (request.status === "accepted") return json({ status: "friends" });
        return json({ status: request.requester_id === identity.id ? "pending" : "incoming", request_id: request.id });
      }
      case "list_friend_requests": {
        const requests = await supabaseGet(config, `community_friend_requests?recipient_id=eq.${encodeURIComponent(identity.id)}&status=eq.pending&select=id,requester_id,recipient_id,status,created_at&order=created_at.desc&limit=100`);
        const ids = requests.map((row) => row.requester_id).filter((id) => typeof id === "string");
        const profiles = ids.length ? await supabaseGet(config, `community_profiles?user_id=in.(${ids.map((id) => encodeURIComponent(id)).join(",")})&select=user_id,username,display_name,bio,is_verified,profile_image_reference&limit=100`) : [];
        const byId = new Map(profiles.map((row) => [row.user_id, row]));
        return json({ requests: requests.map((row) => ({ ...row, requester_profile: byId.get(row.requester_id) ?? {} })) });
      }
      case "list_notifications": {
        const notifications = await supabaseGet(config, `community_notifications?recipient_id=eq.${encodeURIComponent(identity.id)}&select=id,type,friend_request_id,is_read,created_at,actor_id&order=created_at.desc&limit=50`);
        const actorIds = notifications.map((row) => row.actor_id).filter((id) => typeof id === "string");
        const profiles = actorIds.length ? await supabaseGet(config, `community_profiles?user_id=in.(${actorIds.map((id) => encodeURIComponent(id)).join(",")})&select=user_id,username,display_name,profile_image_reference&limit=100`) : [];
        const byId = new Map(profiles.map((row) => [row.user_id, row]));
        return json({ notifications: notifications.map((row) => ({ ...row, actor_profile: byId.get(row.actor_id) ?? {} })) });
      }
      case "respond_friend_request": {
        const requestId = requireString(body.request_id, "request id", 80);
        const accept = body.accept === true;
        const requests = await supabaseGet(config, `community_friend_requests?id=eq.${encodeURIComponent(requestId)}&recipient_id=eq.${encodeURIComponent(identity.id)}&status=eq.pending&select=id,requester_id,recipient_id&limit=1`);
        if (!requests.length) throw new MediaFunctionError("not_found", 404, "The friend request was not found.");
        const request = requests[0];
        await supabaseUpdate(config, "community_friend_requests", `id=eq.${encodeURIComponent(requestId)}&recipient_id=eq.${encodeURIComponent(identity.id)}&status=eq.pending`, { status: accept ? "accepted" : "rejected" });
        if (!accept) return json({ status: "none" });
        const low = request.requester_id < request.recipient_id ? request.requester_id : request.recipient_id;
        const high = request.requester_id < request.recipient_id ? request.recipient_id : request.requester_id;
        await supabaseInsert(config, "community_friendships", { user_low_id: low, user_high_id: high });
        await supabaseInsert(config, "community_notifications", { recipient_id: request.requester_id, actor_id: identity.id, type: "friend_request_accepted", friend_request_id: requestId });
        return json({ status: "friends" });
      }
      case "create_post": {
        const content = typeof body.content === "string" ? body.content.trim() : "";
        const link = body.link == null ? null : requireString(body.link, "link", 2048);
        const postType = ["text", "image", "audio", "link", "mixed"].includes(body.post_type)
          ? body.post_type
          : "text";
        if (!content && !link) throw new MediaFunctionError("invalid_input", 400, "A post needs text or a link.");
        const post = await supabaseInsert(config, "community_posts", { author_id: identity.id, content, post_type: postType, link_url: link });
        return json(post);
      }
      case "create_comment": {
        const postId = requireString(body.post_id, "post id", 80);
        const content = text(body.content, "comment", 2000);
        const rows = await supabaseGet(config, `community_posts?id=eq.${encodeURIComponent(postId)}&deleted_at=is.null&select=id,author_id&limit=1`);
        if (!rows.length) throw new MediaFunctionError("not_found", 404, "The post was not found.");
        const comment = await supabaseInsert(config, "community_comments", { post_id: postId, author_id: identity.id, content });
        if (rows[0].author_id !== identity.id) await supabaseInsert(config, "community_notifications", { recipient_id: rows[0].author_id, actor_id: identity.id, type: "comment", post_id: postId, comment_id: comment.id });
        return json(comment);
      }
      case "toggle_like": {
        const postId = requireString(body.post_id, "post id", 80);
        const rows = await supabaseGet(config, `community_post_likes?post_id=eq.${encodeURIComponent(postId)}&user_id=eq.${encodeURIComponent(identity.id)}&select=post_id&limit=1`);
        if (rows.length) {
          const response = await fetch(`${config.supabaseUrl}/rest/v1/community_post_likes?post_id=eq.${encodeURIComponent(postId)}&user_id=eq.${encodeURIComponent(identity.id)}`, { method: "DELETE", headers: { apikey: config.serviceRoleKey, Authorization: `Bearer ${config.serviceRoleKey}` } });
          if (!response.ok) throw new MediaFunctionError("database_error", 502, "The community service is unavailable.");
          return json({ liked: false });
        }
        await supabaseInsert(config, "community_post_likes", { post_id: postId, user_id: identity.id });
        const posts = await supabaseGet(config, `community_posts?id=eq.${encodeURIComponent(postId)}&select=author_id&limit=1`);
        if (posts.length && posts[0].author_id !== identity.id) await supabaseInsert(config, "community_notifications", { recipient_id: posts[0].author_id, actor_id: identity.id, type: "like", post_id: postId });
        return json({ liked: true });
      }
      case "send_friend_request": {
        const recipient = requireString(body.user_id, "user id", 128);
        if (recipient === identity.id) throw new MediaFunctionError("invalid_input", 400, "You cannot send a friend request to yourself.");
        const existing = await supabaseGet(config, `community_friend_requests?or=(and(requester_id.eq.${encodeURIComponent(identity.id)},recipient_id.eq.${encodeURIComponent(recipient)}),and(requester_id.eq.${encodeURIComponent(recipient)},recipient_id.eq.${encodeURIComponent(identity.id)}))&status=in.(pending,accepted)&select=id,requester_id,status&order=created_at.desc&limit=1`);
        if (existing.length) {
          if (existing[0].status === "accepted") return json({ status: "friends" });
          return json({ status: existing[0].requester_id === identity.id ? "pending" : "incoming" });
        }
        const request = await supabaseInsert(config, "community_friend_requests", { requester_id: identity.id, recipient_id: recipient, status: "pending" });
        await supabaseInsert(config, "community_notifications", { recipient_id: recipient, actor_id: identity.id, type: "friend_request", friend_request_id: request.id });
        return json({ status: "pending" });
      }
      case "update_profile": {
        const bio = typeof body.bio === "string" ? body.bio.trim().slice(0, 2000) : "";
        return json(await supabaseUpdate(config, "community_profiles", `user_id=eq.${encodeURIComponent(identity.id)}`, { bio }));
      }
      case "open_conversation": {
        const otherUserId = requireString(body.user_id, "user id", 128);
        if (otherUserId === identity.id) throw new MediaFunctionError("invalid_input", 400, "You cannot message yourself.");
        const mine = await supabaseGet(config, `community_conversation_members?user_id=eq.${encodeURIComponent(identity.id)}&select=conversation_id&limit=100`);
        const ids = mine.map((row) => row.conversation_id).filter((id) => typeof id === "string");
        if (ids.length) {
          const shared = await supabaseGet(config, `community_conversation_members?conversation_id=in.(${ids.map((id) => encodeURIComponent(id)).join(",")})&user_id=eq.${encodeURIComponent(otherUserId)}&select=conversation_id&limit=1`);
          if (shared.length) return json({ conversation_id: shared[0].conversation_id });
        }
        const conversation = await supabaseInsert(config, "community_conversations", { is_private: true, created_by: identity.id });
        await supabaseInsert(config, "community_conversation_members", { conversation_id: conversation.id, user_id: identity.id });
        await supabaseInsert(config, "community_conversation_members", { conversation_id: conversation.id, user_id: otherUserId });
        return json({ conversation_id: conversation.id });
      }
      case "send_message": {
        const conversationId = requireString(body.conversation_id, "conversation id", 80);
        const content = text(body.content, "message", 5000);
        await member(config, conversationId, identity.id);
        const message = await supabaseInsert(config, "community_messages", { conversation_id: conversationId, sender_id: identity.id, content, message_type: "text" });
        await supabaseUpdate(config, "community_conversations", `id=eq.${encodeURIComponent(conversationId)}`, { updated_at: new Date().toISOString() });
        return json(message);
      }
      case "delete_comment": {
        const commentId = requireString(body.comment_id, "comment id", 80);
        const comments = await supabaseGet(config, `community_comments?id=eq.${encodeURIComponent(commentId)}&author_id=eq.${encodeURIComponent(identity.id)}&deleted_at=is.null&select=id&limit=1`);
        if (!comments.length) throw new MediaFunctionError("forbidden", 403, "You do not have permission for this comment.");
        return json(await supabaseUpdate(config, "community_comments", `id=eq.${encodeURIComponent(commentId)}&author_id=eq.${encodeURIComponent(identity.id)}`, { deleted_at: new Date().toISOString() }));
      }
      case "delete_post": {
        const postId = requireString(body.post_id, "post id", 80);
        await ownedPost(config, postId, identity.id);
        return json(await supabaseUpdate(config, "community_posts", `id=eq.${encodeURIComponent(postId)}&author_id=eq.${encodeURIComponent(identity.id)}`, { deleted_at: new Date().toISOString() }));
      }
      default:
        throw new MediaFunctionError("invalid_input", 400, "Unsupported community action.");
    }
  } catch (error) {
    if (error instanceof MediaFunctionError && error.status === 204) return new Response(null, { status: 204, headers: corsHeaders });
    return errorResponse(error);
  }
});
