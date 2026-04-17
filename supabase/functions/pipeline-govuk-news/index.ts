// pipeline-govuk-news v15
// GOV.UK News ingestion for Ailane regulatory intelligence.
// Writes to public.govuk_news_intelligence (dedicated table).
// Applies GNYO-001 Levers A (HMRC-narrow), B (expanded orgs), C (no doc_type), D (count=200 + incremental).
// Constitutional authority: ACEI Art. XI.
//
// Managed via Supabase Dashboard. Source of truth: ailane-backend repo.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// --- Required secrets ---
const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

function requireSecret(name: string, value: string | undefined): string {
  if (!value || value.length === 0) {
    throw new Error(`MISSING_SECRET:${name}`);
  }
  return value;
}

// --- Constants ---
const PIPELINE_CODE = 'govuk_employment_news_daily';
const UA = 'Ailane-Regulatory-Intelligence/1.0 (+https://ailane.ai)';
const API_BASE = 'https://www.gov.uk/api/search.json';
const ISRF_BUCKET = 'isrf-govuk';
const COUNT = 200;
const MAX_START_PLUS_COUNT = 1000;
const PAGE_SLEEP_MS = 1000;
const ORG_SLEEP_MS = 2000;
const FIRST_RUN_BACKFILL_DAYS = 90;
const OVERLAP_HOURS = 24;

// Broad org channel (Lever B). HMRC intentionally excluded — see HMRC_NARROW below.
const BROAD_ORGS: string[] = [
  'department-for-business-and-trade',
  'acas',
  'health-and-safety-executive',
  'equality-and-human-rights-commission',
  'information-commissioners-office',
  'the-pensions-regulator',
  // 'fair-work-agency', // INCLUDE ONLY IF §0 probe returns HTTP 200 + total>=1
];

// HMRC narrow query (Lever A).
const HMRC_NARROW = {
  org: 'hm-revenue-customs',
  q: 'employment OR payroll OR wage OR PAYE OR "national minimum wage" OR "national insurance contributions" OR redundancy OR apprentice OR "off-payroll" OR IR35',
};

const DEFAULT_FIELDS = ['title', 'description', 'link', 'public_timestamp', 'document_type'].join(',');

