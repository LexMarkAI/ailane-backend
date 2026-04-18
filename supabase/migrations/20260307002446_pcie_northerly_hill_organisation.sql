-- Migration: 20260307002446_pcie_northerly_hill_organisation
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: pcie_northerly_hill_organisation


-- ============================================================
-- NORTHERLY HILL FACILITIES MANAGEMENT LTD
-- Fictional demonstration entity — AILANE-SPEC-PCIE-003 v3.0
-- Fixed org_id: d0000000-0000-4000-8000-000000000001
-- ============================================================

-- Insert demonstration organisation record
INSERT INTO organisations (
  id,
  name,
  industry,
  headcount,
  plan,
  jurisdiction,
  primary_jurisdiction_code,
  region,
  companies_house_number,
  is_demonstration_entity,
  pcie_company_number,
  registered_address,
  annual_turnover_band,
  incorporated_year,
  sic_primary,
  sic_secondary,
  operational_sites,
  acei_sector_code,
  acei_sector_multiplier,
  workforce_jm_weighted,
  onboarding_completed,
  onboarding_data
)
VALUES (
  'd0000000-0000-4000-8000-000000000001'::uuid,
  'Northerly Hill Facilities Management Ltd',
  'Facilities Management & Workplace Services',
  238,
  'enterprise',
  'UK',
  'GB',
  'Wales',
  NULL,
  true,
  'NH-2014-0347',
  'Unit 4, Capital Business Park, Cardiff CF3 2PX',
  '£7.5m–£10m',
  2014,
  '81210',
  ARRAY['81220', '81300'],
  '[
    {"site": "Cardiff HQ", "region": "Wales", "postcode": "CF3 2PX", "headcount": 100, "jm": 1.05},
    {"site": "Swansea Service Depot", "region": "Wales", "postcode": "SA1 2AB", "headcount": 52, "jm": 1.05},
    {"site": "Bristol Service Depot", "region": "South West", "postcode": "BS1 4AB", "headcount": 46, "jm": 0.95},
    {"site": "Birmingham Service Depot", "region": "West Midlands", "postcode": "B1 1AA", "headcount": 40, "jm": 1.05}
  ]'::jsonb,
  'D4',
  1.20,
  1.03,
  true,
  '{
    "employee_mix": {
      "field_operatives": 148,
      "site_supervisors": 34,
      "admin_hr": 36,
      "management": 18,
      "directors": 2
    },
    "trade_union_recognition": false,
    "pcie_spec_version": "AILANE-SPEC-PCIE-003-v3.0",
    "demonstration_entity": true,
    "entity_verified_clear": true,
    "verification_date": "2026-03-07"
  }'::jsonb
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  is_demonstration_entity = EXCLUDED.is_demonstration_entity,
  onboarding_data = EXCLUDED.onboarding_data;

-- Register in PCIE demonstration entity registry
INSERT INTO pcie_demonstration_entities (
  org_id,
  entity_ref,
  display_name,
  fictional_company_number,
  spec_version,
  ratification_date,
  sector_code,
  headcount,
  employee_mix,
  operational_sites
) VALUES (
  'd0000000-0000-4000-8000-000000000001'::uuid,
  'northerly-hill',
  'Northerly Hill Facilities Management Ltd',
  'NH-2014-0347',
  'AILANE-SPEC-PCIE-003-v3.0',
  '2026-03-07',
  'D4',
  238,
  '{
    "field_operatives": 148,
    "site_supervisors": 34,
    "admin_hr": 36,
    "management": 18,
    "directors": 2
  }'::jsonb,
  '[
    {"site": "Cardiff HQ", "region": "Wales"},
    {"site": "Swansea Service Depot", "region": "Wales"},
    {"site": "Bristol Service Depot", "region": "South West"},
    {"site": "Birmingham Service Depot", "region": "West Midlands"}
  ]'::jsonb
)
ON CONFLICT (org_id) DO NOTHING;

