-- Migration: 20260415185931_dmsp002_soa_column_and_employer_rollup_view
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: dmsp002_soa_column_and_employer_rollup_view


-- SOA 1992 column
ALTER TABLE tribunal_enrichment 
  ADD COLUMN IF NOT EXISTS soa_1992_identified BOOLEAN DEFAULT NULL;

COMMENT ON COLUMN tribunal_enrichment.soa_1992_identified IS 'DMSP-002 §5.2: True if SOA 1992 s.2 allegation. Automatic lifetime anonymity. Suppress from ALL external outputs.';

-- Employer Rollup (GREEN product)
CREATE MATERIALIZED VIEW IF NOT EXISTS commercial_intelligence.employer_rollup AS
SELECT 
  em.normalised_name AS employer_name,
  em.companies_house_number,
  em.sic_primary,
  em.acei_sector,
  em.headcount_band,
  em.jurisdiction_region,
  etp.total_decisions,
  etp.decisions_year_1,
  etp.decisions_year_2,
  etp.decisions_year_3,
  etp.claimant_won,
  etp.respondent_won,
  etp.settled,
  etp.withdrawn,
  etp.adverse_outcome_rate,
  etp.total_compensation,
  etp.avg_award,
  etp.max_single_award,
  etp.categories_affected,
  etp.category_distribution,
  etp.primary_category,
  etp.has_repeat_pattern,
  etp.aps_total,
  etp.aps_segment,
  etp.observation_window_start,
  etp.observation_window_end,
  etp.computed_at
FROM public.employer_tribunal_profile etp
JOIN public.employer_master em ON em.id = etp.employer_id
WHERE em.normalised_name IS NOT NULL;

COMMENT ON MATERIALIZED VIEW commercial_intelligence.employer_rollup IS 'DMSP-002 §8.1: Employer Rollup (GREEN). Corporate data. Not personal data. Licensable with OGL attribution.';

CREATE INDEX IF NOT EXISTS idx_cr_employer_rollup_name ON commercial_intelligence.employer_rollup (employer_name);
CREATE INDEX IF NOT EXISTS idx_cr_employer_rollup_ch ON commercial_intelligence.employer_rollup (companies_house_number) WHERE companies_house_number IS NOT NULL;

