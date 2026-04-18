-- Migration: 20260302183500_create_aie_supporting_tables
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_aie_supporting_tables


-- AIE Migration 5: Supporting Tables
CREATE TABLE IF NOT EXISTS employer_name_aliases (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employer_id uuid REFERENCES employer_master(id) ON DELETE CASCADE,
  alias_name text NOT NULL,
  alias_source text,
  created_at timestamptz DEFAULT now(),
  UNIQUE(alias_name)
);

CREATE INDEX idx_ena_alias ON employer_name_aliases(alias_name);
CREATE INDEX idx_ena_employer ON employer_name_aliases(employer_id);

COMMENT ON TABLE employer_name_aliases IS 'AIE: Alternative name variants for employer entities.';

CREATE TABLE IF NOT EXISTS aps_computation_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  computed_at timestamptz DEFAULT now(),
  employers_processed integer,
  employers_scored integer,
  segment_a_count integer,
  segment_b_count integer,
  segment_c_count integer,
  segment_d_count integer,
  computation_duration_ms integer,
  metadata jsonb DEFAULT '{}'::jsonb
);

COMMENT ON TABLE aps_computation_log IS 'AIE: Audit trail for APS computation cycles. Constitutional reproducibility requirement.';

