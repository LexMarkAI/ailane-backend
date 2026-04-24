-- ============================================================================
-- AILANE-SPEC-DMSP-002-W7 §5.5 additive implementation
-- AMD-089 Stage A · CC Build Brief 1 EXEC-01 · §2
-- Migration: w7_create_completeness_views_v2
-- Purpose : (a) Add w7_sweep_provenance jsonb column to tribunal_enrichment
--           for W7 Haiku sweep provenance storage.
--           (b) Create _v2 siblings of v_enrichment_completeness and
--           v_enrichment_completion_register, partitioned by enrichment_scope
--           and carrying W7 coverage columns.
-- Brief    : AILANE-CC-BRIEF-001-EXEC-01 (Director-ratified 24 Apr 2026)
-- Schema   : llm_raw_response is text (hybrid narrative + JSON content across
--           34,205 rows; 85% non-JSON narrative). Per Director Option A
--           ratification, a dedicated w7_sweep_provenance jsonb column is
--           introduced instead of converting llm_raw_response. Existing
--           llm_raw_response content is preserved unmodified.
-- Scope    : Director Decision 5 preserved: original v_enrichment_completeness
--           and v_enrichment_completion_register remain UNMODIFIED; _v2 siblings
--           are net-new.
-- ============================================================================

-- §2-PRE: Provenance column (new — replaces spec §12.4 storage assumption)
ALTER TABLE public.tribunal_enrichment
    ADD COLUMN IF NOT EXISTS w7_sweep_provenance jsonb NULL;

COMMENT ON COLUMN public.tribunal_enrichment.w7_sweep_provenance IS
    'W7 Haiku sweep provenance block (AMD-089 Stage A EXEC-01). Jsonb store for swept_at, agent_version, model_id, prompt_version, rro_value, rro_confidence, rro_signals[], soa_value, soa_confidence, soa_signals[], pdf_text_length. Constraint chk_w7_sweep_true_has_signals guards non-empty signals arrays when flag value is TRUE. Introduced because llm_raw_response is text-typed with hybrid content (85% non-JSON narrative) and cannot host jsonb operators per W7 §12.4 spec assumption.';

-- §2-A: Completeness view, scope-partitioned
CREATE OR REPLACE VIEW public.v_enrichment_completeness_v2 AS
SELECT
    enrichment_scope,
    enrichment_schema_version,
    extraction_method,
    count(*) AS total_records,
    count(*) FILTER (WHERE extraction_complete = true) AS fully_complete,
    count(*) FILTER (WHERE re_enrichment_needed = true) AS needs_re_enrichment,
    count(*) FILTER (WHERE domain_completion IS NOT NULL) AS has_provenance,
    round(avg(extraction_confidence), 2) AS avg_confidence,
    count(*) FILTER (WHERE claimant_rep_name IS NOT NULL) AS has_claimant_rep_name,
    count(*) FILTER (WHERE acei_primary_category IS NOT NULL) AS has_acei_category,
    -- W7-specific coverage columns (EXEC-01 substitution)
    count(*) FILTER (WHERE restricted_reporting_order IS NOT NULL) AS has_rro_value,
    count(*) FILTER (WHERE soa_1992_identified IS NOT NULL) AS has_soa_value,
    count(*) FILTER (WHERE w7_sweep_provenance IS NOT NULL) AS has_w7_sweep_provenance
FROM public.tribunal_enrichment
GROUP BY enrichment_scope, enrichment_schema_version, extraction_method
ORDER BY enrichment_scope, count(*) DESC;

COMMENT ON VIEW public.v_enrichment_completeness_v2 IS
    'Additive W7-aware sibling of v_enrichment_completeness. Partitioned by enrichment_scope so full-enrichment progress reporting (scope=full) does not include W7-only rows and W7 coverage reporting (scope=w7_only) does not exclude them. Added by AMD-089 Stage A per DMSP-002-W7 §5.5. Original v_enrichment_completeness is preserved unmodified. Provenance coverage now reads from dedicated w7_sweep_provenance jsonb column per EXEC-01.';

-- §2-B: Completion register view, scope-partitioned
CREATE OR REPLACE VIEW public.v_enrichment_completion_register_v2 AS
SELECT
    enrichment_scope,
    enrichment_schema_version,
    extraction_complete,
    re_enrichment_needed,
    count(*) AS record_count,
    count(*) FILTER (WHERE domain_completion IS NOT NULL) AS has_provenance,
    count(*) FILTER (WHERE domain_completion IS NULL) AS missing_provenance,
    count(*) FILTER (WHERE acei_primary_category IS NOT NULL) AS has_acei_category,
    count(*) FILTER (WHERE claimant_rep_name IS NOT NULL) AS has_claimant_rep,
    count(*) FILTER (WHERE respondent_rep_name IS NOT NULL) AS has_respondent_rep,
    round(avg(extraction_confidence), 3) AS avg_confidence,
    -- W7-specific coverage columns (EXEC-01 substitution)
    count(*) FILTER (WHERE restricted_reporting_order IS NOT NULL) AS has_rro_value,
    count(*) FILTER (WHERE soa_1992_identified IS NOT NULL) AS has_soa_value,
    count(*) FILTER (WHERE w7_sweep_provenance IS NOT NULL) AS has_w7_sweep_provenance
FROM public.tribunal_enrichment te
GROUP BY enrichment_scope, enrichment_schema_version, extraction_complete, re_enrichment_needed
ORDER BY enrichment_scope, enrichment_schema_version, extraction_complete, re_enrichment_needed;

COMMENT ON VIEW public.v_enrichment_completion_register_v2 IS
    'Additive W7-aware sibling of v_enrichment_completion_register. Partitioned by enrichment_scope per DMSP-002-W7 §5.5. Added by AMD-089 Stage A. Original v_enrichment_completion_register is preserved unmodified. Provenance coverage now reads from dedicated w7_sweep_provenance jsonb column per EXEC-01.';
