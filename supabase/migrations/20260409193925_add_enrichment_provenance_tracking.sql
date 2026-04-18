-- Migration: 20260409193925_add_enrichment_provenance_tracking
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_enrichment_provenance_tracking


-- ============================================================
-- Enrichment Provenance & Completeness Tracking
-- Authority: AILANE-SPEC-JIPA-001 (AMD-039), AILANE-SPEC-CMA-001 (AMD-040)
-- Purpose: Distinguish NULL = absent-from-judgment vs NULL = never-checked.
--          Prevent repeat enrichment on genuinely complete records.
--          Track schema version to identify re-enrichment candidates.
-- ============================================================

-- 1. Schema version — which extraction prompt produced this record
ALTER TABLE tribunal_enrichment
  ADD COLUMN IF NOT EXISTS enrichment_schema_version text DEFAULT 'pre-v2.1';

-- 2. Extraction complete flag — true = record fully processed under current schema,
--    all applicable domains checked, no repeat enrichment needed
ALTER TABLE tribunal_enrichment
  ADD COLUMN IF NOT EXISTS extraction_complete boolean DEFAULT false;

-- 3. Domain completion JSONB — per-domain applicability and check status.
--    Populated by the extraction agent alongside field values.
--    Keys: A through K (matching skill domains)
--    Values: 'complete' | 'not_applicable' | 'partial' | 'unchecked'
--    NULL on this column = record predates provenance tracking = treat as unchecked
ALTER TABLE tribunal_enrichment
  ADD COLUMN IF NOT EXISTS domain_completion jsonb;

-- 4. Re-enrichment flag — set to true when a field gap is detected post-insert,
--    or when schema version advances and this record needs an update pass.
ALTER TABLE tribunal_enrichment
  ADD COLUMN IF NOT EXISTS re_enrichment_needed boolean DEFAULT false;

-- 5. Re-enrichment reason — human/machine readable explanation
ALTER TABLE tribunal_enrichment
  ADD COLUMN IF NOT EXISTS re_enrichment_reason text;

-- ============================================================
-- Backfill existing records with correct schema version labels
-- ============================================================

-- llm_extract records: enriched by LLM but before v2.1 full schema
UPDATE tribunal_enrichment
  SET enrichment_schema_version = 'pre-v2.1',
      extraction_complete = false,
      re_enrichment_needed = true,
      re_enrichment_reason = 'Enriched before schema v2.1 — representative identity columns absent, 19 fields not in prompt'
  WHERE extraction_method = 'llm_extract'
    AND enrichment_schema_version = 'pre-v2.1';

-- pdf_parse records: basic parse, minimal LLM extraction
UPDATE tribunal_enrichment
  SET enrichment_schema_version = 'pdf_parse_v1',
      extraction_complete = false,
      re_enrichment_needed = true,
      re_enrichment_reason = 'PDF parse only — no LLM field extraction, full re-enrichment required'
  WHERE extraction_method = 'pdf_parse'
    AND enrichment_schema_version = 'pre-v2.1';

-- manual records: human-entered, assumed complete for fields present
UPDATE tribunal_enrichment
  SET enrichment_schema_version = 'manual_v1',
      extraction_complete = false,
      re_enrichment_needed = false,
      re_enrichment_reason = 'Manual entry — field completeness varies, no automated re-enrichment'
  WHERE extraction_method = 'manual'
    AND enrichment_schema_version = 'pre-v2.1';

-- ============================================================
-- Index: fast querying of re-enrichment candidates
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_te_schema_version
  ON tribunal_enrichment (enrichment_schema_version);

CREATE INDEX IF NOT EXISTS idx_te_extraction_complete
  ON tribunal_enrichment (extraction_complete);

CREATE INDEX IF NOT EXISTS idx_te_re_enrichment_needed
  ON tribunal_enrichment (re_enrichment_needed)
  WHERE re_enrichment_needed = true;

-- ============================================================
-- View: re-enrichment candidates — ordered by priority
-- (20k+ chars first, then 10k-19k, by year desc)
-- ============================================================
CREATE OR REPLACE VIEW v_re_enrichment_candidates AS
SELECT
  te.id AS enrichment_id,
  te.decision_id,
  td.case_number,
  td.claimant_name,
  td.respondent_name,
  td.decision_date,
  EXTRACT(YEAR FROM td.decision_date)::int AS decision_year,
  char_length(td.pdf_extracted_text) AS text_len,
  te.enrichment_schema_version,
  te.extraction_method,
  te.extraction_confidence,
  te.re_enrichment_reason,
  te.acei_primary_category,
  te.claimant_rep_name IS NULL AS rep_name_missing,
  te.domain_completion IS NULL AS predates_provenance_tracking
FROM tribunal_enrichment te
JOIN tribunal_decisions td ON td.id = te.decision_id
WHERE te.re_enrichment_needed = true
  AND td.pdf_extracted_text IS NOT NULL
  AND char_length(td.pdf_extracted_text) > 2000
ORDER BY
  char_length(td.pdf_extracted_text) DESC,
  td.decision_date DESC;

-- ============================================================
-- View: completeness dashboard
-- ============================================================
CREATE OR REPLACE VIEW v_enrichment_completeness AS
SELECT
  enrichment_schema_version,
  extraction_method,
  COUNT(*) AS total_records,
  COUNT(*) FILTER (WHERE extraction_complete = true) AS fully_complete,
  COUNT(*) FILTER (WHERE re_enrichment_needed = true) AS needs_re_enrichment,
  COUNT(*) FILTER (WHERE domain_completion IS NOT NULL) AS has_provenance,
  ROUND(AVG(extraction_confidence)::numeric, 2) AS avg_confidence,
  COUNT(*) FILTER (WHERE claimant_rep_name IS NOT NULL) AS has_claimant_rep_name,
  COUNT(*) FILTER (WHERE acei_primary_category IS NOT NULL) AS has_acei_category
FROM tribunal_enrichment
GROUP BY enrichment_schema_version, extraction_method
ORDER BY total_records DESC;

