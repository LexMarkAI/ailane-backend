-- Migration: 20260408102132_create_govuk_blog_content_table
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_govuk_blog_content_table


-- AILANE-SPEC-ISRF-001 v1.0 — GOV.UK Blog & Podcast Content Table
-- Covers: HMCTS blog/podcast, ACAS blog, ACAS podcast, ICO blog, HSE news

CREATE TABLE govuk_blog_content (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_code TEXT NOT NULL,
  published_date DATE NOT NULL,
  title TEXT NOT NULL,
  content_type TEXT NOT NULL CHECK (content_type IN ('blog_post', 'podcast_episode', 'press_release', 'news', 'guidance_update')),
  summary TEXT,
  content_text TEXT,
  transcript_url TEXT,
  source_url TEXT NOT NULL UNIQUE,
  publisher TEXT NOT NULL,
  category_tags TEXT[],
  acei_categories INTEGER[],
  embedding vector(1024),
  embedded_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_govuk_blog_date ON govuk_blog_content (published_date DESC);
CREATE INDEX idx_govuk_blog_source ON govuk_blog_content (source_code);
CREATE INDEX idx_govuk_blog_type ON govuk_blog_content (content_type);

-- Update calendar status for blog/podcast sources
UPDATE intelligence_publication_calendar
SET scraper_status = 'table_deployed', updated_at = now()
WHERE source_code IN ('hmcts-blog-podcast', 'acas-blog', 'acas-podcast', 'ico-blog', 'hse-news')
AND scraper_status = 'pending_build';

