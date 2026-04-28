-- Phase 1 of AILANE-CC-BRIEF-IS-SOLE-TRADER-001
-- Deterministic seed from existing ch_fetch_status taxonomy.
-- Bucket 1: confirmed FALSE (companies / statutory bodies)
-- Bucket 2: confirmed FALSE via canonical inheritance (skipped_duplicate)
-- Bucket 3: confirmed TRUE (skipped_individual)
-- Unaddressed (NULL): low_confidence, not_found, skipped_insufficient_name -- Phase 2 backfills.

-- Bucket 1: explicit company / statutory body status
UPDATE public.employer_master
SET is_sole_trader = FALSE,
    is_sole_trader_method = 'ch_fetch_status_seed_v1',
    is_sole_trader_confidence = 'HIGH',
    is_sole_trader_classified_at = now()
WHERE ch_fetch_status IN ('verified', 'completed', 'statutory_body_seeded', 'skipped_statutory')
  AND is_sole_trader IS NULL;

-- Bucket 2: skipped_duplicate inherits from canonical
UPDATE public.employer_master d
SET is_sole_trader = FALSE,
    is_sole_trader_method = 'canonical_inheritance',
    is_sole_trader_confidence = 'MEDIUM',
    is_sole_trader_classified_at = now()
FROM public.employer_master c
WHERE d.ch_fetch_status = 'skipped_duplicate'
  AND d.canonical_employer_id = c.id
  AND c.ch_fetch_status IN ('verified', 'completed', 'statutory_body_seeded', 'skipped_statutory')
  AND d.is_sole_trader IS NULL;

-- Bucket 3: skipped_individual is the explicit sole-trader signal
UPDATE public.employer_master
SET is_sole_trader = TRUE,
    is_sole_trader_method = 'ch_fetch_status_seed_v1',
    is_sole_trader_confidence = 'HIGH',
    is_sole_trader_classified_at = now()
WHERE ch_fetch_status = 'skipped_individual'
  AND is_sole_trader IS NULL;

