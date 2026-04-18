-- Migration: 20260307033640_tribunal_enrichment_deep_fields
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: tribunal_enrichment_deep_fields


ALTER TABLE tribunal_enrichment

-- Claimant profile
ADD COLUMN IF NOT EXISTS claimant_gender           TEXT CHECK (claimant_gender IN ('male','female','unknown')),
ADD COLUMN IF NOT EXISTS claimant_age_band         TEXT CHECK (claimant_age_band IN ('under_25','25_34','35_44','45_54','55_64','65_plus','unknown')),
ADD COLUMN IF NOT EXISTS claimant_protected_chars  TEXT[],  -- array: age, disability, race, sex, religion, pregnancy, marriage, orientation, gender_reassignment

-- Employment context
ADD COLUMN IF NOT EXISTS length_of_service_months  INTEGER,
ADD COLUMN IF NOT EXISTS employment_start_date      DATE,
ADD COLUMN IF NOT EXISTS dismissal_date             DATE,
ADD COLUMN IF NOT EXISTS dismissal_type             TEXT CHECK (dismissal_type IN (
                            'actual_dismissal','constructive_dismissal','redundancy',
                            'expiry_fixed_term','retirement','resignation','unknown'
                          )),
ADD COLUMN IF NOT EXISTS notice_paid                BOOLEAN,
ADD COLUMN IF NOT EXISTS notice_weeks               NUMERIC(5,1),

-- Claim detail
ADD COLUMN IF NOT EXISTS claims_brought             TEXT[],  -- all claim types in this case
ADD COLUMN IF NOT EXISTS primary_claim              TEXT,    -- dominant claim
ADD COLUMN IF NOT EXISTS statutory_breaches         TEXT[],  -- specific Acts/Regs cited
ADD COLUMN IF NOT EXISTS precedent_cases_cited      TEXT[],  -- case references cited by judge
ADD COLUMN IF NOT EXISTS acas_certificate           BOOLEAN, -- early conciliation attempted
ADD COLUMN IF NOT EXISTS acas_certificate_number    TEXT,

-- Judgment quality signals
ADD COLUMN IF NOT EXISTS judge_found_credible       TEXT CHECK (judge_found_credible IN (
                            'claimant','respondent','both','neither','unknown'
                          )),
ADD COLUMN IF NOT EXISTS judgment_sentiment         TEXT CHECK (judgment_sentiment IN (
                            'strongly_claimant','mildly_claimant','neutral',
                            'mildly_respondent','strongly_respondent','unknown'
                          )),
ADD COLUMN IF NOT EXISTS contributory_fault_pct     INTEGER, -- % reduction for claimant conduct
ADD COLUMN IF NOT EXISTS polkey_reduction_pct       INTEGER, -- % reduction for procedural fairness
ADD COLUMN IF NOT EXISTS appeal_mentioned           BOOLEAN DEFAULT FALSE,

-- Employer conduct flags
ADD COLUMN IF NOT EXISTS disciplinary_process_followed  BOOLEAN,
ADD COLUMN IF NOT EXISTS investigation_conducted        BOOLEAN,
ADD COLUMN IF NOT EXISTS appeal_offered                 BOOLEAN,
ADD COLUMN IF NOT EXISTS without_prejudice_discussed    BOOLEAN,

-- Settlement intelligence  
ADD COLUMN IF NOT EXISTS settlement_amount          NUMERIC(12,2),
ADD COLUMN IF NOT EXISTS cot3_agreement             BOOLEAN DEFAULT FALSE,  -- ACAS COT3 settlement
ADD COLUMN IF NOT EXISTS tomlin_order               BOOLEAN DEFAULT FALSE,

-- Additional award components
ADD COLUMN IF NOT EXISTS notice_pay_award           NUMERIC(12,2),
ADD COLUMN IF NOT EXISTS holiday_pay_award          NUMERIC(12,2),
ADD COLUMN IF NOT EXISTS arrears_of_pay             NUMERIC(12,2),
ADD COLUMN IF NOT EXISTS uplift_award               NUMERIC(12,2),  -- ACAS uplift
ADD COLUMN IF NOT EXISTS personal_injury_award      NUMERIC(12,2),

-- Wider intelligence
ADD COLUMN IF NOT EXISTS multiple_claimants         BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS number_of_claimants        INTEGER,
ADD COLUMN IF NOT EXISTS linked_cases               TEXT[],
ADD COLUMN IF NOT EXISTS tribunal_office_location   TEXT,
ADD COLUMN IF NOT EXISTS hearing_format             TEXT CHECK (hearing_format IN (
                            'in_person','remote','hybrid','on_papers','unknown'
                          ));

COMMENT ON TABLE tribunal_enrichment IS
  'Deep intelligence extraction from UK employment tribunal judgment PDFs.
   Schema v2 — expanded fields covering claimant profile, employment context,
   claim detail, judgment quality signals, employer conduct, and full award breakdown.
   Powers CCI Bayesian weighting, ACEI category scoring, and EPLI data licensing.';

