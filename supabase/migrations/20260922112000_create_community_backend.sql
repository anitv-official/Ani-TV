create extension if not exists pgcrypto;

-- Appwrite remains the identity authority. This claim is populated only by a
-- future trusted Appwrite -> Supabase JWT/Edge Function bridge. Client input is
-- never trusted as an identity claim by RLS.
create or replace function public.community_current_user_id()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'appwrite_user_id';
$$;

create table if not exists public.community_profiles (
  user_id text primary key,
  username text not null,
  display_name text,
  country text,
  date_of_birth date,
  bio text not null default '',
  is_verified boolean not null default false,
  verified_at timestamptz,
  verified_by text,
  profile_image_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint community_profiles_username_key unique (username),
  constraint community_profiles_verification_consistency check (is_verified or (verified_at is null and verified_by is null))
);

create table if not exists public.community_profile_favorites (
  id uuid primary key default gen_random_uuid(),
  user_id text not null references public.community_profiles(user_id) on delete cascade,
  item_type text not null,
  item_id text not null,
  title text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, item_type, item_id)
);

create table if not exists public.community_posts (
  id uuid primary key default gen_random_uuid(),
  author_id text not null references public.community_profiles(user_id) on delete restrict,
  content text not null default '',
  post_type text not null check (post_type in ('text', 'image', 'audio', 'link', 'mixed')),
  link_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint community_posts_has_content check (length(trim(content)) > 0 or link_url is not null or post_type in ('image', 'audio', 'mixed'))
);

create table if not exists public.community_post_media (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts(id) on delete cascade,
  media_type text not null check (media_type in ('image', 'audio')),
  storage_provider text not null check (storage_provider in ('backblaze_b2', 'pending')),
  storage_key text not null,
  file_name text,
  mime_type text,
  file_size bigint,
  duration_ms bigint,
  width integer,
  height integer,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.community_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.community_posts(id) on delete cascade,
  author_id text not null references public.community_profiles(user_id) on delete restrict,
  content text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint community_comments_content_not_blank check (length(trim(content)) > 0)
);

