// supabase/functions/paystack-webhook/index.ts
// Verifies Paystack signature, re-verifies transaction with Paystack API,
// then atomically credits wallet once (idempotent via unique reference index).
// Secrets: PAYSTACK_SECRET_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Constant-time HMAC-SHA-512 to prevent timing attacks on signature check.
async function hmacHex(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-512' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(body));
  return [...new Uint8Array(sig)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

// XOR-based constant-time string comparison — prevents timing attacks.
function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

serve(async (req) => {
  if (req.method !== 'POST') {
    return Response.json({ ok: false, message: 'POST only' }, { status: 405 });
  }

  const paystackKey = Deno.env.get('PAYSTACK_SECRET_KEY') ?? '';
  if (!paystackKey) {
    return Response.json({ ok: false, message: 'Paystack key not configured' }, { status: 500 });
  }

  const supa = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  try {
    const raw = await req.text();

    // 1. Verify Paystack HMAC signature (constant-time).
    const signature = req.headers.get('x-paystack-signature') ?? '';
    const expected = await hmacHex(paystackKey, raw);
    if (!constantTimeEqual(signature, expected)) {
      return Response.json({ ok: false }, { status: 401 });
    }

    const event = JSON.parse(raw);
    if (event?.event !== 'charge.success') {
      return Response.json({ ok: true, ignored: event?.event });
    }

    const ref: string = event.data?.reference ?? '';
    const webhookAmount: number = event.data?.amount ?? 0;
    if (!ref) {
      return Response.json({ ok: false, message: 'Missing reference' }, { status: 400 });
    }

    // 2. Re-verify with Paystack API — never trust the webhook body alone.
    const vr = await fetch(
      `https://api.paystack.co/transaction/verify/${encodeURIComponent(ref)}`,
      { headers: { Authorization: `Bearer ${paystackKey}` } },
    );
    const vdata = await vr.json();
    const tx = vdata?.data;
    if (
      vdata?.status !== true ||
      tx?.status !== 'success' ||
      tx?.reference !== ref ||
      tx?.currency !== 'NGN'
    ) {
      return Response.json({ ok: false, message: 'Paystack verification failed' }, { status: 402 });
    }

    // 3. Amount sanity — verified amount must match the webhook body.
    const amount: number = tx.amount;
    if (!Number.isSafeInteger(amount) || amount <= 0 || amount !== webhookAmount) {
      return Response.json(
        { ok: false, message: 'Amount mismatch between webhook and verification' },
        { status: 400 },
      );
    }

    // 4. Extract and validate user metadata.
    const userId: string = tx.metadata?.user_id ?? '';
    const email: string = tx.customer?.email ?? '';
    if (!userId) {
      return Response.json({ ok: false, message: 'No user_id in metadata' }, { status: 400 });
    }

    // 5. Insert transaction — unique index on `reference` provides idempotency.
    //    A second delivery for the same reference will hit the unique constraint
    //    and return a 23505 error, which we treat as a duplicate (already done).
    const { error: txErr } = await supa.from('transactions').insert({
      user_id: userId,
      kind: 'wallet_funding',
      title: 'Wallet Top-up',
      recipient: 'DataVault Wallet',
      amount_kobo: amount,
      reference: ref,
      provider: 'Paystack',
      status: 'success',
      metadata: { method: 'card', channel: 'Paystack', email },
    });

    if (txErr) {
      if (txErr.code === '23505') {
        // Duplicate — already processed.
        return Response.json({ ok: true, duplicate: true });
      }
      console.error('Transaction insert failed', ref, txErr.message);
      return Response.json(
        { ok: false, message: 'Failed to record transaction: ' + txErr.message },
        { status: 500 },
      );
    }

    // 6. Atomic wallet credit via the RPC defined in 001_wallet_ledger.sql.
    //    This is an upsert + increment in a single SQL statement.
    const { error: creditErr } = await supa.rpc('credit_wallet', {
      p_user_id: userId,
      p_amount_kobo: amount,
    });
    if (creditErr) {
      // Transaction row was written but credit failed — alert for manual review.
      console.error('credit_wallet failed for ref', ref, creditErr.message);
      return Response.json(
        { ok: false, message: 'Wallet credit failed: ' + creditErr.message },
        { status: 500 },
      );
    }

    return Response.json({ ok: true });
  } catch (e) {
    console.error('Webhook error', e);
    return Response.json({ ok: false, message: String(e) }, { status: 500 });
  }
});
