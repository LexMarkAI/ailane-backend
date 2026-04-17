-- AILANE GNYO-001 — Migration B
-- Dedicated table for GOV.UK news & agency communications.
-- Split out of parliamentary_intelligence per Director intent 2026-04-17.

CREATE TABLE IF NOT EXISTS public.govuk_news_intelligence (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  source_type           text NOT NULL,
  source_org_slug       text,
  source_org_name       text,
  title                 text NOT NULL,
  summary               text,
  url                   text,
  published_date        date,
  public_timestamp      timestamptz,
  acei_categories       text[],
  acei_category_primary text,
  legislative_urgency   text DEFAULT 'monitor',
  ticker_eligible       boolean DEFAULT true,
  ticker_tier           text DEFAULT 'all',
  briefing_generated    boolean DEFAULT false,
  briefing_id           uuid,
  content_hash          text,
  isrf_file_path        text,
  raw_document_type     text,
  CONSTRAINT govuk_news_title_not_empty
    CHECK (length(trim(both from title)) > 0),
  CONSTRAINT govuk_news_source_type_check
    CHECK (source_type = ANY (ARRAY[
      'govuk_press_release',
      'govuk_news_story',
      'govuk_guidance',
      'govuk_statutory_guidance',
      'govuk_consultation',
      'govuk_speech',
      'acas_news_rss'
    ])),
  CONSTRAINT govuk_news_legislative_urgency_check
    CHECK (legislative_urgency = ANY (ARRAY['critical','high','elevated','monitor','archived'])),
  CONSTRAINT govuk_news_ticker_tier_check
    CHECK (ticker_tier = ANY (ARRAY['all','governance','institutional'])),
  CONSTRAINT govuk_news_content_hash_key
    UNIQUE (content_hash)
);

CREATE INDEX IF NOT EXISTS idx_govuk_news_published_date
  ON public.govuk_news_intelligence (published_date DESC);

CREATE INDEX IF NOT EXISTS idx_govuk_news_ticker_pending
  ON public.govuk_news_intelligence (ticker_eligible, briefing_generated, published_date DESC)
  WHERE ticker_eligible = true AND briefing_generated = false;

CREATE INDEX IF NOT EXISTS idx_govuk_news_source_org_slug
  ON public.govuk_news_intelligence (source_org_slug);

CREATE INDEX IF NOT EXISTS idx_govuk_news_public_timestamp
  ON public.govuk_news_intelligence (public_timestamp DESC);

-- RLS
ALTER TABLE public.govuk_news_intelligence ENABLE ROW LEVEL SECURITY;

CREATE POLICY "govuk_news_service_role_all"
  ON public.govuk_news_intelligence
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

CREATE POLICY "govuk_news_authenticated_select"
  ON public.govuk_news_intelligence
  FOR SELECT
  TO authenticated
  USING (true);

COMMENT ON TABLE public.govuk_news_intelligence IS
  'GOV.UK news, agency communications, and ACAS RSS items. Populated by pipeline-govuk-news. Constitutional authority: ACEI Art. XI.';
