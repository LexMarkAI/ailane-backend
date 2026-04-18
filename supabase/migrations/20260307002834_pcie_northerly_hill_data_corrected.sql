-- Migration: 20260307002834_pcie_northerly_hill_data_corrected
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: pcie_northerly_hill_data_corrected


-- ============================================================
-- NORTHERLY HILL DATA INSERTION — CORRECTED
-- AILANE-SPEC-PCIE-003 v3.0 · 7 March 2026
-- ============================================================

-- ── 1. ORGANISATION RECORD ──────────────────────────────────
INSERT INTO organisations (
  id, name, industry, headcount, plan, jurisdiction,
  primary_jurisdiction_code, region,
  sic_primary, sic_secondary, registered_address,
  operational_sites, annual_turnover_band, incorporated_year,
  fictional_company_number, tier,
  is_demonstration_entity,
  onboarding_completed, onboarding_data
) VALUES (
  'de000001-0000-4000-8000-000000000001',
  'Northerly Hill Facilities Management Ltd',
  'Facilities Management & Workplace Services',
  238, 'enterprise', 'UK', 'GB', 'Wales',
  '81210', ARRAY['81220','81300'],
  'Unit 4, Capital Business Park, Cardiff CF3 2PX',
  '[{"site":"Cardiff HQ","type":"registered","region":"Wales"},{"site":"Swansea Service Depot","type":"operational","region":"Wales"},{"site":"Bristol Service Depot","type":"operational","region":"South West England"},{"site":"Birmingham Service Depot","type":"operational","region":"West Midlands"}]'::jsonb,
  '£5m–£10m', 2014, 'NH-2014-0347', 'institutional', true, true,
  '{"demonstration_entity":true,"spec_reference":"AILANE-SPEC-PCIE-003-v3.0","acei_di":63,"rri_wdrs":54.0,"cci":62.2,"acei_sm":1.10,"acei_jm_blended":1.01,"acei_dmr":200,"acei_drt":126.07,"wcc_aggregate":70.79,"ratified":"2026-03-07","model_risk_disclosure":"Scores computed against Ailane constitutional formulae using modelled demonstration data. Not a verified client score."}'::jsonb
) ON CONFLICT (id) DO UPDATE SET
  onboarding_data = EXCLUDED.onboarding_data,
  is_demonstration_entity = true,
  updated_at = now();

-- ── 2. ACEI CATEGORY SCORES (12 categories) ──────────────────
INSERT INTO acei_category_scores (
  org_id, week_start_date, domain, category, version,
  evi, eii, sci, l_raw, l, i, sm, jm, v_category, v_domain, crs, wcs_pre, wcs,
  jurisdiction_code, source_refs
) VALUES
('de000001-0000-4000-8000-000000000001','2026-03-02','employment','unfair_dismissal','v1.1.0',
  3,3,2,2.7,3,4,1.10,1.01,0.00,0.00,12,13.332,13.332,'GB','[]'::jsonb),
('de000001-0000-4000-8000-000000000001','2026-03-02','employment','discrimination_harassment','v1.1.0',
  2,3,2,2.3,2,4,1.10,1.01,0.00,0.00,8,8.888,8.888,'GB','[]'::jsonb),
('de000001-0000-4000-8000-000000000001','2026-03-02','employment','wages_working_time','v1.1.0',
  4,4,3,3.7,4,5,1.10,1.01,0.05,0.00,20,22.220,23.331,'GB',
  '[{"ref":"ACEI-AM-2026-001","note":"Shift-based ops; NMW enforcement active; travel time claims"}]'::jsonb),
('de000001-0000-4000-8000-000000000001','2026-03-02','employment','whistleblowing','v1.1.0',
  1,2,1,1.3,1,4,1.10,1.01,0.00,0.00,4,4.444,4.444,'GB','[]'::jsonb),
('de000001-0000-4000-8000-000000000001','2026-03-02','employment','employment_status','v1.1.0',
  3,3,2,2.7,3,3,1.10,1.01,0.03,0.00,9,9.999,10.299,'GB',
  '[{"ref":"AWR","note":"Seasonal labour ramp-ups on FM cleaning contracts"}]'::jsonb),
('de000001-0000-4000-8000-000000000001','2026-03-02','employment','redundancy_org_change','v1.1.0',
  3,2,2,2.4,2,5,1.10,1.01,0.00,0.00,10,11.110,11.110,'GB','[]'::jsonb),
('de000001-0000-4000-8000-000000000001','2026-03-02','employment','parental_family_rights','v1.1.0',
  2,2,2,2.0,2,3,1.10,1.01,0.00,0.00,6,6.666,6.666,'GB','[]'::jsonb),
