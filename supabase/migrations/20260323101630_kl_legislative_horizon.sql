-- Migration: 20260323101630_kl_legislative_horizon
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: kl_legislative_horizon


-- ================================================================
-- AILANE — Legislative Horizon: Proactive Change Intelligence
-- Pending: AILANE-SPEC-KLTR-001-AM-001
-- Maps pending legislation to training resources with impact
-- analysis and recommended preparatory steps.
-- ================================================================

CREATE TABLE public.kl_legislative_horizon (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Legislation identification
    legislation_title       text NOT NULL,
    legislation_short_name  text NOT NULL,
    legislation_type        text NOT NULL CHECK (legislation_type IN (
        'bill', 'statutory_instrument', 'commencement_order',
        'consultation', 'code_of_practice', 'eu_retained_amendment'
    )),
    parliament_stage        text,
    expected_enactment      text,
    bill_status_summary     text,
    source_url              text,
    
    -- Mapping to training resources
    affected_categories     text[] NOT NULL DEFAULT '{}',
    
    -- Content — displayed in the Legislative Horizon panel
    headline_summary        text NOT NULL,
    key_changes             jsonb NOT NULL DEFAULT '[]',
    business_impact_html    text NOT NULL,
    preparatory_steps_html  text NOT NULL,
    
    -- Legal disclaimer — mandatory on every display
    disclaimer_text         text NOT NULL DEFAULT 'The preparatory steps outlined below are for awareness and forward-planning purposes only. They do not constitute legal advice. Before making any changes to employment contracts, handbooks, policies, or procedures, employers must obtain professional advice from a qualified solicitor or legal expert. Ailane provides compliance intelligence — not legal counsel.',
    
    -- Display control
    priority                text NOT NULL DEFAULT 'medium' CHECK (priority IN ('critical', 'high', 'medium', 'low')),
    status                  text NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending', 'enacted', 'partially_commenced', 'fully_commenced', 'withdrawn'
    )),
    is_published            boolean NOT NULL DEFAULT false,
    display_order           integer NOT NULL DEFAULT 100,
    
    -- Metadata
    last_status_check       timestamptz,
    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX idx_lh_published ON public.kl_legislative_horizon(is_published) WHERE is_published = true;
CREATE INDEX idx_lh_categories ON public.kl_legislative_horizon USING gin(affected_categories);
CREATE INDEX idx_lh_status ON public.kl_legislative_horizon(status);

-- Comments
COMMENT ON TABLE public.kl_legislative_horizon IS 'Legislative Horizon: proactive change intelligence mapping pending legislation to training resources. Renders as prominent panels in the guide reader, providing forward-planning intelligence to HR professionals.';
COMMENT ON COLUMN public.kl_legislative_horizon.key_changes IS 'JSON array of objects: [{change: "...", category: "...", severity: "high|medium|low"}]';
COMMENT ON COLUMN public.kl_legislative_horizon.preparatory_steps_html IS 'HTML content for recommended preparatory steps. Must always be displayed with the disclaimer_text. Language must use "consider", "assess", "evaluate" — never imperative directives.';
COMMENT ON COLUMN public.kl_legislative_horizon.disclaimer_text IS 'Legal disclaimer displayed prominently with every preparatory steps section. Non-negotiable — cannot be hidden or minimised.';

-- RLS
ALTER TABLE public.kl_legislative_horizon ENABLE ROW LEVEL SECURITY;

-- Public read for published entries (anonymous + authenticated)
CREATE POLICY kl_lh_anon_read_published
    ON public.kl_legislative_horizon
    FOR SELECT
    USING (auth.role() = 'anon' AND is_published = true);

CREATE POLICY kl_lh_auth_read_published
    ON public.kl_legislative_horizon
    FOR SELECT
    USING (auth.role() = 'authenticated' AND is_published = true);

-- Service role: full access
CREATE POLICY kl_lh_service_manage
    ON public.kl_legislative_horizon
    FOR ALL
    USING (auth.role() = 'service_role');

