-- Migration: 20260323102926_kl_horizon_tracking_infrastructure
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: kl_horizon_tracking_infrastructure


-- ================================================================
-- AILANE — Legislative Horizon: Automated Tracking Infrastructure
-- Pending: AILANE-SPEC-KLTR-001-AM-001
-- Adds: parliament_bill_id for API tracking
--        kl_horizon_tracking_log for full audit trail
--        kl_horizon_si_watch for statutory instrument monitoring
--        kl_horizon_bill_keywords for new bill detection
-- ================================================================

-- 1. Add parliament_bill_id to kl_legislative_horizon for Bills API tracking
ALTER TABLE public.kl_legislative_horizon
    ADD COLUMN IF NOT EXISTS parliament_bill_id integer,
    ADD COLUMN IF NOT EXISTS legislation_gov_uk_id text,
    ADD COLUMN IF NOT EXISTS auto_tracked boolean NOT NULL DEFAULT false,
    ADD COLUMN IF NOT EXISTS last_api_response jsonb;

COMMENT ON COLUMN public.kl_legislative_horizon.parliament_bill_id IS 'Parliament Bills API bill ID (e.g. 3737 for Employment Rights Bill). Used by horizon-bill-tracker for automated stage monitoring.';
COMMENT ON COLUMN public.kl_legislative_horizon.legislation_gov_uk_id IS 'legislation.gov.uk identifier (e.g. ukpga/2024/19). Used by horizon-si-monitor for commencement order tracking.';
COMMENT ON COLUMN public.kl_legislative_horizon.auto_tracked IS 'True if this entry is automatically monitored by horizon pipeline functions.';
COMMENT ON COLUMN public.kl_legislative_horizon.last_api_response IS 'Cached last API response for debugging and audit purposes.';

-- Set the Employment Rights Bill parliament_bill_id
UPDATE public.kl_legislative_horizon
SET parliament_bill_id = 3737,
    auto_tracked = true,
    updated_at = now()
WHERE legislation_short_name = 'Employment Rights Bill';

-- 2. Tracking log — complete audit trail of every automated check and change
CREATE TABLE public.kl_horizon_tracking_log (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- What was checked
    tracker_type    text NOT NULL CHECK (tracker_type IN (
        'bill_stage_check', 'bill_stage_change',
        'si_scan', 'si_new_detected',
        'new_bill_scan', 'new_bill_detected',
        'manual_update',
        'error'
    )),
    
    -- References
    horizon_id      uuid REFERENCES public.kl_legislative_horizon(id),
    
    -- What happened
    previous_value  text,
    new_value       text,
    detail          jsonb DEFAULT '{}',
    
    -- API source
    api_source      text,
    api_endpoint    text,
    api_response_status integer,
    
    -- Metadata
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_htl_type ON public.kl_horizon_tracking_log(tracker_type);
CREATE INDEX idx_htl_horizon ON public.kl_horizon_tracking_log(horizon_id) WHERE horizon_id IS NOT NULL;
CREATE INDEX idx_htl_created ON public.kl_horizon_tracking_log(created_at DESC);

COMMENT ON TABLE public.kl_horizon_tracking_log IS 'Complete audit trail for Legislative Horizon automated tracking. Every API check, stage change, new SI detection, and new bill detection is logged here.';

ALTER TABLE public.kl_horizon_tracking_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY kl_htl_service_manage
    ON public.kl_horizon_tracking_log
    FOR ALL
    USING (auth.role() = 'service_role');

-- 3. SI watch list — maps enacted legislation to SI search terms
CREATE TABLE public.kl_horizon_si_watch (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- What to watch
    act_title       text NOT NULL,
    act_year        integer NOT NULL,
    legislation_gov_uk_type text NOT NULL DEFAULT 'ukpga',
    search_keywords text[] NOT NULL DEFAULT '{}',
    
    -- Link to horizon entry
    horizon_id      uuid REFERENCES public.kl_legislative_horizon(id),
    
    -- Tracking
    last_checked_at timestamptz,
    last_si_found   text,
    is_active       boolean NOT NULL DEFAULT true,
    
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.kl_horizon_si_watch IS 'Statutory Instrument watch list. Maps enacted legislation to search terms for monitoring commencement orders, amendments, and secondary legislation on legislation.gov.uk.';

ALTER TABLE public.kl_horizon_si_watch ENABLE ROW LEVEL SECURITY;

CREATE POLICY kl_hsw_service_manage
    ON public.kl_horizon_si_watch
    FOR ALL
    USING (auth.role() = 'service_role');

-- 4. New bill detection keywords — employment law relevance signals
CREATE TABLE public.kl_horizon_bill_keywords (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    
    keyword         text NOT NULL UNIQUE,
    category        text NOT NULL,
    weight          integer NOT NULL DEFAULT 1,
    is_active       boolean NOT NULL DEFAULT true,
    
    created_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.kl_horizon_bill_keywords IS 'Keywords used by horizon-new-bill-scanner to identify employment-law-relevant bills. Higher weight = stronger signal of relevance.';

ALTER TABLE public.kl_horizon_bill_keywords ENABLE ROW LEVEL SECURITY;

CREATE POLICY kl_hbk_service_manage
    ON public.kl_horizon_bill_keywords
    FOR ALL
    USING (auth.role() = 'service_role');

-- Populate with employment law detection keywords
INSERT INTO public.kl_horizon_bill_keywords (keyword, category, weight) VALUES
    ('employment', 'primary', 5),
    ('worker', 'primary', 4),
    ('employee', 'primary', 4),
    ('trade union', 'primary', 4),
    ('dismissal', 'primary', 4),
    ('redundancy', 'primary', 4),
    ('discrimination', 'primary', 4),
    ('equality', 'primary', 3),
    ('maternity', 'primary', 3),
    ('paternity', 'primary', 3),
    ('parental', 'primary', 3),
    ('flexible working', 'primary', 3),
    ('minimum wage', 'primary', 3),
    ('sick pay', 'primary', 3),
    ('health and safety', 'primary', 3),
    ('whistleblowing', 'primary', 3),
    ('data protection', 'primary', 3),
    ('TUPE', 'primary', 3),
    ('industrial action', 'secondary', 2),
    ('collective bargaining', 'secondary', 2),
    ('working time', 'secondary', 2),
    ('zero hours', 'secondary', 2),
    ('gig economy', 'secondary', 2),
    ('agency worker', 'secondary', 2),
    ('tribunal', 'secondary', 2),
    ('ACAS', 'secondary', 2),
    ('workplace', 'secondary', 1),
    ('labour market', 'secondary', 1),
    ('pay gap', 'secondary', 2),
    ('harassment', 'secondary', 2),
    ('neonatal', 'secondary', 2),
    ('carer leave', 'secondary', 2),
    ('fire and rehire', 'secondary', 3),
    ('insolvency', 'secondary', 1),
    ('contract of employment', 'primary', 3);

