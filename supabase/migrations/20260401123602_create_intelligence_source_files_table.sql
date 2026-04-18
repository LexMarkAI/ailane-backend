-- Migration: 20260401123602_create_intelligence_source_files_table
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_intelligence_source_files_table


-- Raw file storage for all intelligence source documents
-- Phase 1: Download and catalogue every file from every source
-- Phase 2: Parse/extract structured data from stored files
CREATE TABLE IF NOT EXISTS public.intelligence_source_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_identifier TEXT NOT NULL UNIQUE,
    source_name TEXT NOT NULL,
    source_category TEXT NOT NULL,
    file_url TEXT NOT NULL,
    file_name TEXT NOT NULL,
    file_type TEXT NOT NULL,
    file_size_bytes INTEGER,
    publication_date DATE,
    period_start DATE,
    period_end DATE,
    period_label TEXT,
    raw_content TEXT,
    extraction_status TEXT DEFAULT 'downloaded',
    extracted_data JSONB DEFAULT '{}'::jsonb,
    extraction_method TEXT,
    extraction_notes TEXT,
    source_page_url TEXT,
    downloaded_at TIMESTAMPTZ DEFAULT now(),
    extracted_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'::jsonb,
    jurisdiction_code VARCHAR NOT NULL DEFAULT 'GB',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_isf_source_name ON public.intelligence_source_files(source_name);
CREATE INDEX IF NOT EXISTS idx_isf_source_category ON public.intelligence_source_files(source_category);
CREATE INDEX IF NOT EXISTS idx_isf_extraction_status ON public.intelligence_source_files(extraction_status);
CREATE INDEX IF NOT EXISTS idx_isf_file_type ON public.intelligence_source_files(file_type);
CREATE INDEX IF NOT EXISTS idx_isf_publication_date ON public.intelligence_source_files(publication_date);

-- Check constraint for source categories
ALTER TABLE public.intelligence_source_files 
ADD CONSTRAINT chk_isf_source_category 
CHECK (source_category IN (
    'hmcts_quarterly',
    'hmcts_annual', 
    'acas_quarterly',
    'acas_annual',
    'union_annual_report',
    'hse_statistics',
    'eat_judgment',
    'moj_annual',
    'other'
));

-- Check constraint for extraction status
ALTER TABLE public.intelligence_source_files 
ADD CONSTRAINT chk_isf_extraction_status 
CHECK (extraction_status IN (
    'pending',
    'downloaded',
    'text_extracted',
    'structured_extracted',
    'ai_analysed',
    'failed',
    'skipped'
));

-- Grants
GRANT SELECT, INSERT, UPDATE ON public.intelligence_source_files TO service_role;
GRANT SELECT ON public.intelligence_source_files TO anon, authenticated;

COMMENT ON TABLE public.intelligence_source_files IS 
'Phase 1 raw file storage for all intelligence source documents. Download first, parse later — same pattern as tribunal PDF extraction.';

