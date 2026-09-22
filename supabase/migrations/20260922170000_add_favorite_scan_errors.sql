create table if not exists public.favorite_scan_errors (
  id uuid primary key default gen_random_uuid(),
  favorite_row_id text,
  user_id text,
  item_id text,
  source text,
  content_type text,
  error_message text not null,
  attempts integer not null default 1,
  created_at timestamptz not null default now(),
  resolved_at timestamptz
);

create index if not exists favorite_scan_errors_created_idx
  on public.favorite_scan_errors (created_at desc);
create index if not exists favorite_scan_errors_favorite_idx
  on public.favorite_scan_errors (favorite_row_id, created_at desc);

alter table public.favorite_scan_errors enable row level security;
revoke all on public.favorite_scan_errors from anon, authenticated;

comment on table public.favorite_scan_errors is
  'Server-written Favorite source failures. The scanner records errors and retries on later runs.';
