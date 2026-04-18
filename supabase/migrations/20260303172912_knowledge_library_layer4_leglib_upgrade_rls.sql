-- Migration: 20260303172912_knowledge_library_layer4_leglib_upgrade_rls
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: knowledge_library_layer4_leglib_upgrade_rls


-- ═══════════════════════════════════════════════════════════════
-- LAYER 4: LEGISLATION LIBRARY UPGRADE + RLS + TRIGGERS
-- Adds provenance tracking, source FKs, verification status
-- ═══════════════════════════════════════════════════════════════

-- Add new columns to legislation_library
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'legislation_library' AND column_name = 'home_jurisdiction_code'
    ) THEN
        ALTER TABLE legislation_library ADD COLUMN home_jurisdiction_code text REFERENCES jurisdictions(code);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'legislation_library' AND column_name = 'instrument_type_id'
    ) THEN
        ALTER TABLE legislation_library ADD COLUMN instrument_type_id uuid REFERENCES instrument_types(id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'legislation_library' AND column_name = 'source_id'
    ) THEN
        ALTER TABLE legislation_library ADD COLUMN source_id uuid REFERENCES regulatory_sources(id);
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'legislation_library' AND column_name = 'citation'
    ) THEN
        ALTER TABLE legislation_library ADD COLUMN citation text;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'legislation_library' AND column_name = 'source_url'
    ) THEN
        ALTER TABLE legislation_library ADD COLUMN source_url text;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'legislation_library' AND column_name = 'source_hash'
    ) THEN
        ALTER TABLE legislation_library ADD COLUMN source_hash text;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'legislation_library' AND column_name = 'source_fetched_at'
    ) THEN
        ALTER TABLE legislation_library ADD COLUMN source_fetched_at timestamptz;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'legislation_library' AND column_name = 'provenance_chain'
    ) THEN
        ALTER TABLE legislation_library ADD COLUMN provenance_chain jsonb DEFAULT '[]'::jsonb;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'legislation_library' AND column_name = 'verification_status'
    ) THEN
        ALTER TABLE legislation_library ADD COLUMN verification_status text DEFAULT 'unverified'
            CHECK (verification_status IN ('verified', 'stale', 'conflict', 'unverified'));
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_leglib_home_jurisdiction ON legislation_library(home_jurisdiction_code);
CREATE INDEX IF NOT EXISTS idx_leglib_instrument_type ON legislation_library(instrument_type_id);
CREATE INDEX IF NOT EXISTS idx_leglib_source ON legislation_library(source_id);
CREATE INDEX IF NOT EXISTS idx_leglib_verification ON legislation_library(verification_status);

-- ═══════════════════════════════════════════════════════════════
-- RLS POLICIES — All six new tables
-- ═══════════════════════════════════════════════════════════════

ALTER TABLE regulatory_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE instrument_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE instrument_jurisdictions ENABLE ROW LEVEL SECURITY;
ALTER TABLE regulatory_bodies ENABLE ROW LEVEL SECURITY;
ALTER TABLE legislation_category_keywords ENABLE ROW LEVEL SECURITY;

-- Authenticated read (dashboard)
CREATE POLICY "Authenticated read regulatory_sources" ON regulatory_sources FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated read instrument_types" ON instrument_types FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated read instrument_jurisdictions" ON instrument_jurisdictions FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated read regulatory_bodies" ON regulatory_bodies FOR SELECT TO authenticated USING (true);
CREATE POLICY "Authenticated read legislation_category_keywords" ON legislation_category_keywords FOR SELECT TO authenticated USING (true);

-- Service role full access (scrapers, edge functions)
CREATE POLICY "Service role full regulatory_sources" ON regulatory_sources FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "Service role full instrument_types" ON instrument_types FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "Service role full instrument_jurisdictions" ON instrument_jurisdictions FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "Service role full regulatory_bodies" ON regulatory_bodies FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "Service role full legislation_category_keywords" ON legislation_category_keywords FOR ALL TO service_role USING (true) WITH CHECK (true);

-- Anon read for public Knowledge Library queries
CREATE POLICY "Anon read instrument_types" ON instrument_types FOR SELECT TO anon USING (true);
CREATE POLICY "Anon read regulatory_sources" ON regulatory_sources FOR SELECT TO anon USING (true);

-- ═══════════════════════════════════════════════════════════════
-- UPDATED_AT TRIGGERS
-- ═══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['jurisdictions', 'regulatory_sources', 'regulatory_bodies']
    LOOP
        EXECUTE format('
            DROP TRIGGER IF EXISTS trigger_updated_at ON %I;
            CREATE TRIGGER trigger_updated_at
            BEFORE UPDATE ON %I
            FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
        ', t, t);
    END LOOP;
END $$;

