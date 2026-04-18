-- Migration: 20260329203630_create_match_documents_rpc
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_match_documents_rpc


-- KLIA-001 §10.3: RAG retrieval function for Eileen EQIS pipeline
-- Accepts a query embedding and returns the top-N most similar provisions
-- by cosine similarity. Used by kl_ai_assistant Edge Function (Stage 3: KB Retrieval)

CREATE OR REPLACE FUNCTION public.match_provisions(
    query_embedding extensions.vector(1536),
    match_threshold FLOAT DEFAULT 0.5,
    match_count INT DEFAULT 10,
    filter_instrument TEXT DEFAULT NULL
)
RETURNS TABLE (
    provision_id UUID,
    instrument_id TEXT,
    section_num TEXT,
    title TEXT,
    summary TEXT,
    current_text TEXT,
    source_url TEXT,
    key_principle TEXT,
    in_force BOOLEAN,
    acei_category TEXT,
    similarity FLOAT
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

-- Matching function for cases
CREATE OR REPLACE FUNCTION public.match_cases(
    query_embedding extensions.vector(1536),
    match_threshold FLOAT DEFAULT 0.5,
    match_count INT DEFAULT 5
)
RETURNS TABLE (
    case_id UUID,
    name TEXT,
    citation TEXT,
    court TEXT,
    year INTEGER,
    principle TEXT,
    held TEXT,
    significance TEXT,
    bailii_url TEXT,
    similarity FLOAT
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

COMMENT ON FUNCTION public.match_provisions IS 'KLIA-001 §10.3: RAG provision retrieval for Eileen EQIS Stage 3.';
COMMENT ON FUNCTION public.match_cases IS 'KLIA-001 §10.3: RAG case law retrieval for Eileen EQIS Stage 3.';

