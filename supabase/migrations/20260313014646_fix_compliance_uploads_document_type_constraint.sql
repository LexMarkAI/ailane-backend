-- Migration: 20260313014646_fix_compliance_uploads_document_type_constraint
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: fix_compliance_uploads_document_type_constraint


ALTER TABLE compliance_uploads 
  DROP CONSTRAINT IF EXISTS compliance_uploads_document_type_check;

ALTER TABLE compliance_uploads
  ADD CONSTRAINT compliance_uploads_document_type_check
  CHECK (document_type = ANY (ARRAY[
    'employment_contract', 'contract', 'handbook', 'policy', 'both'
  ]));

