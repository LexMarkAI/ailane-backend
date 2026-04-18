-- Migration: 20260409195134_formalise_provenance_tracking_v2_2
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: formalise_provenance_tracking_v2_2


-- ============================================================================
-- FORMALISATION MIGRATION: Provenance Tracking System v2.2
-- ============================================================================
-- Purpose: Retroactively formalises 5 provenance columns, 3 indexes, and 1 view
--          that were added via raw DDL (governance violation) during a Sonnet
--          session on 9 April 2026. Adds missing CHECK constraint and schema
--          documentation comments.
--
-- Columns formalised (already exist — no ALTER ADD):
--   enrichment_schema_version (text, default 'pre-v2.1')
--   extraction_complete (boolean, default false)
--   domain_completion (jsonb)
--   re_enrichment_needed (boolean, default false)
--   re_enrichment_reason (text)
--
-- Indexes formalised (already exist — no CREATE):
--   idx_te_schema_version
--   idx_te_extraction_complete
--   idx_te_re_enrichment_needed (partial, WHERE re_enrichment_needed = true)
--
-- View formalised (already exists):
--   v_re_enrichment_candidates
--
-- NEW in this migration:
--   1. CHECK constraint on enrichment_schema_version
--   2. COMMENT documentation on all 5 provenance columns
--   3. Composite index for completion register queries
-- ============================================================================

-- 1. CHECK constraint — valid schema version identifiers only
ALTER TABLE tribunal_enrichment
ADD CONSTRAINT chk_enrichment_schema_version
CHECK (enrichment_schema_version IN (
  'pre-v2.1',        -- Legacy llm_extract records (pre-provenance)
  'pdf_parse_v1',    -- Legacy PDF parse records
  'manual_v1',       -- Manual entry records (excluded from auto re-enrichment)
  'v2.1',            -- First provenance-aware schema (9 Apr 2026)
  'v2.2'             -- Provenance formalisation (9 Apr 2026)
));

-- 2. Composite index for completion register queries
CREATE INDEX IF NOT EXISTS idx_te_completion_register
ON tribunal_enrichment (enrichment_schema_version, extraction_complete, re_enrichment_needed);

-- 3. Self-documenting schema comments
COMMENT ON COLUMN tribunal_enrichment.enrichment_schema_version IS
  'Schema version identifier at time of enrichment. Determines which prompt and column set was used. CHECK-constrained to valid values. Added v2.2.';

COMMENT ON COLUMN tribunal_enrichment.extraction_complete IS
  'TRUE = all applicable domains fully checked against judgment text. FALSE = enrichment ran but completeness not verified, or predates provenance system. Added v2.2.';

COMMENT ON COLUMN tribunal_enrichment.domain_completion IS
  'JSONB object recording per-domain extraction status. Keys: A_core_outcome through J_costs, plus K_representative. Values: "complete" (checked, data is what it is), "not_applicable" (domain cannot apply to this case type). NULL = predates provenance tracking. Added v2.2.';

COMMENT ON COLUMN tribunal_enrichment.re_enrichment_needed IS
  'TRUE = record is a candidate for re-enrichment (schema version outdated or extraction incomplete). FALSE = record is current or excluded (manual). Added v2.2.';

COMMENT ON COLUMN tribunal_enrichment.re_enrichment_reason IS
  'Human-readable reason for re-enrichment flag. Examples: "pre-v2.1 schema — representative columns missing", "domain_completion NULL — predates provenance". NULL when re_enrichment_needed is false. Added v2.2.';

-- 4. Replace view with improved version including completion register fields
CREATE OR REPLACE VIEW v_re_enrichment_candidates AS
SELECT
  te.id AS enrichment_id,
  te.decision_id,
  td.case_number,
  td.claimant_name,
  td.respondent_name,
  td.decision_date,
  EXTRACT(year FROM td.decision_date)::integer AS decision_year,
  char_length(td.pdf_extracted_text) AS text_len,
  te.enrichment_schema_version,
  te.extraction_method,
  te.extraction_confidence,
  te.re_enrichment_reason,
  te.acei_primary_category,
  te.claimant_rep_name IS NULL AS rep_name_missing,
  te.domain_completion IS NULL AS predates_provenance_tracking,
  te.extraction_complete
FROM tribunal_enrichment te
JOIN tribunal_decisions td ON td.id = te.decision_id
WHERE te.re_enrichment_needed = true
  AND td.pdf_extracted_text IS NOT NULL
  AND char_length(td.pdf_extracted_text) > 2000
ORDER BY char_length(td.pdf_extracted_text) DESC, td.decision_date DESC;

-- 5. Completion register view — institutional overview of estate health
CREATE OR REPLACE VIEW v_enrichment_completion_register AS
SELECT
  te.enrichment_schema_version,
  te.extraction_complete,
  te.re_enrichment_needed,
  COUNT(*) AS record_count,
  COUNT(*) FILTER (WHERE te.domain_completion IS NOT NULL) AS has_provenance,
  COUNT(*) FILTER (WHERE te.domain_completion IS NULL) AS missing_provenance,
  COUNT(*) FILTER (WHERE te.acei_primary_category IS NOT NULL) AS has_acei_category,
  COUNT(*) FILTER (WHERE te.claimant_rep_name IS NOT NULL) AS has_claimant_rep,
  COUNT(*) FILTER (WHERE te.respondent_rep_name IS NOT NULL) AS has_respondent_rep,
  ROUND(AVG(te.extraction_confidence)::numeric, 3) AS avg_confidence
FROM tribunal_enrichment te
GROUP BY te.enrichment_schema_version, te.extraction_complete, te.re_enrichment_needed
ORDER BY te.enrichment_schema_version, te.extraction_complete, te.re_enrichment_needed;

-- 6. Per-record completion detail view — answers "is this record fully done?"
CREATE OR REPLACE VIEW v_enrichment_record_status AS
SELECT
  te.id AS enrichment_id,
  te.decision_id,
  td.case_number,
  te.enrichment_schema_version,
  te.extraction_complete,
  te.re_enrichment_needed,
  te.extraction_method,
  te.extraction_confidence,
  te.domain_completion,
  te.re_enrichment_reason,
  -- Domain-level completeness indicators
  (te.domain_completion->>'A_core_outcome') AS domain_a_status,
  (te.domain_completion->>'B_claims') AS domain_b_status,
  (te.domain_completion->>'C_statutory') AS domain_c_status,
  (te.domain_completion->>'D_procedural') AS domain_d_status,
  (te.domain_completion->>'E_financial') AS domain_e_status,
  (te.domain_completion->>'F_precedent') AS domain_f_status,
  (te.domain_completion->>'G_time_limits') AS domain_g_status,
  (te.domain_completion->>'H_discrimination') AS domain_h_status,
  (te.domain_completion->>'I_whistleblowing') AS domain_i_status,
  (te.domain_completion->>'J_costs') AS domain_j_status,
  (te.domain_completion->>'K_representative') AS domain_k_status,
  -- Quick flag: all applicable domains accounted for?
  CASE
    WHEN te.domain_completion IS NULL THEN 'no_provenance'
    WHEN te.extraction_complete = true THEN 'complete'
    ELSE 'partial'
  END AS completion_status
FROM tribunal_enrichment te
JOIN tribunal_decisions td ON td.id = te.decision_id;

