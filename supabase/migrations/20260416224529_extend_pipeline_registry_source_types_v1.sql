-- Migration: 20260416224529_extend_pipeline_registry_source_types_v1
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: extend_pipeline_registry_source_types_v1

-- Extend source_type CHECK to permit 6 Ailane scraper source types
ALTER TABLE public.pipeline_registry
    DROP CONSTRAINT IF EXISTS pipeline_registry_source_type_check;

ALTER TABLE public.pipeline_registry
    ADD CONSTRAINT pipeline_registry_source_type_check
    CHECK (source_type = ANY (ARRAY[
        'govuk_tribunal'::text,
        'parliament_bills'::text,
        'parliament_hansard'::text,
        'parliament_committees'::text,
        'govuk_news'::text,
        'legislation_govuk'::text,
        'bbc_parliament'::text,
        'companies_house'::text,
        'eu_eurlex'::text,
        'hse_enforcement'::text,
        'ico_enforcement'::text,
        'ehrc_enforcement'::text,
        'acas_guidance'::text,
        'fos_complaints'::text,
        'fca_complaints'::text,
        'tpr_penalties'::text,
        'fca_enforcement'::text,
        'tpo_determinations'::text,
        'eat_decisions'::text,
        'custom'::text
    ]));
