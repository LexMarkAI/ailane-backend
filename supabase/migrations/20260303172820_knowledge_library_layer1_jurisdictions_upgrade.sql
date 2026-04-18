-- Migration: 20260303172820_knowledge_library_layer1_jurisdictions_upgrade
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: knowledge_library_layer1_jurisdictions_upgrade


-- ═══════════════════════════════════════════════════════════════
-- LAYER 1: JURISDICTIONS TABLE UPGRADE
-- Adds sovereignty_type and updated_at to existing table
-- Existing PK: code (text) — preserved, all FKs will reference code
-- ═══════════════════════════════════════════════════════════════

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'jurisdictions' AND column_name = 'sovereignty_type'
    ) THEN
        ALTER TABLE jurisdictions ADD COLUMN sovereignty_type text DEFAULT 'sovereign'
            CHECK (sovereignty_type IN ('sovereign', 'devolved', 'federated_state', 'territory', 'supranational', 'autonomous_region', 'dependent_territory'));
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'jurisdictions' AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE jurisdictions ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now();
    END IF;
END $$;

-- Backfill sovereignty_type for existing UK jurisdictions
UPDATE jurisdictions SET sovereignty_type = 'devolved' WHERE code IN ('GB-SCT', 'GB-WLS', 'GB-NIR');
UPDATE jurisdictions SET sovereignty_type = 'territory' WHERE code IN ('GB-ENG', 'GB-LDN', 'GB-NW', 'GB-SE');
UPDATE jurisdictions SET sovereignty_type = 'sovereign' WHERE code IN ('GB', 'US', 'IN', 'AU', 'CA', 'DE', 'FR', 'JP', 'BR', 'ZA', 'SG', 'AE', 'NZ', 'IE', 'KR', 'CN', 'HK', 'MX', 'NG', 'KE', 'EG', 'SA', 'IL');
UPDATE jurisdictions SET sovereignty_type = 'supranational' WHERE code = 'EU';
UPDATE jurisdictions SET sovereignty_type = 'federated_state' WHERE parent_code IN ('US', 'IN', 'AU', 'CA', 'DE', 'BR', 'NG', 'MX') AND level > 0;

COMMENT ON TABLE jurisdictions IS 'Layer 1: Hierarchical jurisdiction registry for multi-jurisdiction ACEI aggregation (Art. VIII §8.2). PK: code (text).';
COMMENT ON COLUMN jurisdictions.sovereignty_type IS 'Constitutional classification: sovereign, devolved, federated_state, supranational, territory';

