-- Migration: 20260307040915_rpc_get_decisions_needing_pdf_urls
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: rpc_get_decisions_needing_pdf_urls


CREATE OR REPLACE FUNCTION get_decisions_needing_pdf_urls(
    p_limit  INT DEFAULT 100,
    p_offset INT DEFAULT 0
)
RETURNS TABLE (
    id            UUID,
    source_url    TEXT,
    title         TEXT,
    decision_date DATE
)
LANGUAGE sql
STABLE
SET statement_timeout = '120s'
AS $$
    SELECT id, source_url, title, decision_date
    FROM tribunal_decisions
    WHERE pdf_urls IS NULL
      AND source_url IS NOT NULL
      AND processing_status NOT IN ('enriched','reclassified','enriched_no_jcode')
    ORDER BY decision_date DESC
    LIMIT p_limit
    OFFSET p_offset;
$$;

GRANT EXECUTE ON FUNCTION get_decisions_needing_pdf_urls TO service_role, authenticated, anon;

