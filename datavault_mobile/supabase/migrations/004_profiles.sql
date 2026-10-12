-- 004_profiles.sql
-- Creates the profiles table (if not already created via Supabase dashboard)
-- and applies Row Level Security so users can only read/write their own row.
-- Run in Supabase SQL editor or via: supabase db push

create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  full_name     text not null default '',
  phone         text not null default '',
  avatar_url    text,
  email_notifications boolean not null default true,
  push_notifications  boolean not null default true,
  onboarding_complete boolean not null default false,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

-- Auto-update updated_at on every row change
create or replace function public.handle_profile_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists trg_profiles_updated_at on public.profiles;
create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.handle_profile_updated_at();

-- Row Level Security
alter table public.profiles enable row level security;

-- Each user can read and write only their own profile row.
drop policy if exists "profiles_owner_select" on public.profiles;
create policy "profiles_owner_select" on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "profiles_owner_insert" on public.profiles;
create policy "profiles_owner_insert" on public.profiles
  for insert with check (auth.uid() = id);

drop policy if exists "profiles_owner_update" on public.profiles;
create policy "profiles_owner_update" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

-- Beneficiaries table (created by the app but no prior migration existed)
create table if not exists public.beneficiaries (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  kind       text not null,
  nickname   text not null default '',
  recipient  text not null,
  provider   text not null default '',
  provider_id text not null default '',
  created_at timestamptz default now(),
  -- one entry per user+kind+recipient combination
  unique (user_id, kind, recipient)
);

create index if not exists beneficiaries_user_idx on public.beneficiaries(user_id);

alter table public.beneficiaries enable row level security;

drop policy if exists "beneficiaries_owner_all" on public.beneficiaries;
create policy "beneficiaries_owner_all" on public.beneficiaries
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Notifications table
create table if not exists public.notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  title      text not null default '',
  message    text not null default '',
  read_at    timestamptz,
  created_at timestamptz default now()
);

create index if not exists notifications_user_idx on public.notifications(user_id);

alter table public.notifications enable row level security;

drop policy if exists "notifications_owner_all" on public.notifications;
create policy "notifications_owner_all" on public.notifications
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
