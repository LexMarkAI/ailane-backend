-- Migration: 20260329203420_enable_pgvector_extension
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: enable_pgvector_extension


-- KLIA-001 Phase 1: Enable pgvector for embedding columns
-- Required by AILANE-DPIA-KLIA-001 (approved 29 March 2026)
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA extensions;

