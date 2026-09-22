create or replace function public.community_is_conversation_member(target_conversation_id uuid, target_user_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select target_user_id = public.community_current_user_id()
    and exists (
      select 1 from public.community_conversation_members m
      where m.conversation_id = target_conversation_id and m.user_id = target_user_id
    );
$$;

create or replace function public.community_is_conversation_creator(target_conversation_id uuid, target_user_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select target_user_id = public.community_current_user_id()
    and exists (
      select 1 from public.community_conversations c
      where c.id = target_conversation_id and c.created_by = target_user_id
    );
$$;

grant execute on function public.community_is_conversation_member(uuid, text) to anon, authenticated;
grant execute on function public.community_is_conversation_creator(uuid, text) to anon, authenticated;
