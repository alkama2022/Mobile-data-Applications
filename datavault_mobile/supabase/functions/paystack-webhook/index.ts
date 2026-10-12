// supabase/functions/paystack-webhook/index.ts
// Verifies Paystack signature, verifies transaction, credits wallet once (idempotent on reference).
// Secrets: PAYSTACK_SECRET_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

async function hmacHex(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-512' }, false, ['sign']);
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(body));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

serve(async (req) => {
  const supa = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  try {
    const raw = await req.text();
    const signature = req.headers.get('x-paystack-signature') ?? '';
    const expected = await hmacHex(Deno.env.get('PAYSTACK_SECRET_KEY') ?? '', raw);
    if (signature !== expected) return Response.json({ ok: false }, { status: 401 });

    const event = JSON.parse(raw);
    if (event?.event !== 'charge.success') return Response.json({ ok: true, ignored: event?.event });

    const ref: string = event.data.reference;
    const amount: number = event.data.amount; // kobo
    const email: string = event.data.customer?.email ?? '';
    const userId: string | undefined = event.data.metadata?.user_id;

    // Verify with Paystack server-side before crediting anything
    // (never trust webhook body alone — always re-verify the reference).
    const vr = await fetch(`https://api.paystack.co/transaction/verify/${ref}`, {
      headers: { Authorization: `Bearer ${Deno.env.get('PAYSTACK_SECRET_KEY') ?? ''}` },
    });
    const vdata = await vr.json();
    if (!vdata?.data || vdata.data.status !== 'success') {
      return Response.json({ ok: false, message: 'Paystack verification failed' }, { status: 402 });
    }
    const uid = userId ?? null;
    if (!uid) return Response.json({ ok: false, message: 'No user_id in metadata' }, { status: 400 });

    // Insert the transaction record first (reference unique index provides idempotency
    // at the DB level — a duplicate webhook will fail here before touching the wallet).
    const { error: txErr } = await supa.from('transactions').insert({
      user_id: uid, kind: 'wallet_funding', title: 'Wallet Top-up',
      recipient: 'DataVault Wallet', amount_kobo: amount,
      reference: ref, provider: 'Paystack', status: 'success',
      metadata: { method: 'card', channel: 'Paystack', email },
    });
    if (txErr) {
      // Unique-constraint violation means this reference was already processed.
      if (txErr.code === '23505') return Response.json({ ok: true, duplicate: true });
      return Response.json({ ok: false, message: 'Failed to record transaction: ' + txErr.message }, { status: 500 });
    }

    // Use the atomic credit_wallet RPC (see migrations/001_wallet_ledger.sql).
    // This is an upsert + increment in a single SQL statement — safe under concurrent
    // webhook deliveries because the transaction insert above already acted as a lock.
    const { error: creditErr } = await supa.rpc('credit_wallet', {
      p_user_id: uid,
      p_amount_kobo: amount,
    });
    if (creditErr) {
      // The transaction row was written but the credit failed — log for manual review.
      console.error('credit_wallet failed for ref', ref, creditErr.message);
      return Response.json({ ok: false, message: 'Wallet credit failed: ' + creditErr.message }, { status: 500 });
    }

    return Response.json({ ok: true });
  } catch (e) {
    return Response.json({ ok: false, message: String(e) }, { status: 500 });
  }
});
