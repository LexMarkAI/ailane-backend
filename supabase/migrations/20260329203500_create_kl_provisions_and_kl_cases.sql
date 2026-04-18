-- Migration: 20260329203500_create_kl_provisions_and_kl_cases
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_kl_provisions_and_kl_cases


-- KLIA-001 §10.2: Core RAG tables for Eileen's Knowledge Library intelligence
-- kl_provisions: Every provision of every tracked instrument with embedding
-- kl_cases: Significant employment law cases with embedding

CREATE TABLE public.kl_provisions (
    provision_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    instrument_id TEXT NOT NULL,          -- Content file ID e.g. era1996
    section_num TEXT NOT NULL,            -- Section number e.g. s.94, Reg.13
    title TEXT NOT NULL,                  -- Official heading of the provision
    summary TEXT,                         -- Plain English summary
    current_text TEXT NOT NULL,           -- Full enacted statutory text currently in force
    source_url TEXT,                      -- legislation.gov.uk URL for this section
    key_principle TEXT,                   -- Single most important legal principle
    in_force BOOLEAN NOT NULL DEFAULT true,
    is_era_2025 BOOLEAN NOT NULL DEFAULT false,  -- ERA 2025 forward intelligence flag
    acei_category TEXT,                   -- Primary ACEI category mapping
    acei_categories TEXT[] DEFAULT '{}',  -- All ACEI categories
    common_errors TEXT[] DEFAULT '{}',    -- Common employer compliance errors
    embedding extensions.vector(1536),   -- text-embedding-3-small vector
    last_verified TIMESTAMPTZ,           -- Last content verification timestamp
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(instrument_id, section_num)
);

CREATE TABLE public.kl_cases (
    case_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,                   -- Case name e.g. Polkey v AE Dayton Services Ltd
    citation TEXT NOT NULL,               -- Neutral citation e.g. [1987] UKHL 8
    court TEXT NOT NULL,                  -- Court: UKSC, EWCA, EAT, ET
    year INTEGER NOT NULL,
    provisions_affected TEXT[] DEFAULT '{}',  -- Array of provision references e.g. ["era1996:s.98"]
    principle TEXT,                        -- Core legal principle established
    facts TEXT,                           -- Key facts summary
    held TEXT,                            -- What the court held
    significance TEXT,                    -- Why this case matters
    bailii_url TEXT,                      -- BAILII URL for full judgment
    embedding extensions.vector(1536),   -- text-embedding-3-small vector
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes for RAG retrieval performance
CREATE INDEX idx_kl_provisions_instrument ON public.kl_provisions(instrument_id);
CREATE INDEX idx_kl_provisions_acei ON public.kl_provisions(acei_category);
CREATE INDEX idx_kl_cases_court ON public.kl_cases(court);
CREATE INDEX idx_kl_cases_year ON public.kl_cases(year);

COMMENT ON TABLE public.kl_provisions IS 'KLIA-001 §10.2: Every provision of every tracked instrument. Primary vector search table for Eileen RAG.';
COMMENT ON TABLE public.kl_cases IS 'KLIA-001 §10.2: Significant employment law cases with embeddings for Eileen RAG.';

