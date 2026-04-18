-- Migration: 20260418201409_backfill_amd066_enrichment_pipeline
-- Purpose:   RULE 17 source-of-truth backfill to bring the repo into parity with
--            the live Supabase project cnbsxwtvazfvzmltkuvx after AMD-066 was
--            applied via Chairman MCP Path A on 9 April 2026 without a repo commit.
-- Governed by: AILANE-CC-BRIEF-HAIKU-BATCH-001 Addendum A §A.1
-- Idempotent: uses IF NOT EXISTS throughout so re-application is safe.
--
-- Scope: brings AMD-066 objects (columns + 4 satellite tables) into the repo.
--        The older extraction_method and re_enrichment_needed columns are left
--        untouched — live DB carries both sets side-by-side.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- §A.1.1  tribunal_enrichment: AMD-066 columns
-- ------------------------------------------------------------------------------
ALTER TABLE public.tribunal_enrichment
  ADD COLUMN IF NOT EXISTS extraction_model   text,
  ADD COLUMN IF NOT EXISTS needs_reenrichment boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS dual_pass_verified boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS citation_anchored  boolean NOT NULL DEFAULT false;

-- ------------------------------------------------------------------------------
-- §A.1.2  enrichment_halt_flag
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.enrichment_halt_flag (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  reason                text        NOT NULL,
  violating_decision_id uuid,
  rule_broken           text,
  raw_payload           jsonb,
  raised_at             timestamptz NOT NULL DEFAULT now(),
  resolved_at           timestamptz,
  resolved_by           text,
  resolution_notes      text
);

CREATE INDEX IF NOT EXISTS idx_ehf_active
  ON public.enrichment_halt_flag (resolved_at)
  WHERE resolved_at IS NULL;

-- ------------------------------------------------------------------------------
-- §A.1.3  enrichment_in_flight
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.enrichment_in_flight (
  enrichment_id uuid,
  decision_id   uuid        PRIMARY KEY,
  phase         smallint    NOT NULL CHECK (phase IN (1, 2)),
  claimed_at    timestamptz NOT NULL DEFAULT now(),
  claimed_by    text        NOT NULL DEFAULT 'ailane-tribunal-enrichment-continuous'
);

CREATE INDEX IF NOT EXISTS idx_eif_stale
  ON public.enrichment_in_flight (claimed_at);

-- ------------------------------------------------------------------------------
-- §A.1.4  tribunal_enrichment_citations
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tribunal_enrichment_citations (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  enrichment_id       uuid        NOT NULL
                                  REFERENCES public.tribunal_enrichment(id) ON DELETE CASCADE,
  decision_id         uuid        NOT NULL
                                  REFERENCES public.tribunal_decisions(id) ON DELETE CASCADE,
  field_name          text        NOT NULL,
  field_value         text,
  source_quote        text        NOT NULL,
  source_char_offset  integer,
  source_char_length  integer,
  extraction_pass     smallint    NOT NULL DEFAULT 1
                                  CHECK (extraction_pass IN (1, 2)),
  extraction_model    text        NOT NULL,
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_tec_decision_id   ON public.tribunal_enrichment_citations (decision_id);
CREATE INDEX IF NOT EXISTS idx_tec_enrichment_id ON public.tribunal_enrichment_citations (enrichment_id);
CREATE INDEX IF NOT EXISTS idx_tec_field_name    ON public.tribunal_enrichment_citations (field_name);

-- ------------------------------------------------------------------------------
-- §A.1.5  tribunal_enrichment_review_queue
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tribunal_enrichment_review_queue (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_id        uuid        NOT NULL
                                 REFERENCES public.tribunal_decisions(id) ON DELETE CASCADE,
  enrichment_id      uuid        REFERENCES public.tribunal_enrichment(id) ON DELETE SET NULL,
  review_reason      text        NOT NULL
                                 CHECK (review_reason IN (
                                   'dual_pass_mismatch',
                                   'low_confidence_below_floor',
                                   'closed_vocab_ambiguous',
                                   'check_constraint_borderline',
                                   'citation_anchor_missing',
                                   'other'
                                 )),
  pass_1_payload     jsonb       NOT NULL,
  pass_2_payload     jsonb,
  mismatched_fields  text[],
  extraction_model   text        NOT NULL,
  flagged_at         timestamptz NOT NULL DEFAULT now(),
  resolved_at        timestamptz,
  resolved_by        text,
  resolution         text        CHECK (resolution IS NULL OR resolution IN (
                                   'accepted_pass_1',
                                   'accepted_pass_2',
                                   'human_corrected',
                                   'discarded_insufficient_source'
                                 ))
);

CREATE INDEX IF NOT EXISTS idx_terq_decision_id  ON public.tribunal_enrichment_review_queue (decision_id);
CREATE INDEX IF NOT EXISTS idx_terq_reason       ON public.tribunal_enrichment_review_queue (review_reason);
CREATE INDEX IF NOT EXISTS idx_terq_resolved_at  ON public.tribunal_enrichment_review_queue (resolved_at)
  WHERE resolved_at IS NULL;
