-- Migration: 20260313233125_qai_002_complaint_log
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: qai_002_complaint_log

CREATE TABLE IF NOT EXISTS public.complaint_log (
  id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id                      UUID REFERENCES public.organisations(id),
  session_id                  UUID REFERENCES public.compliance_portal_sessions(id),
  stripe_payment_intent_id    TEXT,
  clause_disputed             TEXT NOT NULL,
  alleged_miss_description    TEXT NOT NULL,
  submitted_at                TIMESTAMPTZ DEFAULT NOW(),
  discovery_date              DATE NOT NULL,
  signal_grounded_at_scan     BOOLEAN,
  pipeline_alerted_at         TIMESTAMPTZ,
  complaint_window_type       TEXT CHECK (
    complaint_window_type IN (
      'contemporaneous',
      'post_scan_pipeline_miss',
      'pipeline_failure'
    )
  ),
  window_valid                BOOLEAN,
  validation_status           TEXT CHECK (
    validation_status IN (
      'pending',
      'failure_mode_a',
      'failure_mode_b_confirmed',
      'not_upheld',
      'moot'
    )
  ),
  failure_mode_classification  TEXT,
  gpt4_invoked                BOOLEAN DEFAULT FALSE,
  gpt4_finding                TEXT,
  refund_triggered            BOOLEAN DEFAULT FALSE,
  refund_amount_pence         INTEGER,
  stripe_refund_id            TEXT,
  resolved_at                 TIMESTAMPTZ,
  resolution_notes            TEXT,
  created_at                  TIMESTAMPTZ DEFAULT NOW(),
  updated_at                  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.complaint_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "complaint_log_org_read"
  ON public.complaint_log
  FOR SELECT
  USING (
    org_id = (
      SELECT org_id FROM public.app_users
      WHERE id = auth.uid()
      LIMIT 1
    )
  );

CREATE POLICY "complaint_log_service_all"
  ON public.complaint_log
  FOR ALL
  USING (auth.role() = 'service_role');

COMMENT ON TABLE public.complaint_log
IS 'QAI-001 §7 and §10: Complaint and quality dispute records. Three-timestamp framework. 7-year retention per Privacy Policy. Auto-refund trigger on Failure Mode B for Flash/Full Check products.';
