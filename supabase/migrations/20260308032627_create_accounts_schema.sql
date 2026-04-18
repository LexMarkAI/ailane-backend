-- Migration: 20260308032627_create_accounts_schema
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_accounts_schema


-- ============================================================
-- AILANE ACCOUNTS SCHEMA — Phase 1
-- AI Lane Limited (Company No. 17035654)
-- Accounting year end: 28 February
-- ============================================================

CREATE SCHEMA IF NOT EXISTS accounts;

-- ── SUPPLIERS ────────────────────────────────────────────────
CREATE TABLE accounts.suppliers (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL,
  domain        TEXT,
  category      TEXT CHECK (category IN ('saas','infrastructure','legal','professional','travel','utilities','hardware','marketing','other')),
  vat_number    TEXT,
  notes         TEXT,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ── TRANSACTIONS ─────────────────────────────────────────────
CREATE TABLE accounts.transactions (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date                  DATE NOT NULL,
  amount                NUMERIC(10,2) NOT NULL,
  currency              TEXT DEFAULT 'GBP',
  supplier_id           UUID REFERENCES accounts.suppliers(id),
  supplier_name         TEXT,
  description           TEXT,
  category              TEXT CHECK (category IN ('saas','infrastructure','legal','professional','travel','utilities','hardware','marketing','salary','dividend','other')),
  vat_amount            NUMERIC(10,2),
  vat_rate              NUMERIC(5,2),
  source                TEXT NOT NULL CHECK (source IN ('monzo','email','photo_upload','manual','stripe')),
  status                TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','categorised','reconciled','excluded')),
  monzo_transaction_id  TEXT UNIQUE,
  receipt_image_id      UUID,
  is_revenue            BOOLEAN DEFAULT FALSE,
  stripe_payment_id     TEXT UNIQUE,
  client_tier           TEXT,
  notes                 TEXT,
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW()
);

-- ── RECEIPT IMAGES ───────────────────────────────────────────
CREATE TABLE accounts.receipt_images (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id   UUID REFERENCES accounts.transactions(id),
  storage_path     TEXT,
  image_data       TEXT,  -- base64 for small images
  ocr_raw          JSONB,
  ocr_extracted    JSONB, -- {supplier, amount, date, vat_number, vat_amount}
  source           TEXT CHECK (source IN ('photo_upload','email_attachment')),
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

-- Add FK back on transactions
ALTER TABLE accounts.transactions 
  ADD CONSTRAINT fk_receipt_image 
  FOREIGN KEY (receipt_image_id) REFERENCES accounts.receipt_images(id);

-- ── VAT TRACKER ──────────────────────────────────────────────
CREATE TABLE accounts.vat_tracker (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  snapshot_date       DATE NOT NULL DEFAULT CURRENT_DATE,
  rolling_12m_revenue NUMERIC(10,2) DEFAULT 0,
  threshold_70k       BOOLEAN GENERATED ALWAYS AS (rolling_12m_revenue >= 70000) STORED,
  threshold_80k       BOOLEAN GENERATED ALWAYS AS (rolling_12m_revenue >= 80000) STORED,
  threshold_90k       BOOLEAN GENERATED ALWAYS AS (rolling_12m_revenue >= 90000) STORED,
  vat_registered      BOOLEAN DEFAULT FALSE,
  vat_registration_no TEXT,
  notes               TEXT,
  created_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ── FILING CALENDAR ──────────────────────────────────────────
CREATE TABLE accounts.filing_calendar (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  obligation          TEXT NOT NULL,
  due_date            DATE NOT NULL,
  filing_body         TEXT NOT NULL CHECK (filing_body IN ('companies_house','hmrc','ico','internal')),
  status              TEXT DEFAULT 'upcoming' CHECK (status IN ('upcoming','in_progress','filed','overdue')),
  notes               TEXT,
  notify_days_before  INTEGER[] DEFAULT '{60,30,14,7,1}',
  created_at          TIMESTAMPTZ DEFAULT NOW(),
  updated_at          TIMESTAMPTZ DEFAULT NOW()
);

-- ── MONZO WEBHOOK LOG ────────────────────────────────────────
CREATE TABLE accounts.monzo_webhook_log (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type   TEXT,
  raw_payload  JSONB,
  processed    BOOLEAN DEFAULT FALSE,
  error        TEXT,
  created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ── INDEXES ──────────────────────────────────────────────────
CREATE INDEX idx_transactions_date        ON accounts.transactions(date DESC);
CREATE INDEX idx_transactions_source      ON accounts.transactions(source);
CREATE INDEX idx_transactions_status      ON accounts.transactions(status);
CREATE INDEX idx_transactions_is_revenue  ON accounts.transactions(is_revenue);
CREATE INDEX idx_filing_calendar_due      ON accounts.filing_calendar(due_date ASC);

-- ── UPDATED_AT TRIGGER ───────────────────────────────────────
CREATE OR REPLACE FUNCTION accounts.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$;

CREATE TRIGGER trg_transactions_updated
  BEFORE UPDATE ON accounts.transactions
  FOR EACH ROW EXECUTE FUNCTION accounts.set_updated_at();

CREATE TRIGGER trg_filing_calendar_updated
  BEFORE UPDATE ON accounts.filing_calendar
  FOR EACH ROW EXECUTE FUNCTION accounts.set_updated_at();

-- ── SEED: FILING CALENDAR ────────────────────────────────────
INSERT INTO accounts.filing_calendar (obligation, due_date, filing_body, notes) VALUES
  ('First Confirmation Statement', '2027-03-01', 'companies_house', 'Statement date: 15 Feb 2027. Annual confirmation of company details. ~£13 filing fee.'),
  ('First Annual Accounts', '2027-11-16', 'companies_house', 'Accounts made up to 28 Feb 2027. Micro-entity format applies. Auto-generation from accounts schema.'),
  ('Corporation Tax Return (CT600)', '2027-11-30', 'hmrc', 'Due 9 months after accounting year end (28 Feb 2027). CT600 data pack auto-generated from transactions.'),
  ('ICO Registration Renewal', '2027-02-01', 'ico', 'ICO Reg No: 00013389720. Annual renewal ~£40 for micro-org. Verify renewal date with ICO.'),
  ('Accounting Year End', '2027-02-28', 'internal', 'AI Lane Limited accounting year end. Begin P&L reconciliation.');

-- ── SEED: COMMON SUPPLIERS ───────────────────────────────────
INSERT INTO accounts.suppliers (name, domain, category) VALUES
  ('Supabase', 'supabase.com', 'infrastructure'),
  ('Anthropic', 'anthropic.com', 'infrastructure'),
  ('GitHub', 'github.com', 'infrastructure'),
  ('Google Workspace', 'workspace.google.com', 'saas'),
  ('Monzo Business', 'monzo.com', 'other'),
  ('UKIPO', 'ipo.gov.uk', 'legal'),
  ('ICO', 'ico.org.uk', 'legal');

-- ── RLS ──────────────────────────────────────────────────────
ALTER TABLE accounts.transactions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts.suppliers         ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts.receipt_images    ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts.vat_tracker       ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts.filing_calendar   ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts.monzo_webhook_log ENABLE ROW LEVEL SECURITY;

-- Service role has full access; no public access
CREATE POLICY "service_role_all_transactions"   ON accounts.transactions      TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service_role_all_suppliers"      ON accounts.suppliers         TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service_role_all_receipts"       ON accounts.receipt_images    TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service_role_all_vat"            ON accounts.vat_tracker       TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service_role_all_filing"         ON accounts.filing_calendar   TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "service_role_all_webhook_log"    ON accounts.monzo_webhook_log TO service_role USING (true) WITH CHECK (true);

