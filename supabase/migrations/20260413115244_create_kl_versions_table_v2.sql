-- Migration: 20260413115244_create_kl_versions_table_v2
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_kl_versions_table_v2


-- kl_versions — Historical versions of every provision with dated text and provenance
-- Per KLIA-001 §10.2 Supabase Knowledge Base Schema
-- Enables the Temporal Intelligence Layer (TIL) to resolve any provision at any date

CREATE TABLE IF NOT EXISTS kl_versions (
  version_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provision_id UUID REFERENCES kl_provisions(provision_id) ON DELETE CASCADE,
  instrument_id TEXT NOT NULL,
  section_num TEXT NOT NULL,
  effective_from DATE NOT NULL,
  effective_to DATE, -- NULL if current version
  text TEXT NOT NULL,
  amended_by TEXT, -- The amending instrument (e.g., SI 2026/357)
  source_url TEXT,
  policy_rationale TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for temporal queries (TIL resolver)
CREATE INDEX IF NOT EXISTS idx_kl_versions_temporal 
ON kl_versions (instrument_id, section_num, effective_from, effective_to);

-- Index for provision lookups
CREATE INDEX IF NOT EXISTS idx_kl_versions_provision 
ON kl_versions (provision_id);

COMMENT ON TABLE kl_versions IS 'Historical versions of legislative provisions. Enables TIL (Temporal Intelligence Layer) temporal queries. Per KLIA-001 §5.2 and §10.2. Created 13 April 2026.';

