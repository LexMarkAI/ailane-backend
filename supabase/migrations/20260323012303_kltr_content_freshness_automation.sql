-- Migration: 20260323012303_kltr_content_freshness_automation
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: kltr_content_freshness_automation


-- ═══════════════════════════════════════════════════════════════
-- KLTR-001 — Content Freshness Automation Layer
-- Automatic periodic review detection and staleness flagging
-- Constitutional separation maintained: this system monitors
-- content currency only — it never modifies ACEI/RRI/CCI scores
-- ═══════════════════════════════════════════════════════════════

-- ────────────────────────────────────────────────────────────────
-- TABLE: kl_content_review_log
-- Tracks every review cycle and content update event
-- ────────────────────────────────────────────────────────────────
CREATE TABLE public.kl_content_review_log (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    resource_id     uuid NOT NULL REFERENCES public.kl_training_resources(id) ON DELETE CASCADE,
    review_type     text NOT NULL CHECK (review_type IN (
                        'scheduled_check',    -- Automated periodic check
                        'legislative_trigger', -- Triggered by legislation change
                        'case_law_trigger',   -- Triggered by significant tribunal/court decision
                        'manual_review',      -- CEO/editor initiated
                        'content_update'      -- Actual content was updated
                    )),
    trigger_source  text,                     -- e.g., 'ERA 1996 amendment', 'Supreme Court decision', 'annual review cycle'
    previous_version text,
    new_version     text,
    changes_summary text,                     -- Human-readable description of what changed
    reviewed_by     text NOT NULL DEFAULT 'system',
    status          text NOT NULL DEFAULT 'pending' CHECK (status IN (
                        'pending',            -- Review identified but not yet actioned
                        'current',            -- Content confirmed still current
                        'update_required',    -- Content needs updating
                        'updated',            -- Content has been updated
                        'superseded'          -- Content replaced by new resource
                    )),
    created_at      timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.kl_content_review_log IS
    'KLTR-001: Content freshness audit trail. Records every automated and manual review cycle. Constitutional separation: review system monitors content currency only — never modifies ACEI/RRI/CCI scoring pathway.';

-- Indexes for efficient querying
CREATE INDEX idx_kl_crl_resource ON public.kl_content_review_log(resource_id);
CREATE INDEX idx_kl_crl_status ON public.kl_content_review_log(status) WHERE status IN ('pending', 'update_required');
CREATE INDEX idx_kl_crl_created ON public.kl_content_review_log(created_at DESC);

-- RLS
ALTER TABLE public.kl_content_review_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "kl_crl_service_manage" ON public.kl_content_review_log
    FOR ALL TO service_role
    USING (true) WITH CHECK (true);

CREATE POLICY "kl_crl_read_authenticated" ON public.kl_content_review_log
    FOR SELECT TO authenticated
    USING (true);

-- ────────────────────────────────────────────────────────────────
-- Add freshness tracking columns to kl_training_resources
-- ────────────────────────────────────────────────────────────────
ALTER TABLE public.kl_training_resources
    ADD COLUMN IF NOT EXISTS last_reviewed_at timestamptz,
    ADD COLUMN IF NOT EXISTS next_review_due timestamptz,
    ADD COLUMN IF NOT EXISTS review_frequency_days integer NOT NULL DEFAULT 90,
    ADD COLUMN IF NOT EXISTS freshness_status text NOT NULL DEFAULT 'current' CHECK (freshness_status IN (
        'current',           -- Content confirmed up to date
        'review_due',        -- Scheduled review period reached
        'update_required',   -- Legislative or case law change detected
        'stale'              -- Overdue for review (>30 days past due)
    )),
    ADD COLUMN IF NOT EXISTS legislation_watch_keys text[] DEFAULT '{}';

COMMENT ON COLUMN public.kl_training_resources.review_frequency_days IS
    'Days between scheduled freshness reviews. Default 90 (quarterly). Configurable per resource based on legislative volatility.';
COMMENT ON COLUMN public.kl_training_resources.legislation_watch_keys IS
    'Array of legislation identifiers this resource monitors. When the platform detects changes to these instruments, the resource is flagged for review. E.g., {ERA_1996_PART_X, ACAS_COP_DISCIPLINARY}';
COMMENT ON COLUMN public.kl_training_resources.freshness_status IS
    'Automated freshness status. System sets to review_due when next_review_due passes. System sets to stale if 30+ days overdue. Manual or AI review resets to current.';

-- ────────────────────────────────────────────────────────────────
-- Set initial review dates and watch keys for all 12 guides
-- ────────────────────────────────────────────────────────────────
UPDATE public.kl_training_resources SET
    last_reviewed_at = now(),
    next_review_due = now() + interval '90 days',
    review_frequency_days = 90
WHERE content_type = 'written_guide';

-- Set legislation watch keys per guide
UPDATE public.kl_training_resources SET legislation_watch_keys = ARRAY['ERA_1996_PART_X', 'ACAS_COP_DISCIPLINARY', 'ACAS_COP_GRIEVANCE']
WHERE slug = 'guide-unfair-dismissal-exposure';

UPDATE public.kl_training_resources SET legislation_watch_keys = ARRAY['EA_2010', 'EA_2010_COP_EMPLOYMENT', 'EA_2010_COP_EQUAL_PAY', 'EHRC_TECHNICAL_GUIDANCE']
WHERE slug = 'guide-discrimination-employer-obligations';

UPDATE public.kl_training_resources SET legislation_watch_keys = ARRAY['HSWA_1974', 'MHSWR_1999', 'HSE_ACoP_SERIES', 'RIDDOR_2013']
WHERE slug = 'guide-health-safety-employer-obligations';

UPDATE public.kl_training_resources SET legislation_watch_keys = ARRAY['ERA_1996_PART_II', 'NMWA_1998', 'NMW_REGS_2015', 'WTR_1998_REG_14_16']
WHERE slug = 'guide-wages-deductions-framework';

UPDATE public.kl_training_resources SET legislation_watch_keys = ARRAY['WTR_1998', 'WTR_AMENDMENT_2003', 'WTD_2003_88_EC']
WHERE slug = 'guide-working-time-compliance';

UPDATE public.kl_training_resources SET legislation_watch_keys = ARRAY['ERA_1996_PART_IVA', 'PIDA_1998', 'ERRA_2013_S17', 'PRESCRIBED_PERSONS_ORDER_2014']
WHERE slug = 'guide-whistleblowing-protection';

UPDATE public.kl_training_resources SET legislation_watch_keys = ARRAY['EA_2010_CH3', 'EA_2010_S77', 'EA_2010_S78', 'GPGI_REGS_2017']
WHERE slug = 'guide-equal-pay-obligations';

UPDATE public.kl_training_resources SET legislation_watch_keys = ARRAY['TUPE_2006', 'TUPE_AMENDMENT_2014', 'PENSIONS_ACT_2004_S257']
WHERE slug = 'guide-tupe-workforce-change';

UPDATE public.kl_training_resources SET legislation_watch_keys = ARRAY['UK_GDPR', 'DPA_2018', 'ICO_EMPLOYMENT_CODE', 'PECR_2003']
WHERE slug = 'guide-data-protection-employment';

UPDATE public.kl_training_resources SET legislation_watch_keys = ARRAY['ERA_1996_PART_VIII', 'MPLR_1999', 'PALR_2002', 'SPLR_2014', 'FLEXIBLE_WORKING_ACT_2023', 'REDUNDANCY_PREGNANCY_ACT_2023']
WHERE slug = 'guide-parental-rights-entitlements';

UPDATE public.kl_training_resources SET legislation_watch_keys = ARRAY['TULRCA_1992', 'ERA_1999', 'TUA_2016', 'BLACKLISTS_REGS_2010']
WHERE slug = 'guide-trade-union-rights';

UPDATE public.kl_training_resources SET legislation_watch_keys = ARRAY['ERA_1996_S1', 'ERA_1996_S95', 'ETEJO_1994', 'ACAS_COP_FIRE_REHIRE_2024']
WHERE slug = 'guide-contractual-disputes';

-- ────────────────────────────────────────────────────────────────
-- CRON FUNCTION: Automated freshness scanner
-- Runs daily, flags resources due for review
-- ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.kltr_freshness_scan()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    r RECORD;
BEGIN
    -- Flag resources where review is due
    FOR r IN 
        SELECT id, title, next_review_due
        FROM public.kl_training_resources
        WHERE is_published = true
          AND next_review_due IS NOT NULL
          AND next_review_due <= now()
          AND freshness_status = 'current'
    LOOP
        -- Update status to review_due
        UPDATE public.kl_training_resources
        SET freshness_status = 'review_due',
            updated_at = now()
        WHERE id = r.id;
        
        -- Log the scheduled check
        INSERT INTO public.kl_content_review_log (
            resource_id, review_type, trigger_source,
            reviewed_by, status
        ) VALUES (
            r.id, 'scheduled_check',
            'Quarterly review cycle — next_review_due reached ' || r.next_review_due::text,
            'system', 'pending'
        );
    END LOOP;
    
    -- Escalate to stale if 30+ days overdue
    UPDATE public.kl_training_resources
    SET freshness_status = 'stale',
        updated_at = now()
    WHERE freshness_status = 'review_due'
      AND next_review_due < now() - interval '30 days';
END;
$$;

COMMENT ON FUNCTION public.kltr_freshness_scan IS
    'KLTR-001: Daily automated freshness scanner. Flags published resources for review when their next_review_due date passes. Escalates to stale after 30 days overdue. Constitutional separation: never touches ACEI/RRI/CCI.';

-- ────────────────────────────────────────────────────────────────
-- CRON FUNCTION: Legislative change detector stub
-- Called when legislation_library instruments are updated
-- Cross-references watch keys to flag affected training resources
-- ────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.kltr_legislation_change_detector(
    changed_instrument_key text,
    change_description text DEFAULT 'Legislative instrument updated'
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    affected_count integer := 0;
    r RECORD;
BEGIN
    FOR r IN
        SELECT id, title
        FROM public.kl_training_resources
        WHERE changed_instrument_key = ANY(legislation_watch_keys)
          AND freshness_status IN ('current', 'review_due')
    LOOP
        UPDATE public.kl_training_resources
        SET freshness_status = 'update_required',
            updated_at = now()
        WHERE id = r.id;
        
        INSERT INTO public.kl_content_review_log (
            resource_id, review_type, trigger_source,
            reviewed_by, status
        ) VALUES (
            r.id, 'legislative_trigger',
            change_description || ' [key: ' || changed_instrument_key || ']',
            'system', 'update_required'
        );
        
        affected_count := affected_count + 1;
    END LOOP;
    
    RETURN affected_count;
END;
$$;

COMMENT ON FUNCTION public.kltr_legislation_change_detector IS
    'KLTR-001: Callable when any legislative instrument is updated. Cross-references the changed instrument key against all training resource watch keys and flags affected resources for content update. Returns count of affected resources.';

-- ────────────────────────────────────────────────────────────────
-- Schedule the daily freshness scan via pg_cron
-- ────────────────────────────────────────────────────────────────
SELECT cron.schedule(
    'kltr-daily-freshness-scan',
    '0 4 * * *',  -- 04:00 UTC daily (after kl_vault_cleanup at 03:00)
    $$SELECT public.kltr_freshness_scan()$$
);

