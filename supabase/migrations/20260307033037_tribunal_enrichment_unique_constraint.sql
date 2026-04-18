-- Migration: 20260307033037_tribunal_enrichment_unique_constraint
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: tribunal_enrichment_unique_constraint


ALTER TABLE tribunal_enrichment 
ADD CONSTRAINT tribunal_enrichment_decision_id_key UNIQUE (decision_id);

