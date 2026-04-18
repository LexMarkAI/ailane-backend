-- Migration: 20260409005118_tribunal_enrichment_comprehensive_schema_v2
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: tribunal_enrichment_comprehensive_schema_v2


-- ==============================================================
-- AILANE: tribunal_enrichment Comprehensive Schema Enhancement
-- Migration: tribunal_enrichment_comprehensive_schema_v2
-- Authority: CEO instruction 9 April 2026
-- Governed by: AILANE-AMD-REG-001 (AMD-040 CMA-001 governing spec)
-- Total new columns: 82 across Domains A-J
-- ==============================================================

-- DOMAIN A: Missing SKILL.md Columns (16)
ALTER TABLE tribunal_enrichment
  ADD COLUMN IF NOT EXISTS acei_primary_category integer,
  ADD COLUMN IF NOT EXISTS acei_secondary_categories integer[],
  ADD COLUMN IF NOT EXISTS respondent_sector text,
  ADD COLUMN IF NOT EXISTS respondent_size_band text,
  ADD COLUMN IF NOT EXISTS panel_hearing boolean,
  ADD COLUMN IF NOT EXISTS lay_member_count integer,
  ADD COLUMN IF NOT EXISTS settlement_stage text,
  ADD COLUMN IF NOT EXISTS remedy_type text,
  ADD COLUMN IF NOT EXISTS just_and_equitable_reduction boolean,
  ADD COLUMN IF NOT EXISTS employer_admission boolean,
  ADD COLUMN IF NOT EXISTS judgment_date date,
  ADD COLUMN IF NOT EXISTS costs_awarded boolean,
  ADD COLUMN IF NOT EXISTS deposit_order boolean,
  ADD COLUMN IF NOT EXISTS strike_out_attempted boolean,
  ADD COLUMN IF NOT EXISTS unless_order boolean,
  ADD COLUMN IF NOT EXISTS restricted_reporting_order boolean;

-- DOMAIN B: Financial & Award Granularity (12)
ALTER TABLE tribunal_enrichment
  ADD COLUMN IF NOT EXISTS claimant_weekly_pay_stated numeric,
  ADD COLUMN IF NOT EXISTS statutory_cap_applied boolean,
  ADD COLUMN IF NOT EXISTS pension_loss_award numeric,
  ADD COLUMN IF NOT EXISTS future_loss_weeks integer,
  ADD COLUMN IF NOT EXISTS past_loss_weeks integer,
  ADD COLUMN IF NOT EXISTS grossing_up_applied boolean,
  ADD COLUMN IF NOT EXISTS protective_award_amount numeric,
  ADD COLUMN IF NOT EXISTS statutory_redundancy_payment numeric,
  ADD COLUMN IF NOT EXISTS acas_uplift_pct integer,
  ADD COLUMN IF NOT EXISTS acas_reduction_pct integer,
  ADD COLUMN IF NOT EXISTS s12a_financial_penalty numeric,
  ADD COLUMN IF NOT EXISTS schedule_2_award numeric;

-- DOMAIN C: Party & Employer Intelligence (9)
ALTER TABLE tribunal_enrichment
  ADD COLUMN IF NOT EXISTS claimant_job_title text,
  ADD COLUMN IF NOT EXISTS claimant_salary_annual numeric,
  ADD COLUMN IF NOT EXISTS respondent_is_public_body boolean,
  ADD COLUMN IF NOT EXISTS respondent_is_nhs boolean,
  ADD COLUMN IF NOT EXISTS respondent_postcode_area text,
  ADD COLUMN IF NOT EXISTS respondent_employee_count_stated integer,
  ADD COLUMN IF NOT EXISTS tupe_transfer_confirmed boolean,
  ADD COLUMN IF NOT EXISTS second_respondent_present boolean,
  ADD COLUMN IF NOT EXISTS personal_liability_found boolean;

-- DOMAIN D: Procedural & Case Management Intelligence (15)
ALTER TABLE tribunal_enrichment
  ADD COLUMN IF NOT EXISTS judgment_word_count integer,
  ADD COLUMN IF NOT EXISTS judgment_reserved boolean,
  ADD COLUMN IF NOT EXISTS oral_evidence_heard boolean,
  ADD COLUMN IF NOT EXISTS witness_count_claimant integer,
  ADD COLUMN IF NOT EXISTS witness_count_respondent integer,
  ADD COLUMN IF NOT EXISTS list_of_issues_produced boolean,
  ADD COLUMN IF NOT EXISTS preliminary_hearings_count integer,
  ADD COLUMN IF NOT EXISTS respondent_conceded_liability boolean,
  ADD COLUMN IF NOT EXISTS claimant_failed_to_mitigate boolean,
  ADD COLUMN IF NOT EXISTS wasted_costs_order boolean,
  ADD COLUMN IF NOT EXISTS without_prejudice_save_as_to_costs boolean,
  ADD COLUMN IF NOT EXISTS time_extension_granted boolean,
  ADD COLUMN IF NOT EXISTS hearing_start_date date,
  ADD COLUMN IF NOT EXISTS claim_lodged_date date,
  ADD COLUMN IF NOT EXISTS remedy_hearing_date date;

