-- Migration: 20260313233110_qai_001_stripe_payment_intent_id
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: qai_001_stripe_payment_intent_id

ALTER TABLE public.compliance_portal_sessions
ADD COLUMN IF NOT EXISTS stripe_payment_intent_id TEXT;

COMMENT ON COLUMN public.compliance_portal_sessions.stripe_payment_intent_id
IS 'QAI-001: Links scan session to Stripe charge for automatic refund trigger on Failure Mode B.';
