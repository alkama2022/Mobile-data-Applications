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

    // Idempotency: skip if reference already recorded
    const { data: existing } = await supa.from('transactions').select('id').eq('reference', ref).maybeSingle();
    if (existing) return Response.json({ ok: true, duplicate: true });

    // Verify with Paystack server-side (never trust webhook body alone)
    const vr = await fetch(`https://api.paystack.co/transaction/verify/${ref}`, {
      headers: { Authorization: `Bearer ${Deno.env.get('PAYSTACK_SECRET_KEY') ?? ''}` },
    });
    const vdata = await vr.json();
    if (!vdata?.data || vdata.data.status !== 'success') {
      return Response.json({ ok: false, message: 'Paystack verification failed' }, { status: 402 });
    }
    const uid = userId ?? null;
    if (!uid) return Response.json({ ok: false, message: 'No user_id in metadata' }, { status: 400 });

    await supa.from('transactions').insert({
      user_id: uid, kind: 'wallet_funding', title: 'Wallet Top-up',
      recipient: 'DataVault Wallet', amount_kobo: amount,
      reference: ref, provider: 'Paystack', status: 'success',
      metadata: { method: 'card', channel: 'Paystack', email },
    });
    // Upsert + credit
    const { data: wallet } = await supa.from('wallets').select().eq('user_id', uid).maybeSingle();
    if (!wallet) {
      await supa.from('wallets').insert({ user_id: uid, balance_kobo: amount });
    } else {
      await supa.from('wallets').update({ balance_kobo: (wallet.balance_kobo ?? 0) + amount }).eq('user_id', uid);
    }
    return Response.json({ ok: true });
  } catch (e) {
    return Response.json({ ok: false, message: String(e) }, { status: 500 });
  }
});