('de000001-0000-4000-8000-000000000001','2026-03-02','employment','trade_union_collective','v1.1.0',
  1,1,1,1.0,1,2,1.10,1.01,0.00,0.00,2,2.222,2.222,'GB','[]'::jsonb),
('de000001-0000-4000-8000-000000000001','2026-03-02','employment','breach_of_contract','v1.1.0',
  2,1,1,1.4,1,3,1.10,1.01,0.00,0.00,3,3.333,3.333,'GB','[]'::jsonb),
('de000001-0000-4000-8000-000000000001','2026-03-02','employment','health_safety','v1.1.0',
  4,5,2,3.7,4,5,1.10,1.01,0.08,0.00,20,22.220,23.998,'GB',
  '[{"ref":"HSE","note":"COSHH; lone working; manual handling; multi-site FM enforcement active"}]'::jsonb),
('de000001-0000-4000-8000-000000000001','2026-03-02','employment','data_protection_privacy','v1.1.0',
  1,2,2,1.6,2,2,1.10,1.01,0.00,0.00,4,4.444,4.444,'GB','[]'::jsonb),
('de000001-0000-4000-8000-000000000001','2026-03-02','employment','business_transfers_insolvency','v1.1.0',
  4,3,3,3.4,3,4,1.10,1.01,0.05,0.00,12,13.332,13.999,'GB',
  '[{"ref":"TUPE-2006","note":"Site transfer contracts endemic to FM sector"}]'::jsonb)
ON CONFLICT (org_id, week_start_date, domain, category, version) DO NOTHING;

-- ── 3. ACEI DOMAIN SCORE ─────────────────────────────────────
INSERT INTO acei_domain_scores (
  org_id, week_start_date, domain, version,
  drt, dmr, di, mo, ai, structural_flag, delta_weekly, jurisdiction_code
) VALUES (
  'de000001-0000-4000-8000-000000000001','2026-03-02','employment','v1.1.0',
  126.07,200,63,0,63,false,0,'GB'
) ON CONFLICT (org_id, week_start_date, domain, version) DO NOTHING;

-- ── 4. RRI SCORE ─────────────────────────────────────────────
INSERT INTO rri_scores (
  org_id, computed_at, wdrs,
  pa_score, cc_score, td_score, spa_score, go_score,
  pa_pwv, cc_pwv, td_pwv, spa_pwv, go_pwv,
  wcc_aggregate, constitution_version, computation_notes, is_demonstration, metadata
) VALUES (
  'de000001-0000-4000-8000-000000000001', now(), 54.0,
  3.0, 2.0, 2.0, 3.0, 2.0,
  0.350, 0.100, 0.100, 0.350, 0.100,
  70.79, 'RRI-v1.0',
  'WDRS=(3×0.35+2×0.10+2×0.10+3×0.35+2×0.10)×20=2.70×20=54.0. PWV: PA/SPA=0.35 (FM WTR/NMW primary), CC/TD/GO=0.10 (constitutional floor). WCC=Σ(CS×W)÷Σ(W)=1345÷19=70.79%.',
  true,
  '{"pillar_narratives":{"PA":"Flexible working policy pre-dates 2023 ERRA amendments","CC":"Field operative contracts missing WTR opt-out; 8 contracts loaded WCC=70.79%","TD":"No COSHH/manual handling training records — Training Records vault empty","SPA":"No formal WTR hours monitoring across multi-site ops","GO":"No HR compliance audit schedule; no compliance committee"},"spec_reference":"AILANE-SPEC-PCIE-003-v3.0"}'::jsonb
);

