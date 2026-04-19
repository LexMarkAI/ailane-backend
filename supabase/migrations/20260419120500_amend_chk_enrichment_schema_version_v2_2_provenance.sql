-- Migration: 20260419120500_amend_chk_enrichment_schema_version_v2_2_provenance
-- Name: amend_chk_enrichment_schema_version_v2_2_provenance
--
-- Stream 2: permit enrichment_schema_version = 'v2.2_provenance'
-- Governance: AMD-072, EILEEN-009 Cornerstone, 2026-04-18 enrichment_halt_flag
-- Pre-req: v1.0 migration 20260419120000 must be applied. This migration is
-- idempotent on CHECK replacement only.
--
-- Director-relayed pre-amendment IN-list (pg_get_constraintdef from live prod
-- project cnbsxwtvazfvzmltkuvx, 2026-04-19): 'pre-v2.1', 'pdf_parse_v1',
-- 'manual_v1', 'v2.1', 'v2.2'. Zero prod-vs-repo drift. Every existing value
-- is preserved verbatim; 'v2.2_provenance' is appended.
-- ============================================================================

BEGIN;

ALTER TABLE public.tribunal_enrichment
  DROP CONSTRAINT chk_enrichment_schema_version;

ALTER TABLE public.tribunal_enrichment
  ADD CONSTRAINT chk_enrichment_schema_version
  CHECK (enrichment_schema_version IN (
    'pre-v2.1',         -- Legacy llm_extract records (pre-provenance)
    'pdf_parse_v1',     -- Legacy PDF parse records
    'manual_v1',        -- Manual entry records (excluded from auto re-enrichment)
    'v2.1',             -- First provenance-aware schema (9 Apr 2026) — declared-but-unused, preserved
    'v2.2',             -- Provenance formalisation (9 Apr 2026)
    'v2.2_provenance'   -- Stream 1 backfill target (AMD-072 / EILEEN-009 / Stream 2 unblock 2026-04-19)
  ));

COMMIT;

-- ============================================================================
-- End of migration 20260419120500_amend_chk_enrichment_schema_version_v2_2_provenance
-- ============================================================================
