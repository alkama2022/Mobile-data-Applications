-- 002_schedules.sql — auto-buy / scheduled payments. Run in Supabase SQL editor.
create table if not exists public.schedules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null,
  provider text not null default '',
  provider_id text not null default '',
  recipient text not null,
  amount_kobo bigint not null check (amount_kobo >= 10000),
  product_id text,
  frequency text not null default 'monthly' check (frequency in ('once','daily','weekly','monthly')),
  next_run_at timestamptz not null default now(),
  last_run_at timestamptz,
  active boolean not null default true,
  metadata jsonb not null default '{}',
  created_at timestamptz default now()
);
create index if not exists schedules_user_idx on public.schedules(user_id);
create index if not exists schedules_due_idx on public.schedules(active, next_run_at);

alter table public.schedules enable row level security;
drop policy if exists "sched_owner_all" on public.schedules;
create policy "sched_owner_all" on public.schedules for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
