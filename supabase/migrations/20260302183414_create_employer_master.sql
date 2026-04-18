-- Migration: 20260302183414_create_employer_master
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_employer_master


-- AIE Migration 1: Employer Master Table
-- Constitutional Reference: CCI Art. V §5.1.1 (Tier P Data)
CREATE TABLE IF NOT EXISTS employer_master (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  
  raw_name text NOT NULL,
  normalised_name text,
  companies_house_number text UNIQUE,
  companies_house_status text,
  
  sic_codes text[],
  sic_primary text,
  acei_sector text,
  acei_sector_multiplier numeric(4,2),
  
  registered_address jsonb,
  jurisdiction_region text,
  acei_jurisdiction_multiplier numeric(4,2),
  
  headcount_estimate integer,
  headcount_band text CHECK (headcount_band IN (
    'micro_1_9','small_10_49','medium_50_249',
    'large_250_499','enterprise_500_plus'
  )),
  headcount_source text,
  
  officers jsonb DEFAULT '[]'::jsonb,
  
  normalisation_method text,
  normalisation_confidence numeric(3,2),
  match_aliases text[],
  
  ch_last_fetched timestamptz,
  ch_fetch_status text DEFAULT 'pending'
);

CREATE INDEX idx_em_ch_number ON employer_master(companies_house_number);
CREATE INDEX idx_em_normalised ON employer_master(normalised_name);
CREATE INDEX idx_em_sector ON employer_master(acei_sector);
CREATE INDEX idx_em_jurisdiction ON employer_master(jurisdiction_region);
CREATE INDEX idx_em_headcount ON employer_master(headcount_band);
CREATE INDEX idx_em_fetch_status ON employer_master(ch_fetch_status);

COMMENT ON TABLE employer_master IS 'AIE: Canonical employer identity table. Tier P data only (CCI Art. V §5.1.1).';

