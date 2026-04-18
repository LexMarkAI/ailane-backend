-- Migration: 20260321020729_qtailane_stage3_evidence_functions
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: qtailane_stage3_evidence_functions


-- ============================================================
-- QTAILANE STAGE 3 — MIGRATION 2: EVIDENCE INGESTION FUNCTIONS
-- Authority: QTAILANE-BUILD-001 Stage 3 / QTAILANE-MTH-005 Ch.3
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. INGEST EVIDENCE ITEM
-- Single item ingestion with automatic dedup and source tagging.
-- Called by each evidence connector Edge Function.
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION qtailane_ingest_evidence(
  p_source_name       TEXT,
  p_title             TEXT,
  p_content_summary   TEXT,
  p_content_hash      TEXT,
  p_published_at      TIMESTAMPTZ DEFAULT NULL,
  p_categories        qtailane_event_category[] DEFAULT '{}',
  p_jurisdictions     TEXT[] DEFAULT '{}',
  p_sentiment         FLOAT DEFAULT NULL,
  p_narrative_intensity FLOAT DEFAULT NULL,
  p_source_item_id    TEXT DEFAULT NULL,
  p_is_original       BOOLEAN DEFAULT false,
  p_ancestry_chain    TEXT[] DEFAULT '{}',
  p_metadata          JSONB DEFAULT '{}'
)
RETURNS JSONB AS $$
DECLARE
  v_source_id UUID;
  v_source_class qtailane_source_class;
  v_existing_id UUID;
  v_item_id UUID;
