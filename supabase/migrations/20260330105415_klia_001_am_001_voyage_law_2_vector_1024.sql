-- Migration: 20260330105415_klia_001_am_001_voyage_law_2_vector_1024
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: klia_001_am_001_voyage_law_2_vector_1024


-- ============================================================================
-- AILANE-SPEC-KLIA-001-AM-001: Vector Embedding Architecture Amendment
-- Migration: Change vector dimensions from 1536 to 1024 (voyage-law-2)
-- Pre-deployment change — both tables verified empty (0 rows)
-- ============================================================================

-- Step 1: Alter kl_provisions embedding column from vector(1536) to vector(1024)
ALTER TABLE public.kl_provisions
  ALTER COLUMN embedding TYPE vector(1024);

-- Step 2: Alter kl_cases embedding column from vector(1536) to vector(1024)
ALTER TABLE public.kl_cases
  ALTER COLUMN embedding TYPE vector(1024);

-- Step 3: Recreate match_provisions RPC with explicit vector(1024) parameter
DROP FUNCTION IF EXISTS public.match_provisions(vector, double precision, integer, text);

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
SET search_path = public
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

-- Step 4: Recreate match_cases RPC with explicit vector(1024) parameter
DROP FUNCTION IF EXISTS public.match_cases(vector, double precision, integer);

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
SET search_path = public
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

-- Step 5: Grant execute permissions for RPCs
GRANT EXECUTE ON FUNCTION public.match_provisions(vector(1024), double precision, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.match_provisions(vector(1024), double precision, integer, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.match_cases(vector(1024), double precision, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.match_cases(vector(1024), double precision, integer) TO service_role;

-- Add comment for governance traceability
COMMENT ON FUNCTION public.match_provisions IS 'KLIA-001-AM-001: Semantic search over kl_provisions using voyage-law-2 (1024-dim) embeddings';
COMMENT ON FUNCTION public.match_cases IS 'KLIA-001-AM-001: Semantic search over kl_cases using voyage-law-2 (1024-dim) embeddings';

