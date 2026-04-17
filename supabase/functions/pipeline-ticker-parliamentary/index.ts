// pipeline-ticker-parliamentary v13
// Generates Anthropic-powered briefings for both parliamentary_intelligence and govuk_news_intelligence.
// Writes to ticker_briefings using source_table to distinguish origin.
// Managed via Supabase Dashboard. Source of truth: ailane-backend repo.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
const ANTHROPIC_KEY = Deno.env.get('ANTHROPIC_API_KEY');

function requireSecret(name: string, v: string | undefined): string {
  if (!v || v.length === 0) throw new Error(`MISSING_SECRET:${name}`);
  return v;
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
    const prompt = `Generate an employment law intelligence briefing for this ${sourceLabel} development:

Title: ${item.title}
Source: ${item.source_type}
Summary: ${item.summary || 'Not available'}
ACEI Categories: ${(item.acei_categories as string[] || []).join(', ')}
Legislative Urgency: ${item.legislative_urgency}
Tier: ${tier}

${tier === 'institutional' ? 'Include specific quantified risk estimates and precedent case references where applicable.' : ''}

Briefing:`;
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
    .limit(20);

  if (error) { console.error(`[${tableName}] fetch error:`, error); return { processed, generated, failed }; }
  if (!items?.length) { console.log(`[${tableName}] no items`); return { processed, generated, failed }; }

  for (const item of items) {
    processed++;
    const tiers = item.ticker_tier === 'all'
      ? ['all', 'governance', 'institutional']
      : item.ticker_tier === 'governance'
        ? ['governance', 'institutional']
        : ['institutional'];

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
          generated_at: new Date().toISOString(),
          acei_category: item.acei_category_primary,
          event_date: item.event_date || item.published_date,
          headline: item.title,
          source_url: item.url,
          legislative_urgency: item.legislative_urgency,
        }, { onConflict: 'source_table,source_id,tier' })
        .select('id')
        .single();

      if (!tbErr && tb) {
        briefingId = tb.id;
        generated++;
      }

      await new Promise(r => setTimeout(r, 1000));
    }

    if (briefingId) {
      await db.from(tableName).update({
        briefing_generated: true,
        briefing_id: briefingId,
        updated_at: new Date().toISOString(),
      }).eq('id', item.id);
    }

    await new Promise(r => setTimeout(r, 500));
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

  console.log('[ticker-parliamentary v13] Starting dual-source briefing generation');

  try {
    const parl = await processTable(db, anthropicKey, 'parliamentary_intelligence', 'parliamentary/regulatory');
    const news = await processTable(db, anthropicKey, 'govuk_news_intelligence', 'GOV.UK news/guidance');

    const totals = {
      processed: parl.processed + news.processed,
      generated: parl.generated + news.generated,
      failed: parl.failed + news.failed,
    };

    console.log(`Done: parliamentary=${JSON.stringify(parl)} govuk_news=${JSON.stringify(news)}`);
    return Response.json({ success: true, totals, parliamentary: parl, govuk_news: news });
  } catch (e) {
    console.error('Fatal:', e);
    return Response.json({ success: false, error: String(e) }, { status: 500 });
  }
});
