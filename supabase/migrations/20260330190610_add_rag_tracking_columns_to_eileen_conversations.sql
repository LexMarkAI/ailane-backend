-- Migration: 20260330190610_add_rag_tracking_columns_to_eileen_conversations
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_rag_tracking_columns_to_eileen_conversations


-- Add RAG tracking columns to kl_eileen_conversations
ALTER TABLE kl_eileen_conversations
ADD COLUMN IF NOT EXISTS provisions_retrieved text[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS cases_retrieved text[] DEFAULT '{}',
ADD COLUMN IF NOT EXISTS rag_provision_count integer DEFAULT 0,
ADD COLUMN IF NOT EXISTS rag_case_count integer DEFAULT 0;

COMMENT ON COLUMN kl_eileen_conversations.provisions_retrieved IS 'Section numbers of provisions retrieved via RAG for this query';
COMMENT ON COLUMN kl_eileen_conversations.cases_retrieved IS 'Citations of cases retrieved via RAG for this query';
COMMENT ON COLUMN kl_eileen_conversations.rag_provision_count IS 'Number of provisions retrieved via RAG';
COMMENT ON COLUMN kl_eileen_conversations.rag_case_count IS 'Number of cases retrieved via RAG';

