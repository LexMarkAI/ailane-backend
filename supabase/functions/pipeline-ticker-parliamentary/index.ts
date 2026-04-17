import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ANTHROPIC_KEY = Deno.env.get('ANTHROPIC_API_KEY')!;

const db = createClient(SUPABASE_URL, SUPABASE_KEY);

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

async function generateBriefing(item: Record<string, unknown>, tier: string): Promise<string | null> {
  try {
    const prompt = `Generate an employment law intelligence briefing for this parliamentary/regulatory development:

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
        'x-api-key': ANTHROPIC_KEY,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json'
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 400,
        system: SYSTEM_PROMPT,
        messages: [{ role: 'user', content: prompt }]
      })
    });

    if (!r.ok) { console.error(`Anthropic ${r.status}`); return null; }
    const data = await r.json();
    return data.content?.[0]?.text?.trim() || null;
  } catch (e) {
    console.error('Briefing generation error:', e);
    return null;
  }
}

Deno.serve(async (_req) => {
  console.log('[ticker-parliamentary] Starting briefing generation');
  let processed = 0, generated = 0, failed = 0;

  try {
    // Fetch parliamentary intelligence items needing briefings
    const { data: items, error } = await db
      .from('parliamentary_intelligence')
      .select('*')
      .eq('ticker_eligible', true)
      .eq('briefing_generated', false)
      .gte('published_date', new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0])
      .order('published_date', { ascending: false })
      .limit(20);

    if (error) throw error;
    if (!items?.length) {
      console.log('No items needing briefings');
      return Response.json({ success: true, processed: 0, generated: 0 });
    }

    console.log(`Processing ${items.length} items`);

    for (const item of items) {
      processed++;
      const tiers = item.ticker_tier === 'all'
        ? ['all', 'governance', 'institutional']
        : item.ticker_tier === 'governance'
        ? ['governance', 'institutional']
        : ['institutional'];

      let briefingId: string | null = null;

      for (const tier of tiers) {
        const briefing = await generateBriefing(item, tier);
        if (!briefing) { failed++; continue; }

        // Determine source table and ID for ticker_briefings
        const { data: tb, error: tbErr } = await db.from('ticker_briefings').upsert({
          source_table: 'parliamentary_intelligence',
          source_id: item.id,
          tier,
          briefing_text: briefing,
          generated_at: new Date().toISOString(),
          acei_category: item.acei_category_primary,
          event_date: item.event_date || item.published_date,
          headline: item.title,
          source_url: item.url,
          legislative_urgency: item.legislative_urgency,
        }, { onConflict: 'source_table,source_id,tier' }).select('id').single();

        if (!tbErr && tb) {
          briefingId = tb.id;
          generated++;
        }

        await new Promise(r => setTimeout(r, 1000));
      }

      // Mark as briefing generated
      if (briefingId) {
        await db.from('parliamentary_intelligence').update({
          briefing_generated: true,
          briefing_id: briefingId,
          updated_at: new Date().toISOString()
        }).eq('id', item.id);
      }

      await new Promise(r => setTimeout(r, 500));
    }

    console.log(`Done: ${generated} briefings generated, ${failed} failed`);
    return Response.json({ success: true, processed, generated, failed });

  } catch (e) {
    console.error('Fatal:', e);
    return Response.json({ success: false, error: String(e) }, { status: 500 });
  }
});