BEGIN
  -- 1. Resolve source
  SELECT id, source_class INTO v_source_id, v_source_class
  FROM qtailane_evidence_sources
  WHERE source_name = p_source_name AND is_active = true
  LIMIT 1;
  
  IF v_source_id IS NULL THEN
    RETURN jsonb_build_object('status', 'error', 'reason', 'Unknown source: ' || p_source_name);
  END IF;

  -- 2. Deduplication check via content hash
  SELECT id INTO v_existing_id
  FROM qtailane_evidence_items
  WHERE content_hash = p_content_hash
  LIMIT 1;
  
  IF v_existing_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'status', 'duplicate',
      'existing_id', v_existing_id,
      'content_hash', p_content_hash
    );
  END IF;

  -- 3. Insert evidence item
  INSERT INTO qtailane_evidence_items (
    source_id, source_class, source_item_id,
    title, content_summary, content_hash,
    relevance_categories, relevance_jurisdictions,
    sentiment_score, narrative_intensity,
    is_original_reporting, source_ancestry_chain,
    published_at, raw_metadata
  ) VALUES (
    v_source_id, v_source_class, p_source_item_id,
    p_title, LEFT(p_content_summary, 2000), p_content_hash,
    p_categories, p_jurisdictions,
    p_sentiment, p_narrative_intensity,
    p_is_original, p_ancestry_chain,
    COALESCE(p_published_at, now()), p_metadata
  )
  RETURNING id INTO v_item_id;

  -- 4. Update source statistics
  UPDATE qtailane_evidence_sources
  SET last_ingestion_at = now(),
      total_items_ingested = total_items_ingested + 1
  WHERE id = v_source_id;

  -- 5. Audit
  INSERT INTO qtailane_audit_log (action, action_category, severity, actor_type, actor_id, target_type, target_id, detail)
  VALUES ('EVIDENCE_INGESTED', 'INFERENCE', 'INFO', 'SYSTEM', 'evidence_ingester', 'evidence_item', v_item_id,
    jsonb_build_object('source', p_source_name, 'class', v_source_class::TEXT, 'is_original', p_is_original,
      'categories', p_categories::TEXT[], 'hash', p_content_hash));

  RETURN jsonb_build_object(
    'status', 'ingested',
    'item_id', v_item_id,
    'source_class', v_source_class::TEXT,
    'is_original', p_is_original
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ────────────────────────────────────────────────────────────
-- 2. INDEPENDENCE VERIFIER
-- Given a set of evidence item IDs, determines which items
-- are truly independent vs derived from common ancestry.
-- Returns independence groups. BFC-01 protection.
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION qtailane_verify_independence(
  p_item_ids UUID[]
)
RETURNS TABLE(
  item_id UUID,
  source_name TEXT,
  source_class qtailane_source_class,
  independence_group TEXT,
  is_independent BOOLEAN,
  shared_ancestry_with UUID[]
) AS $$
BEGIN
  RETURN QUERY
  WITH item_sources AS (
    SELECT 
      ei.id AS item_id,
      es.source_name,
      ei.source_class,
      es.independence_group,
      es.parent_source_id,
      ei.source_ancestry_chain
    FROM qtailane_evidence_items ei
    JOIN qtailane_evidence_sources es ON ei.source_id = es.id
    WHERE ei.id = ANY(p_item_ids)
  ),
  ancestry_links AS (
    -- Find items that share a parent source or independence group
    SELECT 
      a.item_id,
      a.source_name,
      a.source_class,
      COALESCE(a.independence_group, a.item_id::TEXT) AS independence_group,
      -- An item is independent if:
      -- 1. Its source has no parent (is_primary)
      -- 2. No other item in the set shares its independence_group
      -- 3. Its ancestry chain doesn't overlap with any other item's
      (a.parent_source_id IS NULL AND
       NOT EXISTS (
         SELECT 1 FROM item_sources b
         WHERE b.item_id != a.item_id
         AND b.independence_group IS NOT NULL
         AND b.independence_group = a.independence_group
       )) AS is_independent,
      ARRAY(
        SELECT b.item_id FROM item_sources b
        WHERE b.item_id != a.item_id
        AND (
          (b.independence_group IS NOT NULL AND b.independence_group = a.independence_group)
          OR (b.parent_source_id IS NOT NULL AND b.parent_source_id = a.parent_source_id)
          OR (a.source_ancestry_chain && b.source_ancestry_chain AND cardinality(a.source_ancestry_chain) > 0)
        )
      ) AS shared_ancestry_with
    FROM item_sources a
  )
  SELECT 
    al.item_id,
    al.source_name,
    al.source_class,
    al.independence_group,
    al.is_independent,
    al.shared_ancestry_with
  FROM ancestry_links al;
END;
$$ LANGUAGE plpgsql;

-- ────────────────────────────────────────────────────────────
-- 3. COMPUTE NARRATIVE STRESS
-- Aggregates evidence flow into narrative stress metrics.
-- Feeds the NS dimension of the regime object.
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION qtailane_compute_narrative_stress(
  p_window_minutes INTEGER DEFAULT 60,
  p_category qtailane_event_category DEFAULT NULL
)
RETURNS FLOAT AS $$
DECLARE
  v_window_start TIMESTAMPTZ;
  v_item_count INTEGER;
  v_source_count INTEGER;
  v_sentiment_stddev FLOAT;
  v_volume_zscore FLOAT;
  v_avg_intensity FLOAT;
  v_rolling_avg_count FLOAT;
  v_rolling_std_count FLOAT;
  v_ns FLOAT;
BEGIN
  v_window_start := now() - (p_window_minutes || ' minutes')::INTERVAL;

  -- Count items and sources in window
  SELECT count(*), count(DISTINCT source_id), 
         COALESCE(stddev(sentiment_score), 0),
         COALESCE(avg(narrative_intensity), 0)
  INTO v_item_count, v_source_count, v_sentiment_stddev, v_avg_intensity
  FROM qtailane_evidence_items
  WHERE ingested_at >= v_window_start
    AND (p_category IS NULL OR p_category = ANY(relevance_categories));

  -- Volume z-score: compare current window to 30-day rolling average
  SELECT COALESCE(avg(item_count), 1), COALESCE(stddev(item_count), 1)
  INTO v_rolling_avg_count, v_rolling_std_count
  FROM qtailane_narrative_stress_snapshots
  WHERE computed_at >= now() - interval '30 days'
    AND window_minutes = p_window_minutes
    AND category IS NOT DISTINCT FROM p_category;

  IF v_rolling_std_count > 0 THEN
    v_volume_zscore := (v_item_count - v_rolling_avg_count) / v_rolling_std_count;
  ELSE
    v_volume_zscore := 0;
  END IF;

  -- Composite NS score:
  -- 40% sentiment polarisation (high stddev = high stress)
  -- 30% volume anomaly (high z-score = unusual volume)
  -- 30% average narrative intensity from items
  v_ns := LEAST(1.0, GREATEST(0.0,
    0.4 * LEAST(1.0, v_sentiment_stddev * 2) +
    0.3 * LEAST(1.0, GREATEST(0.0, v_volume_zscore / 3)) +
    0.3 * COALESCE(v_avg_intensity, 0)
  ));

  -- Store snapshot
  INSERT INTO qtailane_narrative_stress_snapshots (
    category, narrative_stress, source_count, item_count,
    sentiment_divergence, volume_z_score,
    window_start, window_end, window_minutes
  ) VALUES (
    p_category, v_ns, v_source_count, v_item_count,
    v_sentiment_stddev, v_volume_zscore,
    v_window_start, now(), p_window_minutes
  );

  RETURN v_ns;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ────────────────────────────────────────────────────────────
-- 4. EVIDENCE RETENTION ENFORCEMENT
-- Anonymise evidence after 2 years, delete after 5 years.
-- Per QTAILANE-GOV-002 §7.4
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION qtailane_enforce_evidence_retention()
RETURNS JSONB AS $$
DECLARE
  v_anonymised INTEGER := 0;
  v_deleted INTEGER := 0;
BEGIN
  -- Anonymise items older than 2 years: remove source attribution details
  UPDATE qtailane_evidence_items
  SET content_summary = '[ANONYMISED - retention policy]',
      title = '[ANONYMISED]',
      raw_metadata = '{"anonymised": true}'::JSONB,
      source_ancestry_chain = '{}',
      processing_status = 'DISCARDED',
      discarded_reason = 'retention_anonymisation_2yr'
  WHERE ingested_at < now() - interval '2 years'
    AND content_summary != '[ANONYMISED - retention policy]';
  GET DIAGNOSTICS v_anonymised = ROW_COUNT;

  -- Hard delete items older than 5 years
  DELETE FROM qtailane_evidence_items
  WHERE ingested_at < now() - interval '5 years';
  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  -- Audit
  INSERT INTO qtailane_audit_log (action, action_category, severity, actor_type, actor_id, detail)
  VALUES ('EVIDENCE_RETENTION_ENFORCED', 'SYSTEM', 'INFO', 'SYSTEM', 'retention_enforcer',
    jsonb_build_object('anonymised_2yr', v_anonymised, 'deleted_5yr', v_deleted));

  RETURN jsonb_build_object('anonymised', v_anonymised, 'deleted', v_deleted);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ────────────────────────────────────────────────────────────
-- 5. EVIDENCE QUEUE VIEW
-- Items awaiting classification and clustering (Stage 5 consumes this).
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW qtailane_evidence_queue AS
SELECT 
  ei.id,
  ei.source_class,
  es.source_name,
  es.trust_score,
  ei.title,
  ei.content_summary,
  ei.relevance_categories,
  ei.relevance_jurisdictions,
  ei.sentiment_score,
  ei.narrative_intensity,
  ei.is_original_reporting,
  ei.published_at,
  ei.ingested_at,
  ei.processing_status,
  EXTRACT(EPOCH FROM (now() - ei.ingested_at))::INTEGER AS age_seconds
FROM qtailane_evidence_items ei
JOIN qtailane_evidence_sources es ON ei.source_id = es.id
WHERE ei.processing_status IN ('INGESTED', 'CLASSIFIED')
ORDER BY ei.ingested_at DESC;

