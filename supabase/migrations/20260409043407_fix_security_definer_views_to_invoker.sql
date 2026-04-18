-- Migration: 20260409043407_fix_security_definer_views_to_invoker
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: fix_security_definer_views_to_invoker


-- P1 SECURITY FIX: Convert 7 SECURITY DEFINER views to SECURITY INVOKER
-- These views currently bypass RLS by running as the view creator
-- After fix: views respect the querying user's RLS policies

-- 1. qtailane_instrument_prices
DROP VIEW IF EXISTS public.qtailane_instrument_prices;
CREATE VIEW public.qtailane_instrument_prices
WITH (security_invoker = on) AS
SELECT i.id,
    i.venue,
    i.instrument_id,
    i.display_name,
    i.instrument_type,
    i.asset_class,
    i.last_price,
    i.last_price_at,
    i.avg_daily_volume,
    i.avg_spread,
    i.is_market_open,
    i.is_tradeable,
    i.event_category,
    cs.status AS connector_status,
    cs.last_heartbeat AS connector_heartbeat,
    (EXTRACT(epoch FROM (now() - i.last_price_at)))::integer AS seconds_since_update
FROM (qtailane_instruments i
    LEFT JOIN qtailane_connector_status cs ON ((cs.venue = i.venue)))
WHERE (i.is_active = true)
ORDER BY i.venue, i.asset_class, i.display_name;

-- 2. clause_heat_map
DROP VIEW IF EXISTS public.clause_heat_map;
CREATE VIEW public.clause_heat_map
WITH (security_invoker = on) AS
SELECT cf.clause_category,
    cf.statutory_ref,
    rr.requirement_name,
    sum(cf.total_occurrences) AS total_occurrences,
    sum(cf.critical_count) AS total_critical,
    sum(cf.major_count) AS total_major,
    sum(cf.minor_count) AS total_minor,
    sum(cf.compliant_count) AS total_compliant,
    round((((sum(cf.critical_count))::numeric / (NULLIF(sum(cf.total_occurrences), 0))::numeric) * (100)::numeric), 1) AS critical_rate_pct,
    round((((sum(cf.major_count))::numeric / (NULLIF(sum(cf.total_occurrences), 0))::numeric) * (100)::numeric), 1) AS major_rate_pct,
    round((((sum(cf.compliant_count))::numeric / (NULLIF(sum(cf.total_occurrences), 0))::numeric) * (100)::numeric), 1) AS compliant_rate_pct,
    round(avg(cf.heat_score), 3) AS avg_heat_score,
    max(cf.heat_score) AS max_heat_score,
    max(tcs.total_cases) AS tribunal_total_cases,
    max(tcs.claimant_win_rate) AS tribunal_claimant_win_rate,
    round(max(tcs.avg_compensation), 0) AS tribunal_avg_compensation,
    round(max(tcs.max_compensation), 0) AS tribunal_max_compensation,
    min(cf.first_seen_at) AS first_seen_at,
    max(cf.last_seen_at) AS last_seen_at
FROM ((clause_fingerprints cf
    LEFT JOIN regulatory_requirements rr ON ((rr.id = cf.requirement_id)))
    LEFT JOIN tribunal_clause_signals tcs ON (((tcs.clause_category = cf.clause_category) AND (tcs.statutory_ref = cf.statutory_ref))))
GROUP BY cf.clause_category, cf.statutory_ref, rr.requirement_name
ORDER BY (round(avg(cf.heat_score), 3)) DESC, (sum(cf.critical_count)) DESC;

-- 3. canonical_employers
DROP VIEW IF EXISTS public.canonical_employers;
CREATE VIEW public.canonical_employers
WITH (security_invoker = on) AS
SELECT id,
    created_at,
    updated_at,
    raw_name,
    normalised_name,
    companies_house_number,
    companies_house_status,
    sic_codes,
    sic_primary,
    acei_sector,
    registered_address,
    jurisdiction_region,
    acei_jurisdiction_multiplier,
    headcount_estimate,
    headcount_band,
    headcount_source,
    officers,
    normalisation_method,
    normalisation_confidence,
    match_aliases,
    ch_last_fetched,
    ch_fetch_status,
    acei_sector_code,
    acei_sector_group,
    acei_sector_override,
    acei_sector_multiplier,
    sub_region,
    rfvm_band,
    rfvm_value,
    jurisdiction_multiplier,
    is_canonical,
    canonical_employer_id,
    ch_registered_name,
    (SELECT count(*) FROM employer_master v WHERE (v.canonical_employer_id = em.id)) AS variant_count
