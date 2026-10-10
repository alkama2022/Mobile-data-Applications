// supabase/functions/paystack-init/index.ts
// Initialises a Paystack checkout for wallet funding.
// Secrets: PAYSTACK_SECRET_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, APP_CALLBACK_URL
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  if (req.method !== 'POST') return Response.json({ ok: false, message: 'POST only' }, { status: 405 });
  const supa = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  try {
    const auth = req.headers.get('Authorization') ?? '';
    const { data: { user } } = await supa.auth.getUser(auth.replace('Bearer ', ''));
    if (!user) return Response.json({ ok: false, message: 'Not authenticated' }, { status: 401 });

    const { email, amount_kobo, reference } = await req.json();
    if (!email || !amount_kobo || amount_kobo < 10000) {
      return Response.json({ ok: false, message: 'Valid email and min ₦100 required' }, { status: 400 });
    }
    const r = await fetch('https://api.paystack.co/transaction/initialize', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('PAYSTACK_SECRET_KEY') ?? ''}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email, amount: amount_kobo, reference,
        callback_url: Deno.env.get('APP_CALLBACK_URL') ?? undefined,
        metadata: { user_id: user.id, purpose: 'wallet_funding' },
      }),
    });
    const data = await r.json();
    if (!data?.status) {
      return Response.json({ ok: false, message: data?.message ?? 'Paystack init failed', raw: data }, { status: 502 });
    }
    return Response.json({ ok: true, data: data.data });
  } catch (e) {
    return Response.json({ ok: false, message: String(e) }, { status: 500 });
  }
});
