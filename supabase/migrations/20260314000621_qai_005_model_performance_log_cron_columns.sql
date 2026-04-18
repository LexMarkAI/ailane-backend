-- Migration: 20260314000621_qai_005_model_performance_log_cron_columns
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: qai_005_model_performance_log_cron_columns

ALTER TABLE public.model_performance_log
ADD COLUMN IF NOT EXISTS total_sessions       INTEGER,
ADD COLUMN IF NOT EXISTS critical_count       INTEGER,
ADD COLUMN IF NOT EXISTS major_count          INTEGER,
ADD COLUMN IF NOT EXISTS minor_count          INTEGER,
ADD COLUMN IF NOT EXISTS severity_distribution JSONB,
ADD COLUMN IF NOT EXISTS complaint_volume     INTEGER,
ADD COLUMN IF NOT EXISTS failure_mode_b_count INTEGER,
ADD COLUMN IF NOT EXISTS computed_at          TIMESTAMPTZ;

COMMENT ON COLUMN public.model_performance_log.total_sessions
IS 'QAI-001: Total compliance scan sessions in the audit week.';
COMMENT ON COLUMN public.model_performance_log.critical_count
IS 'QAI-001: Critical findings surfaced this week.';
COMMENT ON COLUMN public.model_performance_log.major_count
IS 'QAI-001: Major findings surfaced this week.';
COMMENT ON COLUMN public.model_performance_log.minor_count
IS 'QAI-001: Minor findings surfaced this week.';
COMMENT ON COLUMN public.model_performance_log.severity_distribution
IS 'QAI-001: JSON breakdown {critical_pct, major_pct, minor_pct} as percentages.';
COMMENT ON COLUMN public.model_performance_log.complaint_volume
IS 'QAI-001: Total complaints submitted this week.';
COMMENT ON COLUMN public.model_performance_log.failure_mode_b_count
IS 'QAI-001: Confirmed Failure Mode B events this week. Drives under_critical_rate.';
COMMENT ON COLUMN public.model_performance_log.computed_at
IS 'QAI-001: Timestamp when the cron audit ran.';
