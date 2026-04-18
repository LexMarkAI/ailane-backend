-- Migration: 20260310233744_fix_app_users_auth_uid_alignment
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: fix_app_users_auth_uid_alignment


-- Fix 1: Remove orphaned app_users rows whose IDs do not match any auth.users UID
-- These rows were created with wrong UUIDs and get_my_org_id() can never resolve them
DELETE FROM app_users
WHERE id IN (
  'a59dba81-a159-438c-a8ff-73110fafdf72',  -- markglane@gmail.com wrong UUID
  '2cab3fac-a20b-4446-b915-2da2ffd6b0b8',  -- ops@ailane.ai wrong UUID
  '81a26427-e13d-4bee-a5e9-cfa484605b3f'   -- mark@ailane.ai duplicate wrong UUID
);

-- Fix 2: Insert correct app_users rows with UUIDs matching auth.users exactly
-- markglane@gmail.com → Ailane Internal org
INSERT INTO app_users (id, org_id, email, role, is_active, created_at, updated_at)
VALUES (
  '049e4be5-995e-4def-abdf-4a0b0a2bde42',
  '0af15296-a804-4387-a39b-1684a62a42c5',
  'markglane@gmail.com',
  'admin',
  true,
  now(),
  now()
)
ON CONFLICT (id) DO UPDATE SET
  org_id = EXCLUDED.org_id,
  updated_at = now();

-- ops@ailane.ai → Demo Operational Readiness org
INSERT INTO app_users (id, org_id, email, role, is_active, created_at, updated_at)
VALUES (
  'c7fbda71-25c1-4852-88de-fb8e9b12e380',
  'fa6598f0-2840-4022-b824-23cdcc7a50af',
  'ops@ailane.ai',
  'admin',
  true,
  now(),
  now()
)
ON CONFLICT (id) DO UPDATE SET
  org_id = EXCLUDED.org_id,
  updated_at = now();

-- Fix 3: Point mark@ailane.ai from the nil UUID org to Ailane Internal
UPDATE app_users
SET org_id = '0af15296-a804-4387-a39b-1684a62a42c5',
    updated_at = now()
WHERE id = 'eb2ef2cd-10e5-41eb-904a-bb280b0cb149';

