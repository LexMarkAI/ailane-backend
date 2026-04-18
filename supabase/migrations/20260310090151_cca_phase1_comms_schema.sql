-- Migration: 20260310090151_cca_phase1_comms_schema
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: cca_phase1_comms_schema


-- Create comms schema
CREATE SCHEMA IF NOT EXISTS comms;

-- Master interactions log
CREATE TABLE comms.interactions (
  id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_org_id             UUID REFERENCES organisations(id) ON DELETE SET NULL,
  tier                      TEXT NOT NULL CHECK (tier IN ('scan','operational','governance','institutional')),
  channel                   TEXT NOT NULL CHECK (channel IN ('in_platform','email','outbound_alert','feedback')),
  layer_resolved            INTEGER CHECK (layer_resolved IN (1,2,3)),
  query_category            TEXT CHECK (query_category IN (
    'score_interpretation','compliance_finding','legislative',
    'product_guidance','billing','complaint','feature_request','other')),
  query_text                TEXT,
  response_text             TEXT,
  ai_confidence             NUMERIC(4,3) CHECK (ai_confidence BETWEEN 0 AND 1),
  satisfaction_signal       TEXT CHECK (satisfaction_signal IN ('helpful','partial','not_helpful','no_response')),
  escalation_reason         TEXT,
  disclaimer_applied        BOOLEAN DEFAULT FALSE,
  follow_up_within_24h      BOOLEAN DEFAULT FALSE,
  preferred_language        TEXT DEFAULT 'en',
  resolution_time_ms        INTEGER,
  constitutional_clauses    TEXT[],
  created_at                TIMESTAMPTZ DEFAULT NOW()
);

-- Layer 2 triage queue
CREATE TABLE comms.triage_queue (
  id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  interaction_id            UUID REFERENCES comms.interactions(id) ON DELETE CASCADE,
  client_org_id             UUID REFERENCES organisations(id) ON DELETE SET NULL,
  tier                      TEXT,
  priority                  TEXT NOT NULL CHECK (priority IN ('P1','P2','P3')),
  interaction_summary       TEXT,
  ai_analysis               TEXT,
  constitutional_position   TEXT,
  drafted_response          TEXT,
  alternative_response      TEXT,
  recommended_action        TEXT CHECK (recommended_action IN ('approve','edit','escalate')),
  status                    TEXT DEFAULT 'pending' CHECK (status IN ('pending','approved','edited','escalated','dismissed')),
  mark_notes                TEXT,
  preferred_language        TEXT DEFAULT 'en',
  created_at                TIMESTAMPTZ DEFAULT NOW(),
  actioned_at               TIMESTAMPTZ
);

-- Layer 3 escalations
CREATE TABLE comms.escalations (
  id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  triage_id                 UUID REFERENCES comms.triage_queue(id) ON DELETE SET NULL,
  client_org_id             UUID REFERENCES organisations(id) ON DELETE SET NULL,
  briefing                  TEXT,
  recommended_action        TEXT,
  status                    TEXT DEFAULT 'open' CHECK (status IN ('open','in_progress','resolved')),
  resolution_notes          TEXT,
  created_at                TIMESTAMPTZ DEFAULT NOW(),
  resolved_at               TIMESTAMPTZ
);

-- Feedback signals
CREATE TABLE comms.feedback_signals (
  id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  interaction_id            UUID REFERENCES comms.interactions(id) ON DELETE SET NULL,
  client_org_id             UUID REFERENCES organisations(id) ON DELETE SET NULL,
  signal_type               TEXT CHECK (signal_type IN ('rating','issue_flag','exit_survey','follow_up')),
  rating                    TEXT CHECK (rating IN ('helpful','partial','not_helpful')),
  issue_description         TEXT,
  processed                 BOOLEAN DEFAULT FALSE,
  created_at                TIMESTAMPTZ DEFAULT NOW()
);

-- RLS
ALTER TABLE comms.interactions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE comms.triage_queue      ENABLE ROW LEVEL SECURITY;
ALTER TABLE comms.escalations       ENABLE ROW LEVEL SECURITY;
ALTER TABLE comms.feedback_signals  ENABLE ROW LEVEL SECURITY;

-- Clients can only read their own interaction history
CREATE POLICY "clients_own_interactions" ON comms.interactions
  FOR SELECT USING (client_org_id = get_my_org_id());

-- Clients can insert their own interactions and feedback
CREATE POLICY "clients_insert_interactions" ON comms.interactions
  FOR INSERT WITH CHECK (client_org_id = get_my_org_id());

CREATE POLICY "clients_insert_feedback" ON comms.feedback_signals
  FOR INSERT WITH CHECK (client_org_id = get_my_org_id());

-- Triage, escalations: service role only (no client access)
CREATE POLICY "service_only_triage" ON comms.triage_queue
  FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "service_only_escalations" ON comms.escalations
  FOR ALL USING (auth.role() = 'service_role');

