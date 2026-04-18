-- Migration: 20260314040511_create_public_assets_bucket
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_public_assets_bucket

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'public-assets',
  'public-assets',
  true,
  5242880,
  ARRAY['text/csv','application/vnd.ms-excel','application/octet-stream']
)
ON CONFLICT (id) DO NOTHING;
