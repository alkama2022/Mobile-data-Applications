// supabase/functions/schedule-cron/index.ts
//
// Runs due scheduled payments server-side — no app open required.
//
// Deploy:
//   supabase functions deploy schedule-cron --no-verify-jwt
//
// Wire to pg_cron (run once in Supabase SQL editor):
//   select cron.schedule(
//     'run-due-schedules',
//     '*/5 * * * *',   -- every 5 minutes
//     $$
//       select net.http_post(
//         url    => current_setting('app.supabase_functions_url') || '/schedule-cron',
//         headers => jsonb_build_object(
//           'Content-Type',  'application/json',
//           'Authorization', 'Bearer ' || current_setting('app.service_role_key')
//         ),
//         body   => '{}'::jsonb
//       );
//     $$
//   );
//
// Or use the Supabase dashboard → Database → Scheduled Functions.
//
// Secrets needed (same as vtu-pay):
//   VTPASS_API_KEY, VTPASS_SECRET_KEY, VTPASS_BASE_URL,
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const BASE = Deno.env.get('VTPASS_BASE_URL') ?? 'https://vtpass.com';

// ── helpers ───────────────────────────────────────────────────────────────────

function serviceIDFor(kind: string, providerId: string): string {
  switch (kind) {
    case 'airtime': return `${providerId}-airtime`;
    case 'data':    return `${providerId}-data`;
    default:        return providerId; // electricity, cable, education, etc.
  }
}

function generateReference(): string {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const suffix = Array.from({ length: 6 }, () =>
    chars[Math.floor(Math.random() * chars.length)],
  ).join('');
  const date = new Date().toISOString().slice(0, 10).replace(/-/g, '');
  return `DVT-${date}-${suffix}`;
}

function nextAfter(freq: string, from: Date): Date {
  const d = new Date(from);
  switch (freq) {
    case 'daily':   d.setDate(d.getDate() + 1); break;
    case 'weekly':  d.setDate(d.getDate() + 7); break;
    case 'monthly': d.setMonth(d.getMonth() + 1); break;
  }
  return d;
}

// ── main handler ──────────────────────────────────────────────────────────────

serve(async (req) => {
  // Only accept POST from authorised callers (pg_cron / dashboard).
  // The function is deployed with --no-verify-jwt but we check the
  // Authorization header for the service-role key as a lightweight guard.
  const authHeader = req.headers.get('Authorization') ?? '';
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
  if (!authHeader.includes(serviceKey)) {
    return Response.json({ ok: false, message: 'Unauthorized' }, { status: 401 });
  }

  const supa = createClient(
    Deno.env.get('SUPABASE_URL')!,
    serviceKey,
  );

  const apiKey    = Deno.env.get('VTPASS_API_KEY');
  const secretKey = Deno.env.get('VTPASS_SECRET_KEY');

  try {
    const now = new Date();

    // Fetch all active schedules that are due.
    const { data: due, error: fetchErr } = await supa
      .from('schedules')
      .select('*, profiles:user_id(id)')
      .eq('active', true)
      .lte('next_run_at', now.toISOString());

    if (fetchErr) {
      return Response.json({ ok: false, message: fetchErr.message }, { status: 500 });
    }
    if (!due || due.length === 0) {
      return Response.json({ ok: true, ran: 0, message: 'Nothing due' });
    }

    let ran = 0;
    const errors: string[] = [];

    for (const s of due) {
      const ref = generateReference();
      const kind: string      = s.kind;
      const recipient: string = s.recipient;
      const amountKobo: number = s.amount_kobo;
      const userId: string    = s.user_id;
      const providerId: string = s.provider_id ?? kind;
      const freq: string      = s.frequency ?? 'monthly';

      try {
        if (apiKey && secretKey) {
          // ── Live mode: debit wallet then call VTpass ──────────────

          // 1. Atomic wallet debit
          const { error: debitErr } = await supa.rpc('debit_wallet', {
            p_user_id: userId,
            p_amount_kobo: amountKobo,
          });
          if (debitErr) throw new Error('Insufficient funds: ' + debitErr.message);

          // 2. Insert pending transaction
          const { data: tx, error: txErr } = await supa
            .from('transactions')
            .insert({
              user_id: userId,
              kind,
              title: `Scheduled ${s.provider ?? kind}`,
              recipient,
              amount_kobo: amountKobo,
              reference: ref,
              provider: s.provider ?? kind,
              status: 'pending',
              metadata: { scheduled: true, schedule_id: s.id },
            })
            .select()
            .single();
          if (txErr) {
            // Refund if we can't book the transaction
            await supa.rpc('credit_wallet', { p_user_id: userId, p_amount_kobo: amountKobo });
            throw new Error('Transaction booking failed: ' + txErr.message);
          }

          // 3. Call VTpass
          const vtBody: Record<string, unknown> = {
            request_id:     ref,
            serviceID:      serviceIDFor(kind, providerId),
            billersCode:    recipient,
            phone:          recipient,
            amount:         Math.round(amountKobo / 100),
            variation_code: s.product_id ?? '',
          };
          const vtRes = await fetch(`${BASE}/api/pay`, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'api-key':      apiKey,
              'secret-key':   secretKey,
            },
            body: JSON.stringify(vtBody),
          });
          const vt = await vtRes.json();
          const success = (vt?.code ?? '') === '000';

          // 4. Update transaction status
          await supa.from('transactions').update({
            status: success ? 'success' : 'failed',
            metadata: { scheduled: true, schedule_id: s.id, vtpass_response: vt },
          }).eq('id', tx.id);

          if (!success) {
            // Auto-refund on VTpass failure
            await supa.rpc('credit_wallet', { p_user_id: userId, p_amount_kobo: amountKobo });
            throw new Error(vt?.response_description ?? 'VTpass declined');
          }
        } else {
          // ── Demo / staging mode: record a success row only ────────
          await supa.from('transactions').insert({
            user_id: userId,
            kind,
            title: `Scheduled ${s.provider ?? kind}`,
            recipient,
            amount_kobo: amountKobo,
            reference: ref,
            provider: s.provider ?? kind,
            status: 'success',
            metadata: { scheduled: true, schedule_id: s.id },
          });
        }

        // 5. Advance or deactivate schedule
        if (freq === 'once') {
          await supa.from('schedules').update({
            active: false,
            last_run_at: now.toISOString(),
          }).eq('id', s.id);
        } else {
          await supa.from('schedules').update({
            last_run_at: now.toISOString(),
            next_run_at: nextAfter(freq, now).toISOString(),
          }).eq('id', s.id);
        }

        ran++;
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        errors.push(`schedule ${s.id}: ${msg}`);
        // Do NOT deactivate — leave for next run.
      }
    }

    return Response.json({
      ok: true,
      ran,
      total: due.length,
      errors: errors.length > 0 ? errors : undefined,
    });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    return Response.json({ ok: false, message: msg }, { status: 500 });
  }
});
