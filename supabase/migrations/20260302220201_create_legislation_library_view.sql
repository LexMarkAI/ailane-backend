-- Migration: 20260302220201_create_legislation_library_view
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_legislation_library_view


-- Dashboard view for legislation library
CREATE OR REPLACE VIEW legislation_library_dashboard AS
SELECT 
  COUNT(*) as total_legislation,
  COUNT(*) FILTER (WHERE legislation_type = 'primary') as acts_of_parliament,
  COUNT(*) FILTER (WHERE legislation_type = 'statutory_instrument') as statutory_instruments,
  COUNT(*) FILTER (WHERE legislation_type = 'binding_code') as codes_of_practice,
  COUNT(*) FILTER (WHERE lifecycle_stage = 'in_force') as in_force,
  COUNT(*) FILTER (WHERE lifecycle_stage = 'bill') as pending_bills,
  COUNT(*) FILTER (WHERE lifecycle_stage = 'partially_commenced') as partially_commenced,
  COUNT(DISTINCT primary_acei_category) as acei_categories_covered,
  COUNT(*) FILTER (WHERE tier_access = 'all') as all_tier_access,
  COUNT(*) FILTER (WHERE tier_access = 'governance') as governance_only,
  COUNT(*) FILTER (WHERE tier_access = 'institutional') as institutional_only,
  MIN(commencement_date) as earliest_legislation,
  MAX(commencement_date) as latest_commencement
FROM legislation_library;

-- View for the Forward Exposure Register (upcoming changes)
CREATE OR REPLACE VIEW upcoming_legislative_changes AS
SELECT 
  l.short_title,
  l.lifecycle_stage,
  l.commencement_date,
  l.acei_categories,
  l.primary_acei_category,
  l.sci_significance,
  l.summary,
  l.obligations_summary,
  l.legislation_gov_url,
  l.tags
FROM legislation_library l
WHERE l.lifecycle_stage IN ('bill', 'royal_assent', 'partially_commenced')
ORDER BY l.sci_significance DESC, l.commencement_date ASC;

