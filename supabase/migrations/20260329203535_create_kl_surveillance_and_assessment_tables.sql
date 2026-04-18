-- Migration: 20260329203535_create_kl_surveillance_and_assessment_tables
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_kl_surveillance_and_assessment_tables


-- KLIA-001 §7.4: Surveillance alert detections
-- KLIA-001 §8.4: Eileen assessment drafts
-- KLIA-001 §10.2: Immutable update audit trail

CREATE TABLE public.kl_legislative_alerts (
    alert_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    detected_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    source TEXT NOT NULL,                  -- Source system e.g. legislation.gov.uk, bailii.org
    source_url TEXT NOT NULL,              -- Direct URL to the detected change
    alert_class INTEGER NOT NULL CHECK (alert_class BETWEEN 1 AND 5),
    alert_type TEXT NOT NULL,              -- e.g. instrument_amendment, commencement_order, case_law_new, guidance_update
    affected_instrument_id TEXT,           -- Content file ID e.g. era1996. NULL if new instrument
    affected_sections TEXT[] DEFAULT '{}', -- Section identifiers affected e.g. ["s.108","s.112"]
    title TEXT NOT NULL,                   -- Title of the detected change
    summary TEXT,                          -- Auto-generated summary
    raw_content JSONB,                     -- Raw API response or scraped content
    status TEXT NOT NULL DEFAULT 'pending_assessment'
        CHECK (status IN ('pending_assessment','eileen_assessing','assessment_complete',
                          'ratification_pending','ratified','rejected','deferred')),
    eileen_assessment_id UUID,             -- FK to kl_update_drafts (set after assessment)
    sla_deadline TIMESTAMPTZ,              -- Calculated from alert_class
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.kl_update_drafts (
    draft_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    alert_id UUID NOT NULL REFERENCES public.kl_legislative_alerts(alert_id),
    affected_file_id TEXT NOT NULL,        -- Content file identifier e.g. era1996
    affected_sections TEXT[] DEFAULT '{}',
    current_content JSONB,                 -- Snapshot of current content at assessment time
    proposed_content JSONB,                -- Proposed replacement conforming to KLIA-001 schema
    change_classification TEXT NOT NULL
        CHECK (change_classification IN ('text_correction','amendment_in_force','case_law_update',
                                          'guidance_update','rate_update','commencement_update')),
    acei_impact JSONB,                     -- { categories, direction, magnitude, rationale }
    eileen_confidence NUMERIC(3,2),        -- 0.00-1.00, below 0.80 flagged for extra review
    eileen_summary TEXT NOT NULL,          -- Plain English for CEO review, max 500 words
    source_citations JSONB,                -- Array of { source, url, retrieved_at }
    status TEXT NOT NULL DEFAULT 'awaiting_ratification'
        CHECK (status IN ('awaiting_ratification','ratified','rejected','referred_back','deferred')),
    ratification_notes TEXT,
    ratified_at TIMESTAMPTZ,
    ratified_by TEXT,
    deployed_at TIMESTAMPTZ,
    amd_entry TEXT,                         -- AMD-REG entry number on ratification
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.kl_update_history (
    history_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    draft_id UUID NOT NULL REFERENCES public.kl_update_drafts(draft_id),
    instrument_id TEXT NOT NULL,
    sections_updated TEXT[] DEFAULT '{}',
    deployed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    amd_entry TEXT,                         -- AMD-REG entry number
    commit_url TEXT,                        -- GitHub commit URL
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Add deferred FK from kl_legislative_alerts to kl_update_drafts
ALTER TABLE public.kl_legislative_alerts
    ADD CONSTRAINT fk_alerts_assessment
    FOREIGN KEY (eileen_assessment_id) REFERENCES public.kl_update_drafts(draft_id);

-- Indexes
CREATE INDEX idx_kl_alerts_class ON public.kl_legislative_alerts(alert_class);
CREATE INDEX idx_kl_alerts_status ON public.kl_legislative_alerts(status);
CREATE INDEX idx_kl_alerts_instrument ON public.kl_legislative_alerts(affected_instrument_id);
CREATE INDEX idx_kl_drafts_status ON public.kl_update_drafts(status);
CREATE INDEX idx_kl_drafts_alert ON public.kl_update_drafts(alert_id);
CREATE INDEX idx_kl_history_instrument ON public.kl_update_history(instrument_id);

COMMENT ON TABLE public.kl_legislative_alerts IS 'KLIA-001 §7.4: All surveillance detections from ALSF Layer 1.';
COMMENT ON TABLE public.kl_update_drafts IS 'KLIA-001 §8.4: Eileen assessment drafts awaiting CEO ratification.';
COMMENT ON TABLE public.kl_update_history IS 'KLIA-001 §10.2: Immutable audit trail of every deployed KL update.';

