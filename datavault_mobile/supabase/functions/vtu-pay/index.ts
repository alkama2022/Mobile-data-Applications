// supabase/functions/vtu-pay/index.ts
// Debit wallet atomically -> call VTpass /api/pay -> record transaction.
// Secrets: VTPASS_API_KEY, VTPASS_SECRET_KEY, VTPASS_BASE_URL, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const BASE = Deno.env.get('VTPASS_BASE_URL') ?? 'https://vtpass.com';

serve(async (req) => {
  if (req.method !== 'POST') return Response.json({ ok: false, message: 'POST only' }, { status: 405 });
  const supa = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);

  try {
    const auth = req.headers.get('Authorization') ?? '';
    const jwt = auth.replace('Bearer ', '');
    const { data: { user } } = await supa.auth.getUser(jwt);
    if (!user) return Response.json({ ok: false, message: 'Not authenticated' }, { status: 401 });

    const { kind, title, recipient, amount_kobo, reference, provider, vtpass, metadata } = await req.json();
    if (!kind || !recipient || !amount_kobo || !reference || !vtpass?.serviceID) {
      return Response.json({ ok: false, message: 'Missing kind/recipient/amount/reference/vtpass.serviceID' }, { status: 400 });
    }

    // 1. Atomic debit (fails if insufficient funds). See migrations/001_wallet_ledger.sql
    const { data: debit, error: debitErr } = await supa.rpc('debit_wallet', {
      p_user_id: user.id,
      p_amount_kobo: amount_kobo,
    });
    if (debitErr) {
      return Response.json({ ok: false, message: 'Insufficient wallet balance or wallet missing' }, { status: 402 });
    }

    // 2. Insert pending transaction
    const { data: tx, error: txErr } = await supa.from('transactions').insert({
      user_id: user.id,
      kind, title: title ?? kind,
      recipient, amount_kobo, reference,
      provider, status: 'pending',
      metadata: { ...(metadata ?? {}), vtpass, new_balance_kobo: debit },
    }).select().single();
    if (txErr) {
      // refund on bookkeeping failure
      await supa.rpc('credit_wallet', { p_user_id: user.id, p_amount_kobo: amount_kobo });
      return Response.json({ ok: false, message: 'Could not book transaction: ' + txErr.message }, { status: 500 });
    }

    // 3. Call VTpass
    const payBody = {
      request_id: reference,
      serviceID: vtpass.serviceID,
      billersCode: vtpass.billersCode ?? recipient,
      variation_code: vtpass.variation_code ?? '',
      amount: Math.round(amount_kobo / 100),
      phone: vtpass.phone ?? recipient,
    };
    const apiKey = Deno.env.get('VTPASS_API_KEY');
    const secretKey = Deno.env.get('VTPASS_SECRET_KEY');
    if (!apiKey || !secretKey) {
      return Response.json({ ok: false, message: 'VTpass keys not configured' }, { status: 500 });
    }
    const r = await fetch(`${BASE}/api/pay`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'api-key': apiKey,
        'secret-key': secretKey,
      },
      body: JSON.stringify(payBody),
    });
    const vt = await r.json();
    const code: string = vt?.code ?? '';
    const success = code === '000';

    // VTpass returns electricity tokens / PINs inside content
    const content = vt?.content ?? {};
    const token = content?.purchased_code ?? content?.pin ?? content?.token ?? null;

    const { data: updated } = await supa.from('transactions').update({
      status: success ? 'success' : 'failed',
      metadata: {
        ...(metadata ?? {}), vtpass,
        vtpass_response: vt,
        token, serialNumber: content?.serialNumber ?? null,
      },
    }).eq('id', tx.id).select().single();

    if (!success) {
      // auto-refund failed VTU purchase
      await supa.rpc('credit_wallet', { p_user_id: user.id, p_amount_kobo: amount_kobo });
      return Response.json({ ok: false, message: vt?.response_description ?? 'VTU provider declined', transaction: updated ?? tx });
    }

    return Response.json({ ok: true, transaction: updated ?? tx });
  } catch (e) {
    return Response.json({ ok: false, message: String(e) }, { status: 500 });
  }
});
