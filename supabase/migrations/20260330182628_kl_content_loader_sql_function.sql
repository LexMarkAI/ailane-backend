-- Migration: 20260330182628_kl_content_loader_sql_function
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: kl_content_loader_sql_function


-- KL Content Loader — SQL Function
-- Replicates kl-content-loader Edge Function logic entirely in PostgreSQL
-- Uses http extension to fetch JSON, parses parts[].sections[], upserts provisions + cases
-- DB triggers on kl_provisions/kl_cases auto-fire kl-embed-provision for embeddings

CREATE OR REPLACE FUNCTION kl_load_content_file(p_file_id TEXT)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_doc jsonb;
  v_http_response record;
  v_instrument_id text;
  v_part jsonb;
  v_section jsonb;
  v_case jsonb;
  v_prov_count int := 0;
  v_case_count int := 0;
  v_skip_count int := 0;
  v_error_count int := 0;
  v_section_num text;
  v_title text;
  v_current_text text;
  v_existing_case_id uuid;
  v_existing_provisions text[];
  v_url text;
BEGIN
  v_url := 'https://ailane.ai/knowledge-library/content/' || p_file_id || '.json';
  
  -- Fetch JSON file
  SELECT * INTO v_http_response FROM http_get(v_url);
  
  IF v_http_response.status != 200 THEN
    RETURN jsonb_build_object(
      'file', p_file_id, 'status', 'error',
      'error', 'HTTP ' || v_http_response.status
    );
  END IF;
  
  v_doc := v_http_response.content::jsonb;
  v_instrument_id := COALESCE(v_doc->>'id', p_file_id);
  
  -- Process parts[].sections[] → kl_provisions
  IF v_doc ? 'parts' AND jsonb_typeof(v_doc->'parts') = 'array' THEN
    FOR v_part IN SELECT * FROM jsonb_array_elements(v_doc->'parts')
    LOOP
      IF v_part ? 'sections' AND jsonb_typeof(v_part->'sections') = 'array' THEN
        FOR v_section IN SELECT * FROM jsonb_array_elements(v_part->'sections')
        LOOP
          v_section_num := COALESCE(v_section->>'num', v_section->>'id', 'unknown-' || extract(epoch from now())::text);
          v_title := COALESCE(v_section->>'title', 'Untitled');
          v_current_text := COALESCE(v_section->>'text', v_section->>'content', '');
          
          -- Skip if text too short (KLIA-001 §12.3)
          IF length(v_current_text) < 50 THEN
            v_skip_count := v_skip_count + 1;
            CONTINUE;
          END IF;
          
          -- UPSERT provision
          BEGIN
            INSERT INTO kl_provisions (
              instrument_id, section_num, title, current_text,
              summary, source_url, key_principle, in_force, is_era_2025,
              acei_category, acei_categories, common_errors,
              last_verified, updated_at
            ) VALUES (
              v_instrument_id,
              v_section_num,
              v_title,
              v_current_text,
              v_section->>'summary',
              v_section->>'sourceUrl',
              v_section->>'keyPrinciple',
              NOT COALESCE((v_section->>'notInForce')::boolean, false),
              COALESCE((v_section->>'isEra2025')::boolean, false),
              v_section->>'aceiCategory',
              COALESCE(
                (SELECT array_agg(x::text) FROM jsonb_array_elements_text(v_section->'aceiCategories') x),
                '{}'::text[]
              ),
              COALESCE(
                (SELECT array_agg(
                  CASE WHEN jsonb_typeof(x) = 'string' THEN x#>>'{}'
                       ELSE COALESCE(x->>'description', x::text)
                  END
                ) FROM jsonb_array_elements(v_section->'commonErrors') x),
                '{}'::text[]
              ),
              now(),
              now()
            )
            ON CONFLICT (instrument_id, section_num) DO UPDATE SET
              title = EXCLUDED.title,
              current_text = EXCLUDED.current_text,
              summary = EXCLUDED.summary,
              source_url = EXCLUDED.source_url,
              key_principle = EXCLUDED.key_principle,
              in_force = EXCLUDED.in_force,
              is_era_2025 = EXCLUDED.is_era_2025,
              acei_category = EXCLUDED.acei_category,
              acei_categories = EXCLUDED.acei_categories,
              common_errors = EXCLUDED.common_errors,
              last_verified = now(),
              updated_at = now();
            
            v_prov_count := v_prov_count + 1;
          EXCEPTION WHEN OTHERS THEN
            v_error_count := v_error_count + 1;
          END;
          
          -- Process section-level leadingCases → kl_cases
          IF v_section ? 'leadingCases' AND jsonb_typeof(v_section->'leadingCases') = 'array' THEN
            FOR v_case IN SELECT * FROM jsonb_array_elements(v_section->'leadingCases')
            LOOP
              IF v_case->>'citation' IS NOT NULL THEN
                BEGIN
                  -- Check if case already exists
                  SELECT case_id, provisions_affected INTO v_existing_case_id, v_existing_provisions
                  FROM kl_cases WHERE citation = v_case->>'citation' LIMIT 1;
                  
                  IF v_existing_case_id IS NOT NULL THEN
                    -- Update existing case, merge provisions_affected
                    UPDATE kl_cases SET
                      name = COALESCE(v_case->>'name', v_case->>'caseName', name),
                      principle = COALESCE(v_case->>'principle', v_case->>'keyPrinciple', principle),
                      held = COALESCE(v_case->>'held', held),
                      significance = COALESCE(v_case->>'significance', significance),
                      bailii_url = COALESCE(v_case->>'bailiiUrl', v_case->>'url', bailii_url),
                      provisions_affected = (
                        SELECT array_agg(DISTINCT x) FROM unnest(
                          array_cat(COALESCE(v_existing_provisions, '{}'), ARRAY[v_section_num])
                        ) x
                      ),
                      updated_at = now()
                    WHERE case_id = v_existing_case_id;
                  ELSE
                    INSERT INTO kl_cases (
                      name, citation, court, year, provisions_affected,
                      principle, facts, held, significance, bailii_url, updated_at
                    ) VALUES (
                      COALESCE(v_case->>'name', v_case->>'caseName', 'Unknown'),
                      v_case->>'citation',
                      COALESCE(v_case->>'court', 'Unknown'),
                      COALESCE((v_case->>'year')::int, 0),
                      ARRAY[v_section_num],
                      COALESCE(v_case->>'principle', v_case->>'keyPrinciple'),
                      v_case->>'facts',
                      v_case->>'held',
                      v_case->>'significance',
                      COALESCE(v_case->>'bailiiUrl', v_case->>'url'),
                      now()
                    );
                  END IF;
                  v_case_count := v_case_count + 1;
                EXCEPTION WHEN OTHERS THEN
                  v_error_count := v_error_count + 1;
                END;
              END IF;
            END LOOP;
          END IF;
          
        END LOOP;
      END IF;
    END LOOP;
  END IF;
  
  -- Process file-level cases
  IF v_doc ? 'fileLevelCases' OR v_doc ? 'leadingCases' THEN
    FOR v_case IN 
      SELECT * FROM jsonb_array_elements(
        COALESCE(v_doc->'fileLevelCases', v_doc->'leadingCases', '[]'::jsonb)
      )
    LOOP
      IF v_case->>'citation' IS NOT NULL THEN
        BEGIN
          INSERT INTO kl_cases (
            name, citation, court, year, provisions_affected,
            principle, facts, held, significance, bailii_url, updated_at
          ) VALUES (
            COALESCE(v_case->>'name', v_case->>'caseName', 'Unknown'),
            v_case->>'citation',
            COALESCE(v_case->>'court', 'Unknown'),
            COALESCE((v_case->>'year')::int, 0),
            COALESCE(
              (SELECT array_agg(x::text) FROM jsonb_array_elements_text(v_case->'provisionsAffected') x),
              '{}'::text[]
            ),
            COALESCE(v_case->>'principle', v_case->>'keyPrinciple'),
            v_case->>'facts',
            v_case->>'held',
            v_case->>'significance',
            COALESCE(v_case->>'bailiiUrl', v_case->>'url'),
            now()
          )
          ON CONFLICT (citation) DO UPDATE SET
            name = COALESCE(EXCLUDED.name, kl_cases.name),
            principle = COALESCE(EXCLUDED.principle, kl_cases.principle),
            held = COALESCE(EXCLUDED.held, kl_cases.held),
            significance = COALESCE(EXCLUDED.significance, kl_cases.significance),
            bailii_url = COALESCE(EXCLUDED.bailii_url, kl_cases.bailii_url),
            updated_at = now();
          
          v_case_count := v_case_count + 1;
        EXCEPTION WHEN OTHERS THEN
          v_error_count := v_error_count + 1;
        END;
      END IF;
    END LOOP;
  END IF;
  
  RETURN jsonb_build_object(
    'file', p_file_id,
    'status', 'complete',
    'provisions', v_prov_count,
    'cases', v_case_count,
    'skipped', v_skip_count,
    'errors', v_error_count
  );
END;
$$;

