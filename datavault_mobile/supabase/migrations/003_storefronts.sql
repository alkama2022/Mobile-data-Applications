-- 003_storefronts.sql — reseller storefront handles. Run in Supabase SQL editor.
create table if not exists public.storefronts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  handle text unique not null check (handle ~ '^[a-z0-9_]{3,30}$'),
  display_name text not null default '',
  markup_pct numeric not null default 0 check (markup_pct >= 0 and markup_pct <= 50),
  active boolean not null default true,
  created_at timestamptz default now()
);
alter table public.storefronts enable row level security;
drop policy if exists "store_owner_all" on public.storefronts;
create policy "store_owner_all" on public.storefronts for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
drop policy if exists "store_public_read" on public.storefronts;
create policy "store_public_read" on public.storefronts for select using (active = true);
