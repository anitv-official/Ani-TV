revoke execute on function public.community_current_user_id() from public, anon, authenticated;
alter function public.community_set_updated_at() set search_path = public;
