-- ============================================================================
-- AILANE-SPEC-DMSP-002-W7 §13.3 cohort selection
-- AMD-089 Stage A · CC Build Brief 1 · v1.1 · §2.8.3
-- Migration: w7_create_channel_selector_functions
-- Purpose : Two RPC functions that the w7-hmcts-resync EF calls to select
--           its next working batch. Keeping selection in SECURITY DEFINER
--           SQL (a) avoids ugly COALESCE predicates in the EF code,
--           (b) cleanly separates service-role read access from RLS concerns,
--           (c) lets DBAs tune selection without EF redeploy,
--           (d) centralises the resync_processed_date < CURRENT_DATE filter
--               that keeps the batched self-chaining pattern (COP P1-3/P1-4)
--               stable against sort-order drift between batches.
-- Brief    : AILANE-CC-BRIEF-001 v1.1 (ratified CEO-RAT-AMD-089, 24 Apr 2026)
-- Pagination note (v1.1): Selectors take p_limit only, NOT p_offset. The
--           resync_processed_date filter naturally advances the working set
--           between self-chained batches — rows processed in earlier batches
--           are marked resync_processed_date = CURRENT_DATE by the EF and
--           fall out of subsequent selections automatically. No OFFSET
--           parameter is required, and no sort-order drift concern arises.
-- Depends  : §2.2 (last_resync_at + resync_processed_date columns) and §2.8.1
--           (resync_change_detected_at column) must be applied first.
-- Security : SECURITY DEFINER with pinned search_path per ailane-cc-brief
--           RULE 5. EXECUTE revoked from PUBLIC, granted to service_role only.
-- ============================================================================

-- Channel A: cold archive (excludes last-60-days window), oldest-resync-first,
-- top ~5% of total cold archive per night capped via chain-depth (see EF).
-- Rows processed today (resync_processed_date = CURRENT_DATE) are excluded,
-- so self-chained batches naturally advance through the unprocessed set.
CREATE OR REPLACE FUNCTION public.w7_select_channel_a_cohort(p_limit integer)
RETURNS TABLE(id uuid, source_url text, content_hash text, last_resync_at timestamptz)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT td.id, td.source_url, td.content_hash, td.last_resync_at
  FROM public.tribunal_decisions td
  WHERE td.source_url IS NOT NULL
    AND COALESCE(td.decision_date, td.scraped_at::date) < (CURRENT_DATE - INTERVAL '60 days')
    AND (td.resync_processed_date IS NULL OR td.resync_processed_date < CURRENT_DATE)
  ORDER BY td.last_resync_at NULLS FIRST, td.id
  LIMIT p_limit;
$$;

-- Channel B: last-60-days window, oldest-resync-first, full cohort per night.
-- Same daily-processed filter as Channel A; expected cohort size (~4,500 rows
-- assuming ~75 decisions/day × 60 days) is well below the MAX_CHAIN_DEPTH ceiling.
CREATE OR REPLACE FUNCTION public.w7_select_channel_b_cohort(p_limit integer)
RETURNS TABLE(id uuid, source_url text, content_hash text, last_resync_at timestamptz)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT td.id, td.source_url, td.content_hash, td.last_resync_at
  FROM public.tribunal_decisions td
  WHERE td.source_url IS NOT NULL
    AND COALESCE(td.decision_date, td.scraped_at::date) >= (CURRENT_DATE - INTERVAL '60 days')
    AND (td.resync_processed_date IS NULL OR td.resync_processed_date < CURRENT_DATE)
  ORDER BY td.last_resync_at NULLS FIRST, td.id
  LIMIT p_limit;
$$;

REVOKE ALL ON FUNCTION public.w7_select_channel_a_cohort(integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.w7_select_channel_b_cohort(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.w7_select_channel_a_cohort(integer) TO service_role;
GRANT EXECUTE ON FUNCTION public.w7_select_channel_b_cohort(integer) TO service_role;
