-- Migration: 20260314040520_public_assets_rls
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: public_assets_rls

CREATE POLICY "Public read access"
ON storage.objects FOR SELECT
USING (bucket_id = 'public-assets');

CREATE POLICY "Service role upload"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'public-assets');