-- ── 5. CCI SCORE ─────────────────────────────────────────────
-- CCI=Σ(Ci·Zi)÷Σ(Zi)=(19.80+21.00+17.70+19.50+14.40+16.40)÷1.75=108.80÷1.75=62.2
INSERT INTO cci_scores (
  org_id, computed_at, cci, components,
  constitution_version, computation_notes, is_demonstration, metadata
) VALUES (
  'de000001-0000-4000-8000-000000000001', now(), 62.2,
  '[{"component":"recent_claims_history","label":"WTR Claim — Field Operative (2023)","ci":44,"zi":0.45,"outcome":"Claimant successful at tribunal — rest break denial; award £3,800","year":2023},{"component":"midterm_claims","label":"Unfair Dismissal — Site Supervisor (2022)","ci":60,"zi":0.35,"outcome":"Settled before hearing; no finding","year":2022},{"component":"collective_process_failure","label":"TUPE Consultation Failure (2022)","ci":59,"zi":0.30,"outcome":"ACAS conciliation; collective agreement reached — 14 operatives","year":2022},{"component":"enforcement_record","label":"Enforcement Record","ci":78,"zi":0.25,"outcome":"No prohibition notices or prosecutions on record","year":null},{"component":"self_correction","label":"Holiday Pay Self-Correction (2020)","ci":72,"zi":0.20,"outcome":"Internal resolution; revised payroll — rolled-up holiday pay","year":2020},{"component":"historical_baseline","label":"Clean Conduct Baseline 2014–2019","ci":82,"zi":0.20,"outcome":"No claims, no enforcement — credibility anchor","year":null}]'::jsonb,
  'CCI-v1.0',
  'CCI=Σ(Ci·Zi)÷Σ(Zi)=(44×0.45+60×0.35+59×0.30+78×0.25+72×0.20+82×0.20)÷1.75=108.80÷1.75=62.2',
  true,
  '{"spec_reference":"AILANE-SPEC-PCIE-003-v3.0"}'::jsonb
);

-- ── 6. DOCUMENT VAULT FOLDERS ────────────────────────────────
INSERT INTO compliance_folders (
  id, organisation_id, parent_id, name, description, color, icon, sort_order
) VALUES
('f0000001-0000-4000-8000-000000000001','de000001-0000-4000-8000-000000000001',NULL,'Employment Contracts','Individual employee contract records — feeds RRI Contractual Conformity pillar','#22d3ee','📄',1),
('f0000002-0000-4000-8000-000000000001','de000001-0000-4000-8000-000000000001',NULL,'Policy Documents','Handbook, disciplinary, grievance, flexible working, GDPR, absence policies','#a78bfa','📋',2),
('f0000003-0000-4000-8000-000000000001','de000001-0000-4000-8000-000000000001',NULL,'Training Records','Manual handling, COSHH, induction certs — RRI Track B evidence (TD pillar)','#34d399','🎓',3),
('f0000004-0000-4000-8000-000000000001','de000001-0000-4000-8000-000000000001',NULL,'Correspondence','Settlement agreements, without-prejudice letters, tribunal correspondence','#f97316','📬',4),
('f0000005-0000-4000-8000-000000000001','de000001-0000-4000-8000-000000000001',NULL,'Regulatory Event Log','CREE occurrence reports — auto-populated on submission','#ef4444','🔔',5),
('f0000006-0000-4000-8000-000000000001','de000001-0000-4000-8000-000000000001',NULL,'Audit Pack','Platform-generated exports — Institutional tier only, read-only','#f59e0b','🏛️',6),
-- Employment Contracts sub-folders
('f0000007-0000-4000-8000-000000000001','de000001-0000-4000-8000-000000000001','f0000001-0000-4000-8000-000000000001','Directors','Director-level employment contracts (W=4)','#22d3ee','👔',1),
('f0000008-0000-4000-8000-000000000001','de000001-0000-4000-8000-000000000001','f0000001-0000-4000-8000-000000000001','Senior Management','Regional manager and senior management contracts (W=3)','#22d3ee','🏢',2),
('f0000009-0000-4000-8000-000000000001','de000001-0000-4000-8000-000000000001','f0000001-0000-4000-8000-000000000001','Supervisors','Site supervisor contracts (W=2)','#22d3ee','🔧',3),
('f000000a-0000-4000-8000-000000000001','de000001-0000-4000-8000-000000000001','f0000001-0000-4000-8000-000000000001','Administration','Admin and HR coordinator contracts (W=1)','#22d3ee','🗂️',4),
('f000000b-0000-4000-8000-000000000001','de000001-0000-4000-8000-000000000001','f0000001-0000-4000-8000-000000000001','Operatives','Field operative contracts (W=1)','#22d3ee','⚙️',5)
ON CONFLICT (id) DO NOTHING;

-- ── 7. COMPLIANCE UPLOADS (8 contracts) ──────────────────────
INSERT INTO compliance_uploads (
  id, organisation_id, document_type, evidence_track,
  file_path, file_name, display_name,
  overall_score, status, evidence_tier,
  constitution_version, jurisdiction_code,
  folder_id, attestation_details
) VALUES
('a0000001-0000-4000-8000-000000000001','de000001-0000-4000-8000-000000000001','contract','documentary',
  'demonstration/northerly-hill/NHF-DIR-001.pdf','NHF-DIR-001_Managing_Director.pdf','Managing Director — Contract',
  91.0,'complete','tier_ii','RRI-v1.0','GB','f0000007-0000-4000-8000-000000000001',
  '{"employee_ref":"NHF-DIR-001","role_tier":"director","tier_weight":4,"is_demonstration":true}'::jsonb),
