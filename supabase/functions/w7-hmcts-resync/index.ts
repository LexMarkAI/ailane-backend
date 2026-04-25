// supabase/functions/w7-hmcts-resync/index.ts
// AILANE-SPEC-DMSP-002-W7 §13.1-§13.6
// AMD-095 · Operational fix v4: throughput + hash stability + chain trigger + jitter + recent-first cohort
// Deploy: verify_jwt=false (pipeline-class; invoked by pg_cron with service-role bearer)
// Authoring: 2026-04-25 · Path A Chairman MCP deploy under express Director instruction
//
// Changes from v2 (AMD-089 Stage A):
//   - DEFAULT_BATCH_SIZE: 150 -> 60 (fits in Supabase Edge Function 150s gateway timeout)
//   - INTER_REQUEST_DELAY: fixed 2000ms -> jittered 750-1250ms (mean 1000ms; defeats metronomic detection)
//   - STARTUP_JITTER_MAX_MS: 0 -> 30000 (random 0-30s pause at first chain link only; modest start-time variance)
//   - MAX_CHAIN_DEPTH: 50 -> 30 (Director-instructed conservative cap; ~1,800 rows/day, ~73-day full coverage)
//   - Chain trigger: cohort.length >= limit -> cohort.length > 0 (chain on any work; cohort RPC's
//     daily-idempotency filter is the natural terminator)
//   - Hash input: raw HTTP body -> text-extracted content (strip scripts/styles/tags/
//     comments/whitespace) to eliminate false-positive change detection from dynamic UI
//   - Hash format: 'v2:' prefix added; v1 hashes (raw HTML body) recognised as method-
//     migration baselines, NOT logged as content changes
//   - Cohort RPC ordering (separate migration w7_cohort_recent_first_amd_095):
//     last_resync_at NULLS FIRST, enriched DESC, decision_date DESC, id
//     -> prioritises commercially most-relevant rows (enriched + recent) for baselining

import { createClient } from 'npm:@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('[w7-hmcts-resync] missing required secret(s) at cold start');
}

const HASH_VERSION = 'v2';
const DEFAULT_BATCH_SIZE = 60;
const MAX_CHAIN_DEPTH = 30;
const INTER_REQUEST_DELAY_BASE_MS = 1000;
const INTER_REQUEST_DELAY_JITTER_MS = 500;  // ±250 around base = 750-1250ms actual
const STARTUP_JITTER_MAX_MS = 30_000;         // 0-30s random pause on first chain link only
const MAX_RETRIES = 3;
const RETRY_BACKOFF_MS = [1000, 3000, 9000];
const BATCH_FAILURE_ALERT_PCT = 0.02;

interface Decision {
  id: string;
  source_url: string;
  content_hash: string | null;
  last_resync_at: string | null;
}

// Stable text extraction: strip dynamic page elements before hashing.
// HMCTS pages contain timestamps, session tokens, CSRF tokens, cache-bust query
// strings on assets, and meta tags that change between requests. Hashing the raw
// body would produce false-positive change events on every refetch.
function extractTextContent(html: string): string {
  return html
    .replace(/<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>/gi, ' ')
    .replace(/<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>/gi, ' ')
    .replace(/<noscript\b[^<]*(?:(?!<\/noscript>)<[^<]*)*<\/noscript>/gi, ' ')
    .replace(/<!--[\s\S]*?-->/g, ' ')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/g, ' ')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/\s+/g, ' ')
    .trim();
}

async function computeHash(content: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(content);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  const hex = Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
  return `${HASH_VERSION}:${hex}`;
}

