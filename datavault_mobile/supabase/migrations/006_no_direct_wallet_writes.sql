-- 006_no_direct_wallet_writes.sql
-- Regression guard: clients must NEVER write wallets/transactions directly.
-- All balance changes go through service_role Edge Functions
-- (debit_wallet / credit_wallet / credit_wallet_for_topup).
-- 001 already creates SELECT-only policies; this migration asserts no
-- INSERT/UPDATE/DELETE policies exist for anon/authenticated and fails loudly
-- if someone adds one later.

do $$
declare
  v_bad int;
begin
  select count(*) into v_bad
  from pg_policies
  where schemaname = 'public'
    and tablename in ('wallets', 'transactions')
    and cmd in ('INSERT', 'UPDATE', 'DELETE')
    and roles::text like '%authenticated%';

  if v_bad > 0 then
    raise exception 'Direct client write policy detected on wallets/transactions (% policies). Remove it — writes go through Edge Functions only.', v_bad;
  end if;
end $$;
