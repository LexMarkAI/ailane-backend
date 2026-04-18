-- Migration: 20260306021000_create_compliance_portal_sessions
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_compliance_portal_sessions


-- ── COMPLIANCE PORTAL SESSIONS ──────────────────────────────────────────────
-- Captures every visitor who completes the access gate on the compliance portal
-- Source documents are NEVER stored here — this table holds contact + metadata only
-- Retention: indefinite for contact records, findings_json purged after 30 days via scheduled job

CREATE TABLE IF NOT EXISTS compliance_portal_sessions (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at        timestamptz NOT NULL DEFAULT now(),

  -- Contact data (data capture value)
  name              text NOT NULL,
  email             text NOT NULL,
  company_name      text NOT NULL,
  job_title         text,

  -- Purchase context
  tier              text NOT NULL CHECK (tier IN ('flash', 'full')),
  stripe_session_id text,                    -- populated later when webhook wired

  -- Analysis lifecycle
  status            text NOT NULL DEFAULT 'gate_passed'
                    CHECK (status IN (
                      'gate_passed',         -- user passed gate, not yet uploaded
                      'uploaded',            -- documents received, analysis queued
                      'analysing',           -- analysis in progress
                      'complete',            -- report generated
                      'failed'               -- analysis failed
                    )),

  -- Report output (findings stored here, NOT the source document)
  report_ref        text UNIQUE,             -- e.g. ACP-20260306-123456
  report_generated_at timestamptz,
  findings_json     jsonb,                   -- full findings payload, purged after 30 days

  -- Source document audit (name only — no content ever stored)
  doc_contract_name text,
  doc_handbook_name text,
  doc_policies_name text,
  doc_deleted_at    timestamptz,             -- timestamp of document deletion confirmation

  -- GDPR compliance
  deletion_requested_at timestamptz,         -- if user exercises right to erasure
  deletion_completed_at timestamptz,

  -- Metadata
  source            text DEFAULT 'compliance_portal',
  ip_address        inet,
  user_agent        text
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_cps_email       ON compliance_portal_sessions(email);
CREATE INDEX IF NOT EXISTS idx_cps_company     ON compliance_portal_sessions(company_name);
CREATE INDEX IF NOT EXISTS idx_cps_created_at  ON compliance_portal_sessions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cps_status      ON compliance_portal_sessions(status);
CREATE INDEX IF NOT EXISTS idx_cps_report_ref  ON compliance_portal_sessions(report_ref);

-- Comment
COMMENT ON TABLE compliance_portal_sessions IS
  'Compliance portal access sessions. Stores contact data and analysis metadata only. '
  'Source documents are never persisted. findings_json subject to 30-day purge policy. '
  'Governed by Ailane Privacy Policy and UK GDPR. Created 2026-03-06.';

-- ── RLS ──────────────────────────────────────────────────────────────────────
ALTER TABLE compliance_portal_sessions ENABLE ROW LEVEL SECURITY;

-- Anon can INSERT only (portal writes on gate pass, no auth required)
CREATE POLICY "portal_insert" ON compliance_portal_sessions
  FOR INSERT TO anon
  WITH CHECK (true);

-- Authenticated users (service role / CEO dashboard) can read all
CREATE POLICY "service_read" ON compliance_portal_sessions
  FOR SELECT TO authenticated
  USING (true);

-- Service role can update (status transitions, report data, deletion timestamps)
CREATE POLICY "service_update" ON compliance_portal_sessions
  FOR UPDATE TO authenticated
  USING (true);

