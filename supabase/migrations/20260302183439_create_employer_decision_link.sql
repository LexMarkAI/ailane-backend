-- Migration: 20260302183439_create_employer_decision_link
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_employer_decision_link


-- AIE Migration 3: Employer-Decision Junction Table
CREATE TABLE IF NOT EXISTS employer_decision_link (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employer_id uuid REFERENCES employer_master(id) ON DELETE CASCADE,
  decision_id uuid REFERENCES tribunal_decisions(id) ON DELETE CASCADE,
  link_confidence numeric(3,2),
  link_method text,
  created_at timestamptz DEFAULT now(),
  UNIQUE(employer_id, decision_id)
);

CREATE INDEX idx_edl_employer ON employer_decision_link(employer_id);
CREATE INDEX idx_edl_decision ON employer_decision_link(decision_id);

COMMENT ON TABLE employer_decision_link IS 'AIE: Links employers to their tribunal decisions with confidence scoring.';

