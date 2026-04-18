-- Migration: 20260418201509_amd067_haiku_batch_pipeline
-- Purpose:   Net-new objects for AMD-067 Haiku Batch enrichment pipeline, layered
--            on top of the AMD-066 backfill. Creates:
--              * tribunal_enrichment_batches            (Haiku Batch API job tracking)
--              * tribunal_enrichment_qa_sample_queue    (Opus 4.7 cross-model QA pool)
--              * tribunal_enrichment_extraction_model_check CHECK constraint
-- Governed by: AILANE-CC-BRIEF-HAIKU-BATCH-001 Addendum A §A.2
-- Depends on: 20260418201409_backfill_amd066_enrichment_pipeline.sql
-- Idempotent: uses IF NOT EXISTS for tables/indexes; constraint guarded with
--             a DO block so the CHECK is only added when missing.
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- §A.2.1  tribunal_enrichment_batches
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tribunal_enrichment_batches (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  anthropic_batch_id  text        NOT NULL UNIQUE,
  status              text        NOT NULL DEFAULT 'in_progress'
                                  CHECK (status IN ('in_progress','ended','canceled','expired','failed')),
  submitted_at        timestamptz NOT NULL DEFAULT now(),
  ended_at            timestamptz,
  request_count       integer     NOT NULL DEFAULT 0,
  succeeded_count     integer     NOT NULL DEFAULT 0,
  errored_count       integer     NOT NULL DEFAULT 0,
  canceled_count      integer     NOT NULL DEFAULT 0,
  expired_count       integer     NOT NULL DEFAULT 0,
  result_url          text,
  qa_sample_size      integer     NOT NULL DEFAULT 0,
  qa_sample_model     text,
  qa_discrepancy_pct  numeric(5,2),
  metadata            jsonb       NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS idx_teb_status   ON public.tribunal_enrichment_batches (status);
CREATE INDEX IF NOT EXISTS idx_teb_ended_at ON public.tribunal_enrichment_batches (ended_at);

-- ------------------------------------------------------------------------------
-- §A.2.2  tribunal_enrichment_qa_sample_queue
-- ------------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.tribunal_enrichment_qa_sample_queue (
  id                 uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id           uuid        NOT NULL
                                 REFERENCES public.tribunal_enrichment_batches(id) ON DELETE CASCADE,
  enrichment_id      uuid        NOT NULL
                                 REFERENCES public.tribunal_enrichment(id) ON DELETE CASCADE,
  decision_id        uuid        NOT NULL
                                 REFERENCES public.tribunal_decisions(id) ON DELETE CASCADE,
  sampling_stratum   text        NOT NULL
                                 CHECK (sampling_stratum IN (
                                   'low_confidence','closed_vocab','check_borderline','random'
                                 )),
  haiku_payload      jsonb       NOT NULL,
  opus_payload       jsonb,
  opus_model         text,
  discrepancies      text[],
  reviewed_at        timestamptz,
  review_outcome     text        CHECK (review_outcome IS NULL OR review_outcome IN (
                                   'agree','minor_disagree','material_disagree','escalated_to_human'
                                 )),
  queued_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_teqsq_batch_id    ON public.tribunal_enrichment_qa_sample_queue (batch_id);
CREATE INDEX IF NOT EXISTS idx_teqsq_reviewed_at ON public.tribunal_enrichment_qa_sample_queue (reviewed_at)
  WHERE reviewed_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_teqsq_stratum     ON public.tribunal_enrichment_qa_sample_queue (sampling_stratum);

-- ------------------------------------------------------------------------------
-- §A.2.3  New CHECK on tribunal_enrichment.extraction_model
-- ------------------------------------------------------------------------------
-- Live DB column is currently all-NULL, so no cleanup is required before adding
-- the constraint. Guarded with a DO block so re-running the migration is safe.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'tribunal_enrichment_extraction_model_check'
      AND conrelid = 'public.tribunal_enrichment'::regclass
  ) THEN
    ALTER TABLE public.tribunal_enrichment
      ADD CONSTRAINT tribunal_enrichment_extraction_model_check
      CHECK (extraction_model IS NULL OR extraction_model IN (
        'claude-haiku-4-5-20251001',
        'claude-opus-4-6',
        'claude-opus-4-7',
        'manual-human'
      ));
  END IF;
END
$$;
