-- Migration: 20260413014928_eileen_007_presales_tables
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: eileen_007_presales_tables


-- EILEEN-007 Database Migration (AMD-046)
-- Tables: eileen_presales_conversations, eileen_presales_compliance_log
-- Governing spec: AILANE-SPEC-EILEEN-007 v1.0

-- ============================================================
-- TABLE 1: eileen_presales_conversations
-- ============================================================

CREATE TABLE IF NOT EXISTS public.eileen_presales_conversations (
    conversation_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    page_source TEXT NOT NULL CHECK (page_source IN ('main', 'kl-access')),
    visitor_hash TEXT NOT NULL,
    section_at_first_interaction TEXT,
    messages JSONB NOT NULL DEFAULT '[]'::jsonb,
    message_count INTEGER NOT NULL DEFAULT 0,
    conversation_duration_seconds INTEGER DEFAULT 0,
    outcome TEXT CHECK (outcome IS NULL OR outcome IN (
        'checkout_initiated',
        'session_purchased',
        'subscription_started'
    )),
    product_purchased TEXT,
    satisfaction_signal TEXT CHECK (satisfaction_signal IS NULL OR satisfaction_signal IN (
        'positive',
        'negative'
    )),
    prompt_version TEXT NOT NULL DEFAULT 'v1',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_epc_visitor_hash_created 
    ON public.eileen_presales_conversations (visitor_hash, created_at DESC);

CREATE INDEX idx_epc_page_source_created 
    ON public.eileen_presales_conversations (page_source, created_at DESC);

CREATE INDEX idx_epc_outcome 
    ON public.eileen_presales_conversations (outcome) 
    WHERE outcome IS NOT NULL;

ALTER TABLE public.eileen_presales_conversations ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.eileen_presales_conversations IS 
    'EILEEN-007 §8.1 — Anonymous pre-sales conversation logs for conversion intelligence. Visitor hash is one-way SHA-256. Messages JSONB is PII-redacted server-side.';

-- ============================================================
-- TABLE 2: eileen_presales_compliance_log
-- ============================================================

CREATE TABLE IF NOT EXISTS public.eileen_presales_compliance_log (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID REFERENCES public.eileen_presales_conversations(conversation_id) ON DELETE SET NULL,
    prompt_version TEXT NOT NULL,
    failure_type TEXT NOT NULL CHECK (failure_type IN (
        'banned_phrase',
        'advisory_language',
        'missing_disclaimer',
        'missing_contextual',
        'adversarial_attempt'
    )),
    blocked_response TEXT NOT NULL,
    matched_phrase TEXT,
    visitor_hash TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_epcl_prompt_version_created 
    ON public.eileen_presales_compliance_log (prompt_version, created_at DESC);

CREATE INDEX idx_epcl_failure_type 
    ON public.eileen_presales_compliance_log (failure_type, created_at DESC);

ALTER TABLE public.eileen_presales_compliance_log ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.eileen_presales_compliance_log IS 
    'EILEEN-007 §7.6.3 — Compliance log for output verification failures. Records every blocked response for CEO review.';

