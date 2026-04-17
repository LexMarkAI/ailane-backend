import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const PIPELINE_CODE = 'govuk_employment_news_daily';
const UA = 'Ailane-Regulatory-Intelligence/1.0 (+https://ailane.ai)';

const db = createClient(SUPABASE_URL, SUPABASE_KEY);

const SEARCH_TOPICS = [
  'employment rights', 'employment tribunal', 'minimum wage', 'trade unions',
  'redundancy', 'workplace discrimination', 'maternity pay', 'flexible working',
  'zero hours contracts', 'fire and rehire', 'ACAS', 'HMRC employer'
];

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
  return [...new Set(cats)];
}

function hash(s: string): string {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = Math.imul(31, h) + s.charCodeAt(i) | 0;
  return Math.abs(h).toString(16);
}

async function startRun(): Promise<string> {
  const { data } = await db.from('pipeline_runs').insert({
    pipeline_code: PIPELINE_CODE, status: 'running', trigger_type: 'scheduled'
  }).select('id').single();
  return data!.id;
}

async function finishRun(runId: string, status: string, counts: Record<string, number>, error?: string) {
  await db.from('pipeline_runs').update({
    status, completed_at: new Date().toISOString(), error_message: error || null, ...counts
  }).eq('id', runId);
  await db.from('pipeline_registry').update({
    last_run_at: new Date().toISOString(),
    ...(status === 'success' ? { last_success_at: new Date().toISOString(), consecutive_failures: 0 } : {})
  }).eq('pipeline_code', PIPELINE_CODE);
}

Deno.serve(async (_req) => {
  const runId = await startRun();
  console.log(`[govuk-news] Run ${runId}`);
  let found = 0, inserted = 0, duplicate = 0;

  try {
    // GOV.UK Search API — filter_any_organisations[] applies OR semantics across orgs.
    // Bare filter_organisations= defaults to AND (invalid for multi-org OR queries -> 422).
    // document_type removed from fields= (rejected as invalid request field); still returned by default in result body.
    const apiUrl = 'https://www.gov.uk/api/search.json?filter_any_organisations%5B%5D=department-for-business-and-trade&filter_any_organisations%5B%5D=acas&filter_any_organisations%5B%5D=hm-revenue-customs&count=50&order=-public_timestamp&fields=title,description,link,public_timestamp';

    const r = await fetch(apiUrl, { headers: { 'User-Agent': UA, Accept: 'application/json' } });
    if (!r.ok) throw new Error(`GOV.UK API: ${r.status}`);
    const data = await r.json();
    const results = data.results || [];

    const yesterday = new Date();
    yesterday.setDate(yesterday.getDate() - 1);

    for (const item of results) {
      const title = item.title?.trim();
      if (!title) continue;

      const desc = item.description || '';
      const allText = title + ' ' + desc;

      // Filter to employment-relevant content
      const relevant = SEARCH_TOPICS.some(t => allText.toLowerCase().includes(t.toLowerCase()));
      if (!relevant) continue;
      found++;

      const pubDate = item.public_timestamp ? item.public_timestamp.split('T')[0] : new Date().toISOString().split('T')[0];
      const url = item.link ? 'https://www.gov.uk' + item.link : null;
      const acei = inferCategories(allText);
      const contentHash = hash(title + (item.link || ''));

      const docType = item.document_type || '';
      let sourceType = 'govuk_press_release';

      const { error } = await db.from('parliamentary_intelligence').insert({
        source_type: sourceType,
        title,
        summary: desc || null,
        url,
        parliament_url: url,
        published_date: pubDate,
        event_date: pubDate,
        acei_categories: acei,
        acei_category_primary: acei[0] || null,
        legislative_urgency: 'monitor',
        ticker_eligible: true,
        ticker_tier: 'all',
        content_hash: contentHash
      });

      if (error?.code === '23505') duplicate++;
      else if (!error) inserted++;
    }

    // Also fetch ACAS news RSS
    try {
      const acasRes = await fetch('https://www.acas.org.uk/news-and-views/rss', { headers: { 'User-Agent': UA } });
      if (acasRes.ok) {
        const xml = await acasRes.text();
        const itemRe = /<item>([\s\S]*?)<\/item>/g;
        let m;
        while ((m = itemRe.exec(xml)) !== null) {
          const block = m[1];
          const titleM = block.match(/<title>(?:<!\[CDATA\[)?([^\]<]+)/);
          const linkM = block.match(/<link>([^<]+)</);
          const dateM = block.match(/<pubDate>([^<]+)</);
          const descM = block.match(/<description>(?:<!\[CDATA\[)?([^\]<]+)/);

          const title = titleM?.[1]?.trim();
          if (!title) continue;
          found++;

          const url = linkM?.[1]?.trim() || null;
          const pubDate = dateM?.[1] ? new Date(dateM[1]).toISOString().split('T')[0] : new Date().toISOString().split('T')[0];
          const acei = inferCategories(title + (descM?.[1] || ''));
          const contentHash = hash('acas:' + title + pubDate);

          const { error } = await db.from('parliamentary_intelligence').insert({
            source_type: 'govuk_press_release',
            committee_name: 'ACAS',
            title: 'ACAS: ' + title,
            summary: descM?.[1]?.trim() || null,
            url,
            published_date: pubDate,
            event_date: pubDate,
            acei_categories: acei,
            acei_category_primary: acei[0] || null,
            legislative_urgency: 'monitor',
            ticker_eligible: true,
            ticker_tier: 'all',
            content_hash: contentHash
          });
          if (error?.code === '23505') duplicate++;
          else if (!error) inserted++;
        }
      }
    } catch (e) { console.warn('ACAS RSS error:', e); }

    await finishRun(runId, 'success', { records_found: found, records_new: inserted, records_duplicate: duplicate });
    console.log(`Done: ${inserted} new GOV.UK/ACAS items`);
    return Response.json({ success: true, found, inserted, duplicate });

  } catch (e) {
    console.error('Fatal:', e);
    await finishRun(runId, 'failed', { records_found: found }, String(e));
    return Response.json({ success: false, error: String(e) }, { status: 500 });
  }
});
