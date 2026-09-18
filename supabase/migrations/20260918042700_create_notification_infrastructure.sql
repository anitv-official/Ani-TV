create extension if not exists pgcrypto;

create table if not exists public.notification_history (
  id uuid primary key default gen_random_uuid(), user_id text not null, title text not null, body text not null,
  type text not null check (type in ('episode','chapter','movie','series','drama','broadcast','update','news')),
  item_id text, source text, url text, payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), read_at timestamptz
);
create index if not exists notification_history_user_created_idx on public.notification_history (user_id, created_at desc);
create index if not exists notification_history_unread_idx on public.notification_history (user_id, read_at) where read_at is null;

create table if not exists public.notification_deliveries (
  dedupe_key text primary key, user_id text not null, type text not null, source text, item_id text,
  content_number text, notification_id uuid references public.notification_history(id) on delete set null,
  status text not null check (status in ('pending','sent','failed')) default 'pending', attempts integer not null default 0,
  last_error text, created_at timestamptz not null default now(), sent_at timestamptz
);

create table if not exists public.favorite_scan_runs (
  id uuid primary key default gen_random_uuid(), dry_run boolean not null default false, scanned integer not null default 0,
  checked integer not null default 0, notified integer not null default 0, skipped integer not null default 0,
  failed integer not null default 0, status text not null check (status in ('running','completed','failed')) default 'running',
  error_message text, started_at timestamptz not null default now(), completed_at timestamptz
);

alter table public.notification_history enable row level security;
alter table public.notification_deliveries enable row level security;
alter table public.favorite_scan_runs enable row level security;
revoke all on public.notification_history from anon, authenticated;
revoke all on public.notification_deliveries from anon, authenticated;
revoke all on public.favorite_scan_runs from anon, authenticated;

comment on table public.notification_history is 'Server-written notification history; users access rows through a trusted API after Appwrite identity verification.';
comment on table public.notification_deliveries is 'Idempotency ledger for server-side push delivery.';
comment on table public.favorite_scan_runs is 'Server-side summaries for scheduled Appwrite favorite scans.';
