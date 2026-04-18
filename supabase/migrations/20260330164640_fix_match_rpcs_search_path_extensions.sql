-- Migration: 20260330164640_fix_match_rpcs_search_path_extensions
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: fix_match_rpcs_search_path_extensions


-- Fix match_provisions: add extensions to search_path for pgvector <=> operator
CREATE OR REPLACE FUNCTION public.match_provisions(
    query_embedding vector(1024),
    match_threshold double precision DEFAULT 0.5,
    match_count integer DEFAULT 10,
    filter_instrument text DEFAULT NULL
)
RETURNS TABLE (
    provision_id uuid,
    instrument_id text,
    section_num text,
    title text,
    summary text,
    current_text text,
    source_url text,
    key_principle text,
    in_force boolean,
    acei_category text,
    similarity double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
    RETURN QUERY
    SELECT
        kp.provision_id,
        kp.instrument_id,
        kp.section_num,
        kp.title,
        kp.summary,
        kp.current_text,
        kp.source_url,
        kp.key_principle,
        kp.in_force,
        kp.acei_category,
        1 - (kp.embedding <=> query_embedding) AS similarity
    FROM public.kl_provisions kp
    WHERE
        kp.embedding IS NOT NULL
        AND 1 - (kp.embedding <=> query_embedding) > match_threshold
        AND (filter_instrument IS NULL OR kp.instrument_id = filter_instrument)
    ORDER BY kp.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Fix match_cases: add extensions to search_path for pgvector <=> operator
CREATE OR REPLACE FUNCTION public.match_cases(
    query_embedding vector(1024),
    match_threshold double precision DEFAULT 0.5,
    match_count integer DEFAULT 5
)
RETURNS TABLE (
    case_id uuid,
    name text,
    citation text,
    court text,
    year integer,
    principle text,
    held text,
    significance text,
    bailii_url text,
    similarity double precision
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
    RETURN QUERY
    SELECT
        kc.case_id,
        kc.name,
        kc.citation,
        kc.court,
        kc.year,
        kc.principle,
        kc.held,
        kc.significance,
        kc.bailii_url,
        1 - (kc.embedding <=> query_embedding) AS similarity
    FROM public.kl_cases kc
    WHERE
        kc.embedding IS NOT NULL
        AND 1 - (kc.embedding <=> query_embedding) > match_threshold
    ORDER BY kc.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Re-grant execute permissions
GRANT EXECUTE ON FUNCTION public.match_provisions(vector(1024), double precision, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.match_provisions(vector(1024), double precision, integer, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.match_cases(vector(1024), double precision, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.match_cases(vector(1024), double precision, integer) TO service_role;

