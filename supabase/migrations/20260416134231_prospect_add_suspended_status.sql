-- Migration: 20260416134231_prospect_add_suspended_status
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: prospect_add_suspended_status


-- Add 'suspended' as valid status for prospects held pending legal review
-- Per council AMD-REVIEW-001 outcome, status governance must support suspension state
ALTER TABLE prospect_organisations 
DROP CONSTRAINT prospect_organisations_status_check;

ALTER TABLE prospect_organisations 
ADD CONSTRAINT prospect_organisations_status_check 
CHECK (status = ANY (ARRAY[
  'prepared'::text, 
  'brief_sent'::text, 
  'preview_active'::text, 
  'engaged'::text, 
  'converting'::text, 
  'converted'::text, 
  'declined'::text, 
  'expired'::text,
  'suspended'::text
]));

