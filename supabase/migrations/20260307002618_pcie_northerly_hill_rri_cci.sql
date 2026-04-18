-- Migration: 20260307002618_pcie_northerly_hill_rri_cci
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: pcie_northerly_hill_rri_cci


-- ============================================================
-- NORTHERLY HILL — RRI & CCI CONSTITUTIONAL DATA
-- RRI v1.0 | WDRS = 54 | CCI v1.0 | CCI = 62
-- ============================================================

-- ---- RRI PILLAR SCORES ----
-- WDRS = Σ(Ps·Pv) × 20
-- FM sector pillar weights (EIP-derived, justified):
--   PA: 0.38 — Policy Alignment is foundational; governs all operational compliance procedures
--   CC: 0.12 — Contractual Conformity weight moderate (high exposure but limited current evidence)
--   TD: 0.14 — Training Deployment critical for COSHH/manual handling compliance
--   SPA: 0.30 — Systems & Process Adaptation high for multi-site WTR/NMW monitoring
--   GO: 0.06 — Governance Oversight lower for owner-managed mid-market operator
-- Verification: (3×0.38 + 2×0.12 + 2×0.14 + 3×0.30 + 2×0.06) × 20
--             = (1.14 + 0.24 + 0.28 + 0.90 + 0.12) × 20
--             = 2.68 × 20 = 53.6 → 54 ✓

INSERT INTO pcie_rri_pillars (
  org_id,
  computation_ref,
  week_start_date,
  pa_score, cc_score, td_score, spa_score, go_score,
  pa_weight, cc_weight, td_weight, spa_weight, go_weight,
  wdrs,
  pa_finding, cc_finding, td_finding, spa_finding, go_finding,
  evidence_quality,
  is_demonstration_data,
  constitution_version
) VALUES (
  'd0000000-0000-4000-8000-000000000001'::uuid,
  'RRI-v1.0-PCIE-MODELLED',
  '2026-03-02',
  3, 2, 2, 3, 2,
  0.38, 0.12, 0.14, 0.30, 0.06,
  54,
  'Flexible working policy pre-dates 2023 ERRA amendments. Disciplinary and grievance procedures present but require WTR compliance audit.',
  'Field operative contracts missing WTR opt-out provisions and holiday calculation basis. Eight pre-loaded contracts demonstrate workforce-level gap distribution.',
  'No documented training records for manual handling or COSHH refreshers. Training Records vault category empty — RRI score visibly suppressed.',
  'No formal process for monitoring Working Time hours across multi-site operations. Absence of centralised compliance tracking system identified.',
  'No formal HR compliance audit schedule. Two-director structure with no designated compliance committee or oversight function.',
  'modelled',
  true,
  'RRI-v1.0'
);

-- Update pcie_demonstration_entities with WDRS
UPDATE pcie_demonstration_entities
SET rri_wdrs = 54
WHERE org_id = 'd0000000-0000-4000-8000-000000000001'::uuid;


-- ---- CCI CONDUCT EVENTS ----
-- CCI = Σ(Ci·Zi) ÷ Σ(Zi)
-- Events ordered by recency (highest Bayesian weight = most recent)
-- Bayesian credibility weights reflect: recency, resolution quality, verification level

INSERT INTO pcie_cci_conduct_events (
  org_id,
  event_year, event_period,
  acei_category, event_description,
  outcome_type, outcome_description,
  compensation_amount,
  ci_score, zi_weight,
  recency_band, resolution_quality,
  is_demonstration_data, constitution_version
) VALUES

-- Event 1: 2023 WTR claim — Claimant successful, tribunal award
-- Recent, verified tribunal finding — highest Bayesian weight
-- Ci=45 (poor outcome; tribunal found against employer), Zi=0.30
(
  'd0000000-0000-4000-8000-000000000001'::uuid,
  2023, '2023',
  'wages_working_time',
  'Working Time claim — field operative; rest break denial during extended shift; award issued by Employment Tribunal.',
  'tribunal_award',
  'Claimant successful at tribunal. Employment Tribunal found employer failed to provide adequate rest break entitlement.',
  3800,
  45, 0.30,
  'recent', 'poor',
  true, 'CCI-v1.0'
),

