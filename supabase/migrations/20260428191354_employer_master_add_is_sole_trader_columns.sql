-- Phase 1 of AILANE-CC-BRIEF-IS-SOLE-TRADER-001
-- Adds is_sole_trader gating column and three provenance columns to employer_master.
-- All columns nullable; seed UPDATE in migration 3 sets values from existing operational state.

ALTER TABLE public.employer_master
  ADD COLUMN is_sole_trader BOOLEAN,
  ADD COLUMN is_sole_trader_method TEXT,
  ADD COLUMN is_sole_trader_confidence TEXT,
  ADD COLUMN is_sole_trader_classified_at TIMESTAMPTZ;

ALTER TABLE public.employer_master
  ADD CONSTRAINT chk_em_is_sole_trader_method
    CHECK (is_sole_trader_method IS NULL OR is_sole_trader_method IN (
      'ch_fetch_status_seed_v1',
      'canonical_inheritance',
      'ch_api_backfill',
      'manual_director',
      'manual_dpia'
    )),
  ADD CONSTRAINT chk_em_is_sole_trader_confidence
    CHECK (is_sole_trader_confidence IS NULL OR is_sole_trader_confidence IN ('HIGH', 'MEDIUM', 'LOW')),
  ADD CONSTRAINT chk_em_is_sole_trader_provenance_pairing
    CHECK (
      (is_sole_trader IS NULL AND is_sole_trader_method IS NULL AND is_sole_trader_confidence IS NULL)
      OR
      (is_sole_trader IS NOT NULL AND is_sole_trader_method IS NOT NULL AND is_sole_trader_confidence IS NOT NULL)
    );

COMMENT ON COLUMN public.employer_master.is_sole_trader IS
  'Gating column for named-employer commercial outputs. TRUE = confirmed sole trader / individual; FALSE = confirmed company / statutory body; NULL = unclassified. Per AILANE-AUDIT-FIELDS-LEGAL-001 v1.0 §43.4 view-creation pattern.';
COMMENT ON COLUMN public.employer_master.is_sole_trader_method IS
  'Provenance: how the is_sole_trader value was set. Per AILANE-CC-BRIEF-IS-SOLE-TRADER-001 §4.3.';
COMMENT ON COLUMN public.employer_master.is_sole_trader_confidence IS
  'HIGH / MEDIUM / LOW. NULL where is_sole_trader IS NULL.';
COMMENT ON COLUMN public.employer_master.is_sole_trader_classified_at IS
  'Timestamp when is_sole_trader was last set. NULL where is_sole_trader IS NULL.';

