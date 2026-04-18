-- Migration: 20260313234629_qai_004_finding_feedback_client_columns
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: qai_004_finding_feedback_client_columns

-- Add session_id for client-submitted severity-band feedback
ALTER TABLE public.finding_feedback
ADD COLUMN IF NOT EXISTS session_id UUID REFERENCES public.compliance_portal_sessions(id);

-- Add feedback_source to distinguish client feedback from internal QA pipeline
ALTER TABLE public.finding_feedback
ADD COLUMN IF NOT EXISTS feedback_source TEXT DEFAULT 'internal';

-- Relax NOT NULL constraints so client feedback rows can omit internal QA fields
ALTER TABLE public.finding_feedback ALTER COLUMN finding_id DROP NOT NULL;
ALTER TABLE public.finding_feedback ALTER COLUMN upload_id DROP NOT NULL;
ALTER TABLE public.finding_feedback ALTER COLUMN confidence DROP NOT NULL;
ALTER TABLE public.finding_feedback ALTER COLUMN is_training_candidate DROP NOT NULL;

COMMENT ON COLUMN public.finding_feedback.session_id
IS 'QAI-001: Compliance portal session ID for client-submitted severity-band feedback.';

COMMENT ON COLUMN public.finding_feedback.feedback_source
IS 'QAI-001: "client" = thumbs up/down from scan UI. "internal" = internal QA pipeline verification.';
