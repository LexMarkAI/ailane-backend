-- Migration: 20260302215826_create_legislation_library
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_legislation_library


-- ============================================================================
-- AILANE - Employment Legislation Library
-- Constitutional Authority: ACEI Art. V (SCI), ACEI Art. VII (Forward Exposure),
--                          RRI Art. II §2.3 (RCE Types), Feature Matrix §3
-- ============================================================================

-- Core legislation table: every Act, SI, Code, and Regulation
CREATE TABLE IF NOT EXISTS legislation_library (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    
    -- Identity
    legislation_ref TEXT UNIQUE NOT NULL,          -- e.g. "ukpga/2010/15" (Equality Act 2010)
    short_title TEXT NOT NULL,                      -- e.g. "Equality Act 2010"
    long_title TEXT,                                -- Full official title
    legislation_type TEXT NOT NULL CHECK (legislation_type IN (
        'primary',           -- Act of Parliament (RCE Type 1)
        'statutory_instrument', -- SI / Regulation (RCE Type 2)
        'binding_code',      -- ACAS Code, HSE Code (RCE Type 3)
        'regulator_guidance', -- ICO guidance, EHRC guidance (RCE Type 3b)
        'court_precedent',   -- Leading case law (RCE Type 4)
        'devolved',          -- Devolved legislation (RCE Type 5)
        'contractual'        -- Contractual flow-down (RCE Type 6)
    )),
    rce_type INTEGER CHECK (rce_type BETWEEN 1 AND 6),
    
    -- Lifecycle tracking (Feature Matrix §3.1)
    lifecycle_stage TEXT NOT NULL DEFAULT 'in_force' CHECK (lifecycle_stage IN (
        'bill',              -- Stage 1: Parliamentary passage
        'royal_assent',      -- Stage 2: Enacted but not yet commenced
        'commenced',         -- Stage 3: In force
        'in_force',          -- Stage 4: Fully operational
        'partially_commenced', -- Some provisions in force
        'repealed',          -- No longer in force
        'amended'            -- Substantively amended (still in force)
    )),
    
    -- Key dates
    royal_assent_date DATE,
    commencement_date DATE,
    amendment_date DATE,
    repeal_date DATE,
    
    -- ACEI category mapping (can affect multiple categories)
    acei_categories INTEGER[] NOT NULL DEFAULT '{}',  -- Array of category numbers 1-12
    primary_acei_category INTEGER CHECK (primary_acei_category BETWEEN 1 AND 12),
    
    -- SCI significance (ACEI Art. V)
    sci_significance INTEGER DEFAULT 3 CHECK (sci_significance BETWEEN 1 AND 5),
    
    -- Content
    summary TEXT,                                  -- Plain English summary
    key_provisions TEXT,                           -- Key sections relevant to employment
    obligations_summary TEXT,                      -- What employers must do
    enforcement_mechanism TEXT,                    -- How it's enforced
    penalty_summary TEXT,                          -- Consequences of non-compliance
    
    -- External references
    legislation_gov_url TEXT,                      -- Link to legislation.gov.uk
    explanatory_notes_url TEXT,                    -- Link to explanatory notes
    
    -- Sector applicability
    sector_applicability TEXT DEFAULT 'all',       -- 'all' or comma-separated SIC ranges
    headcount_threshold INTEGER,                   -- Minimum employees for applicability
    
    -- RRI linkage
    rri_pillars_affected TEXT[],                   -- Which RRI pillars are impacted
    
    -- Tier access control (Feature Matrix §3.2)
    tier_access TEXT NOT NULL DEFAULT 'all' CHECK (tier_access IN (
        'all',               -- Available to all tiers
        'governance',        -- Governance + Institutional only
        'institutional'      -- Institutional only
    )),
    
    -- Metadata
    parent_legislation_ref TEXT,                   -- For SIs: the parent Act
    related_legislation TEXT[],                    -- Related legislation refs
    tags TEXT[],                                   -- Searchable tags
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_leg_lib_type ON legislation_library(legislation_type);
CREATE INDEX IF NOT EXISTS idx_leg_lib_stage ON legislation_library(lifecycle_stage);
CREATE INDEX IF NOT EXISTS idx_leg_lib_primary_cat ON legislation_library(primary_acei_category);
CREATE INDEX IF NOT EXISTS idx_leg_lib_acei_cats ON legislation_library USING GIN(acei_categories);
CREATE INDEX IF NOT EXISTS idx_leg_lib_tags ON legislation_library USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_leg_lib_commencement ON legislation_library(commencement_date);

-- RLS
ALTER TABLE legislation_library ENABLE ROW LEVEL SECURITY;

CREATE POLICY anon_read_legislation ON legislation_library
    FOR SELECT TO anon USING (true);

CREATE POLICY anon_insert_legislation ON legislation_library
    FOR INSERT TO anon WITH CHECK (true);

CREATE POLICY anon_update_legislation ON legislation_library
    FOR UPDATE TO anon USING (true) WITH CHECK (true);

CREATE POLICY service_all_legislation ON legislation_library
    FOR ALL TO authenticated USING (true) WITH CHECK (true);


-- Legislation amendments tracking table
CREATE TABLE IF NOT EXISTS legislation_amendments (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    legislation_id UUID REFERENCES legislation_library(id),
    amendment_ref TEXT NOT NULL,                   -- The amending instrument ref
    amendment_title TEXT NOT NULL,
    amendment_date DATE,
    sections_affected TEXT,
    summary TEXT,
    acei_impact TEXT,                              -- How it changes the ACEI landscape
    sci_delta NUMERIC(3,1),                        -- SCI score change
    legislation_gov_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE legislation_amendments ENABLE ROW LEVEL SECURITY;
CREATE POLICY anon_read_amendments ON legislation_amendments FOR SELECT TO anon USING (true);
CREATE POLICY anon_insert_amendments ON legislation_amendments FOR INSERT TO anon WITH CHECK (true);


-- Forward Exposure Register (ACEI Art. VII)
CREATE TABLE IF NOT EXISTS forward_exposure_register (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    legislation_id UUID REFERENCES legislation_library(id),
    legislation_ref TEXT NOT NULL,
    title TEXT NOT NULL,
    
    -- Forward projection (ACEI Art. VII §7.3)
    current_domain_index NUMERIC(5,1),
    projected_domain_index NUMERIC(5,1),
    delta NUMERIC(5,1),
    
    -- Dates
    activation_date DATE NOT NULL,
    registered_date DATE DEFAULT CURRENT_DATE,
    
    -- Categories affected
    acei_categories_affected INTEGER[],
    
    -- Status
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'activated', 'revoked', 'archived')),
    
    -- Governance (ACEI Art. VII §7.5)
    aic_review_date DATE,
    approved_by TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE forward_exposure_register ENABLE ROW LEVEL SECURITY;
CREATE POLICY anon_read_forward ON forward_exposure_register FOR SELECT TO anon USING (true);
CREATE POLICY anon_insert_forward ON forward_exposure_register FOR INSERT TO anon WITH CHECK (true);

