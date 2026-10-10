-- 001_wallet_ledger.sql
-- Atomic wallet debit/credit + RLS. Run in Supabase SQL editor.

-- Ensure wallets table shape
create table if not exists public.wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  balance_kobo bigint not null default 0 check (balance_kobo >= 0),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Atomic debit: locks row, fails if insufficient
create or replace function public.debit_wallet(p_user_id uuid, p_amount_kobo bigint)
returns bigint language plpgsql security definer as $$
declare v_new bigint;
begin
  if p_amount_kobo <= 0 then raise exception 'Invalid amount'; end if;
  update public.wallets set balance_kobo = balance_kobo - p_amount_kobo, updated_at = now()
  where user_id = p_user_id and balance_kobo >= p_amount_kobo
  returning balance_kobo into v_new;
  if not found then raise exception 'INSUFFICIENT_FUNDS'; end if;
  return v_new;
end $$;

-- Atomic credit (upserts wallet)
create or replace function public.credit_wallet(p_user_id uuid, p_amount_kobo bigint)
returns bigint language plpgsql security definer as $$
declare v_new bigint;
begin
  if p_amount_kobo <= 0 then raise exception 'Invalid amount'; end if;
  insert into public.wallets(user_id, balance_kobo)
  values (p_user_id, p_amount_kobo)
  on conflict (user_id) do update set balance_kobo = public.wallets.balance_kobo + excluded.balance_kobo, updated_at = now()
  returning balance_kobo into v_new;
  return v_new;
end $$;

-- Unique references for idempotency
do $$ begin
  if not exists (select 1 from pg_indexes where indexname = 'transactions_reference_uidx') then
    create unique index transactions_reference_uidx on public.transactions(reference);
  end if;
end $$;

-- RLS
alter table public.wallets enable row level security;
alter table public.transactions enable row level security;

drop policy if exists "wallets_owner_read" on public.wallets;
create policy "wallets_owner_read" on public.wallets for select using (auth.uid() = user_id);

drop policy if exists "tx_owner_read" on public.transactions;
create policy "tx_owner_read" on public.transactions for select using (auth.uid() = user_id);
-- Writes go through service_role Edge Functions only; no direct insert policy for clients.
