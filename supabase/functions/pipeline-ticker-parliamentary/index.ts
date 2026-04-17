// pipeline-ticker-parliamentary v15
// Generates Anthropic-powered briefings for parliamentary_intelligence and govuk_news_intelligence.
// v15 fixes (2026-04-17):
//   1. 'all' tier mapping -> ['operational','governance','institutional'] (tier CHECK constraint).
//   2. source_table values parliamentary_intelligence | govuk_news_intelligence now admitted by
//      CHECK constraint (migration gnyo_001_ticker_briefings_source_table_extend).
//   3. headline column renamed to event_title in upsert (migration gnyo_001_ticker_briefings_context_columns).
//   4. limit(5) per table per run + tighter inter-call sleeps -> fits inside 150s idle timeout.
//   5. Error-reporting: upsert errors now counted as failed rather than silently ignored.
// Managed via Supabase Dashboard / MCP deploy_edge_function. Source of truth: ailane-backend repo.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const ANTHROPIC_KEY = Deno.env.get('ANTHROPIC_API_KEY');

const PER_TABLE_LIMIT = 5;
const TIER_SLEEP_MS = 200;
const ITEM_SLEEP_MS = 100;

function requireSecret(name: string, v: string | undefined): string {
  if (!v || v.length === 0) throw new Error(`MISSING_SECRET:${name}`);
  return v;
}

function tiersFor(tickerTier: string): string[] {
  if (tickerTier === 'all') return ['operational', 'governance', 'institutional'];
  if (tickerTier === 'operational') return ['operational', 'governance', 'institutional'];
  if (tickerTier === 'governance') return ['governance', 'institutional'];
  if (tickerTier === 'institutional') return ['institutional'];
  return ['institutional'];
}

const SYSTEM_PROMPT = `You are an expert UK employment law analyst writing constitutional-grade intelligence briefings for HR directors and compliance leads at UK employers.

Your briefings must:
- Lead with the employer risk implication, not the political narrative
- Reference specific statutory instruments, case law, or legislative provisions where applicable
- Quantify exposure where possible (tribunal awards, fine ranges, compliance costs)
- Flag urgency clearly: CRITICAL (action required now), HIGH (monitor closely), ELEVATED (awareness), MONITOR (background intelligence)
- Be concise: 3-5 sentences maximum
- Never reproduce copyrighted text verbatim
- Maintain strict constitutional separation: ACEI (external risk), RRI (readiness), CCI (conduct) — do not conflate

Write in authoritative, precise language appropriate for institutional-grade intelligence products.`;

async function generateBriefing(
  anthropicKey: string,
  item: Record<string, unknown>,
  tier: string,
  sourceLabel: string,
): Promise<string | null> {
  try {
    const prompt = `Generate an employment law intelligence briefing for this ${sourceLabel} development:\n\nTitle: ${item.title}\nSource: ${item.source_type}\nSummary: ${item.summary || 'Not available'}\nACEI Categories: ${(item.acei_categories as string[] || []).join(', ')}\nLegislative Urgency: ${item.legislative_urgency}\nTier: ${tier}\n\n${tier === 'institutional' ? 'Include specific quantified risk estimates and precedent case references where applicable.' : ''}\n\nBriefing:`;
    const r = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': anthropicKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 400,
        system: SYSTEM_PROMPT,
        messages: [{ role: 'user', content: prompt }],
      }),
    });
    if (!r.ok) { console.error(`Anthropic ${r.status}`); return null; }
    const data = await r.json();
    return data.content?.[0]?.text?.trim() ?? null;
  } catch (e) {
    console.error('Briefing error:', e);
    return null;
  }
}

async function processTable(
  db: any,
  anthropicKey: string,
  tableName: 'parliamentary_intelligence' | 'govuk_news_intelligence',
  sourceLabel: string,
): Promise<{ processed: number; generated: number; failed: number }> {
  let processed = 0, generated = 0, failed = 0;

  const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
  const { data: items, error } = await db
    .from(tableName)
    .select('*')
    .eq('ticker_eligible', true)
    .eq('briefing_generated', false)
    .gte('published_date', since)
    .order('published_date', { ascending: false })
    .limit(PER_TABLE_LIMIT);

  if (error) { console.error(`[${tableName}] fetch error:`, error); return { processed, generated, failed }; }
  if (!items?.length) { console.log(`[${tableName}] no items`); return { processed, generated, failed }; }

  for (const item of items) {
    processed++;
    const tiers = tiersFor(String(item.ticker_tier ?? 'institutional'));

    let briefingId: string | null = null;

    for (const tier of tiers) {
      const briefing = await generateBriefing(anthropicKey, item, tier, sourceLabel);
      if (!briefing) { failed++; continue; }

      const { data: tb, error: tbErr } = await db
        .from('ticker_briefings')
        .upsert({
          source_table: tableName,
          source_id: item.id,
          tier,
          briefing_text: briefing,
          generation_status: 'completed',
          generated_at: new Date().toISOString(),
          acei_category: item.acei_category_primary,
          event_date: item.event_date || item.published_date,
          event_title: item.title,
          source_url: item.url,
          legislative_urgency: item.legislative_urgency,
        }, { onConflict: 'source_table,source_id,tier' })
        .select('id')
        .single();

      if (tbErr) { console.error(`[${tableName}] upsert err:`, tbErr); failed++; continue; }
      if (tb) {
        briefingId = tb.id;
        generated++;
      }

      await new Promise(r => setTimeout(r, TIER_SLEEP_MS));
    }

    if (briefingId) {
      await db.from(tableName).update({
        briefing_generated: true,
        briefing_id: briefingId,
        updated_at: new Date().toISOString(),
      }).eq('id', item.id);
    }

    await new Promise(r => setTimeout(r, ITEM_SLEEP_MS));
  }

  return { processed, generated, failed };
}

Deno.serve(async (_req) => {
  let db: any, anthropicKey: string;
  try {
    const url = requireSecret('SUPABASE_URL', SUPABASE_URL);
    const key = requireSecret('SUPABASE_SERVICE_ROLE_KEY', SUPABASE_KEY);
    anthropicKey = requireSecret('ANTHROPIC_API_KEY', ANTHROPIC_KEY);
    db = createClient(url, key);
  } catch (e) {
    return Response.json({ success: false, error: String(e) }, { status: 500 });
  }

  console.log('[ticker-parliamentary v15] Starting dual-source briefing generation');

  try {
    const parl = await processTable(db, anthropicKey, 'parliamentary_intelligence', 'parliamentary/regulatory');
    const news = await processTable(db, anthropicKey, 'govuk_news_intelligence', 'GOV.UK news/guidance');

    const totals = {
      processed: parl.processed + news.processed,
      generated: parl.generated + news.generated,
      failed: parl.failed + news.failed,
    };

    console.log(`Done: parliamentary=${JSON.stringify(parl)} govuk_news=${JSON.stringify(news)}`);
    return Response.json({ success: true, version: 15, totals, parliamentary: parl, govuk_news: news });
  } catch (e) {
    console.error('Fatal:', e);
    return Response.json({ success: false, error: String(e) }, { status: 500 });
  }
});
