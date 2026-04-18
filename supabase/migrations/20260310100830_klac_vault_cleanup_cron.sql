-- Migration: 20260310100830_klac_vault_cleanup_cron
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: klac_vault_cleanup_cron


-- C3: KLAC-001 Vault Cleanup Cron Job
-- Runs daily at 03:00 UTC
-- Soft-deletes expired vault documents, then hard-deletes extracted text
-- for documents already soft-deleted > 1 hour ago

SELECT cron.schedule(
  'kl_vault_cleanup',
  '0 3 * * *',
  $$
  -- Step 1: Soft-delete vault documents where expires_at has passed
  UPDATE public.kl_vault_documents
  SET deleted_at = now()
  WHERE deleted_at IS NULL
    AND expires_at IS NOT NULL
    AND expires_at < now();

  -- Step 2: Hard-delete extracted text for documents already soft-deleted
  -- (1-hour grace period to allow any in-flight reads to complete)
  DELETE FROM public.kl_vault_document_text
  WHERE document_id IN (
    SELECT id
    FROM public.kl_vault_documents
    WHERE deleted_at IS NOT NULL
      AND deleted_at < now() - interval '1 hour'
  );
  $$
);

