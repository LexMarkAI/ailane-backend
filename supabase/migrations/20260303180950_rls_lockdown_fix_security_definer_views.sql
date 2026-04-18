-- Migration: 20260303180950_rls_lockdown_fix_security_definer_views
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: rls_lockdown_fix_security_definer_views


-- ============================================================
-- AILANE RLS LOCKDOWN — MIGRATION 2 OF 3
-- Recreate 6 views as SECURITY INVOKER (respect caller's RLS)
-- Fixes all 6 ERROR-level security advisories
-- ============================================================

-- ── 1. aie_enrichment_dashboard ─────────────────────────────
DROP VIEW IF EXISTS aie_enrichment_dashboard;
CREATE VIEW aie_enrichment_dashboard
WITH (security_invoker = true) AS
SELECT count(*) AS total_employers,
    count(CASE WHEN (ch_fetch_status = 'completed') THEN 1 ELSE NULL END) AS enriched,
    count(CASE WHEN (ch_fetch_status = 'pending') THEN 1 ELSE NULL END) AS pending,
    count(CASE WHEN (ch_fetch_status = 'not_found') THEN 1 ELSE NULL END) AS not_found,
    count(CASE WHEN (ch_fetch_status = 'low_confidence') THEN 1 ELSE NULL END) AS low_confidence,
    count(CASE WHEN (ch_fetch_status = 'skipped_individual') THEN 1 ELSE NULL END) AS individuals,
    count(CASE WHEN (ch_fetch_status = 'error') THEN 1 ELSE NULL END) AS errors,
    count(CASE WHEN (acei_sector = 'Financial Services') THEN 1 ELSE NULL END) AS sector_financial,
    count(CASE WHEN (acei_sector = 'Professional Services') THEN 1 ELSE NULL END) AS sector_professional,
    count(CASE WHEN (acei_sector = 'Healthcare') THEN 1 ELSE NULL END) AS sector_healthcare,
    count(CASE WHEN (acei_sector = 'Technology') THEN 1 ELSE NULL END) AS sector_technology,
    count(CASE WHEN (acei_sector = 'Retail & Hospitality') THEN 1 ELSE NULL END) AS sector_retail,
    count(CASE WHEN (acei_sector = 'Manufacturing') THEN 1 ELSE NULL END) AS sector_manufacturing,
    count(CASE WHEN (acei_sector = 'Construction') THEN 1 ELSE NULL END) AS sector_construction,
    count(CASE WHEN (acei_sector = 'Education') THEN 1 ELSE NULL END) AS sector_education,
    count(CASE WHEN (acei_sector = 'Public Sector') THEN 1 ELSE NULL END) AS sector_public,
    count(CASE WHEN (acei_sector = 'Transport & Logistics') THEN 1 ELSE NULL END) AS sector_transport,
    count(CASE WHEN (jurisdiction_region = 'London') THEN 1 ELSE NULL END) AS jurisdiction_london,
    count(CASE WHEN (jurisdiction_region = 'Scotland') THEN 1 ELSE NULL END) AS jurisdiction_scotland,
    count(CASE WHEN (jurisdiction_region = 'Wales') THEN 1 ELSE NULL END) AS jurisdiction_wales,
    count(CASE WHEN (jurisdiction_region = 'Northern Ireland') THEN 1 ELSE NULL END) AS jurisdiction_ni,
    count(CASE WHEN (headcount_band = 'micro_1_9') THEN 1 ELSE NULL END) AS size_micro,
    count(CASE WHEN (headcount_band = 'small_10_49') THEN 1 ELSE NULL END) AS size_small,
    count(CASE WHEN (headcount_band = 'medium_50_249') THEN 1 ELSE NULL END) AS size_medium,
    count(CASE WHEN (headcount_band = 'large_250_499') THEN 1 ELSE NULL END) AS size_large,
    count(CASE WHEN (headcount_band = 'enterprise_500_plus') THEN 1 ELSE NULL END) AS size_enterprise
FROM employer_master;

-- ── 2. employer_exposure_parameters ─────────────────────────
DROP VIEW IF EXISTS employer_exposure_parameters;
CREATE VIEW employer_exposure_parameters
WITH (security_invoker = true) AS
SELECT em.id,
    em.normalised_name,
    em.jurisdiction_region,
    em.sub_region,
    em.acei_sector_code,
    sm.sector_name,
    sm.sector_group_name,
    COALESCE(em.acei_sector_multiplier, 1.00) AS sector_multiplier,
    (em.acei_sector_override IS NOT NULL) AS is_override_classified,
    COALESCE(em.jurisdiction_multiplier, 1.00) AS jurisdiction_multiplier,
    COALESCE(em.rfvm_value, 1.00) AS rfvm_value,
    em.rfvm_band,
    round((COALESCE(em.acei_sector_multiplier, 1.00) * COALESCE(em.jurisdiction_multiplier, 1.00)), 4) AS combined_likelihood_modifier,
    CASE
        WHEN ((em.acei_sector_code IS NOT NULL) AND (em.jurisdiction_multiplier IS NOT NULL) AND (em.rfvm_value IS NOT NULL)) THEN 'FULL'
        WHEN (em.jurisdiction_multiplier IS NOT NULL) THEN 'PARTIAL_JM_ONLY'
        WHEN (em.acei_sector_code IS NOT NULL) THEN 'PARTIAL_SM_ONLY'
        ELSE 'UNCLASSIFIED'
    END AS classification_status
FROM employer_master em
LEFT JOIN acei_sector_sic_map sm ON (em.acei_sector_code = sm.sector_code);

-- ── 3. legislation_library_dashboard ────────────────────────
DROP VIEW IF EXISTS legislation_library_dashboard;
CREATE VIEW legislation_library_dashboard
WITH (security_invoker = true) AS
SELECT count(*) AS total_legislation,
    count(*) FILTER (WHERE legislation_type = 'primary') AS acts_of_parliament,
    count(*) FILTER (WHERE legislation_type = 'statutory_instrument') AS statutory_instruments,
    count(*) FILTER (WHERE legislation_type = 'binding_code') AS codes_of_practice,
    count(*) FILTER (WHERE lifecycle_stage = 'in_force') AS in_force,
    count(*) FILTER (WHERE lifecycle_stage = 'bill') AS pending_bills,
    count(*) FILTER (WHERE lifecycle_stage = 'partially_commenced') AS partially_commenced,
    count(DISTINCT primary_acei_category) AS acei_categories_covered,
    count(*) FILTER (WHERE tier_access = 'all') AS all_tier_access,
    count(*) FILTER (WHERE tier_access = 'governance') AS governance_only,
    count(*) FILTER (WHERE tier_access = 'institutional') AS institutional_only,
    min(commencement_date) AS earliest_legislation,
    max(commencement_date) AS latest_commencement
FROM legislation_library;

-- ── 4. regional_exposure_summary ────────────────────────────
DROP VIEW IF EXISTS regional_exposure_summary;
CREATE VIEW regional_exposure_summary
WITH (security_invoker = true) AS
SELECT jm.jurisdiction_region,
    jm.jurisdiction_multiplier,
    jm.rfvm_band,
    jm.rfvm_value,
    jm.employer_failure_rate,
    jm.population_millions,
    count(em.id) AS employer_count,
    count(CASE WHEN (em.acei_sector_code IS NOT NULL) THEN 1 ELSE NULL END) AS sector_classified,
    count(CASE WHEN (em.sub_region IS NOT NULL) THEN 1 ELSE NULL END) AS sub_region_assigned,
    round((1.0 * count(em.id)::numeric / NULLIF(jm.population_millions, 0::numeric)), 0) AS employers_per_million
FROM acei_jurisdiction_map jm
LEFT JOIN employer_master em ON (em.jurisdiction_region = jm.jurisdiction_region)
GROUP BY jm.jurisdiction_region, jm.jurisdiction_multiplier, jm.rfvm_band, jm.rfvm_value, jm.employer_failure_rate, jm.population_millions
ORDER BY jm.jurisdiction_multiplier DESC;

-- ── 5. sector_exposure_summary ──────────────────────────────
DROP VIEW IF EXISTS sector_exposure_summary;
CREATE VIEW sector_exposure_summary
WITH (security_invoker = true) AS
SELECT sm.sector_code,
    sm.sector_name,
    sm.sector_group,
    sm.sector_group_name,
    sm.sector_multiplier,
    count(em.id) AS employer_count,
    count(td.id) AS tribunal_cases,
    round((1.0 * count(td.id)::numeric / NULLIF(count(DISTINCT em.id), 0)::numeric), 3) AS cases_per_employer,
    round(avg(COALESCE(em.jurisdiction_multiplier, 1.00)), 3) AS avg_jm,
    round(avg(COALESCE(em.rfvm_value, 1.00)), 3) AS avg_rfvm
FROM acei_sector_sic_map sm
LEFT JOIN employer_master em ON (em.acei_sector_code = sm.sector_code)
LEFT JOIN tribunal_decisions td ON (lower(td.respondent_name) = lower(em.normalised_name))
GROUP BY sm.sector_code, sm.sector_name, sm.sector_group, sm.sector_group_name, sm.sector_multiplier
ORDER BY sm.sector_group, sm.sector_code;

-- ── 6. upcoming_legislative_changes ─────────────────────────
DROP VIEW IF EXISTS upcoming_legislative_changes;
CREATE VIEW upcoming_legislative_changes
WITH (security_invoker = true) AS
SELECT short_title,
    lifecycle_stage,
    commencement_date,
    acei_categories,
    primary_acei_category,
    sci_significance,
    summary,
    obligations_summary,
    legislation_gov_url,
    tags
FROM legislation_library
WHERE lifecycle_stage = ANY (ARRAY['bill', 'royal_assent', 'partially_commenced'])
ORDER BY sci_significance DESC, commencement_date;

