-- Migration: 20260416224442_create_scraper_landing_tables_v1
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_scraper_landing_tables_v1

-- ─────────────────────────────────────────────────────────────────────
-- AILANE SCRAPER LANDING TABLES — 5 new regulatory intelligence tables
-- Constitutional authority: ACEI Art. XI (Data Governance)
-- Pattern: per-regulator landing table, UPSERT on content_hash, OGL v3.0 sources
-- ─────────────────────────────────────────────────────────────────────

-- ── 1. FOS Firm Complaints (half-yearly) ─────────────────────────────
CREATE TABLE IF NOT EXISTS public.fos_firm_complaints (
    id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    firm_name                   text NOT NULL,
    firm_name_normalised        text NOT NULL,
    firm_reference_number       text,
    period_label                text NOT NULL,           -- e.g. "H2 2024", "H1 2025"
    period_start                date,
    period_end                  date,
    product_category            text,                    -- banking-and-credit, insurance, investments, ...
    new_complaints              integer,
    complaints_upheld           integer,
    percent_upheld              numeric(5,2),
    source_url                  text,
    data_file_url               text,
    content_hash                text NOT NULL,
    scraped_at                  timestamp with time zone DEFAULT now(),
    metadata                    jsonb DEFAULT '{}'::jsonb,
    processing_status           text DEFAULT 'raw',
    jurisdiction_code           varchar(2) NOT NULL DEFAULT 'GB',
    created_at                  timestamp with time zone DEFAULT now(),
    updated_at                  timestamp with time zone DEFAULT now(),
    CONSTRAINT fos_firm_complaints_hash_unique UNIQUE (content_hash)
);
CREATE INDEX IF NOT EXISTS idx_fos_fc_firm_norm ON public.fos_firm_complaints (firm_name_normalised);
CREATE INDEX IF NOT EXISTS idx_fos_fc_period ON public.fos_firm_complaints (period_label);
CREATE INDEX IF NOT EXISTS idx_fos_fc_frn ON public.fos_firm_complaints (firm_reference_number);

-- ── 2. FCA Firm Complaints (half-yearly) ─────────────────────────────
CREATE TABLE IF NOT EXISTS public.fca_firm_complaints (
    id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    firm_name                   text NOT NULL,
    firm_name_normalised        text NOT NULL,
    firm_reference_number       text,
    period_label                text NOT NULL,
    period_start                date,
    period_end                  date,
    product_group               text,
    complaints_opened           integer,
    complaints_closed           integer,
    complaints_upheld           integer,
    main_cause                  text,
    redress_paid                numeric(14,2),
    source_url                  text,
    data_file_url               text,
    content_hash                text NOT NULL,
    scraped_at                  timestamp with time zone DEFAULT now(),
    metadata                    jsonb DEFAULT '{}'::jsonb,
    processing_status           text DEFAULT 'raw',
    jurisdiction_code           varchar(2) NOT NULL DEFAULT 'GB',
    created_at                  timestamp with time zone DEFAULT now(),
    updated_at                  timestamp with time zone DEFAULT now(),
    CONSTRAINT fca_firm_complaints_hash_unique UNIQUE (content_hash)
);
CREATE INDEX IF NOT EXISTS idx_fca_fc_firm_norm ON public.fca_firm_complaints (firm_name_normalised);
CREATE INDEX IF NOT EXISTS idx_fca_fc_period ON public.fca_firm_complaints (period_label);
CREATE INDEX IF NOT EXISTS idx_fca_fc_frn ON public.fca_firm_complaints (firm_reference_number);

-- ── 3. TPR Penalty Notices ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tpr_penalty_notices (
    id                          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_identifier           text,
    notice_type                 text,
    date_issued                 date,
    organisation_name           text,
    organisation_name_normalised text,
    pension_scheme_name         text,
    penalty_amount              numeric(14,2),
    legislation_cited           text,
    brief_summary               text,
    source_url                  text,
    content_hash                text NOT NULL,
    scraped_at                  timestamp with time zone DEFAULT now(),
    metadata                    jsonb DEFAULT '{}'::jsonb,
    processing_status           text DEFAULT 'raw',
    acei_category               text,
    acei_category_number        integer,
    jurisdiction_code           varchar(2) NOT NULL DEFAULT 'GB',
    created_at                  timestamp with time zone DEFAULT now(),
    updated_at                  timestamp with time zone DEFAULT now(),
    CONSTRAINT tpr_penalty_notices_hash_unique UNIQUE (content_hash)
);
CREATE INDEX IF NOT EXISTS idx_tpr_pn_org_norm ON public.tpr_penalty_notices (organisation_name_normalised);
CREATE INDEX IF NOT EXISTS idx_tpr_pn_date ON public.tpr_penalty_notices (date_issued);
CREATE INDEX IF NOT EXISTS idx_tpr_pn_notice_type ON public.tpr_penalty_notices (notice_type);

