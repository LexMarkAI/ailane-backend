-- Migration: 20260302183429_create_employer_tribunal_profile
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_employer_tribunal_profile


-- AIE Migration 2: Employer Tribunal Profile & APS Scoring
CREATE TABLE IF NOT EXISTS employer_tribunal_profile (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employer_id uuid REFERENCES employer_master(id) ON DELETE CASCADE,
  computed_at timestamptz DEFAULT now(),
  observation_window_start date,
  observation_window_end date,
  
  total_decisions integer DEFAULT 0,
  decisions_year_1 integer DEFAULT 0,
  decisions_year_2 integer DEFAULT 0,
  decisions_year_3 integer DEFAULT 0,
  recency_weighted_count numeric(6,2),
  
  claimant_won integer DEFAULT 0,
  respondent_won integer DEFAULT 0,
  settled integer DEFAULT 0,
  withdrawn integer DEFAULT 0,
  adverse_outcome_rate numeric(4,3),
  
  total_compensation numeric(12,2) DEFAULT 0,
  max_single_award numeric(12,2) DEFAULT 0,
  avg_award numeric(12,2) DEFAULT 0,
  recency_weighted_compensation numeric(12,2),
  
  categories_affected integer DEFAULT 0,
  category_distribution jsonb DEFAULT '{}'::jsonb,
  primary_category text,
  
  has_repeat_pattern boolean DEFAULT false,
  repeat_categories text[],
  years_with_decisions integer DEFAULT 0,
  
  max_severity_band integer,
  avg_severity_band numeric(3,1),
  
  aps_frequency numeric(5,2) DEFAULT 0,
  aps_recency numeric(5,2) DEFAULT 0,
  aps_severity numeric(5,2) DEFAULT 0,
  aps_spread numeric(5,2) DEFAULT 0,
  aps_repeat numeric(5,2) DEFAULT 0,
  aps_total numeric(5,2) DEFAULT 0,
  aps_segment text CHECK (aps_segment IN (
    'A_critical','B_elevated','C_historical','D_clean'
  )),
  
  UNIQUE(employer_id)
);

CREATE INDEX idx_etp_aps ON employer_tribunal_profile(aps_total DESC);
CREATE INDEX idx_etp_segment ON employer_tribunal_profile(aps_segment);
CREATE INDEX idx_etp_employer ON employer_tribunal_profile(employer_id);

COMMENT ON TABLE employer_tribunal_profile IS 'AIE: Computed tribunal history and Acquisition Priority Score per employer.';

