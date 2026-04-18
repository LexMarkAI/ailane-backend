-- Migration: 20260331115843_create_expanded_intelligence_tables
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_expanded_intelligence_tables


-- ============================================================================
-- AILANE EXPANDED INTELLIGENCE ESTATE
-- Constitutional Authority: ACEI Art. III (EVI), Art. IV (EII), Art. V (SCI)
--                          CCI Art. III (Employer Risk Intelligence)
-- Migration: create_expanded_intelligence_tables
-- Date: 2026-03-31
-- ============================================================================

-- 1. CORONER PREVENTION OF FUTURE DEATHS REPORTS
-- Source: judiciary.uk/prevention-of-future-death-reports/
-- Frequency: Ongoing (daily check)
-- Constitutional: ACEI Category 8 (Health & Safety), CCI critical risk signal
CREATE TABLE IF NOT EXISTS public.coroner_pfd_reports (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    source_identifier text NOT NULL UNIQUE,
    report_date date,
    deceased_name text,
    coroner_name text,
    coroner_area text,
    category text,                          -- judiciary.uk category assignment
    categories text[],                      -- multiple categories possible
    employer_name text,                     -- employer/organisation named in report
    employer_companies_house text,          -- CH number if identifiable
    cause_of_death text,
    circumstances_summary text,
    systemic_failures text[],              -- extracted compliance failures
    recommendations text,                   -- coroner's recommended actions
    addressee text,                         -- who must respond
    response_due_date date,                -- 56-day statutory deadline
    response_received boolean DEFAULT false,
    response_summary text,
    report_pdf_url text,
    response_pdf_url text,
    employment_related boolean DEFAULT false, -- filtered flag for relevance
    acei_category text,
    acei_category_number integer,
    sector text,
    region text,
    source_url text NOT NULL,
    content_hash text,
    scraped_at timestamptz DEFAULT now(),
    enrichment_status text DEFAULT 'raw',   -- raw, enriched, reviewed
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_coroner_pfd_employer ON public.coroner_pfd_reports(employer_name);
CREATE INDEX IF NOT EXISTS idx_coroner_pfd_date ON public.coroner_pfd_reports(report_date);
CREATE INDEX IF NOT EXISTS idx_coroner_pfd_employment ON public.coroner_pfd_reports(employment_related) WHERE employment_related = true;
CREATE INDEX IF NOT EXISTS idx_coroner_pfd_category ON public.coroner_pfd_reports(category);

-- 2. HSE PROSECUTIONS (convictions register — separate from enforcement notices)
-- Source: resources.hse.gov.uk/convictions/
-- Frequency: Weekly check
-- Constitutional: ACEI Category 8, CCI critical risk signal, director liability
CREATE TABLE IF NOT EXISTS public.hse_prosecutions (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    source_identifier text NOT NULL UNIQUE,
    case_reference text,
    defendant_name text NOT NULL,
    defendant_type text,                    -- company, individual, director
    defendant_companies_house text,         -- CH number if company
    date_of_offence date,
    date_of_conviction date,
    court_name text,
    legislation_breached text,
    offence_description text,
    outcome text,                           -- convicted, acquitted
    fine_amount numeric,
    costs_amount numeric,
    custodial_sentence text,                -- e.g. '9 months'
    custodial_suspended boolean,
    community_order text,
    fatality_involved boolean DEFAULT false,
    number_of_fatalities integer DEFAULT 0,
    injured_persons integer DEFAULT 0,
    sic_code text,
    sector text,
    region text,
    local_authority text,
    acei_category text DEFAULT 'health_and_safety',
    acei_category_number integer DEFAULT 8,
    source_url text NOT NULL,
    content_hash text,
    scraped_at timestamptz DEFAULT now(),
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hse_pros_defendant ON public.hse_prosecutions(defendant_name);
CREATE INDEX IF NOT EXISTS idx_hse_pros_conviction_date ON public.hse_prosecutions(date_of_conviction);
CREATE INDEX IF NOT EXISTS idx_hse_pros_fatality ON public.hse_prosecutions(fatality_involved) WHERE fatality_involved = true;
CREATE INDEX IF NOT EXISTS idx_hse_pros_director ON public.hse_prosecutions(defendant_type) WHERE defendant_type = 'director';

-- 3. HSE WORKPLACE FATALITIES (RIDDOR-reported deaths)
-- Source: hse.gov.uk/foi/fatalities/
-- Frequency: Monthly check
-- Constitutional: ACEI Category 8, maximum severity signal
CREATE TABLE IF NOT EXISTS public.hse_workplace_fatalities (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    source_identifier text NOT NULL UNIQUE,
    deceased_name text,
    date_of_incident date,
    employer_name text,
    employer_companies_house text,
    location text,
    region text,
    sector text,
    sic_code text,
    cause_of_death_summary text,
    circumstances text,
    hse_investigation_status text,          -- investigating, prosecuted, closed
    linked_prosecution_id uuid REFERENCES public.hse_prosecutions(id),
    linked_pfd_id uuid REFERENCES public.coroner_pfd_reports(id),
    financial_year text,                    -- e.g. '2024-25'
    acei_category text DEFAULT 'health_and_safety',
    acei_category_number integer DEFAULT 8,
    source_url text NOT NULL,
    scraped_at timestamptz DEFAULT now(),
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_hse_fatality_employer ON public.hse_workplace_fatalities(employer_name);
CREATE INDEX IF NOT EXISTS idx_hse_fatality_date ON public.hse_workplace_fatalities(date_of_incident);

-- 4. ACAS EARLY CONCILIATION STATISTICS
-- Source: acas.org.uk/about-us/service-statistics/early-conciliation/
-- Frequency: Quarterly
-- Constitutional: EVI funnel intelligence, CCI settlement context
CREATE TABLE IF NOT EXISTS public.acas_early_conciliation_stats (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    source_identifier text NOT NULL UNIQUE,
    period_start date NOT NULL,
    period_end date NOT NULL,
    period_label text,                      -- e.g. 'Q1 2024/25'
    metric_name text NOT NULL,              -- e.g. 'notifications_received', 'cot3_settlements'
    metric_value numeric,
    track_type text,                        -- fast, standard, open, all
    case_type text,                         -- employee_led, employer_led, group
    breakdown_dimension text,               -- optional: region, jurisdiction, etc.
    breakdown_value text,
    percentage numeric,                     -- pre-calculated percentage where available
    source_url text NOT NULL,
    scraped_at timestamptz DEFAULT now(),
    metadata jsonb DEFAULT '{}'::jsonb,
    created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_acas_ec_period ON public.acas_early_conciliation_stats(period_start, period_end);
CREATE INDEX IF NOT EXISTS idx_acas_ec_metric ON public.acas_early_conciliation_stats(metric_name);

-- 5. INTELLIGENCE PUBLICATION CALENDAR
-- Operational: tracks when each source publishes and scraper readiness
CREATE TABLE IF NOT EXISTS public.intelligence_publication_calendar (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    source_code text NOT NULL UNIQUE,       -- e.g. 'acas-ec-quarterly', 'hse-annual-stats'
    source_name text NOT NULL,
    source_url text NOT NULL,
    publisher text NOT NULL,                -- e.g. 'ACAS', 'HSE', 'MOJ', 'Judiciary'
    publication_frequency text NOT NULL,    -- daily, weekly, monthly, quarterly, annual
    typical_publication_month integer,      -- 1-12 for annual publications
    typical_publication_day integer,        -- day of month if known
    typical_lag_days integer,               -- days after period end before publication
    last_publication_date date,
    next_expected_date date,
    last_checked_at timestamptz,
    last_new_data_found_at timestamptz,
    scraper_status text NOT NULL DEFAULT 'pending_build',  -- active, pending_build, disabled, error
    scraper_type text,                      -- edge_function, local_python, manual
    target_table text,                      -- which table this feeds
    constitutional_authority text,          -- ACEI Art reference
    acei_categories integer[],             -- which ACEI categories this feeds
    priority text DEFAULT 'standard',       -- critical, high, standard, low
    notes text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- 6. Enable RLS on all new tables (service_role only for scraper writes)
ALTER TABLE public.coroner_pfd_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hse_prosecutions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hse_workplace_fatalities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.acas_early_conciliation_stats ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.intelligence_publication_calendar ENABLE ROW LEVEL SECURITY;

-- Service role has full access (scrapers use service role)
CREATE POLICY "service_role_full_access_coroner_pfd" ON public.coroner_pfd_reports
    FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_full_access_hse_pros" ON public.hse_prosecutions
    FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_full_access_hse_fatalities" ON public.hse_workplace_fatalities
    FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_full_access_acas_ec" ON public.acas_early_conciliation_stats
    FOR ALL USING (auth.role() = 'service_role');
CREATE POLICY "service_role_full_access_pub_calendar" ON public.intelligence_publication_calendar
    FOR ALL USING (auth.role() = 'service_role');

-- Authenticated users can read (for dashboards/Eileen)
CREATE POLICY "authenticated_read_coroner_pfd" ON public.coroner_pfd_reports
    FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "authenticated_read_hse_pros" ON public.hse_prosecutions
    FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "authenticated_read_hse_fatalities" ON public.hse_workplace_fatalities
    FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "authenticated_read_acas_ec" ON public.acas_early_conciliation_stats
    FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "authenticated_read_pub_calendar" ON public.intelligence_publication_calendar
    FOR SELECT USING (auth.role() = 'authenticated');

