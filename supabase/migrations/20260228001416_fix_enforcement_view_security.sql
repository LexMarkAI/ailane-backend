-- Migration: 20260228001416_fix_enforcement_view_security
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: fix_enforcement_view_security


-- Fix SECURITY DEFINER on unified enforcement view
DROP VIEW IF EXISTS enforcement_events_unified;
CREATE VIEW enforcement_events_unified WITH (security_invoker = true) AS
SELECT id, 'hse' AS source, notice_type AS action_type, date_issued,
  recipient_name AS organisation, sector, fine_amount AS penalty_amount,
  acei_category, acei_category_number, source_url
FROM hse_enforcement_notices
UNION ALL
SELECT id, 'ico' AS source, action_type, date_issued,
  organisation_name AS organisation, sector, penalty_amount,
  acei_category, acei_category_number, source_url
FROM ico_enforcement_actions
UNION ALL
SELECT id, 'ehrc' AS source, action_type, date_issued,
  organisation_name AS organisation, sector, NULL AS penalty_amount,
  acei_category, acei_category_number, source_url
FROM ehrc_enforcement_actions;
