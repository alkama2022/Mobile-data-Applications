// supabase/functions/vtu-verify/index.ts
// Verifies meter / smartcard / customer via VTpass merchant-verify.
// Secrets (set via `supabase secrets set`): VTPASS_API_KEY, VTPASS_SECRET_KEY, VTPASS_BASE_URL, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';

const BASE = Deno.env.get('VTPASS_BASE_URL') ?? 'https://vtpass.com';

serve(async (req) => {
  if (req.method !== 'POST') return Response.json({ ok: false, message: 'POST only' }, { status: 405 });
  const apiKey = Deno.env.get('VTPASS_API_KEY');
  const secretKey = Deno.env.get('VTPASS_SECRET_KEY');
  if (!apiKey || !secretKey) return Response.json({ ok: false, message: 'VTpass keys not configured' }, { status: 500 });
  try {
    const { serviceID, billersCode } = await req.json();
    if (!serviceID || !billersCode) {
      return Response.json({ ok: false, message: 'serviceID and billersCode required' }, { status: 400 });
    }
    const r = await fetch(`${BASE}/api/merchant-verify`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'api-key': apiKey,
        'secret-key': secretKey,
      },
      body: JSON.stringify({ serviceID, billersCode }),
    });
    const data = await r.json();
    const content = data?.content;
    if (!content?.Customer_Name && !content?.customer_name) {
      return Response.json({ ok: false, message: data?.response_description ?? 'Could not verify', raw: data });
    }
    return Response.json({
      ok: true,
      customer: {
        name: content.Customer_Name ?? content.customer_name,
        address: content.Address ?? content.address ?? '',
        raw: content,
      },
    });
  } catch (e) {
    return Response.json({ ok: false, message: String(e) }, { status: 500 });
  }
});