// Per-row jittered delay. Average remains INTER_REQUEST_DELAY_BASE_MS so throughput
// math is unchanged, but the inter-request rhythm becomes irregular rather than
// metronomic — defeats simple "fixed-rate bot" pattern detection.
function jitteredDelayMs(): number {
  const base = INTER_REQUEST_DELAY_BASE_MS;
  const jitter = INTER_REQUEST_DELAY_JITTER_MS;
  return Math.floor((base - jitter / 2) + Math.random() * jitter);
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
): Promise<'unchanged' | 'changed' | 'baseline_established' | 'migrated' | 'failed'> {
  const fetched = await fetchWithRetry(decision.source_url);
  const todayStr = new Date().toISOString().split('T')[0];

  if (!fetched || fetched.status >= 400) {
    await sb
      .from('tribunal_decisions')
      .update({ resync_processed_date: todayStr })
      .eq('id', decision.id);
    return 'failed';
  }

  const textContent = extractTextContent(fetched.body);
  const newHash = await computeHash(textContent);
  const hashBefore = decision.content_hash;

  // Three pre-states for hashBefore:
  //   1. NULL                  -> first baseline establishment
  //   2. v1 (no 'v2:' prefix)  -> method-migration baseline (do NOT log as content change)
  //   3. v2 prefix             -> comparable; flag change_detected if hashes differ
  const isFirstBaseline = hashBefore === null;
  const isV1Migration = hashBefore !== null && !hashBefore.startsWith(`${HASH_VERSION}:`);
  const isV2Comparable = hashBefore !== null && hashBefore.startsWith(`${HASH_VERSION}:`);
  const changed = isV2Comparable && hashBefore !== newHash;

  const { data: enrichmentRow } = await sb
    .from('tribunal_enrichment')
    .select('restricted_reporting_order, soa_1992_identified')
    .eq('decision_id', decision.id)
    .maybeSingle();

  const rroBefore = enrichmentRow?.restricted_reporting_order ?? null;
  const soaBefore = enrichmentRow?.soa_1992_identified ?? null;

  const { error: logErr } = await sb.from('w7_resync_log').insert({
    decision_id: decision.id,
    hash_before: hashBefore,
    hash_after: newHash,
    change_detected: changed,
    rro_before: rroBefore,
    rro_after: rroBefore,
    soa_before: soaBefore,
    soa_after: soaBefore,
  });
  if (logErr) console.error('[w7-hmcts-resync] w7_resync_log insert failed', logErr);

  // content_hash always written in v2 format. resync_change_detected_at gated on real
  // content change so first-baselines and method-migrations don't trip downstream
  // re-enrichment workers.
  const updatePayload: Record<string, unknown> = {
    last_resync_at: new Date().toISOString(),
    resync_processed_date: todayStr,
    content_hash: newHash,
  };
  if (changed) {
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

  if (isFirstBaseline) return 'baseline_established';
  if (isV1Migration) return 'migrated';
  return changed ? 'changed' : 'unchanged';
}

function enqueueNextBatch(
  channel: 'A' | 'B',
  limit: number,
  chainDepth: number,
): void {
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

  if (chainDepth >= MAX_CHAIN_DEPTH) {
    console.error(`[w7-hmcts-resync] chain depth ${chainDepth} >= ${MAX_CHAIN_DEPTH}; terminating chain for channel ${channel}`);
    return new Response(JSON.stringify({
      channel, limit, chain_depth: chainDepth,
      result: 'chain_terminated', reason: 'max_depth_reached',
    }), { status: 200, headers: { 'Content-Type': 'application/json' } });
  }

  // Startup jitter on the first chain link only (chain_depth=0 = the cron-fired kickoff).
  // Adds 0-30s of randomness to the actual HMCTS request start time so HMCTS doesn't
  // see exactly 02:00:00 every day. Subsequent chain links (depth>=1) start immediately
  // to preserve total run-time predictability and stay within Supabase EF gateway budget.
  if (chainDepth === 0 && STARTUP_JITTER_MAX_MS > 0) {
    const jitterMs = Math.floor(Math.random() * STARTUP_JITTER_MAX_MS);
    if (jitterMs > 0) {
      console.log(`[w7-hmcts-resync] channel ${channel} startup jitter: ${jitterMs}ms`);
      await new Promise((r) => setTimeout(r, jitterMs));
    }
  }

  const cohort = await selectCohort(sb, channel, limit);

  if (cohort.length === 0) {
    return new Response(JSON.stringify({
      channel, limit, chain_depth: chainDepth,
      cohort_size: 0, result: 'chain_complete',
    }), { status: 200, headers: { 'Content-Type': 'application/json' } });
  }

  let unchanged = 0, changed = 0, failed = 0, baselined = 0, migrated = 0;
  for (const decision of cohort) {
    const outcome = await resyncRow(sb, decision);
    if (outcome === 'unchanged') unchanged++;
    else if (outcome === 'changed') changed++;
    else if (outcome === 'baseline_established') baselined++;
    else if (outcome === 'migrated') migrated++;
    else failed++;
    await new Promise((r) => setTimeout(r, jitteredDelayMs()));
  }

  const failureRate = cohort.length ? failed / cohort.length : 0;
  if (failureRate > BATCH_FAILURE_ALERT_PCT) {
    console.error(`[w7-hmcts-resync] batch failure rate ${(failureRate * 100).toFixed(2)}% exceeds ${BATCH_FAILURE_ALERT_PCT * 100}% threshold`);
  }

  // Chain trigger: chain whenever cohort returned any work. The cohort RPC's daily-
  // idempotency filter (resync_processed_date < CURRENT_DATE) ensures the cohort
  // returns 0 once today's eligible work is exhausted, naturally terminating the chain.
  const chainContinues = cohort.length > 0;
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
      baselined,
      migrated,
      failed,
      failure_rate: failureRate,
      chain_continues: chainContinues,
      ran_at: new Date().toISOString(),
    }),
    { status: 200, headers: { 'Content-Type': 'application/json' } },
  );
});
