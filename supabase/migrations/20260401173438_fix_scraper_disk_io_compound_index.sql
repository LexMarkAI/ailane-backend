-- Migration: 20260401173438_fix_scraper_disk_io_compound_index
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: fix_scraper_disk_io_compound_index


-- Fix for scraper 500 errors / Disk IO exhaustion
-- The scraper query hits sequential scans on 131k rows (32s+), exhausting IO budget

-- 1. Create compound partial index matching the exact scraper query pattern
CREATE INDEX IF NOT EXISTS idx_td_scraper_pending_pdfs
ON public.tribunal_decisions (scraped_at DESC)
WHERE pdf_extraction_status = 'pending' AND pdf_urls IS NOT NULL;

-- 2. Drop the old single-column partial index (now redundant)
DROP INDEX IF EXISTS idx_td_pdf_extraction_status;

-- 3. Create full index on pdf_extraction_status for the counts/stats query
CREATE INDEX IF NOT EXISTS idx_td_pdf_extraction_status_full
ON public.tribunal_decisions (pdf_extraction_status);

-- 4. Analyze the table so planner picks up new indexes
ANALYZE public.tribunal_decisions;

