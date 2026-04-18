-- Migration: 20260415185152_dmsp002_commercial_intelligence_schema
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: dmsp002_commercial_intelligence_schema


-- DMSP-002 Compliance Migration
-- SOA 1992 column + commercial_intelligence schema with materialised views
-- Governed by: AILANE-SPEC-DMSP-002 v1.0 (AMD-053)

-- 1. Add SOA 1992 identification column (DMSP-002 §5.2)
ALTER TABLE public.tribunal_enrichment 
ADD COLUMN IF NOT EXISTS soa_1992_identified BOOLEAN DEFAULT NULL;

COMMENT ON COLUMN public.tribunal_enrichment.soa_1992_identified IS 
'DMSP-002 §5.2: True if case relates to SOA 1992 offence allegation. Lifetime anonymity. Suppress from all commercial outputs.';

-- 2. Create commercial_intelligence schema (DMSP-002 §8)
CREATE SCHEMA IF NOT EXISTS commercial_intelligence;

-- 3. Employer Rollup View (GREEN — DMSP-002 §8.1)
CREATE MATERIALIZED VIEW IF NOT EXISTS commercial_intelligence.employer_rollup AS
SELECT 
  em.id AS employer_id,
  em.normalised_name AS employer_name,
  em.companies_house_number,
  em.sic_primary,
  em.sic_codes,
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
  etp.max_single_award,
  etp.avg_award,
  etp.categories_affected,
  etp.category_distribution,
  etp.primary_category,
  etp.has_repeat_pattern,
  etp.repeat_categories,
  etp.years_with_decisions,
  etp.aps_total AS acei_exposure_score,
  etp.aps_segment AS acei_segment,
  etp.observation_window_start,
  etp.observation_window_end,
  etp.computed_at
FROM public.employer_tribunal_profile etp
JOIN public.employer_master em ON em.id = etp.employer_id
WITH NO DATA;

-- 4. Pseudonymised Record View (AMBER — DMSP-002 §8.2)
CREATE MATERIALIZED VIEW IF NOT EXISTS commercial_intelligence.pseudonymised_record AS
SELECT 
  te.decision_id,
  te.outcome,
  te.hearing_type,
  te.claims_brought,
  te.statutory_breaches,
  te.statutory_breach_count,
  te.acei_primary_category,
  te.acei_secondary_categories,
  te.award_total,
  te.basic_award,
  te.compensatory_award,
  te.injury_to_feelings,
  te.personal_injury_award,
  te.respondent_sector,
  te.respondent_size_band,
  te.respondent_is_public_body,
  te.respondent_is_nhs,
  LEFT(te.respondent_postcode_area, 2) AS postcode_area_generalised,
  te.protected_characteristic_primary,
  te.claimant_age_band,
  CASE 
    WHEN te.claimant_salary_annual IS NULL THEN NULL
    WHEN te.claimant_salary_annual < 20000 THEN '0-20k'
    WHEN te.claimant_salary_annual < 40000 THEN '20-40k'
    WHEN te.claimant_salary_annual < 60000 THEN '40-60k'
    WHEN te.claimant_salary_annual < 100000 THEN '60-100k'
    ELSE '100k+'
  END AS salary_band,
  te.claimant_gender,
  te.dismissal_type,
  te.working_pattern,
  te.direct_discrimination_found,
  te.indirect_discrimination_found,
  te.harassment_found,
  te.victimisation_found,
  te.reasonable_adjustments_breach,
  te.disability_agreed,
  te.comparator_type,
  te.contributory_fault_pct,
  te.polkey_reduction_pct,
  te.judge_criticised_respondent,
  te.judge_criticised_claimant,
  te.costs_awarded,
  te.tupe_transfer_confirmed,
  te.fire_and_rehire_tactics,
  te.zero_hours_contract_involved,
  te.fair_work_agency_relevant,
  te.judgment_date,
  te.panel_hearing,
  te.judgment_reserved
FROM public.tribunal_enrichment te
WHERE te.restricted_reporting_order IS DISTINCT FROM TRUE
  AND te.soa_1992_identified IS DISTINCT FROM TRUE
WITH NO DATA;

-- 5. Access control — service_role only
GRANT USAGE ON SCHEMA commercial_intelligence TO service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA commercial_intelligence TO service_role;
REVOKE ALL ON SCHEMA commercial_intelligence FROM anon;
REVOKE ALL ON SCHEMA commercial_intelligence FROM authenticated;

