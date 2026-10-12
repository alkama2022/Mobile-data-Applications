-- Restrict wallet mutation RPCs to trusted Edge Functions using the service role.
-- Run after the existing migrations, including 001_wallet_ledger.sql.

alter function public.debit_wallet(uuid, bigint)
  set search_path = pg_catalog, public;
alter function public.credit_wallet(uuid, bigint)
  set search_path = pg_catalog, public;

revoke all on function public.debit_wallet(uuid, bigint)
  from public, anon, authenticated;
revoke all on function public.credit_wallet(uuid, bigint)
  from public, anon, authenticated;

grant execute on function public.debit_wallet(uuid, bigint) to service_role;
grant execute on function public.credit_wallet(uuid, bigint) to service_role;

-- Record and credit a Paystack top-up in the same database transaction. A
-- duplicate webhook cannot credit twice, and a failed credit rolls the insert back.
create or replace function public.credit_wallet_for_topup(
  p_user_id uuid,
  p_amount_kobo bigint,
  p_reference text,
  p_email text
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_existing public.transactions%rowtype;
begin
  if p_amount_kobo <= 0 or p_reference is null or length(trim(p_reference)) = 0 then
    raise exception 'Invalid top-up details';
  end if;

  insert into public.transactions (
    user_id, kind, title, recipient, amount_kobo, reference, provider, status, metadata
  ) values (
    p_user_id, 'wallet_funding', 'Wallet Top-up', 'DataVault Wallet',
    p_amount_kobo, p_reference, 'Paystack', 'success',
    jsonb_build_object('method', 'card', 'channel', 'Paystack', 'email', p_email)
  )
  on conflict (reference) do nothing;

  if not found then
    select * into v_existing
    from public.transactions
    where reference = p_reference;

    if v_existing.user_id is distinct from p_user_id
      or v_existing.kind is distinct from 'wallet_funding'
      or v_existing.amount_kobo is distinct from p_amount_kobo
    then
      raise exception 'Top-up reference conflicts with an existing transaction';
    end if;
    return false;
  end if;

  insert into public.wallets (user_id, balance_kobo)
  values (p_user_id, p_amount_kobo)
  on conflict (user_id) do update
    set balance_kobo = public.wallets.balance_kobo + excluded.balance_kobo,
        updated_at = now();

  return true;
end;
$$;

revoke all on function public.credit_wallet_for_topup(uuid, bigint, text, text)
  from public, anon, authenticated;
grant execute on function public.credit_wallet_for_topup(uuid, bigint, text, text)
  to service_role;
