-- Migration: 20260323135001_forward_looking_intelligence_layer
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: forward_looking_intelligence_layer


-- ================================================================
-- AILANE — Forward-Looking Intelligence Layer
-- Architectural enhancement to compliance checker
-- Adds temporal dimension to regulatory requirements:
--   current law → standard compliance findings
--   future law → forward-looking exposure findings
-- Forward findings NEVER affect the current compliance score.
-- ================================================================

-- 1. Extend regulatory_requirements with temporal fields
ALTER TABLE public.regulatory_requirements
    ADD COLUMN IF NOT EXISTS effective_from date,
    ADD COLUMN IF NOT EXISTS source_act text,
    ADD COLUMN IF NOT EXISTS commencement_status text DEFAULT 'in_force'
        CHECK (commencement_status IN (
            'in_force',
            'commenced',
            'pending_commencement',
            'pending_consultation',
            'pending_si'
        )),
    ADD COLUMN IF NOT EXISTS commencement_note text,
    ADD COLUMN IF NOT EXISTS is_forward_requirement boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.regulatory_requirements.effective_from IS 'Date this requirement becomes enforceable. NULL = already in force (pre-existing law). Future date = forward-looking requirement.';
COMMENT ON COLUMN public.regulatory_requirements.source_act IS 'The Act that introduced this requirement (e.g., Employment Rights Act 2025, Equality Act 2010).';
COMMENT ON COLUMN public.regulatory_requirements.commencement_status IS 'Current commencement status: in_force (current law), commenced (recently commenced), pending_commencement (date known), pending_consultation (detail still being consulted on), pending_si (awaiting Statutory Instrument).';
COMMENT ON COLUMN public.regulatory_requirements.commencement_note IS 'Human-readable note about commencement timing, e.g., "Expected 1 January 2027 per Implementation Roadmap published 3 February 2026".';
COMMENT ON COLUMN public.regulatory_requirements.is_forward_requirement IS 'True if this requirement is based on legislation not yet in force. Forward requirements are assessed separately and do not affect the current compliance score.';

-- 2. Extend compliance_findings with forward-looking flag
ALTER TABLE public.compliance_findings
    ADD COLUMN IF NOT EXISTS is_forward_looking boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS forward_effective_date date,
    ADD COLUMN IF NOT EXISTS forward_source_act text;

COMMENT ON COLUMN public.compliance_findings.is_forward_looking IS 'True if this finding is based on legislation not yet in force. Forward-looking findings do NOT affect overall_score.';
COMMENT ON COLUMN public.compliance_findings.forward_effective_date IS 'The date the underlying requirement comes into force.';
COMMENT ON COLUMN public.compliance_findings.forward_source_act IS 'The source Act for forward-looking findings (e.g., Employment Rights Act 2025).';

-- Index for efficient forward/current separation in report generation
CREATE INDEX IF NOT EXISTS idx_cf_forward_looking 
    ON public.compliance_findings(upload_id, is_forward_looking);

-- 3. Set existing requirements as in_force (they predate ERA 2025)
UPDATE public.regulatory_requirements
SET commencement_status = 'in_force',
    is_forward_requirement = false,
    source_act = 'Employment Rights Act 1996'
WHERE effective_from IS NULL
AND source_act IS NULL;

