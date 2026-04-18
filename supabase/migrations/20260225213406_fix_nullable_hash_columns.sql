-- Migration: 20260225213406_fix_nullable_hash_columns
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: fix_nullable_hash_columns


-- Make immutable_hash nullable on scoring tables (generated after insert)
ALTER TABLE acei_domain_scores ALTER COLUMN immutable_hash DROP NOT NULL;
ALTER TABLE acei_category_scores ALTER COLUMN immutable_hash DROP NOT NULL;
