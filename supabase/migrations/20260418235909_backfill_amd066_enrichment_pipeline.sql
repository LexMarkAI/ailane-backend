-- =============================================================================
-- Backfill: AMD-066 Enrichment Pipeline (RULE 17 source-of-truth parity)
-- =============================================================================
-- AMD-066 was applied to the live database (Supabase project cnbsxwtvazfvzmltkuvx)
-- via Chairman MCP Path A on 2026-04-09 but the RULE 17 source-of-truth backfill
-- to LexMarkAI/ailane-backend was never committed. This migration reproduces the
-- AMD-066 live state idempotently so the repo is on parity with production.
--
-- Governance reference: AILANE-CC-BRIEF-HAIKU-BATCH-001 Addendum A §A.1.
--
-- Coexistence note: the four new tribunal_enrichment columns below live alongside
-- the pre-existing extraction_method (text) and re_enrichment_needed (boolean)
-- columns introduced by 20260409193925_add_enrichment_provenance_tracking.sql.
-- The older columns are intentionally preserved; the Governance-grade transition
-- away from extraction_method is deferred to a future amendment.
--
-- No CHECK constraint is created on extraction_model here — that constraint is
-- introduced by the AMD-067 migration once the Haiku Batch permitted-model set
-- is formalised.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- A.1.1  tribunal_enrichment columns added by AMD-066
-- -----------------------------------------------------------------------------
ALTER TABLE public.tribunal_enrichment
  ADD COLUMN IF NOT EXISTS extraction_model   text,
  ADD COLUMN IF NOT EXISTS needs_reenrichment boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS dual_pass_verified boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS citation_anchored  boolean NOT NULL DEFAULT false;

-- -----------------------------------------------------------------------------
-- A.1.2  enrichment_halt_flag
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- A.1.3  enrichment_in_flight
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.enrichment_in_flight (
  enrichment_id uuid,
  decision_id   uuid        PRIMARY KEY,
  phase         smallint    NOT NULL CHECK (phase IN (1, 2)),
  claimed_at    timestamptz NOT NULL DEFAULT now(),
  claimed_by    text        NOT NULL DEFAULT 'ailane-tribunal-enrichment-continuous'
);

CREATE INDEX IF NOT EXISTS idx_eif_stale
  ON public.enrichment_in_flight (claimed_at);

-- -----------------------------------------------------------------------------
-- A.1.4  tribunal_enrichment_citations
-- -----------------------------------------------------------------------------
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

-- -----------------------------------------------------------------------------
-- A.1.5  tribunal_enrichment_review_queue
-- -----------------------------------------------------------------------------
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

-- =============================================================================
-- End of AMD-066 backfill.
-- =============================================================================