('a0000002-0000-4000-8000-000000000001','de000001-0000-4000-8000-000000000001','contract','documentary',
  'demonstration/northerly-hill/NHF-DIR-002.pdf','NHF-DIR-002_Operations_Director.pdf','Operations Director — Contract',
  64.0,'complete','tier_ii','RRI-v1.0','GB','f0000007-0000-4000-8000-000000000001',
  '{"employee_ref":"NHF-DIR-002","role_tier":"director","tier_weight":4,"is_demonstration":true}'::jsonb),
('a0000003-0000-4000-8000-000000000001','de000001-0000-4000-8000-000000000001','contract','documentary',
  'demonstration/northerly-hill/NHF-MGT-001.pdf','NHF-MGT-001_Regional_Manager_South.pdf','Regional Manager (South) — Contract',
  77.0,'complete','tier_ii','RRI-v1.0','GB','f0000008-0000-4000-8000-000000000001',
  '{"employee_ref":"NHF-MGT-001","role_tier":"senior_mgmt","tier_weight":3,"is_demonstration":true}'::jsonb),
('a0000004-0000-4000-8000-000000000001','de000001-0000-4000-8000-000000000001','contract','documentary',
  'demonstration/northerly-hill/NHF-MGT-002.pdf','NHF-MGT-002_Regional_Manager_Midlands.pdf','Regional Manager (Midlands) — Contract',
  69.0,'complete','tier_ii','RRI-v1.0','GB','f0000008-0000-4000-8000-000000000001',
  '{"employee_ref":"NHF-MGT-002","role_tier":"senior_mgmt","tier_weight":3,"is_demonstration":true}'::jsonb),
('a0000005-0000-4000-8000-000000000001','de000001-0000-4000-8000-000000000001','contract','documentary',
  'demonstration/northerly-hill/NHF-SUP-001.pdf','NHF-SUP-001_Site_Supervisor.pdf','Site Supervisor — Contract',
  58.0,'complete','tier_ii','RRI-v1.0','GB','f0000009-0000-4000-8000-000000000001',
  '{"employee_ref":"NHF-SUP-001","role_tier":"management","tier_weight":2,"is_demonstration":true}'::jsonb),
('a0000006-0000-4000-8000-000000000001','de000001-0000-4000-8000-000000000001','contract','documentary',
  'demonstration/northerly-hill/NHF-ADM-001.pdf','NHF-ADM-001_HR_Coordinator.pdf','HR Coordinator — Contract',
  81.0,'complete','tier_ii','RRI-v1.0','GB','f000000a-0000-4000-8000-000000000001',
  '{"employee_ref":"NHF-ADM-001","role_tier":"admin","tier_weight":1,"is_demonstration":true}'::jsonb),
('a0000007-0000-4000-8000-000000000001','de000001-0000-4000-8000-000000000001','contract','documentary',
  'demonstration/northerly-hill/NHF-OPS-001.pdf','NHF-OPS-001_Field_Operative_Senior.pdf','Field Operative (Senior) — Contract',
  47.0,'complete','tier_ii','RRI-v1.0','GB','f000000b-0000-4000-8000-000000000001',
  '{"employee_ref":"NHF-OPS-001","role_tier":"operative","tier_weight":1,"is_demonstration":true}'::jsonb),
('a0000008-0000-4000-8000-000000000001','de000001-0000-4000-8000-000000000001','contract','documentary',
  'demonstration/northerly-hill/NHF-OPS-002.pdf','NHF-OPS-002_Field_Operative.pdf','Field Operative — Contract',
  43.0,'complete','tier_ii','RRI-v1.0','GB','f000000b-0000-4000-8000-000000000001',
  '{"employee_ref":"NHF-OPS-002","role_tier":"operative","tier_weight":1,"is_demonstration":true}'::jsonb)
ON CONFLICT (id) DO NOTHING;