FROM employer_master em
WHERE (is_canonical = true);

-- 4. qtailane_evidence_queue
DROP VIEW IF EXISTS public.qtailane_evidence_queue;
CREATE VIEW public.qtailane_evidence_queue
WITH (security_invoker = on) AS
SELECT ei.id,
    ei.source_class,
    es.source_name,
    es.trust_score,
    ei.title,
    ei.content_summary,
    ei.relevance_categories,
    ei.relevance_jurisdictions,
    ei.sentiment_score,
    ei.narrative_intensity,
    ei.is_original_reporting,
    ei.published_at,
    ei.ingested_at,
    ei.processing_status,
    (EXTRACT(epoch FROM (now() - ei.ingested_at)))::integer AS age_seconds
FROM (qtailane_evidence_items ei
    JOIN qtailane_evidence_sources es ON ((ei.source_id = es.id)))
WHERE (ei.processing_status = ANY (ARRAY['INGESTED'::text, 'CLASSIFIED'::text]))
ORDER BY ei.ingested_at DESC;

-- 5. tribunal_intelligence
DROP VIEW IF EXISTS public.tribunal_intelligence;
CREATE VIEW public.tribunal_intelligence
WITH (security_invoker = on) AS
SELECT td.id,
    td.title,
    td.respondent_name,
    td.acei_category,
    td.decision_date,
    td.source_url,
    te.outcome,
    te.award_total,
    te.basic_award,
    te.compensatory_award,
    te.injury_to_feelings,
    te.vento_band,
    te.costs_order_amount,
    te.costs_order_against,
    te.hearing_days,
    te.judge_name,
    te.tribunal_region,
    te.claimant_rep_type,
    te.respondent_rep_type,
    te.est_total_legal_ecosystem,
    te.extraction_confidence,
    te.scrape_status
FROM (tribunal_decisions td
    LEFT JOIN tribunal_enrichment te ON ((te.decision_id = td.id)));

-- 6. active_corporate_relationships
DROP VIEW IF EXISTS public.active_corporate_relationships;
CREATE VIEW public.active_corporate_relationships
WITH (security_invoker = on) AS
SELECT cr.id,
    cr.relationship_type,
    cr.relationship_confidence,
    cr.confidence_source,
    cr.is_active,
    cr.effective_from,
    cr.effective_to,
    cr.w_computed,
    cr.franchise_brand,
    cr.ownership_pct,
    p.id AS parent_id,
    p.normalised_name AS parent_name,
    p.ch_registered_name AS parent_ch_name,
    p.companies_house_number AS parent_ch_number,
    c.id AS child_id,
    c.normalised_name AS child_name,
    c.ch_registered_name AS child_ch_name,
    c.companies_house_number AS child_ch_number
FROM ((corporate_relationships cr
    JOIN employer_master p ON ((p.id = cr.parent_employer_id)))
    JOIN employer_master c ON ((c.id = cr.child_employer_id)))
WHERE (cr.is_active = true);

-- 7. enterprise_network_summary
DROP VIEW IF EXISTS public.enterprise_network_summary;
CREATE VIEW public.enterprise_network_summary
WITH (security_invoker = on) AS
SELECT ep.root_employer_id,
    em.normalised_name AS root_name,
    em.ch_registered_name AS root_ch_name,
    ep.entity_count,
    ep.franchise_entity_count,
    ep.subsidiary_entity_count,
    ep.direct_acei,
    ep.enterprise_acei,
    ep.frar,
    ep.penetration_rate,
    ep.highest_child_acei,
    ep.computed_at,
    ep.computation_version
FROM (enterprise_profiles ep
    JOIN employer_master em ON ((em.id = ep.root_employer_id)));

