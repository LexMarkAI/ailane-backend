-- Migration: 20260331212953_create_eat_case_law_and_union_annual_data
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_eat_case_law_and_union_annual_data


-- ============================================================
-- eat_case_law — Employment Appeal Tribunal decisions from BAILII
-- ============================================================
CREATE TABLE IF NOT EXISTS public.eat_case_law (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_identifier TEXT NOT NULL UNIQUE,
    case_reference TEXT NOT NULL,
    case_name TEXT NOT NULL,
    judgment_date DATE,
    judge_name TEXT,
    appeal_from TEXT,
    jurisdiction_tags TEXT[],
    acei_categories TEXT[],
    acei_category_numbers INTEGER[],
    headnote TEXT,
    judgment_text TEXT,
    key_principles TEXT[],
    legislation_cited TEXT[],
    cases_cited TEXT[],
    outcome TEXT,
    is_binding_precedent BOOLEAN DEFAULT true,
    employment_law_topic TEXT,
    source_url TEXT NOT NULL,
    bailii_url TEXT,
    content_hash TEXT,
    enrichment_status TEXT DEFAULT 'raw',
    scraped_at TIMESTAMPTZ DEFAULT now(),
    metadata JSONB DEFAULT '{}'::jsonb,
    jurisdiction_code VARCHAR NOT NULL DEFAULT 'GB',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_eat_case_law_source_identifier ON public.eat_case_law(source_identifier);
CREATE INDEX IF NOT EXISTS idx_eat_case_law_judgment_date ON public.eat_case_law(judgment_date);
CREATE INDEX IF NOT EXISTS idx_eat_case_law_case_reference ON public.eat_case_law(case_reference);
CREATE INDEX IF NOT EXISTS idx_eat_case_law_jurisdiction_tags ON public.eat_case_law USING GIN(jurisdiction_tags);
CREATE INDEX IF NOT EXISTS idx_eat_case_law_acei_categories ON public.eat_case_law USING GIN(acei_categories);
CREATE INDEX IF NOT EXISTS idx_eat_case_law_enrichment_status ON public.eat_case_law(enrichment_status);

-- ============================================================
-- union_annual_data — Extracted data from union annual reports
-- ============================================================
CREATE TABLE IF NOT EXISTS public.union_annual_data (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_identifier TEXT NOT NULL UNIQUE,
    union_name TEXT NOT NULL,
    report_year INTEGER NOT NULL,
    report_period_start DATE,
    report_period_end DATE,
    metric_name TEXT NOT NULL,
    metric_value NUMERIC,
    metric_unit TEXT,
    case_type TEXT,
    sector TEXT,
    region TEXT,
    settlement_total NUMERIC,
    cases_total INTEGER,
    cases_settled INTEGER,
    cases_won_at_hearing INTEGER,
    cases_lost INTEGER,
    success_rate_pct NUMERIC,
    source_url TEXT,
    source_document TEXT,
    extraction_method TEXT DEFAULT 'manual',
    acei_category TEXT,
    acei_category_number INTEGER,
    scraped_at TIMESTAMPTZ DEFAULT now(),
    metadata JSONB DEFAULT '{}'::jsonb,
    jurisdiction_code VARCHAR NOT NULL DEFAULT 'GB',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_union_annual_data_source_identifier ON public.union_annual_data(source_identifier);
CREATE INDEX IF NOT EXISTS idx_union_annual_data_union_name ON public.union_annual_data(union_name);
CREATE INDEX IF NOT EXISTS idx_union_annual_data_report_year ON public.union_annual_data(report_year);
CREATE INDEX IF NOT EXISTS idx_union_annual_data_metric_name ON public.union_annual_data(metric_name);

-- Grant access
GRANT SELECT, INSERT, UPDATE ON public.eat_case_law TO service_role;
GRANT SELECT, INSERT, UPDATE ON public.union_annual_data TO service_role;
GRANT SELECT ON public.eat_case_law TO anon, authenticated;
GRANT SELECT ON public.union_annual_data TO anon, authenticated;

