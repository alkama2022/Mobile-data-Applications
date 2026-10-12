// supabase/functions/vtu-query/index.ts
// Requery a pending VTpass request_id and sync the transaction row.
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const BASE = Deno.env.get('VTPASS_BASE_URL') ?? 'https://vtpass.com';

serve(async (req) => {
  if (req.method !== 'POST') return Response.json({ ok: false, message: 'POST only' }, { status: 405 });
  const supa = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const apiKey = Deno.env.get('VTPASS_API_KEY');
  const secretKey = Deno.env.get('VTPASS_SECRET_KEY');
  if (!apiKey || !secretKey) return Response.json({ ok: false, message: 'VTpass keys not configured' }, { status: 500 });
  try {
    const { request_id } = await req.json();
    if (!request_id) return Response.json({ ok: false, message: 'request_id required' }, { status: 400 });
    const r = await fetch(`${BASE}/api/requery`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'api-key': apiKey,
        'secret-key': secretKey,
      },
      body: JSON.stringify({ request_id }),
    });
    const vt = await r.json();
    return Response.json({ ok: true, vtpass: vt });
  } catch (e) {
    return Response.json({ ok: false, message: String(e) }, { status: 500 });
  }
});
