-- Migration: 20260304211834_create_ticker_briefings_cache
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_ticker_briefings_cache


-- Ticker briefings cache: one row per event per tier
CREATE TABLE public.ticker_briefings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Event reference
  source_table text NOT NULL,
  source_id uuid NOT NULL,
  event_title text,
  
  -- Tier
  tier text NOT NULL DEFAULT 'operational',
  
  -- Briefing content
  briefing_text text NOT NULL,
  briefing_sections jsonb DEFAULT '{}',
  
  -- Quality gate
  quality_score integer NOT NULL DEFAULT 0,
  quality_passed boolean NOT NULL DEFAULT false,
  quality_notes text,
  section_count integer DEFAULT 0,
  word_count integer DEFAULT 0,
  
  -- Generation metadata
  generation_status text NOT NULL DEFAULT 'pending',
  generated_at timestamptz NOT NULL DEFAULT now(),
  generated_by text DEFAULT 'claude-sonnet',
  generation_duration_ms integer,
  model_used text,
  
  -- Refresh tracking
  refresh_count integer NOT NULL DEFAULT 0,
  last_refreshed_at timestamptz,
  stale_after timestamptz,
  
  -- Error handling
  error_message text,
  retry_count integer NOT NULL DEFAULT 0,
  
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  
  -- Constraints
  CONSTRAINT ticker_briefings_source_table_check 
    CHECK (source_table IN ('tribunal_decisions', 'legislative_changes', 'enforcement_events_unified')),
  CONSTRAINT ticker_briefings_tier_check 
    CHECK (tier IN ('operational', 'governance', 'institutional')),
  CONSTRAINT ticker_briefings_status_check 
    CHECK (generation_status IN ('pending', 'generating', 'completed', 'failed', 'stale')),
  CONSTRAINT ticker_briefings_quality_score_check 
    CHECK (quality_score >= 0 AND quality_score <= 100),
  
  -- One briefing per event per tier
  CONSTRAINT ticker_briefings_unique_event_tier 
    UNIQUE (source_table, source_id, tier)
);

-- Indexes for fast lookups
CREATE INDEX idx_ticker_briefings_lookup 
  ON public.ticker_briefings (source_table, source_id, tier, generation_status);
  
CREATE INDEX idx_ticker_briefings_stale 
  ON public.ticker_briefings (stale_after) 
  WHERE generation_status = 'completed';

CREATE INDEX idx_ticker_briefings_pending 
  ON public.ticker_briefings (created_at) 
  WHERE generation_status = 'pending';

-- RLS: authenticated users can read completed briefings
ALTER TABLE public.ticker_briefings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can read completed briefings"
  ON public.ticker_briefings FOR SELECT
  TO authenticated
  USING (generation_status = 'completed' AND quality_passed = true);

CREATE POLICY "Service role full access"
  ON public.ticker_briefings FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_ticker_briefings_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ticker_briefings_updated
  BEFORE UPDATE ON public.ticker_briefings
  FOR EACH ROW
  EXECUTE FUNCTION update_ticker_briefings_timestamp();

COMMENT ON TABLE public.ticker_briefings IS 'Cached AI-generated briefings for ticker events. Pipeline-first: generated on ingest, served from cache, refreshed every 24 hours.';