create table if not exists public.community_post_likes (
  post_id uuid not null references public.community_posts(id) on delete cascade,
  user_id text not null references public.community_profiles(user_id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.community_friend_requests (
  id uuid primary key default gen_random_uuid(),
  requester_id text not null references public.community_profiles(user_id) on delete cascade,
  recipient_id text not null references public.community_profiles(user_id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected', 'cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint community_friend_requests_not_self check (requester_id <> recipient_id)
);
create unique index if not exists community_friend_requests_active_pair_idx
  on public.community_friend_requests (requester_id, recipient_id)
  where status in ('pending', 'accepted');

create table if not exists public.community_friendships (
  id uuid primary key default gen_random_uuid(),
  user_low_id text not null references public.community_profiles(user_id) on delete cascade,
  user_high_id text not null references public.community_profiles(user_id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint community_friendships_ordered check (user_low_id < user_high_id),
  unique (user_low_id, user_high_id)
);

create table if not exists public.community_conversations (
  id uuid primary key default gen_random_uuid(),
  is_private boolean not null default true,
  created_by text not null references public.community_profiles(user_id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.community_conversation_members (
  conversation_id uuid not null references public.community_conversations(id) on delete cascade,
  user_id text not null references public.community_profiles(user_id) on delete cascade,
  joined_at timestamptz not null default now(),
  last_read_at timestamptz,
  primary key (conversation_id, user_id)
);

create table if not exists public.community_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.community_conversations(id) on delete cascade,
  sender_id text not null references public.community_profiles(user_id) on delete restrict,
  content text not null default '',
  message_type text not null default 'text' check (message_type in ('text', 'image', 'audio', 'system')),
  media_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  edited_at timestamptz,
  deleted_at timestamptz,
  constraint community_messages_content_check check (length(trim(content)) > 0 or media_reference is not null)
);

create table if not exists public.community_message_reads (
  message_id uuid not null references public.community_messages(id) on delete cascade,
  user_id text not null references public.community_profiles(user_id) on delete cascade,
  status text not null check (status in ('sent', 'delivered', 'read')),
  read_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

create table if not exists public.community_notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id text not null references public.community_profiles(user_id) on delete cascade,
  actor_id text references public.community_profiles(user_id) on delete set null,
  type text not null check (type in ('friend_request', 'friend_request_accepted', 'like', 'comment', 'message', 'verification', 'mention', 'system')),
  post_id uuid references public.community_posts(id) on delete set null,
  comment_id uuid references public.community_comments(id) on delete set null,
  conversation_id uuid references public.community_conversations(id) on delete set null,
  message_id uuid references public.community_messages(id) on delete set null,
  friend_request_id uuid references public.community_friend_requests(id) on delete set null,
  is_read boolean not null default false,
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists community_profiles_username_idx on public.community_profiles (lower(username));
create index if not exists community_posts_author_created_idx on public.community_posts (author_id, created_at desc) where deleted_at is null;
create index if not exists community_posts_created_idx on public.community_posts (created_at desc) where deleted_at is null;
create index if not exists community_post_media_post_sort_idx on public.community_post_media (post_id, sort_order);
create index if not exists community_comments_post_created_idx on public.community_comments (post_id, created_at desc) where deleted_at is null;
create index if not exists community_likes_post_idx on public.community_post_likes (post_id);
create index if not exists community_friend_requests_recipient_idx on public.community_friend_requests (recipient_id, created_at desc);
create index if not exists community_friend_requests_requester_idx on public.community_friend_requests (requester_id, created_at desc);
create index if not exists community_friendships_low_idx on public.community_friendships (user_low_id);
create index if not exists community_friendships_high_idx on public.community_friendships (user_high_id);
create index if not exists community_members_user_idx on public.community_conversation_members (user_id, joined_at desc);
create index if not exists community_messages_conversation_created_idx on public.community_messages (conversation_id, created_at asc) where deleted_at is null;
create index if not exists community_message_reads_user_idx on public.community_message_reads (user_id, updated_at desc);
create index if not exists community_notifications_recipient_created_idx on public.community_notifications (recipient_id, created_at desc);
create index if not exists community_notifications_unread_idx on public.community_notifications (recipient_id, created_at desc) where is_read = false;

create or replace function public.community_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

do $$
declare
  table_name text;
begin
  foreach table_name in array array['community_profiles','community_profile_favorites','community_posts','community_comments','community_friend_requests','community_conversations','community_messages'] loop
    execute format('drop trigger if exists %I on public.%I', table_name || '_updated_at', table_name);
    execute format('create trigger %I before update on public.%I for each row execute function public.community_set_updated_at()', table_name || '_updated_at', table_name);
  end loop;
end $$;

alter table public.community_profiles enable row level security;
alter table public.community_profile_favorites enable row level security;
alter table public.community_posts enable row level security;
alter table public.community_post_media enable row level security;
alter table public.community_comments enable row level security;
alter table public.community_post_likes enable row level security;
alter table public.community_friend_requests enable row level security;
alter table public.community_friendships enable row level security;
alter table public.community_conversations enable row level security;
alter table public.community_conversation_members enable row level security;
alter table public.community_messages enable row level security;
alter table public.community_message_reads enable row level security;
alter table public.community_notifications enable row level security;

-- Public community reads are intentionally limited to non-deleted content. All
-- identity-sensitive writes use the trusted Appwrite JWT claim helper.
create policy community_profiles_public_read on public.community_profiles for select using (true);
create policy community_profiles_self_insert on public.community_profiles for insert with check (user_id = public.community_current_user_id());
create policy community_profiles_self_update on public.community_profiles for update using (user_id = public.community_current_user_id()) with check (user_id = public.community_current_user_id());
create policy community_profiles_self_favorites on public.community_profile_favorites for all using (user_id = public.community_current_user_id()) with check (user_id = public.community_current_user_id());

create policy community_posts_public_read on public.community_posts for select using (deleted_at is null);
create policy community_posts_owner_insert on public.community_posts for insert with check (author_id = public.community_current_user_id());
create policy community_posts_owner_update on public.community_posts for update using (author_id = public.community_current_user_id()) with check (author_id = public.community_current_user_id());
create policy community_posts_owner_delete on public.community_posts for delete using (author_id = public.community_current_user_id());
create policy community_post_media_public_read on public.community_post_media for select using (exists (select 1 from public.community_posts p where p.id = post_id and p.deleted_at is null));
create policy community_post_media_owner_write on public.community_post_media for all using (exists (select 1 from public.community_posts p where p.id = post_id and p.author_id = public.community_current_user_id())) with check (exists (select 1 from public.community_posts p where p.id = post_id and p.author_id = public.community_current_user_id()));

create policy community_comments_public_read on public.community_comments for select using (deleted_at is null);
create policy community_comments_identity_insert on public.community_comments for insert with check (author_id = public.community_current_user_id());
create policy community_comments_owner_update on public.community_comments for update using (author_id = public.community_current_user_id()) with check (author_id = public.community_current_user_id());
create policy community_comments_owner_delete on public.community_comments for delete using (author_id = public.community_current_user_id());

create policy community_likes_public_read on public.community_post_likes for select using (true);
create policy community_likes_identity_write on public.community_post_likes for insert with check (user_id = public.community_current_user_id());
create policy community_likes_identity_delete on public.community_post_likes for delete using (user_id = public.community_current_user_id());

create policy community_friend_requests_participant_read on public.community_friend_requests for select using (requester_id = public.community_current_user_id() or recipient_id = public.community_current_user_id());
create policy community_friend_requests_requester_insert on public.community_friend_requests for insert with check (requester_id = public.community_current_user_id() and requester_id <> recipient_id);
create policy community_friend_requests_participant_update on public.community_friend_requests for update using (requester_id = public.community_current_user_id() or recipient_id = public.community_current_user_id()) with check (requester_id = public.community_current_user_id() or recipient_id = public.community_current_user_id());
create policy community_friendships_participant_read on public.community_friendships for select using (user_low_id = public.community_current_user_id() or user_high_id = public.community_current_user_id());

create policy community_conversations_member_read on public.community_conversations for select using (exists (select 1 from public.community_conversation_members m where m.conversation_id = id and m.user_id = public.community_current_user_id()));
create policy community_conversations_identity_insert on public.community_conversations for insert with check (created_by = public.community_current_user_id());
create policy community_conversations_creator_update on public.community_conversations for update using (created_by = public.community_current_user_id());
create policy community_members_member_read on public.community_conversation_members for select using (user_id = public.community_current_user_id() or exists (select 1 from public.community_conversations c where c.id = conversation_id and c.created_by = public.community_current_user_id()));
create policy community_members_self_or_creator_insert on public.community_conversation_members for insert with check (user_id = public.community_current_user_id() or exists (select 1 from public.community_conversations c where c.id = conversation_id and c.created_by = public.community_current_user_id()));
create policy community_members_self_update on public.community_conversation_members for update using (user_id = public.community_current_user_id()) with check (user_id = public.community_current_user_id());

create policy community_messages_member_read on public.community_messages for select using (exists (select 1 from public.community_conversation_members m where m.conversation_id = conversation_id and m.user_id = public.community_current_user_id()));
create policy community_messages_member_insert on public.community_messages for insert with check (sender_id = public.community_current_user_id() and exists (select 1 from public.community_conversation_members m where m.conversation_id = community_messages.conversation_id and m.user_id = public.community_current_user_id()));
create policy community_messages_sender_update on public.community_messages for update using (sender_id = public.community_current_user_id()) with check (sender_id = public.community_current_user_id());
create policy community_messages_sender_delete on public.community_messages for delete using (sender_id = public.community_current_user_id());
create policy community_message_reads_member_access on public.community_message_reads for all using (user_id = public.community_current_user_id() and exists (select 1 from public.community_messages msg join public.community_conversation_members m on m.conversation_id = msg.conversation_id where msg.id = message_id and m.user_id = public.community_current_user_id())) with check (user_id = public.community_current_user_id());

create policy community_notifications_recipient_read on public.community_notifications for select using (recipient_id = public.community_current_user_id());
create policy community_notifications_recipient_update on public.community_notifications for update using (recipient_id = public.community_current_user_id()) with check (recipient_id = public.community_current_user_id());

comment on function public.community_current_user_id() is 'Returns the Appwrite user ID only from a trusted JWT claim. Client-supplied IDs are never used for RLS identity.';
comment on table public.community_post_media is 'Metadata only. Binary files are expected to live behind a future secure Backblaze B2 upload service.';
comment on table public.community_notifications is 'Separate from notification_history; existing notification infrastructure is preserved unchanged.';

alter table public.community_messages replica identity full;
alter table public.community_message_reads replica identity full;
alter table public.community_notifications replica identity full;
alter table public.community_friend_requests replica identity full;
alter table public.community_comments replica identity full;
alter table public.community_post_likes replica identity full;

do $$
declare
  table_name text;
begin
  foreach table_name in array array['community_messages','community_message_reads','community_notifications','community_friend_requests','community_comments','community_post_likes'] loop
    if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = table_name) then
      execute format('alter publication supabase_realtime add table public.%I', table_name);
    end if;
  end loop;
end $$;
