-- Migration: 20260331000753_add_pdf_extracted_text_to_tribunal_decisions
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_pdf_extracted_text_to_tribunal_decisions

ALTER TABLE public.tribunal_decisions
ADD COLUMN IF NOT EXISTS pdf_extracted_text text,
ADD COLUMN IF NOT EXISTS pdf_text_extracted_at timestamptz;