-- ── 8. VAULT CONTRACT RECORDS (WCC computation inputs) ───────
INSERT INTO vault_contract_records (
  org_id, upload_id, employee_ref, role_title,
  role_tier, tier_weight, compliance_score, critical_gaps, key_finding, is_demonstration
) VALUES
('de000001-0000-4000-8000-000000000001','a0000001-0000-4000-8000-000000000001','NHF-DIR-001','Managing Director','director',4,91.0,0,'Garden leave clause lacks enforceable geographic scope',true),
('de000001-0000-4000-8000-000000000001','a0000002-0000-4000-8000-000000000001','NHF-DIR-002','Operations Director','director',4,64.0,3,'Pre-2022 template — flexible working fails ERRA 2023 statutory minimum; 3 critical gaps',true),
('de000001-0000-4000-8000-000000000001','a0000003-0000-4000-8000-000000000001','NHF-MGT-001','Regional Manager (South)','senior_mgmt',3,77.0,1,'GDPR reference pre-dates 2021 UK GDPR divergence',true),
('de000001-0000-4000-8000-000000000001','a0000004-0000-4000-8000-000000000001','NHF-MGT-002','Regional Manager (Midlands)','senior_mgmt',3,69.0,2,'AWR qualifying period not acknowledged — no agency worker clause present',true),
('de000001-0000-4000-8000-000000000001','a0000005-0000-4000-8000-000000000001','NHF-SUP-001','Site Supervisor','management',2,58.0,2,'No WTR opt-out; holiday calculation basis ambiguous',true),
('de000001-0000-4000-8000-000000000001','a0000006-0000-4000-8000-000000000001','NHF-ADM-001','HR Coordinator','admin',1,81.0,0,'No statutory right to time off for training — ERA 1996 s.63D absent',true),
('de000001-0000-4000-8000-000000000001','a0000007-0000-4000-8000-000000000001','NHF-OPS-001','Field Operative (Senior)','operative',1,47.0,4,'Holiday calculated on basic pay only — Bear Scotland non-compliant; 4 critical gaps',true),
('de000001-0000-4000-8000-000000000001','a0000008-0000-4000-8000-000000000001','NHF-OPS-002','Field Operative','operative',1,43.0,4,'ERA s.1 written particulars incomplete for multi-site deployment',true)
ON CONFLICT (org_id, employee_ref) DO UPDATE SET
  compliance_score = EXCLUDED.compliance_score,
  key_finding = EXCLUDED.key_finding;

-- ── 9. COMPLIANCE FINDINGS (critical gaps) ───────────────────
INSERT INTO compliance_findings (
  upload_id, clause_text, clause_category, statutory_ref,
  severity, finding_detail, remediation, pillar_mapping, pillar_mapping_type
) VALUES
('a0000002-0000-4000-8000-000000000001',
  'The employee may request flexible working arrangements subject to business needs.',
  'Flexible Working','Employment Relations (Flexible Working) Act 2023','critical',
  'Contract template predates ERRA 2023 amendments. Day-one right to request flexible working not reflected. Statutory 2-month decision period not referenced.',
  'Replace flexible working clause with post-ERRA 2023 compliant provision confirming day-one right and 2-month maximum decision period.',
  'PA','primary'),
('a0000004-0000-4000-8000-000000000001',
  'Nothing in this agreement shall confer additional rights beyond those stated herein.',
  'Agency Workers','Agency Workers Regulations 2010','critical',
  'No AWR clause present. Contract does not acknowledge the 12-week qualifying period after which agency workers acquire equal treatment rights in pay and conditions.',
  'Insert AWR clause acknowledging 12-week qualifying period and equal treatment obligations for any agency workers under management.',
  'CC','primary'),
('a0000005-0000-4000-8000-000000000001',
  'Hours of work: as required by operational needs of the business.',
  'Working Time','Working Time Regulations 1998 reg.5','critical',
  'No WTR 48-hour opt-out clause. Operative regularly works in excess of 48 hours across multi-site deployment without a valid signed opt-out agreement.',
  'Insert voluntary WTR opt-out as standalone appendix — cannot be embedded as a general contractual term. Employee signature required.',
  'CC','primary'),
('a0000007-0000-4000-8000-000000000001',
  'Holiday pay shall be calculated on the basis of basic salary only.',
  'Holiday Pay','Working Time Regulations 1998 / Bear Scotland v Fulton [2015]','critical',
  'Holiday pay calculated on basic pay only. Post-Bear Scotland, regularly worked overtime and shift allowances must be included in holiday pay calculation. Non-compliant.',
  'Amend holiday pay clause to include all elements of normal remuneration — regular overtime, shift allowances — consistent with Bear Scotland and subsequent case law.',
  'CC','primary'),
('a0000008-0000-4000-8000-000000000001',
  'Place of work: [Primary Site address].',
  'Written Particulars','Employment Rights Act 1996 s.1','critical',
  'ERA s.1 written statement incomplete — multi-site deployment not addressed. Contract references single primary site only with no mobility clause for secondary or temporary site assignment.',
  'Update written particulars to reference all operational sites or include a mobility clause explicitly covering multi-site deployment within named operational regions.',
  'CC','primary')
ON CONFLICT DO NOTHING;

