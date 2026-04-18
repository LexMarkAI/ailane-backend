-- Migration: 20260331121428_add_pdf_extraction_status_column
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_pdf_extraction_status_column

-- Add extraction status tracking to tribunal_decisions
ALTER TABLE public.tribunal_decisions 
ADD COLUMN IF NOT EXISTS pdf_extraction_status text DEFAULT 'pending';

-- Set status for records that already have extracted text
UPDATE public.tribunal_decisions 
SET pdf_extraction_status = 'complete' 
WHERE pdf_extracted_text IS NOT NULL;

-- Index for efficient queue queries
CREATE INDEX IF NOT EXISTS idx_td_pdf_extraction_status 
ON public.tribunal_decisions(pdf_extraction_status) 
WHERE pdf_extraction_status = 'pending';
