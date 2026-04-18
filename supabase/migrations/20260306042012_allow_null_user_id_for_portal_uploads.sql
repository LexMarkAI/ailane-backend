-- Migration: 20260306042012_allow_null_user_id_for_portal_uploads
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: allow_null_user_id_for_portal_uploads


-- Allow null user_id for portal (public) uploads
ALTER TABLE compliance_uploads ALTER COLUMN user_id DROP NOT NULL;

