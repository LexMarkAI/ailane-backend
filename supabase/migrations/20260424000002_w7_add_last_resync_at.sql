-- ============================================================================
-- AILANE-SPEC-DMSP-002-W7 §13.3 support columns
-- AMD-089 Stage A · CC Build Brief 1 · v1.1 · §2.2
-- Migration: w7_add_last_resync_at
-- Purpose : Add last_resync_at + resync_processed_date columns to
--           tribunal_decisions to support the §13.3 Channel A / Channel B
--           HMCTS resync cadence and the batched self-chaining EF pattern
--           (COP P1-3/P1-4 resolution).
--           COP P1-5: all CREATE INDEX statements use IF NOT EXISTS so this
--           migration is re-run-safe if Stage A must be re-applied after
--           partial rollback.
-- Brief    : AILANE-CC-BRIEF-001 v1.1 (ratified CEO-RAT-AMD-089, 24 Apr 2026)
-- Scope    : Day-zero clean slate — Chairman §0.1 step 8 confirms all six
--           candidate index names absent prior to apply.
-- ============================================================================

-- §13.3 last_resync_at (nullable; NULL indicates "never resynced"; populated
-- by the resync EF on each run regardless of change-detection outcome).
ALTER TABLE public.tribunal_decisions
    ADD COLUMN IF NOT EXISTS last_resync_at timestamptz NULL;

-- §13.3 daily-progress tracking column (supports batched self-chaining resync
-- EF per COP P1-3/P1-4 resolution). Permits selectors to exclude rows already
-- processed in the current day without tracking server-side session state.
ALTER TABLE public.tribunal_decisions
    ADD COLUMN IF NOT EXISTS resync_processed_date date NULL;

-- Index to accelerate Channel A oldest-first selection
CREATE INDEX IF NOT EXISTS idx_tribunal_decisions_last_resync_at
    ON public.tribunal_decisions (last_resync_at NULLS FIRST);

-- Index to accelerate Channel B recent-decision cohort selection
-- COALESCE(decision_date, scraped_at::date) is the Channel B date predicate
-- (spec §13.3: "decision_date (or, where absent, ingested_at)" — scraped_at
-- is the estate's functional analogue of ingested_at)
CREATE INDEX IF NOT EXISTS idx_tribunal_decisions_decision_date
    ON public.tribunal_decisions (decision_date DESC NULLS LAST);
CREATE INDEX IF NOT EXISTS idx_tribunal_decisions_scraped_at
    ON public.tribunal_decisions (scraped_at DESC);

-- Index to accelerate "unprocessed today" filter on batched resync selectors
CREATE INDEX IF NOT EXISTS idx_tribunal_decisions_resync_processed_date
    ON public.tribunal_decisions (resync_processed_date);
