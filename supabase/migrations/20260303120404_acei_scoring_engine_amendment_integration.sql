-- Migration: 20260303120404_acei_scoring_engine_amendment_integration
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: acei_scoring_engine_amendment_integration


-- ============================================================================
-- ACEI Scoring Engine: Amendment Integration
-- Updates employer-level scoring to use revised SM, JM, and new RFVM
-- Constitutional authority: ACEI-AM-2026-001 and ACEI-AM-2026-002
-- ============================================================================

-- View: Employer Exposure Parameters (combines all three multipliers)
CREATE OR REPLACE VIEW employer_exposure_parameters AS
SELECT 
  em.id,
  em.normalised_name,
  em.jurisdiction_region,
  em.sub_region,
  
  -- Sector Multiplier (AM-2026-001)
  em.acei_sector_code,
  sm.sector_name,
  sm.sector_group_name,
  COALESCE(em.acei_sector_multiplier, 1.00) AS sector_multiplier,
  em.acei_sector_override IS NOT NULL AS is_override_classified,
  
  -- Jurisdiction Multiplier (AM-2026-002)
  COALESCE(em.jurisdiction_multiplier, 1.00) AS jurisdiction_multiplier,
  
  -- Regional Financial Vulnerability Modifier (AM-2026-002 Section B4)
  COALESCE(em.rfvm_value, 1.00) AS rfvm_value,
  em.rfvm_band,
  
  -- Combined Likelihood Modifier: SM × JM
  ROUND(COALESCE(em.acei_sector_multiplier, 1.00) * COALESCE(em.jurisdiction_multiplier, 1.00), 4) AS combined_likelihood_modifier,
  
  -- Classification completeness
  CASE 
    WHEN em.acei_sector_code IS NOT NULL AND em.jurisdiction_multiplier IS NOT NULL AND em.rfvm_value IS NOT NULL THEN 'FULL'
    WHEN em.jurisdiction_multiplier IS NOT NULL THEN 'PARTIAL_JM_ONLY'
    WHEN em.acei_sector_code IS NOT NULL THEN 'PARTIAL_SM_ONLY'
    ELSE 'UNCLASSIFIED'
  END AS classification_status
  
FROM employer_master em
LEFT JOIN acei_sector_sic_map sm ON em.acei_sector_code = sm.sector_code;

-- View: Sector exposure summary for dashboard/insurance feed
CREATE OR REPLACE VIEW sector_exposure_summary AS
SELECT 
  sm.sector_code,
  sm.sector_name,
  sm.sector_group,
  sm.sector_group_name,
  sm.sector_multiplier,
  COUNT(em.id) AS employer_count,
  COUNT(td.id) AS tribunal_cases,
  ROUND(1.0 * COUNT(td.id) / NULLIF(COUNT(DISTINCT em.id), 0), 3) AS cases_per_employer,
  ROUND(AVG(COALESCE(em.jurisdiction_multiplier, 1.00)), 3) AS avg_jm,
  ROUND(AVG(COALESCE(em.rfvm_value, 1.00)), 3) AS avg_rfvm
FROM acei_sector_sic_map sm
LEFT JOIN employer_master em ON em.acei_sector_code = sm.sector_code
LEFT JOIN tribunal_decisions td ON LOWER(td.respondent_name) = LOWER(em.normalised_name)
GROUP BY sm.sector_code, sm.sector_name, sm.sector_group, sm.sector_group_name, sm.sector_multiplier
ORDER BY sm.sector_group, sm.sector_code;

-- View: Regional exposure summary with RFVM
CREATE OR REPLACE VIEW regional_exposure_summary AS
SELECT 
  jm.jurisdiction_region,
  jm.jurisdiction_multiplier,
  jm.rfvm_band,
  jm.rfvm_value,
  jm.employer_failure_rate,
  jm.population_millions,
  COUNT(em.id) AS employer_count,
  COUNT(CASE WHEN em.acei_sector_code IS NOT NULL THEN 1 END) AS sector_classified,
  COUNT(CASE WHEN em.sub_region IS NOT NULL THEN 1 END) AS sub_region_assigned,
  ROUND(1.0 * COUNT(em.id) / NULLIF(jm.population_millions, 0), 0) AS employers_per_million
FROM acei_jurisdiction_map jm
LEFT JOIN employer_master em ON em.jurisdiction_region = jm.jurisdiction_region
GROUP BY jm.jurisdiction_region, jm.jurisdiction_multiplier, jm.rfvm_band, jm.rfvm_value, jm.employer_failure_rate, jm.population_millions
ORDER BY jm.jurisdiction_multiplier DESC;

-- Constitutional amendment register
CREATE TABLE IF NOT EXISTS acei_amendment_register (
    id SERIAL PRIMARY KEY,
    amendment_ref TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    amendment_type TEXT NOT NULL CHECK (amendment_type IN ('Minor','Major','Emergency')),
    article_authority TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('Proposed','Adopted','Implemented','Superseded','Withdrawn')),
    date_proposed DATE NOT NULL,
    date_adopted DATE,
    date_implemented DATE,
    affects_sections TEXT[],
    summary TEXT,
    impact_assessment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO acei_amendment_register (amendment_ref, title, amendment_type, article_authority, status, date_proposed, date_adopted, date_implemented, affects_sections, summary, impact_assessment) VALUES
('ACEI-AM-2026-001', 'Revised Sector Multiplier Taxonomy', 'Minor', 'Article XII', 'Implemented', '2026-03-03', '2026-03-03', '2026-03-03',
 ARRAY['Annex B Section B1'],
 '12 founding sector classifications expanded to 32 across 10 groups (A-J). SM range 0.80-1.30 unchanged. Override Classification Protocol for platform/gig economy. AI-assisted classification forward provision.',
 '20,111 employers reclassified. 45 platform/gig economy entities manually overridden to B1 (SM 1.30). Scoring engine updated to use granular sector multipliers.'),

('ACEI-AM-2026-002', 'Revised Jurisdiction Multiplier & Sub-Regional Intelligence Framework', 'Minor', 'Article XII', 'Implemented', '2026-03-03', '2026-03-03', '2026-03-03',
 ARRAY['Annex B Section B2','Annex B Section B3 (New)','Annex B Section B4 (New)'],
 '6 of 12 JM values recalibrated. Two-tier jurisdiction architecture: Tier 1 constitutional scoring, Tier 2 sub-regional intelligence. RFVM (0.95-1.10) introduced modifying Impact derivation.',
 '24,725 employers assigned revised JM/RFVM. 6,858 employers assigned sub-regions. 3 new database tables deployed. Regional exposure summary views created.');

ALTER TABLE acei_amendment_register ENABLE ROW LEVEL SECURITY;
CREATE POLICY anon_read_amendments ON acei_amendment_register FOR SELECT TO anon USING (true);
CREATE POLICY service_all_amendments ON acei_amendment_register FOR ALL TO service_role USING (true) WITH CHECK (true);