-- DOMAIN E: Discrimination-Specific Intelligence (8)
ALTER TABLE tribunal_enrichment
  ADD COLUMN IF NOT EXISTS protected_characteristic_primary text,
  ADD COLUMN IF NOT EXISTS direct_discrimination_found boolean,
  ADD COLUMN IF NOT EXISTS indirect_discrimination_found boolean,
  ADD COLUMN IF NOT EXISTS harassment_found boolean,
  ADD COLUMN IF NOT EXISTS victimisation_found boolean,
  ADD COLUMN IF NOT EXISTS reasonable_adjustments_breach boolean,
  ADD COLUMN IF NOT EXISTS disability_agreed boolean,
  ADD COLUMN IF NOT EXISTS comparator_type text;

-- DOMAIN F: Representation & Credibility Quality Signals (4)
ALTER TABLE tribunal_enrichment
  ADD COLUMN IF NOT EXISTS judge_criticised_claimant boolean,
  ADD COLUMN IF NOT EXISTS judge_criticised_respondent boolean,
  ADD COLUMN IF NOT EXISTS judge_criticised_claimant_rep boolean,
  ADD COLUMN IF NOT EXISTS judge_criticised_respondent_rep boolean;

-- DOMAIN G: Whistleblowing-Specific Intelligence (3)
ALTER TABLE tribunal_enrichment
  ADD COLUMN IF NOT EXISTS qualifying_disclosure_found boolean,
  ADD COLUMN IF NOT EXISTS public_interest_test_passed boolean,
  ADD COLUMN IF NOT EXISTS nda_in_dispute boolean;

-- DOMAIN H: JIPA Normalisation Fields (4)
ALTER TABLE tribunal_enrichment
  ADD COLUMN IF NOT EXISTS judge_canonical text,
  ADD COLUMN IF NOT EXISTS judge_id text,
  ADD COLUMN IF NOT EXISTS citation_count integer,
  ADD COLUMN IF NOT EXISTS statutory_breach_count integer;

-- DOMAIN I: ERA 2025 / Fair Work Agency Intelligence (3)
ALTER TABLE tribunal_enrichment
  ADD COLUMN IF NOT EXISTS fair_work_agency_relevant boolean,
  ADD COLUMN IF NOT EXISTS fire_and_rehire_tactics boolean,
  ADD COLUMN IF NOT EXISTS zero_hours_contract_involved boolean;

-- DOMAIN J: Additional Critical Fields (8)
ALTER TABLE tribunal_enrichment
  ADD COLUMN IF NOT EXISTS dismissal_reason_given text,
  ADD COLUMN IF NOT EXISTS dismissal_reason_accepted boolean,
  ADD COLUMN IF NOT EXISTS working_pattern text,
  ADD COLUMN IF NOT EXISTS remote_working_dispute boolean,
  ADD COLUMN IF NOT EXISTS job_role_category text,
  ADD COLUMN IF NOT EXISTS restrictive_covenant_in_dispute boolean,
  ADD COLUMN IF NOT EXISTS probationary_period_active boolean,
  ADD COLUMN IF NOT EXISTS acei_classification_confidence numeric;

-- ==============================================================
-- CHECK CONSTRAINTS (NOT VALID = skip scan of existing NULL rows)
-- ==============================================================
ALTER TABLE tribunal_enrichment
  ADD CONSTRAINT chk_acei_primary_category
    CHECK (acei_primary_category BETWEEN 1 AND 12) NOT VALID,
  ADD CONSTRAINT chk_lay_member_count
    CHECK (lay_member_count BETWEEN 0 AND 2) NOT VALID,
  ADD CONSTRAINT chk_respondent_size_band
    CHECK (respondent_size_band IN ('micro','small','medium','large','enterprise','public_sector','unknown')) NOT VALID,
  ADD CONSTRAINT chk_settlement_stage
    CHECK (settlement_stage IN ('pre_claim','post_claim_pre_hearing','at_hearing','post_judgment','unknown')) NOT VALID,
  ADD CONSTRAINT chk_remedy_type
    CHECK (remedy_type IN ('compensation','reinstatement','re_engagement','declaration','recommendation','none','unknown')) NOT VALID,
  ADD CONSTRAINT chk_protected_characteristic_primary
    CHECK (protected_characteristic_primary IN ('age','disability','gender_reassignment','marriage_civil_partnership','pregnancy_maternity','race','religion_belief','sex','sexual_orientation','none','unknown')) NOT VALID,
  ADD CONSTRAINT chk_comparator_type
    CHECK (comparator_type IN ('actual','hypothetical','none','unknown')) NOT VALID,
  ADD CONSTRAINT chk_working_pattern
    CHECK (working_pattern IN ('full_time','part_time','variable','unknown')) NOT VALID,
  ADD CONSTRAINT chk_job_role_category
    CHECK (job_role_category IN ('management','professional','manual','clerical','service','technical','executive','unknown')) NOT VALID,
  ADD CONSTRAINT chk_dismissal_reason_given
    CHECK (dismissal_reason_given IN ('conduct','capability','redundancy','statutory_illegality','some_other_substantial_reason','not_stated','unknown')) NOT VALID,
  ADD CONSTRAINT chk_acas_uplift_pct
    CHECK (acas_uplift_pct BETWEEN 0 AND 25) NOT VALID,
  ADD CONSTRAINT chk_acas_reduction_pct
    CHECK (acas_reduction_pct BETWEEN 0 AND 25) NOT VALID,
  ADD CONSTRAINT chk_acei_classification_confidence
    CHECK (acei_classification_confidence BETWEEN 0 AND 1) NOT VALID;

