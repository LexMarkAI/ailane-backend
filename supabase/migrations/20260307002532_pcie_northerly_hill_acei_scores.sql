-- Migration: 20260307002532_pcie_northerly_hill_acei_scores
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: pcie_northerly_hill_acei_scores


-- ============================================================
-- NORTHERLY HILL — ACEI CONSTITUTIONAL COMPUTATION
-- ACEI v1.0 | SM=1.20 | JM=1.03 (workforce-weighted)
-- DRT = 199.19 | DMR = 300 | DI = 66
-- Computed: 7 March 2026 | Week start: 2 March 2026
-- ============================================================

-- Category-level scores — 12 categories, constitutional formula:
-- CRS = L × I
-- WCS_pre = CRS × SM × JM
-- WCS = WCS_pre × (1 + v_total)
-- v_total = v_category + v_domain (capped at 0.15)
-- v_domain = 0.05 (4 categories show v_category ≥ 0.05)

INSERT INTO acei_category_scores (
  org_id, week_start_date, domain, category, version,
  l, i, sm, jm, v_category, v_domain,
  crs, wcs_pre, wcs,
  evi, eii, sci, l_raw,
  jurisdiction_code,
  source_refs
) VALUES

-- Cat 1: Unfair Dismissal & Wrongful Termination
-- FM: high turnover, multi-site procedural risk, 2022 dismissal in conduct history
('d0000000-0000-4000-8000-000000000001'::uuid,
 '2026-03-02', 'employment', 'unfair_dismissal', 'v1.0.0',
 4, 3, 1.20, 1.03, 0.00, 0.00,
 12, 14.832, 14.832,
 4, 3, 4, 3.7,
 'GB',
 '[{"source": "acei_tribunal_db", "category_decision_count": "high"}]'::jsonb),

-- Cat 2: Discrimination & Harassment
-- FM: diverse operative workforce, Equality Act gender pay (248 employees > 250 threshold)
('d0000000-0000-4000-8000-000000000001'::uuid,
 '2026-03-02', 'employment', 'discrimination_harassment', 'v1.0.0',
 3, 4, 1.20, 1.03, 0.00, 0.00,
 12, 14.832, 14.832,
 3, 3, 3, 3.0,
 'GB',
 '[{"source": "acei_tribunal_db", "category_decision_count": "moderate"}]'::jsonb),

-- Cat 3: Wages & Working Time (WTR + NMW combined)
-- FM: shift-based, depot-to-site travel time claims, NMW operative bands
-- VELOCITY: travel time case law momentum + NLW April 2025 enforcement
-- v_domain applies (4 categories ≥ 0.05): v_total = 0.07 + 0.05 = 0.12
('d0000000-0000-4000-8000-000000000001'::uuid,
 '2026-03-02', 'employment', 'wages_working_time', 'v1.0.0',
 4, 5, 1.20, 1.03, 0.07, 0.05,
 20, 24.720, 27.686,
 5, 4, 4, 4.4,
 'GB',
 '[{"source": "acei_tribunal_db", "category_decision_count": "very_high"}, {"source": "hmrc_enforcement", "enforcement_uplift": "nwl_increase_2025"}]'::jsonb),

-- Cat 4: Whistleblowing
-- FM: potential COSHH/H&S protected disclosures; moderate sector exposure
('d0000000-0000-4000-8000-000000000001'::uuid,
 '2026-03-02', 'employment', 'whistleblowing', 'v1.0.0',
 2, 4, 1.20, 1.03, 0.00, 0.00,
 8, 9.888, 9.888,
 2, 2, 2, 2.0,
 'GB',
 '[{"source": "acei_tribunal_db", "category_decision_count": "low"}]'::jsonb),

-- Cat 5: Employment Status
-- FM: worker vs employee classification endemic (zero-hours, AWR agency workers)
-- VELOCITY: ongoing Supreme Court worker classification case law
-- v_total = 0.06 + 0.05 = 0.11
('d0000000-0000-4000-8000-000000000001'::uuid,
 '2026-03-02', 'employment', 'employment_status', 'v1.0.0',
 4, 4, 1.20, 1.03, 0.06, 0.05,
 16, 19.776, 21.952,
 4, 3, 4, 3.7,
 'GB',
 '[{"source": "acei_tribunal_db", "category_decision_count": "high"}, {"source": "acei_enforcement", "awr_enforcement_trend": "elevated"}]'::jsonb),

-- Cat 6: Redundancy & Organisational Change (TUPE)
-- FM: TUPE endemic to sector; contract transitions regular; 2022 TUPE consultation failure
-- VELOCITY: ongoing TUPE reform discussions and case law momentum
-- v_total = 0.05 + 0.05 = 0.10
('d0000000-0000-4000-8000-000000000001'::uuid,
 '2026-03-02', 'employment', 'redundancy_org_change', 'v1.0.0',
 4, 5, 1.20, 1.03, 0.05, 0.05,
 20, 24.720, 27.192,
 5, 3, 3, 3.8,
 'GB',
 '[{"source": "acei_tribunal_db", "category_decision_count": "very_high"}, {"source": "acas_data", "tupe_conciliation_trend": "elevated"}]'::jsonb),