// --- Helpers ---
function hash(s: string): string {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = Math.imul(31, h) + s.charCodeAt(i) | 0;
  return Math.abs(h).toString(16);
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

function inferCategories(text: string): string[] {
  const lower = text.toLowerCase();
  const cats: string[] = [];
  if (lower.includes('dismissal') || lower.includes('redundancy')) cats.push('unfair_dismissal');
  if (lower.includes('discriminat') || lower.includes('equality') || lower.includes('harassment')) cats.push('discrimination_harassment');
  if (lower.includes('wage') || lower.includes('pay')) cats.push('wages_working_time');
  if (lower.includes('maternity') || lower.includes('parental')) cats.push('family_rights');
  if (lower.includes('zero hour') || lower.includes('gig') || lower.includes('agency')) cats.push('atypical_worker_rights');
  if (lower.includes('acas') || lower.includes('tribunal')) cats.push('unfair_dismissal');
  if (lower.includes('pension')) cats.push('pensions_benefits');
  if (lower.includes('health and safety') || lower.includes('hse')) cats.push('health_safety');
  if (lower.includes('data protection') || lower.includes('gdpr') || lower.includes('dpa')) cats.push('data_protection_employment');
  return [...new Set(cats)];
}

function classifySourceType(docType: string | null | undefined): string {
  const t = (docType || '').toLowerCase();
  if (t === 'press_release') return 'govuk_press_release';
  if (t === 'news_story' || t === 'news_article') return 'govuk_news_story';
  if (t === 'guidance' || t === 'detailed_guide') return 'govuk_guidance';
  if (t === 'statutory_guidance') return 'govuk_statutory_guidance';
  if (t === 'consultation' || t === 'open_consultation' || t === 'closed_consultation') return 'govuk_consultation';
  if (t === 'speech') return 'govuk_speech';
  return 'govuk_press_release'; // safe default — matches parliamentary_intelligence legacy value
}

function buildSearchUrl(params: Record<string, string | string[]>): string {
  const p = new URLSearchParams();
  for (const [k, v] of Object.entries(params)) {
    if (Array.isArray(v)) {
      for (const item of v) p.append(k, item);
    } else {
      p.append(k, v);
    }
  }
  return `${API_BASE}?${p.toString()}`;
}

async function fetchPage(url: string): Promise<{ results: any[]; total: number }> {
  const r = await fetch(url, { headers: { 'User-Agent': UA, Accept: 'application/json' } });
  if (!r.ok) throw new Error(`GOV.UK API ${r.status} for ${url}`);
  const data = await r.json();
  return { results: Array.isArray(data.results) ? data.results : [], total: data.total ?? 0 };
}

// --- Watermark helpers ---
async function getWatermark(db: any): Promise<string | null> {
  const { data, error } = await db
    .from('pipeline_registry')
    .select('last_high_watermark_ts')
    .eq('pipeline_code', PIPELINE_CODE)
    .single();
  if (error) throw error;
  return data?.last_high_watermark_ts ?? null;
}

async function setWatermark(db: any, ts: string): Promise<void> {
  const { error } = await db
    .from('pipeline_registry')
    .update({ last_high_watermark_ts: ts, updated_at: new Date().toISOString() })
    .eq('pipeline_code', PIPELINE_CODE);
  if (error) throw error;
}

function computeFilterFrom(lastHwm: string | null): string {
  const now = new Date();
  if (!lastHwm) {
    now.setUTCDate(now.getUTCDate() - FIRST_RUN_BACKFILL_DAYS);
    return now.toISOString();
  }
  const hwm = new Date(lastHwm);
  hwm.setUTCHours(hwm.getUTCHours() - OVERLAP_HOURS);
  return hwm.toISOString();
}

// --- Run lifecycle ---
async function startRun(db: any): Promise<string> {
  const { data, error } = await db
    .from('pipeline_runs')
    .insert({ pipeline_code: PIPELINE_CODE, status: 'running', trigger_type: 'scheduled' })
    .select('id')
    .single();
  if (error) throw error;
  return data.id as string;
}

async function finishRun(
  db: any,
  runId: string,
  status: string,
  counts: Record<string, number>,
  errorMessage?: string,
) {
  await db
    .from('pipeline_runs')
    .update({
      status,
      completed_at: new Date().toISOString(),
      error_message: errorMessage ?? null,
      ...counts,
    })
    .eq('id', runId);
  await db
    .from('pipeline_registry')
    .update({
      last_run_at: new Date().toISOString(),
      ...(status === 'success' ? { last_success_at: new Date().toISOString(), consecutive_failures: 0 } : {}),
    })
    .eq('pipeline_code', PIPELINE_CODE);
}

// --- ISRF (raw JSON) write ---
async function writeIsrf(db: any, item: any, orgSlug: string, contentHash: string): Promise<string | null> {
  try {
    const ts = new Date(item.public_timestamp ?? Date.now());
    const yyyy = ts.getUTCFullYear().toString();
    const mm = (ts.getUTCMonth() + 1).toString().padStart(2, '0');
    const dd = ts.getUTCDate().toString().padStart(2, '0');
    const path = `${orgSlug}/${yyyy}/${mm}/${dd}/${contentHash}.json`;
    const envelope = {
      retrieved_at: new Date().toISOString(),
      source_api_base: API_BASE,
      org_slug: orgSlug,
      ogl_v3_attribution: 'Contains public sector information licensed under the Open Government Licence v3.0.',
      item,
    };
    const body = new Blob([JSON.stringify(envelope, null, 2)], { type: 'application/json' });
    const { error } = await db.storage.from(ISRF_BUCKET).upload(path, body, {
      upsert: true,
      contentType: 'application/json',
    });
    if (error) {
      console.warn(`ISRF write skipped (${error.message}) for ${path}`);
      return null;
    }
    return path;
  } catch (e) {
    console.warn(`ISRF write error: ${e}`);
    return null;
  }
}

// --- Core ingest for a single set of query params ---
async function ingestQuery(
  db: any,
  baseParams: Record<string, string | string[]>,
  orgSlugForIsrf: string,
  filterFromIso: string,
): Promise<{ found: number; inserted: number; duplicate: number; maxPubTs: string | null }> {
  let found = 0, inserted = 0, duplicate = 0;
  let maxPubTs: string | null = null;

  for (let start = 0; start < MAX_START_PLUS_COUNT; start += COUNT) {
    if (start + COUNT > MAX_START_PLUS_COUNT) break;

    const params = {
      ...baseParams,
      count: String(COUNT),
      start: String(start),
      order: '-public_timestamp',
      fields: DEFAULT_FIELDS,
      'filter_public_timestamp': `from:${filterFromIso}`,
    };

    const url = buildSearchUrl(params);
    const { results } = await fetchPage(url);
    if (results.length === 0) break;

    for (const item of results) {
      const title = item.title?.toString().trim();
      if (!title) continue;
      found++;

      const desc = item.description ? String(item.description) : '';
      const pubTs = item.public_timestamp ? String(item.public_timestamp) : null;
      if (pubTs && (!maxPubTs || pubTs > maxPubTs)) maxPubTs = pubTs;

      const pubDate = pubTs ? pubTs.split('T')[0] : new Date().toISOString().split('T')[0];
      const link = item.link ? String(item.link) : null;
      const url_canonical = link ? `https://www.gov.uk${link}` : null;
      const rawDocType = item.document_type ? String(item.document_type) : null;
      const sourceType = classifySourceType(rawDocType);
      const allText = `${title} ${desc}`;
      const acei = inferCategories(allText);
      const contentHash = hash(title + (link ?? ''));

      const isrfPath = await writeIsrf(db, item, orgSlugForIsrf, contentHash);

      const { error } = await db.from('govuk_news_intelligence').insert({
        source_type: sourceType,
        source_org_slug: orgSlugForIsrf,
        title,
        summary: desc || null,
        url: url_canonical,
        published_date: pubDate,
        public_timestamp: pubTs,
        acei_categories: acei,
        acei_category_primary: acei[0] ?? null,
        legislative_urgency: 'monitor',
        ticker_eligible: true,
        ticker_tier: 'all',
        content_hash: contentHash,
        isrf_file_path: isrfPath,
        raw_document_type: rawDocType,
      });

      if (error?.code === '23505') duplicate++;
      else if (!error) inserted++;
      else console.warn(`Insert error (${orgSlugForIsrf}): ${error.message}`);
    }

    if (results.length < COUNT) break;
    await sleep(PAGE_SLEEP_MS);
  }

  return { found, inserted, duplicate, maxPubTs };
}

Deno.serve(async (_req) => {
  let db: any;
  try {
    const url = requireSecret('SUPABASE_URL', SUPABASE_URL);
    const key = requireSecret('SUPABASE_SERVICE_ROLE_KEY', SUPABASE_KEY);
    db = createClient(url, key);
  } catch (e) {
    return Response.json({ success: false, error: String(e) }, { status: 500 });
  }

  const runId = await startRun(db);
  console.log(`[pipeline-govuk-news v15] Run ${runId}`);

  let totalFound = 0, totalInserted = 0, totalDuplicate = 0;
  let maxPubTsOverall: string | null = null;

  try {
    const lastHwm = await getWatermark(db);
    const filterFromIso = computeFilterFrom(lastHwm);
    console.log(`Watermark: ${lastHwm} → filter_public_timestamp=from:${filterFromIso}`);

    // --- Broad query (Lever B) — per-org iteration for ISRF attribution ---
    for (const org of BROAD_ORGS) {
      console.log(`[broad] ${org}`);
      const r = await ingestQuery(
        db,
        { 'filter_any_organisations[]': [org] },
        org,
        filterFromIso,
      );
      totalFound += r.found;
      totalInserted += r.inserted;
      totalDuplicate += r.duplicate;
      if (r.maxPubTs && (!maxPubTsOverall || r.maxPubTs > maxPubTsOverall)) maxPubTsOverall = r.maxPubTs;
      await sleep(ORG_SLEEP_MS);
    }

    // --- HMRC narrow query (Lever A) ---
    console.log(`[narrow] ${HMRC_NARROW.org}`);
    const hmrcResult = await ingestQuery(
      db,
      { 'filter_organisations[]': [HMRC_NARROW.org], q: HMRC_NARROW.q },
      HMRC_NARROW.org,
      filterFromIso,
    );
    totalFound += hmrcResult.found;
    totalInserted += hmrcResult.inserted;
    totalDuplicate += hmrcResult.duplicate;
    if (hmrcResult.maxPubTs && (!maxPubTsOverall || hmrcResult.maxPubTs > maxPubTsOverall)) {
      maxPubTsOverall = hmrcResult.maxPubTs;
    }

    // --- ACAS RSS side-channel (retained from v14) ---
    try {
      const acasRes = await fetch('https://www.acas.org.uk/news-and-views/rss', { headers: { 'User-Agent': UA } });
      if (acasRes.ok) {
        const xml = await acasRes.text();
        const itemRe = /<item>([\s\S]*?)<\/item>/g;
        let m: RegExpExecArray | null;
        while ((m = itemRe.exec(xml)) !== null) {
          const block = m[1];
          const titleM = block.match(/<title>(?:<!\[CDATA\[)?([^\]<]+)/);
          const linkM = block.match(/<link>([^<]+)</);
          const dateM = block.match(/<pubDate>([^<]+)</);
          const descM = block.match(/<description>(?:<!\[CDATA\[)?([^\]<]+)/);
          const title = titleM?.[1]?.trim();
          if (!title) continue;
          totalFound++;
          const url = linkM?.[1]?.trim() ?? null;
          const pubDate = dateM?.[1]
            ? new Date(dateM[1]).toISOString().split('T')[0]
            : new Date().toISOString().split('T')[0];
          const acei = inferCategories(`${title} ${descM?.[1] ?? ''}`);
          const contentHash = hash(`acas:${title}${pubDate}`);
          const { error } = await db.from('govuk_news_intelligence').insert({
            source_type: 'acas_news_rss',
            source_org_slug: 'acas',
            title: `ACAS: ${title}`,
            summary: descM?.[1]?.trim() ?? null,
            url,
            published_date: pubDate,
            public_timestamp: dateM?.[1] ? new Date(dateM[1]).toISOString() : null,
            acei_categories: acei,
            acei_category_primary: acei[0] ?? null,
            legislative_urgency: 'monitor',
            ticker_eligible: true,
            ticker_tier: 'all',
            content_hash: contentHash,
            isrf_file_path: null,
            raw_document_type: 'acas_rss_item',
          });
          if (error?.code === '23505') totalDuplicate++;
          else if (!error) totalInserted++;
        }
      }
    } catch (e) {
      console.warn('ACAS RSS error:', e);
    }

    if (maxPubTsOverall) await setWatermark(db, maxPubTsOverall);

    await finishRun(db, runId, 'success', {
      records_found: totalFound,
      records_new: totalInserted,
      records_duplicate: totalDuplicate,
    });
    console.log(`Done: found=${totalFound}, new=${totalInserted}, duplicate=${totalDuplicate}, maxPubTs=${maxPubTsOverall}`);
    return Response.json({
      success: true,
      found: totalFound,
      inserted: totalInserted,
      duplicate: totalDuplicate,
      max_public_timestamp: maxPubTsOverall,
    });
  } catch (e) {
    console.error('Fatal:', e);
    await finishRun(db, runId, 'failed', { records_found: totalFound }, String(e));
    return Response.json({ success: false, error: String(e) }, { status: 500 });
  }
});
