create or replace function public.community_is_conversation_member(target_conversation_id uuid, target_user_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.community_conversation_members m
    where m.conversation_id = target_conversation_id
      and m.user_id = target_user_id
  );
$$;

create or replace function public.community_is_conversation_creator(target_conversation_id uuid, target_user_id text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.community_conversations c
    where c.id = target_conversation_id
      and c.created_by = target_user_id
  );
$$;

revoke execute on function public.community_is_conversation_member(uuid, text) from public, anon, authenticated;
revoke execute on function public.community_is_conversation_creator(uuid, text) from public, anon, authenticated;

drop policy if exists community_conversations_member_read on public.community_conversations;
drop policy if exists community_members_member_read on public.community_conversation_members;
drop policy if exists community_members_self_or_creator_insert on public.community_conversation_members;
drop policy if exists community_messages_member_read on public.community_messages;
drop policy if exists community_messages_member_insert on public.community_messages;
drop policy if exists community_message_reads_member_access on public.community_message_reads;

create policy community_conversations_member_read
on public.community_conversations for select
using (public.community_is_conversation_member(id, public.community_current_user_id()));

create policy community_members_member_read
on public.community_conversation_members for select
using (user_id = public.community_current_user_id()
  or public.community_is_conversation_creator(conversation_id, public.community_current_user_id()));

create policy community_members_self_or_creator_insert
on public.community_conversation_members for insert
with check (user_id = public.community_current_user_id()
  or public.community_is_conversation_creator(conversation_id, public.community_current_user_id()));

create policy community_messages_member_read
on public.community_messages for select
using (public.community_is_conversation_member(conversation_id, public.community_current_user_id()));

create policy community_messages_member_insert
on public.community_messages for insert
with check (sender_id = public.community_current_user_id()
  and public.community_is_conversation_member(conversation_id, public.community_current_user_id()));

create policy community_message_reads_member_access
on public.community_message_reads for all
using (user_id = public.community_current_user_id()
  and exists (
    select 1
    from public.community_messages msg
    where msg.id = message_id
      and public.community_is_conversation_member(msg.conversation_id, public.community_current_user_id())
  ))
with check (user_id = public.community_current_user_id());

alter function public.community_is_conversation_member(uuid, text) set search_path = public;
alter function public.community_is_conversation_creator(uuid, text) set search_path = public;
