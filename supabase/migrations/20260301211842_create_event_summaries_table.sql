-- Migration: 20260301211842_create_event_summaries_table
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_event_summaries_table


-- Event Summaries: AI-generated intelligence layer for regulatory events
-- Supports both enforcement_events_unified and legislative_changes
-- Designed for pattern analysis and ACEI category enrichment

CREATE TABLE event_summaries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Source reference (polymorphic: can point to either table)
  source_table TEXT NOT NULL CHECK (source_table IN ('enforcement_events_unified', 'legislative_changes')),
  source_id UUID NOT NULL,
  
  -- AI-generated content
  summary_text TEXT NOT NULL,
  key_points JSONB NOT NULL DEFAULT '[]'::jsonb,
  
  -- ACEI relevance classification
  employment_relevant BOOLEAN NOT NULL DEFAULT true,
  relevance_score INTEGER NOT NULL DEFAULT 0 CHECK (relevance_score BETWEEN 0 AND 100),
  acei_categories TEXT[] DEFAULT '{}',
  acei_category_numbers INTEGER[] DEFAULT '{}',
  
  -- Legal classification
  legal_principles TEXT[] DEFAULT '{}',
  outcome_type TEXT,  -- 'claimant_success', 'respondent_success', 'settled', 'struck_out', 'procedural', 'legislative_update'
  sector_tags TEXT[] DEFAULT '{}',
  
  -- Privacy compliance
  privacy_compliant BOOLEAN NOT NULL DEFAULT true,
  anonymisation_notes TEXT,
  
  -- Generation metadata
  generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  generated_by TEXT NOT NULL DEFAULT 'claude-sonnet-4-5',
  source_url TEXT,
  generation_status TEXT NOT NULL DEFAULT 'completed' CHECK (generation_status IN ('pending', 'generating', 'completed', 'failed', 'skipped')),
  error_message TEXT,
  
  -- Uniqueness: one summary per source event
  UNIQUE (source_table, source_id)
);

-- Indexes for dashboard queries
CREATE INDEX idx_event_summaries_source ON event_summaries (source_table, source_id);
CREATE INDEX idx_event_summaries_relevant ON event_summaries (employment_relevant, relevance_score DESC);
CREATE INDEX idx_event_summaries_categories ON event_summaries USING GIN (acei_categories);
CREATE INDEX idx_event_summaries_generated ON event_summaries (generated_at DESC);
CREATE INDEX idx_event_summaries_status ON event_summaries (generation_status);

-- RLS: public read, service_role write (edge function uses service_role)
ALTER TABLE event_summaries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read access to event summaries"
  ON event_summaries FOR SELECT
  USING (true);

CREATE POLICY "Service role full access to event summaries"
  ON event_summaries FOR ALL
  USING (auth.role() = 'service_role');

-- Also allow authenticated users to INSERT (for edge function called with user JWT)
CREATE POLICY "Authenticated users can insert event summaries"
  ON event_summaries FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update event summaries"
  ON event_summaries FOR UPDATE
  USING (auth.role() = 'authenticated');

COMMENT ON TABLE event_summaries IS 'AI-generated intelligence summaries for regulatory events. Supports pattern analysis across ACEI categories. Privacy-compliant extracts from public tribunal decisions and legislative changes.';

