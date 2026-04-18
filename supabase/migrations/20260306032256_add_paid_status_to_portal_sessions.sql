-- Migration: 20260306032256_add_paid_status_to_portal_sessions
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_paid_status_to_portal_sessions


ALTER TABLE compliance_portal_sessions 
DROP CONSTRAINT IF EXISTS compliance_portal_sessions_status_check;

ALTER TABLE compliance_portal_sessions 
ADD CONSTRAINT compliance_portal_sessions_status_check 
CHECK (status = ANY (ARRAY[
  'paid'::text,
  'gate_passed'::text, 
  'uploaded'::text, 
  'analysing'::text, 
  'complete'::text, 
  'failed'::text
]));

