-- AILANE GNYO-001 — Migration A
-- Add incremental-sync high-watermark column to pipeline_registry.
-- Safe: nullable, no backfill needed (null => first-run 90d backfill semantics).

ALTER TABLE public.pipeline_registry
  ADD COLUMN IF NOT EXISTS last_high_watermark_ts timestamptz;

COMMENT ON COLUMN public.pipeline_registry.last_high_watermark_ts IS
  'Maximum source-side public_timestamp observed by the last successful run. Pipelines set filter_public_timestamp=from:(last_high_watermark_ts - overlap) on subsequent runs. Null => first-run backfill.';
