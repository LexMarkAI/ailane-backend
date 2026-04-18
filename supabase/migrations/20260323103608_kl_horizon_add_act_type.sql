-- Migration: 20260323103608_kl_horizon_add_act_type
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: kl_horizon_add_act_type


-- Add 'act' to the legislation_type check constraint
-- A bill that receives Royal Assent becomes an Act — the data model must reflect this
ALTER TABLE public.kl_legislative_horizon
    DROP CONSTRAINT kl_legislative_horizon_legislation_type_check;

ALTER TABLE public.kl_legislative_horizon
    ADD CONSTRAINT kl_legislative_horizon_legislation_type_check
    CHECK (legislation_type IN (
        'bill', 'act', 'statutory_instrument', 'commencement_order',
        'consultation', 'code_of_practice', 'eu_retained_amendment'
    ));

COMMENT ON CONSTRAINT kl_legislative_horizon_legislation_type_check
    ON public.kl_legislative_horizon
    IS 'Valid legislation types. Bill becomes Act on Royal Assent. Added act type via kl_horizon_add_act_type migration.';

