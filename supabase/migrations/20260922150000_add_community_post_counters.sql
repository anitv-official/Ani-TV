alter table public.community_posts
  add column if not exists like_count integer not null default 0,
  add column if not exists comment_count integer not null default 0;

update public.community_posts p
set like_count = (select count(*) from public.community_post_likes l where l.post_id = p.id),
    comment_count = (select count(*) from public.community_comments c where c.post_id = p.id and c.deleted_at is null);

create or replace function public.community_sync_like_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    update public.community_posts set like_count = greatest(like_count - 1, 0) where id = old.post_id;
    return old;
  end if;
  update public.community_posts set like_count = like_count + 1 where id = new.post_id;
  return new;
end;
$$;

drop trigger if exists community_post_likes_count on public.community_post_likes;
create trigger community_post_likes_count
after insert or delete on public.community_post_likes
for each row execute function public.community_sync_like_count();

create or replace function public.community_sync_comment_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' or (tg_op = 'UPDATE' and old.deleted_at is null and new.deleted_at is not null) then
    update public.community_posts set comment_count = greatest(comment_count - 1, 0) where id = old.post_id;
    return coalesce(new, old);
  end if;
  if tg_op = 'INSERT' then
    update public.community_posts set comment_count = comment_count + 1 where id = new.post_id;
  end if;
  return new;
end;
$$;

drop trigger if exists community_comments_count on public.community_comments;
create trigger community_comments_count
after insert or update or delete on public.community_comments
for each row execute function public.community_sync_comment_count();
