-- Migration: 20260228220012_acei_sub_index_columns
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: acei_sub_index_columns


-- ═══════════════════════════════════════════════════════════
-- Add explicit EVI, EII, SCI sub-index columns to category scores
-- for constitutional transparency and auditability
-- Art 3.2.1: L_raw = (0.4 × EVI) + (0.3 × EII) + (0.3 × SCI)
-- ═══════════════════════════════════════════════════════════

ALTER TABLE acei_category_scores ADD COLUMN IF NOT EXISTS evi INTEGER;
ALTER TABLE acei_category_scores ADD COLUMN IF NOT EXISTS eii INTEGER;
ALTER TABLE acei_category_scores ADD COLUMN IF NOT EXISTS sci INTEGER;
ALTER TABLE acei_category_scores ADD COLUMN IF NOT EXISTS l_raw NUMERIC(4,2);

COMMENT ON COLUMN acei_category_scores.evi IS 'Event Volume Index (1-5). Art 3.2, Annex A2.';
COMMENT ON COLUMN acei_category_scores.eii IS 'Enforcement Intensity Index (1-5). Art 3.2, Annex A2.';
COMMENT ON COLUMN acei_category_scores.sci IS 'Structural Change Index (1-5). Art 3.2, Annex A3.';
COMMENT ON COLUMN acei_category_scores.l_raw IS 'L_raw = (0.4 × EVI) + (0.3 × EII) + (0.3 × SCI). Art 3.2.1.';

