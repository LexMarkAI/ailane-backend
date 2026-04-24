// supabase/functions/w7-hmcts-resync/index.ts
// AILANE-SPEC-DMSP-002-W7 §13.1-§13.6
// AMD-089 Stage A · CC Build Brief 1 · v1.1 (batched self-chaining per COP P1-3/P1-4)
// Deploy: verify_jwt=false (pipeline-class; invoked by pg_cron with service-role bearer)

import { createClient } from 'npm:@supabase/supabase-js@2';

// SEC-001 §4 secret validation
const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('[w7-hmcts-resync] missing required secret(s) at cold start');
}

// Batch sizing — COP P1-3/P1-4 resolution
// 150 rows × 2 s inter-request delay + ~50 s overhead ≈ 350 s per invocation,
// safely under the Supabase Edge Function 400 s execution-time limit (Pro plan).
const DEFAULT_BATCH_SIZE = 150;
const MAX_CHAIN_DEPTH = 50;             // safety cap against runaway chains
const INTER_REQUEST_DELAY_MS = 2000;    // HMCTS politeness window
const MAX_RETRIES = 3;
const RETRY_BACKOFF_MS = [1000, 3000, 9000];
const BATCH_FAILURE_ALERT_PCT = 0.02;

interface Decision {
  id: string;
  source_url: string;
  content_hash: string | null;
  last_resync_at: string | null;
}

async function computeHash(body: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(body);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

async function fetchWithRetry(url: string): Promise<{ body: string; status: number } | null> {
  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      const response = await fetch(url, {
        method: 'GET',
        headers: { 'User-Agent': 'AiLaneBot/1.0 w7-hmcts-resync' },
      });
      if (response.status >= 500 && attempt < MAX_RETRIES) {
        await new Promise((r) => setTimeout(r, RETRY_BACKOFF_MS[attempt]));
        continue;
      }
      const body = await response.text();
      return { body, status: response.status };
    } catch (err) {
      if (attempt >= MAX_RETRIES) {
        console.error(`[w7-hmcts-resync] fetch failed after ${MAX_RETRIES} retries: ${url}`, err);
        return null;
      }
      await new Promise((r) => setTimeout(r, RETRY_BACKOFF_MS[attempt]));
    }
  }
  return null;
}

async function selectCohort(
  sb: ReturnType<typeof createClient>,
  channel: 'A' | 'B',
  limit: number,
): Promise<Decision[]> {
  const fn = channel === 'A' ? 'w7_select_channel_a_cohort' : 'w7_select_channel_b_cohort';
  const { data, error } = await sb.rpc(fn, { p_limit: limit });
  if (error) {
    console.error(`[w7-hmcts-resync] ${fn} selection failed`, error);
    return [];
  }
  return (data ?? []) as Decision[];
}

async function resyncRow(
  sb: ReturnType<typeof createClient>,
  decision: Decision,
): Promise<'unchanged' | 'changed' | 'failed'> {
  const fetched = await fetchWithRetry(decision.source_url);
  // Today's date stamp (yyyy-mm-dd) for resync_processed_date
  const todayStr = new Date().toISOString().split('T')[0];

  if (!fetched || fetched.status >= 400) {
    // Mark as processed-today anyway so the chain advances and this row is
    // retried on the next nightly run, not repeatedly within the same night.
    await sb
      .from('tribunal_decisions')
      .update({ resync_processed_date: todayStr })
      .eq('id', decision.id);
    return 'failed';
  }

  const newHash = await computeHash(fetched.body);
  const hashBefore = decision.content_hash;
  const changed = hashBefore !== null && hashBefore !== newHash;

  // Read current flag state for _before capture (spec §13.5 w7_resync_log schema)
  const { data: enrichmentRow } = await sb
    .from('tribunal_enrichment')
    .select('restricted_reporting_order, soa_1992_identified')
    .eq('decision_id', decision.id)
    .maybeSingle();

  const rroBefore = enrichmentRow?.restricted_reporting_order ?? null;
  const soaBefore = enrichmentRow?.soa_1992_identified ?? null;

  // Log every resync event (change_detected boolean records mismatch vs. match)
  const { error: logErr } = await sb.from('w7_resync_log').insert({
    decision_id: decision.id,
    hash_before: hashBefore,
    hash_after: newHash,
    change_detected: changed,
    rro_before: rroBefore,
    rro_after: rroBefore,    // _after unchanged at this stage; re-enrichment updates later
    soa_before: soaBefore,
    soa_after: soaBefore,
  });
  if (logErr) console.error('[w7-hmcts-resync] w7_resync_log insert failed', logErr);

  // Update resync timestamps on every run
  const updatePayload: Record<string, unknown> = {
    last_resync_at: new Date().toISOString(),
    resync_processed_date: todayStr,
  };
  if (changed) {
    updatePayload.content_hash = newHash;
    updatePayload.resync_change_detected_at = new Date().toISOString();
  }
  const { error: updErr } = await sb
    .from('tribunal_decisions')
    .update(updatePayload)
    .eq('id', decision.id);
  if (updErr) {
    console.error('[w7-hmcts-resync] tribunal_decisions update failed', updErr);
    return 'failed';
  }

  return changed ? 'changed' : 'unchanged';
}

