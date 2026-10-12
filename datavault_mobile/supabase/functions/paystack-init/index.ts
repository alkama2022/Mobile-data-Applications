// Initializes an authenticated Paystack checkout for wallet funding.
// Secrets: PAYSTACK_SECRET_KEY, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, APP_CALLBACK_URL
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  if (req.method !== 'POST') {
    return Response.json({ ok: false, message: 'POST only' }, { status: 405 });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const paystackKey = Deno.env.get('PAYSTACK_SECRET_KEY');
  if (!supabaseUrl || !serviceRoleKey || !paystackKey) {
    console.error('Paystack initialization configuration is incomplete');
    return Response.json({ ok: false, message: 'Payment service not configured' }, { status: 500 });
  }

  const supa = createClient(supabaseUrl, serviceRoleKey);
  try {
    const authorization = req.headers.get('Authorization') ?? '';
    const token = authorization.replace(/^Bearer\s+/i, '');
    if (!token || token === authorization) {
      return Response.json({ ok: false, message: 'Not authenticated' }, { status: 401 });
    }
    const { data: { user }, error: authError } = await supa.auth.getUser(token);
    if (authError || !user?.email) {
      return Response.json({ ok: false, message: 'Not authenticated' }, { status: 401 });
    }

    const body = await req.json();
    const amountKobo = body?.amount_kobo;
    const email = body?.email;
    const reference = body?.reference;
    if (
      !Number.isSafeInteger(amountKobo) ||
      amountKobo < 10000 ||
      typeof email !== 'string' ||
      email.toLowerCase() !== user.email.toLowerCase() ||
      typeof reference !== 'string' ||
      !/^[A-Za-z0-9._-]{1,100}$/.test(reference)
    ) {
      return Response.json({ ok: false, message: 'Invalid wallet funding details' }, { status: 400 });
    }

    const response = await fetch('https://api.paystack.co/transaction/initialize', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${paystackKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: user.email,
        amount: amountKobo,
        reference,
        callback_url: Deno.env.get('APP_CALLBACK_URL') ?? undefined,
        metadata: {
          user_id: user.id,
          purpose: 'wallet_funding',
          amount_kobo: amountKobo,
        },
      }),
    });
    const result = await response.json();
    if (!response.ok || result?.status !== true) {
      console.error('Paystack checkout initialization failed', response.status);
      return Response.json(
        { ok: false, message: result?.message ?? 'Could not initialize payment' },
        { status: 502 },
      );
    }
    return Response.json({ ok: true, data: result.data });
  } catch (error) {
    console.error('Paystack initialization failed', error);
    return Response.json({ ok: false, message: 'Could not initialize payment' }, { status: 500 });
  }
});