-- Cat 7: Parental & Family Rights
-- FM: large workforce, ERRA 2023 flexible working changes (SCI=4)
('d0000000-0000-4000-8000-000000000001'::uuid,
 '2026-03-02', 'employment', 'parental_family_rights', 'v1.0.0',
 4, 3, 1.20, 1.03, 0.00, 0.00,
 12, 14.832, 14.832,
 4, 3, 4, 3.7,
 'GB',
 '[{"source": "acei_tribunal_db", "category_decision_count": "moderate"}, {"source": "legislation", "erra_2023_flexible_working": "SCI_elevated"}]'::jsonb),

-- Cat 8: Trade Union & Collective Rights
-- FM: no union recognition; standard sector exposure
('d0000000-0000-4000-8000-000000000001'::uuid,
 '2026-03-02', 'employment', 'trade_union_collective', 'v1.0.0',
 2, 2, 1.20, 1.03, 0.00, 0.00,
 4, 4.944, 4.944,
 1, 2, 3, 1.9,
 'GB',
 '[{"source": "acei_tribunal_db", "category_decision_count": "low"}, {"source": "profile", "union_recognition": false}]'::jsonb),

-- Cat 9: Breach of Contract & Notice Disputes
-- FM: multi-site deployment ERA s.1 written statement issues; restrictive covenants (senior)
('d0000000-0000-4000-8000-000000000001'::uuid,
 '2026-03-02', 'employment', 'breach_of_contract', 'v1.0.0',
 3, 4, 1.20, 1.03, 0.00, 0.00,
 12, 14.832, 14.832,
 4, 2, 3, 3.1,
 'GB',
 '[{"source": "acei_tribunal_db", "category_decision_count": "moderate"}, {"source": "profile", "era_s1_risk": "multi_site_deployment"}]'::jsonb),

-- Cat 10: Health & Safety Protections
-- FM: COSHH, manual handling, lone working, cleaning chemicals, RIDDOR
-- VELOCITY: HSE cleaning sector enforcement programme
-- v_total = 0.05 + 0.05 = 0.10
('d0000000-0000-4000-8000-000000000001'::uuid,
 '2026-03-02', 'employment', 'health_safety', 'v1.0.0',
 4, 5, 1.20, 1.03, 0.05, 0.05,
 20, 24.720, 27.192,
 5, 4, 4, 4.4,
 'GB',
 '[{"source": "hse_enforcement", "sector_programme": "cleaning_services"}, {"source": "acei_tribunal_db", "category_decision_count": "very_high"}]'::jsonb),

-- Cat 11: Data Protection & Employee Privacy
-- FM: CCTV/surveillance in client premises, employee monitoring, UK GDPR
('d0000000-0000-4000-8000-000000000001'::uuid,
 '2026-03-02', 'employment', 'data_protection_privacy', 'v1.0.0',
 3, 3, 1.20, 1.03, 0.00, 0.00,
 9, 11.124, 11.124,
 3, 3, 3, 3.0,
 'GB',
 '[{"source": "ico_enforcement", "monitoring_trend": "moderate"}, {"source": "acei_tribunal_db", "category_decision_count": "moderate"}]'::jsonb),

-- Cat 12: Business Transfers & Insolvency
-- FM: contract losses, NIF claims, statutory redundancy; sector high contract churn
('d0000000-0000-4000-8000-000000000001'::uuid,
 '2026-03-02', 'employment', 'business_transfers_insolvency', 'v1.0.0',
 2, 4, 1.20, 1.03, 0.00, 0.00,
 8, 9.888, 9.888,
 2, 2, 2, 2.0,
 'GB',
 '[{"source": "acei_tribunal_db", "category_decision_count": "low_moderate"}]'::jsonb);


-- Domain-level aggregate score
-- DRT = sum of all WCS = 199.19 | DI = round(199.19/300 × 100) = 66
-- MO = 0 (no mitigation evidence submitted — baseline exposure)
-- AI = 66 (AI = DI - MO; AI ≥ 0; AI ≥ 50% of DI = 33 — floor not triggered)
INSERT INTO acei_domain_scores (
  org_id,
  week_start_date,
  domain,
  version,
  drt,
  dmr,
  di,
  mo,
  ai,
  structural_flag,
  delta_weekly,
  jurisdiction_code
) VALUES (
  'd0000000-0000-4000-8000-000000000001'::uuid,
  '2026-03-02',
  'employment',
  'v1.0.0',
  199.19,
  300,
  66,
  0,
  66,
  false,
  0,
  'GB'
)
ON CONFLICT DO NOTHING;

-- Update pcie_demonstration_entities with computed DI
UPDATE pcie_demonstration_entities
SET acei_di = 66
WHERE org_id = 'd0000000-0000-4000-8000-000000000001'::uuid;

