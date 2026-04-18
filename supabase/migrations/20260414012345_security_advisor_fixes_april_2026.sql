-- Migration: 20260414012345_security_advisor_fixes_april_2026
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: security_advisor_fixes_april_2026


-- ============================================================
-- SECURITY ADVISOR REMEDIATION — 14 April 2026
-- Fixes: RLS disabled, SECURITY DEFINER views, missing policies
-- ============================================================

-- ============================================================
-- FIX 1: kl_versions — CRITICAL — RLS disabled in public
-- This table stores KL provision version history.
-- Only Edge Functions (service_role) should access it.
-- ============================================================
ALTER TABLE public.kl_versions ENABLE ROW LEVEL SECURITY;

-- Service role bypasses RLS automatically.
-- Add a read-only policy for authenticated users (KL read access)
CREATE POLICY "kl_versions_authenticated_read"
  ON public.kl_versions
  FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================
-- FIX 2: eileen_presales_compliance_log — RLS on, no policies
-- Presales logging table — service-role writes, no client reads needed
-- ============================================================
CREATE POLICY "eileen_presales_compliance_log_service_only"
  ON public.eileen_presales_compliance_log
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================
-- FIX 3: eileen_presales_conversations — RLS on, no policies
-- Presales conversation storage — service-role writes only
-- ============================================================
CREATE POLICY "eileen_presales_conversations_service_only"
  ON public.eileen_presales_conversations
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================
-- FIX 4: rate_limits — RLS on, no policies
-- Rate limiting table — service-role managed
-- ============================================================
CREATE POLICY "rate_limits_service_only"
  ON public.rate_limits
  FOR ALL
  TO service_role
  USING (true)
  WITH CHECK (true);

-- ============================================================
-- FIX 5: SECURITY DEFINER views → SECURITY INVOKER
-- These enrichment views should use the caller's permissions
-- ============================================================

-- v_enrichment_completeness
CREATE OR REPLACE VIEW public.v_enrichment_completeness
WITH (security_invoker = true) AS
SELECT enrichment_schema_version,
    extraction_method,
    count(*) AS total_records,
    count(*) FILTER (WHERE extraction_complete = true) AS fully_complete,
    count(*) FILTER (WHERE re_enrichment_needed = true) AS needs_re_enrichment,
    count(*) FILTER (WHERE domain_completion IS NOT NULL) AS has_provenance,
    round(avg(extraction_confidence), 2) AS avg_confidence,
    count(*) FILTER (WHERE claimant_rep_name IS NOT NULL) AS has_claimant_rep_name,
    count(*) FILTER (WHERE acei_primary_category IS NOT NULL) AS has_acei_category
FROM tribunal_enrichment
GROUP BY enrichment_schema_version, extraction_method
ORDER BY count(*) DESC;

-- v_enrichment_completion_register
CREATE OR REPLACE VIEW public.v_enrichment_completion_register
WITH (security_invoker = true) AS
SELECT enrichment_schema_version,
    extraction_complete,
    re_enrichment_needed,
    count(*) AS record_count,
    count(*) FILTER (WHERE domain_completion IS NOT NULL) AS has_provenance,
    count(*) FILTER (WHERE domain_completion IS NULL) AS missing_provenance,
    count(*) FILTER (WHERE acei_primary_category IS NOT NULL) AS has_acei_category,
    count(*) FILTER (WHERE claimant_rep_name IS NOT NULL) AS has_claimant_rep,
    count(*) FILTER (WHERE respondent_rep_name IS NOT NULL) AS has_respondent_rep,
    round(avg(extraction_confidence), 3) AS avg_confidence
FROM tribunal_enrichment te
GROUP BY enrichment_schema_version, extraction_complete, re_enrichment_needed
ORDER BY enrichment_schema_version, extraction_complete, re_enrichment_needed;

-- v_enrichment_record_status
CREATE OR REPLACE VIEW public.v_enrichment_record_status
WITH (security_invoker = true) AS
SELECT te.id AS enrichment_id,
    te.decision_id,
    td.case_number,
    te.enrichment_schema_version,
    te.extraction_complete,
    te.re_enrichment_needed,
    te.extraction_method,
    te.extraction_confidence,
    te.domain_completion,
    te.re_enrichment_reason,
    te.domain_completion ->> 'A_core_outcome' AS domain_a_status,
    te.domain_completion ->> 'B_claims' AS domain_b_status,
    te.domain_completion ->> 'C_statutory' AS domain_c_status,
    te.domain_completion ->> 'D_procedural' AS domain_d_status,
    te.domain_completion ->> 'E_financial' AS domain_e_status,
    te.domain_completion ->> 'F_precedent' AS domain_f_status,
    te.domain_completion ->> 'G_time_limits' AS domain_g_status,
    te.domain_completion ->> 'H_discrimination' AS domain_h_status,
    te.domain_completion ->> 'I_whistleblowing' AS domain_i_status,
    te.domain_completion ->> 'J_costs' AS domain_j_status,
    te.domain_completion ->> 'K_representative' AS domain_k_status,
    CASE
        WHEN te.domain_completion IS NULL THEN 'no_provenance'
        WHEN te.extraction_complete = true THEN 'complete'
        ELSE 'partial'
    END AS completion_status
FROM tribunal_enrichment te
JOIN tribunal_decisions td ON td.id = te.decision_id;

-- v_re_enrichment_candidates
CREATE OR REPLACE VIEW public.v_re_enrichment_candidates
WITH (security_invoker = true) AS
SELECT te.id AS enrichment_id,
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

