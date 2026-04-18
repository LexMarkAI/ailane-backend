-- Migration: 20260331121539_add_pdf_extraction_status_column
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_pdf_extraction_status_column

-- Add extraction status tracking to tribunal_decisions
ALTER TABLE public.tribunal_decisions 
ADD COLUMN IF NOT EXISTS pdf_extraction_status text DEFAULT 'pending';

-- Index for efficient queue queries
CREATE INDEX IF NOT EXISTS idx_td_pdf_extraction_status 
ON public.tribunal_decisions(pdf_extraction_status) 
WHERE pdf_extraction_status = 'pending';
