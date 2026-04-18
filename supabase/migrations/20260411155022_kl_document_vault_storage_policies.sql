-- Migration: 20260411155022_kl_document_vault_storage_policies
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: kl_document_vault_storage_policies

-- Storage policies for kl-document-vault bucket
-- Users can upload to their own folder: {user_id}/{filename}
-- Users can read their own files only
-- Service role can read all (for kl_document_extract EF)

CREATE POLICY "Users can upload own documents" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'kl-document-vault' 
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users can read own documents" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'kl-document-vault' 
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Users can delete own documents" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'kl-document-vault' 
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
