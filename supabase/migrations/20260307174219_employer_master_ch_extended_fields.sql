-- Migration: 20260307174219_employer_master_ch_extended_fields
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: employer_master_ch_extended_fields


-- Extended CH intelligence fields on employer_master
-- Captures filing compliance, risk signals, company profile, and name history

ALTER TABLE employer_master
  ADD COLUMN IF NOT EXISTS company_type            TEXT,
  ADD COLUMN IF NOT EXISTS date_of_creation        DATE,
  ADD COLUMN IF NOT EXISTS accounts_overdue        BOOLEAN,
  ADD COLUMN IF NOT EXISTS accounts_next_due       DATE,
  ADD COLUMN IF NOT EXISTS accounts_last_made_up   DATE,
  ADD COLUMN IF NOT EXISTS confirmation_stmt_overdue    BOOLEAN,
  ADD COLUMN IF NOT EXISTS confirmation_stmt_next_due   DATE,
  ADD COLUMN IF NOT EXISTS has_insolvency_history  BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS has_been_liquidated     BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS has_charges             BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS previous_company_names  JSONB   DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS ch_jurisdiction         TEXT;

-- Index for CCI queries — overdue filing flags
CREATE INDEX IF NOT EXISTS idx_employer_accounts_overdue
  ON employer_master(accounts_overdue)
  WHERE accounts_overdue = TRUE;

CREATE INDEX IF NOT EXISTS idx_employer_cs_overdue
  ON employer_master(confirmation_stmt_overdue)
  WHERE confirmation_stmt_overdue = TRUE;

CREATE INDEX IF NOT EXISTS idx_employer_insolvency
  ON employer_master(has_insolvency_history)
  WHERE has_insolvency_history = TRUE;

-- Index for previous name matching
CREATE INDEX IF NOT EXISTS idx_employer_previous_names_gin
  ON employer_master USING GIN(previous_company_names);

COMMENT ON COLUMN employer_master.company_type IS 'CH company type: ltd, plc, llp, royal-charter, etc.';
COMMENT ON COLUMN employer_master.date_of_creation IS 'CH incorporation date.';
COMMENT ON COLUMN employer_master.accounts_overdue IS 'TRUE if accounts filing is overdue per CH. CCI conduct signal.';
COMMENT ON COLUMN employer_master.accounts_next_due IS 'Date next accounts filing is due.';
COMMENT ON COLUMN employer_master.accounts_last_made_up IS 'Date last accounts were made up to.';
COMMENT ON COLUMN employer_master.confirmation_stmt_overdue IS 'TRUE if confirmation statement is overdue. CCI conduct signal.';
COMMENT ON COLUMN employer_master.confirmation_stmt_next_due IS 'Date next confirmation statement is due.';
COMMENT ON COLUMN employer_master.has_insolvency_history IS 'Company has had insolvency proceedings. Risk signal.';
COMMENT ON COLUMN employer_master.has_been_liquidated IS 'Company has been liquidated.';
COMMENT ON COLUMN employer_master.has_charges IS 'Company has registered charges (financial encumbrances).';
COMMENT ON COLUMN employer_master.previous_company_names IS 'Array of previous registered names with effective dates. Used for variant matching.';
COMMENT ON COLUMN employer_master.ch_jurisdiction IS 'CH jurisdiction: england-wales, scotland, northern-ireland, etc.';

