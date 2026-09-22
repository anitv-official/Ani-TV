alter function public.community_current_user_id() set search_path = public;
revoke execute on function public.community_current_user_id() from anon, authenticated;

drop policy if exists community_post_media_owner_write on public.community_post_media;
create policy community_post_media_owner_insert on public.community_post_media for insert with check (exists (select 1 from public.community_posts p where p.id = post_id and p.author_id = public.community_current_user_id()));
create policy community_post_media_owner_update on public.community_post_media for update using (exists (select 1 from public.community_posts p where p.id = post_id and p.author_id = public.community_current_user_id())) with check (exists (select 1 from public.community_posts p where p.id = post_id and p.author_id = public.community_current_user_id()));
create policy community_post_media_owner_delete on public.community_post_media for delete using (exists (select 1 from public.community_posts p where p.id = post_id and p.author_id = public.community_current_user_id()));

create index if not exists community_comments_author_idx on public.community_comments (author_id);
create index if not exists community_conversations_created_by_idx on public.community_conversations (created_by);
create index if not exists community_messages_sender_idx on public.community_messages (sender_id);
create index if not exists community_notifications_actor_idx on public.community_notifications (actor_id);
create index if not exists community_notifications_comment_idx on public.community_notifications (comment_id);
create index if not exists community_notifications_conversation_idx on public.community_notifications (conversation_id);
create index if not exists community_notifications_message_idx on public.community_notifications (message_id);
create index if not exists community_notifications_friend_request_idx on public.community_notifications (friend_request_id);
create index if not exists community_notifications_post_idx on public.community_notifications (post_id);
create index if not exists community_post_likes_user_idx on public.community_post_likes (user_id);
