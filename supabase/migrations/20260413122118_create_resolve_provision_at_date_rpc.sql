-- Migration: 20260413122118_create_resolve_provision_at_date_rpc
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_resolve_provision_at_date_rpc


-- TIL Resolver RPC Function
-- Per KLIA-001 §5.3 — Temporal Intelligence Layer
-- Resolves the operative version of any provision at a specified date
-- Uses kl_versions table (57 records, deployed 13 April 2026)
-- Falls back to kl_provisions.current_text if no version record exists

CREATE OR REPLACE FUNCTION resolve_provision_at_date(
  p_instrument_id TEXT,
  p_section_num TEXT,
  p_target_date DATE
)
RETURNS TABLE (
  version_id UUID,
  instrument_id TEXT,
  section_num TEXT,
  effective_from DATE,
  effective_to DATE,
  text TEXT,
  amended_by TEXT,
  source_url TEXT,
  policy_rationale TEXT,
  is_current BOOLEAN,
  resolution_source TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Attempt resolution from kl_versions (temporal layer)
  RETURN QUERY
  SELECT 
    v.version_id,
    v.instrument_id,
    v.section_num,
    v.effective_from,
    v.effective_to,
    v.text,
    v.amended_by,
    v.source_url,
    v.policy_rationale,
    (v.effective_to IS NULL) as is_current,
    'kl_versions'::TEXT as resolution_source
  FROM kl_versions v
  WHERE v.instrument_id = p_instrument_id
    AND v.section_num = p_section_num
    AND v.effective_from <= p_target_date
    AND (v.effective_to IS NULL OR v.effective_to >= p_target_date)
  ORDER BY v.effective_from DESC
  LIMIT 1;

  -- Fallback: if no version found, return current provision text
  IF NOT FOUND THEN
    RETURN QUERY
    SELECT 
      NULL::UUID as version_id,
      kp.instrument_id,
      kp.section_num,
      NULL::DATE as effective_from,
      NULL::DATE as effective_to,
      kp.current_text as text,
      NULL::TEXT as amended_by,
      kp.source_url,
      NULL::TEXT as policy_rationale,
      TRUE as is_current,
      'kl_provisions_fallback'::TEXT as resolution_source
    FROM kl_provisions kp
    WHERE kp.instrument_id = p_instrument_id
      AND kp.section_num = p_section_num
    LIMIT 1;
  END IF;
END;
$$;

COMMENT ON FUNCTION resolve_provision_at_date IS 'TIL Resolver — resolves the operative version of any legislative provision at a specified date. Per KLIA-001 §5.3. Deployed 13 April 2026.';