function enqueueNextBatch(
  channel: 'A' | 'B',
  limit: number,
  chainDepth: number,
): void {
  // Fire-and-forget follow-up invocation (COP P1-3/P1-4 self-chaining pattern).
  // Do not await; wrap in EdgeRuntime.waitUntil so the current response returns
  // cleanly while the follow-up request begins.
  const nextCall = fetch(`${SUPABASE_URL}/functions/v1/w7-hmcts-resync`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
    },
    body: JSON.stringify({
      channel,
      limit,
      chain_depth: chainDepth + 1,
    }),
  }).catch((err) => {
    console.error('[w7-hmcts-resync] chain enqueue failed', err);
  });
  const er = (globalThis as unknown as { EdgeRuntime?: { waitUntil?: (p: Promise<unknown>) => void } }).EdgeRuntime;
  if (er && typeof er.waitUntil === 'function') {
    er.waitUntil(nextCall as Promise<unknown>);
  }
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'method_not_allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  // COP P2-4: name the missing secret in the structured error response.
  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    const missing: string[] = [];
    if (!SUPABASE_URL) missing.push('SUPABASE_URL');
    if (!SUPABASE_SERVICE_ROLE_KEY) missing.push('SUPABASE_SERVICE_ROLE_KEY');
    return new Response(JSON.stringify({ error: 'missing_secrets', missing }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  const sb = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  let body: { channel?: string; limit?: number; chain_depth?: number };
  try { body = await req.json(); } catch { body = {}; }

  const channelRaw = (body.channel ?? '').toUpperCase();
  if (channelRaw !== 'A' && channelRaw !== 'B') {
    return new Response(JSON.stringify({ error: 'invalid_channel', expected: 'A or B' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }
  const channel = channelRaw as 'A' | 'B';

  const limit = Math.max(1, Math.min(DEFAULT_BATCH_SIZE, body.limit ?? DEFAULT_BATCH_SIZE));
  const chainDepth = body.chain_depth ?? 0;

  // Chain-depth safety cap
  if (chainDepth >= MAX_CHAIN_DEPTH) {
    console.error(`[w7-hmcts-resync] chain depth ${chainDepth} >= ${MAX_CHAIN_DEPTH}; terminating chain for channel ${channel}`);
    return new Response(JSON.stringify({
      channel, limit, chain_depth: chainDepth,
      result: 'chain_terminated', reason: 'max_depth_reached',
    }), { status: 200, headers: { 'Content-Type': 'application/json' } });
  }

  // Cohort selection — already filters out rows with resync_processed_date = CURRENT_DATE
  const cohort = await selectCohort(sb, channel, limit);

  if (cohort.length === 0) {
    // Nightly cohort exhausted — chain terminates naturally
    return new Response(JSON.stringify({
      channel, limit, chain_depth: chainDepth,
      cohort_size: 0, result: 'chain_complete',
    }), { status: 200, headers: { 'Content-Type': 'application/json' } });
  }

  let unchanged = 0, changed = 0, failed = 0;
  for (const decision of cohort) {
    const outcome = await resyncRow(sb, decision);
    if (outcome === 'unchanged') unchanged++;
    else if (outcome === 'changed') changed++;
    else failed++;
    await new Promise((r) => setTimeout(r, INTER_REQUEST_DELAY_MS));
  }

  const failureRate = cohort.length ? failed / cohort.length : 0;
  if (failureRate > BATCH_FAILURE_ALERT_PCT) {
    console.error(`[w7-hmcts-resync] batch failure rate ${(failureRate * 100).toFixed(2)}% exceeds ${BATCH_FAILURE_ALERT_PCT * 100}% threshold`);
  }

  // Self-chain: if batch was full, more rows likely remain — enqueue next batch
  const chainContinues = cohort.length >= limit;
  if (chainContinues) {
    enqueueNextBatch(channel, limit, chainDepth);
  }

  return new Response(
    JSON.stringify({
      channel,
      chain_depth: chainDepth,
      cohort_size: cohort.length,
      unchanged,
      changed,
      failed,
      failure_rate: failureRate,
      chain_continues: chainContinues,
      ran_at: new Date().toISOString(),
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
});