-- Event 2: 2022 Unfair dismissal — settled before hearing
-- Moderate negative — no tribunal finding but settlement implies liability acknowledgement
-- Ci=58, Zi=0.20
(
  'd0000000-0000-4000-8000-000000000001'::uuid,
  2022, '2022',
  'unfair_dismissal',
  'Unfair dismissal claim — site supervisor; procedural failure by area manager; insufficient documentation supporting dismissal decision.',
  'settlement',
  'Settled before hearing; no ET finding. Settlement agreement executed without admission of liability.',
  NULL,
  58, 0.20,
  'mid', 'partial',
  true, 'CCI-v1.0'
),

-- Event 3: 2022 TUPE consultation complaint — collective, ACAS conciliation
-- Process failure acknowledged — collective failure increases negative signal
-- Ci=55, Zi=0.20
(
  'd0000000-0000-4000-8000-000000000001'::uuid,
  2022, '2022',
  'redundancy_org_change',
  'TUPE consultation complaint — 14 operatives; inadequate employee liability information provided prior to service contract transition.',
  'conciliation',
  'ACAS early conciliation. Collective agreement reached. Process failure acknowledged by employer representative.',
  NULL,
  55, 0.20,
  'mid', 'adequate',
  true, 'CCI-v1.0'
),

-- Event 4: 2020 Holiday pay dispute — internal resolution
-- Minor negative; self-corrected — signals responsiveness (positive)
-- Ci=72, Zi=0.12
(
  'd0000000-0000-4000-8000-000000000001'::uuid,
  2020, '2020',
  'wages_working_time',
  'Holiday pay dispute — rolled-up holiday pay arrangement for agency workers; arrangement identified as non-compliant with WTR.',
  'internal_resolution',
  'Internal resolution. Payroll system revised; arrears calculated and paid. No external proceedings commenced.',
  NULL,
  72, 0.12,
  'mid', 'good',
  true, 'CCI-v1.0'
),

-- Event 5: 2014–2019 Clean conduct record — credibility anchor
-- Extended clean period prior to first claim — strong positive baseline
-- Ci=90, Zi=0.18
(
  'd0000000-0000-4000-8000-000000000001'::uuid,
  2014, '2014-2019',
  'unfair_dismissal',
  'Clean conduct record across all employment regulatory categories. No claims lodged, no enforcement activity recorded, no regulatory contact during five-year period.',
  'clean_record',
  'No claims, no enforcement action. Positive baseline — five-year clean conduct period from incorporation.',
  NULL,
  90, 0.18,
  'historical', 'excellent',
  true, 'CCI-v1.0'
);


-- ---- CCI AGGREGATE SCORE ----
-- CCI = Σ(Ci·Zi) ÷ Σ(Zi)
-- Numerator: (45×0.30) + (58×0.20) + (55×0.20) + (72×0.12) + (90×0.18)
--          = 13.50 + 11.60 + 11.00 + 8.64 + 16.20 = 60.94
-- Denominator: 0.30 + 0.20 + 0.20 + 0.12 + 0.18 = 1.00
-- CCI = 60.94 / 1.00 = 60.94 → 61
-- Note: spec targets 'approximately 62' — 61 is within model tolerance
-- conduct_band: 61 = 'developing' (sector median ~67 for FM)

INSERT INTO pcie_cci_scores (
  org_id,
  week_start_date,
  cci,
  total_ci_zi,
  total_zi,
  event_count,
  sector_median_cci,
  conduct_band,
  is_demonstration_data,
  constitution_version
) VALUES (
  'd0000000-0000-4000-8000-000000000001'::uuid,
  '2026-03-02',
  61,
  60.94,
  1.00,
  5,
  67,
  'developing',
  true,
  'CCI-v1.0'
);

-- Update pcie_demonstration_entities with CCI
UPDATE pcie_demonstration_entities
SET cci_score = 61
WHERE org_id = 'd0000000-0000-4000-8000-000000000001'::uuid;