-- ── 4. FCA Enforcement Notices (final/decision/prohibition) ──────────
CREATE TABLE IF NOT EXISTS public.fca_enforcement_notices (
    id                              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    firm_or_individual              text NOT NULL,
    firm_or_individual_normalised   text NOT NULL,
    firm_reference_number           text,
    notice_type                     text,
    date_published                  date,
    penalty_amount                  numeric(14,2),
    summary                         text,
    detail_url                      text NOT NULL,
    source_url                      text,
    content_hash                    text NOT NULL,
    scraped_at                      timestamp with time zone DEFAULT now(),
    metadata                        jsonb DEFAULT '{}'::jsonb,
    processing_status               text DEFAULT 'raw',
    acei_category                   text,
    acei_category_number            integer,
    jurisdiction_code               varchar(2) NOT NULL DEFAULT 'GB',
    created_at                      timestamp with time zone DEFAULT now(),
    updated_at                      timestamp with time zone DEFAULT now(),
    CONSTRAINT fca_enforcement_notices_url_unique UNIQUE (detail_url),
    CONSTRAINT fca_enforcement_notices_hash_unique UNIQUE (content_hash)
);
CREATE INDEX IF NOT EXISTS idx_fca_en_firm_norm ON public.fca_enforcement_notices (firm_or_individual_normalised);
CREATE INDEX IF NOT EXISTS idx_fca_en_date ON public.fca_enforcement_notices (date_published);
CREATE INDEX IF NOT EXISTS idx_fca_en_type ON public.fca_enforcement_notices (notice_type);

-- ── 5. TPO Determinations (Pensions Ombudsman) ───────────────────────
CREATE TABLE IF NOT EXISTS public.tpo_determinations (
    id                              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    source_identifier               text,
    determination_reference         text,
    complainant_anonymised          text,
    respondent                      text,
    respondent_normalised           text,
    pension_scheme                  text,
    determination_date              date,
    outcome                         text,
    brief_summary                   text,
    full_text                       text,
    detail_url                      text NOT NULL,
    source_url                      text,
    content_hash                    text NOT NULL,
    scraped_at                      timestamp with time zone DEFAULT now(),
    metadata                        jsonb DEFAULT '{}'::jsonb,
    processing_status               text DEFAULT 'raw',
    acei_category                   text,
    acei_category_number            integer,
    jurisdiction_code               varchar(2) NOT NULL DEFAULT 'GB',
    created_at                      timestamp with time zone DEFAULT now(),
    updated_at                      timestamp with time zone DEFAULT now(),
    CONSTRAINT tpo_determinations_url_unique UNIQUE (detail_url),
    CONSTRAINT tpo_determinations_hash_unique UNIQUE (content_hash)
);
CREATE INDEX IF NOT EXISTS idx_tpo_det_resp_norm ON public.tpo_determinations (respondent_normalised);
CREATE INDEX IF NOT EXISTS idx_tpo_det_date ON public.tpo_determinations (determination_date);
CREATE INDEX IF NOT EXISTS idx_tpo_det_outcome ON public.tpo_determinations (outcome);

-- ── RLS ENABLE — service_role writes, anon/authenticated read ────────
ALTER TABLE public.fos_firm_complaints       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fca_firm_complaints       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tpr_penalty_notices       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fca_enforcement_notices   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tpo_determinations        ENABLE ROW LEVEL SECURITY;

-- Read policies (public regulatory data, OGL v3.0)
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['fos_firm_complaints','fca_firm_complaints','tpr_penalty_notices','fca_enforcement_notices','tpo_determinations']
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_public_read', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR SELECT USING (true)', t || '_public_read', t);

    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_service_write', t);
    EXECUTE format('CREATE POLICY %I ON public.%I FOR ALL TO service_role USING (true) WITH CHECK (true)', t || '_service_write', t);
  END LOOP;
END $$;

-- Comments for data dictionary
COMMENT ON TABLE public.fos_firm_complaints      IS 'FOS half-yearly firm complaints data (OGL v3.0, financial-ombudsman.org.uk)';
COMMENT ON TABLE public.fca_firm_complaints      IS 'FCA firm-level complaints data (OGL v3.0, fca.org.uk)';
COMMENT ON TABLE public.tpr_penalty_notices      IS 'TPR penalty notices — pensions regulator (OGL v3.0, thepensionsregulator.gov.uk)';
COMMENT ON TABLE public.fca_enforcement_notices  IS 'FCA final/decision/prohibition notices (OGL v3.0, fca.org.uk)';
COMMENT ON TABLE public.tpo_determinations       IS 'Pensions Ombudsman determinations (OGL v3.0, pensions-ombudsman.org.uk)';
