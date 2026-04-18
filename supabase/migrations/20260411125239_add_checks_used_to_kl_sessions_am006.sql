-- Migration: 20260411125239_add_checks_used_to_kl_sessions_am006
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: add_checks_used_to_kl_sessions_am006

-- KLAC-001-AM-006 §7.5: Add checks_used column to kl_sessions
-- Tracks Contract Compliance Checks consumed within a KL session
ALTER TABLE kl_sessions ADD COLUMN checks_used INTEGER NOT NULL DEFAULT 0;

COMMENT ON COLUMN kl_sessions.checks_used IS 'Number of Contract Compliance Checks consumed in this session. Allowance derived from product_type: kl_quick_session=1, kl_day_pass=2, kl_research_week=3. Per KLAC-001-AM-006 (AMD-043).';
