-- Migration: 20260409190638_create_priority_enrichment_candidates_rpc
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_priority_enrichment_candidates_rpc


CREATE OR REPLACE FUNCTION get_priority_enrichment_candidates(
    p_year      integer,
    p_min_chars integer,
    p_max_chars integer,
    p_limit     integer
)
RETURNS TABLE(
    id                  uuid,
    case_number         text,
    claimant_name       text,
    respondent_name     text,
    pdf_extracted_text  text,
    text_len            integer
)
LANGUAGE sql STABLE SECURITY DEFINER AS $$
    SELECT
        td.id,
        td.case_number,
        td.claimant_name,
        td.respondent_name,
        td.pdf_extracted_text,
        char_length(td.pdf_extracted_text)::integer AS text_len
    FROM tribunal_decisions td
    WHERE NOT EXISTS (
        SELECT 1 FROM tribunal_enrichment te WHERE te.decision_id = td.id
    )
    AND td.pdf_extracted_text IS NOT NULL
    AND char_length(td.pdf_extracted_text) BETWEEN p_min_chars AND p_max_chars
    AND EXTRACT(YEAR FROM td.decision_date)::integer = p_year
    ORDER BY char_length(td.pdf_extracted_text) DESC
    LIMIT p_limit;
$$;

