-- Migration: 20260310131058_auth001_visibility_framework
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: auth001_visibility_framework


-- AILANE-SPEC-AUTH-001 v2.1 — Section 6.3 Schema Amendments
-- AMD-2026-011 | Ratified March 2026

-- ── kl_projects ─────────────────────────────────────────────────────────────
ALTER TABLE kl_projects
  ADD COLUMN IF NOT EXISTS visibility        TEXT    NOT NULL DEFAULT 'personal'
    CHECK (visibility IN ('personal','org_shared','org_required')),
  ADD COLUMN IF NOT EXISTS org_id            UUID    REFERENCES organisations(id) ON DELETE SET NULL;

-- ── kl_vault_documents ───────────────────────────────────────────────────────
ALTER TABLE kl_vault_documents
  ADD COLUMN IF NOT EXISTS visibility        TEXT    NOT NULL DEFAULT 'personal'
    CHECK (visibility IN ('personal','org_shared','org_required')),
  ADD COLUMN IF NOT EXISTS org_id            UUID    REFERENCES organisations(id) ON DELETE SET NULL;

-- ── kl_report_history ────────────────────────────────────────────────────────
ALTER TABLE kl_report_history
  ADD COLUMN IF NOT EXISTS visibility        TEXT    NOT NULL DEFAULT 'personal'
    CHECK (visibility IN ('personal','org_shared','org_required')),
  ADD COLUMN IF NOT EXISTS org_id            UUID    REFERENCES organisations(id) ON DELETE SET NULL;

-- ── kl_account_profiles ──────────────────────────────────────────────────────
ALTER TABLE kl_account_profiles
  ADD COLUMN IF NOT EXISTS org_id            UUID    REFERENCES organisations(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS org_role          TEXT    CHECK (org_role IN ('member','admin')),
  ADD COLUMN IF NOT EXISTS loyalty_unlock_at TIMESTAMPTZ;

-- ── Indexes ──────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_kl_projects_org_visibility
  ON kl_projects (org_id, visibility) WHERE org_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_kl_vault_documents_org_visibility
  ON kl_vault_documents (org_id, visibility) WHERE org_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_kl_report_history_org_visibility
  ON kl_report_history (org_id, visibility) WHERE org_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_kl_account_profiles_org
  ON kl_account_profiles (org_id) WHERE org_id IS NOT NULL;

-- ── RLS policies (Section 6.4) — drop then recreate to be idempotent ─────────
DROP POLICY IF EXISTS kl_projects_org_read ON kl_projects;
CREATE POLICY kl_projects_org_read ON kl_projects FOR SELECT
  USING (
    org_id IS NOT NULL
    AND visibility IN ('org_shared','org_required')
    AND org_id = (
      SELECT org_id FROM kl_account_profiles
      WHERE user_id = auth.uid() LIMIT 1
    )
  );

DROP POLICY IF EXISTS kl_vault_documents_org_read ON kl_vault_documents;
CREATE POLICY kl_vault_documents_org_read ON kl_vault_documents FOR SELECT
  USING (
    org_id IS NOT NULL
    AND visibility IN ('org_shared','org_required')
    AND org_id = (
      SELECT org_id FROM kl_account_profiles
      WHERE user_id = auth.uid() LIMIT 1
    )
  );

DROP POLICY IF EXISTS kl_report_history_org_read ON kl_report_history;
CREATE POLICY kl_report_history_org_read ON kl_report_history FOR SELECT
  USING (
    org_id IS NOT NULL
    AND visibility IN ('org_shared','org_required')
    AND org_id = (
      SELECT org_id FROM kl_account_profiles
      WHERE user_id = auth.uid() LIMIT 1
    )
  );

-- ── Permanent-personal table comments (Section 6.4, Rule V-003) ──────────────
COMMENT ON TABLE kl_session_context IS
  'AUTH-001 V-003: permanently personal. No org access. SELECT WHERE user_id = auth.uid() only.';

COMMENT ON TABLE kl_practice_profiles IS
  'AUTH-001 V-003: permanently personal. No org access. SELECT WHERE user_id = auth.uid() only.';

