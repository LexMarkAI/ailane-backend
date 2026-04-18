-- Migration: 20260309215128_ailane_intelligence_feedback_and_clause_fingerprinting
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: ailane_intelligence_feedback_and_clause_fingerprinting


-- ================================================================
-- AILANE INTELLIGENCE INFRASTRUCTURE v1.0
-- Migration: ailane_intelligence_feedback_and_clause_fingerprinting
-- Purpose: Foundation for the AiLane Agent learning loop.
-- ================================================================

-- ── 1. FINDING FEEDBACK ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS finding_feedback (
    id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    finding_id             uuid NOT NULL REFERENCES compliance_findings(id) ON DELETE CASCADE,
    upload_id              uuid NOT NULL REFERENCES compliance_uploads(id) ON DELETE CASCADE,
    requirement_id         uuid REFERENCES regulatory_requirements(id),
    ai_severity            text NOT NULL CHECK (ai_severity IN ('compliant','minor','major','critical')),
    ai_finding_detail      text,
    ai_remediation         text,
    ai_model_version       text,
    verified_severity      text CHECK (verified_severity IN ('compliant','minor','major','critical')),
    verified_by            text CHECK (verified_by IN ('internal_review','solicitor_partner','client_confirmed','ailane_qa')),
    reviewer_notes         text,
    confidence             text NOT NULL DEFAULT 'medium' CHECK (confidence IN ('high','medium','low')),
    is_training_candidate  boolean NOT NULL DEFAULT false,
    severity_agreed        boolean GENERATED ALWAYS AS (ai_severity = verified_severity) STORED,
    created_at             timestamptz NOT NULL DEFAULT now(),
    updated_at             timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_finding_feedback_finding   ON finding_feedback(finding_id);
CREATE INDEX IF NOT EXISTS idx_finding_feedback_upload    ON finding_feedback(upload_id);
CREATE INDEX IF NOT EXISTS idx_finding_feedback_req       ON finding_feedback(requirement_id);
CREATE INDEX IF NOT EXISTS idx_finding_feedback_agreed    ON finding_feedback(severity_agreed);
CREATE INDEX IF NOT EXISTS idx_finding_feedback_training  ON finding_feedback(is_training_candidate) WHERE is_training_candidate = true;
CREATE INDEX IF NOT EXISTS idx_finding_feedback_model     ON finding_feedback(ai_model_version);

COMMENT ON TABLE finding_feedback IS 'Human verification layer over AI compliance findings. severity_agreed=false rows are correction events — the most valuable training examples for AiLane Agent fine-tuning.';
COMMENT ON COLUMN finding_feedback.severity_agreed IS 'Generated: true when AI and human agree. false = correction event = high-value training signal.';
COMMENT ON COLUMN finding_feedback.is_training_candidate IS 'Flagged by QA when example is high-quality enough for fine-tuning corpus inclusion.';

-- ── 2. CLAUSE FINGERPRINTS ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS clause_fingerprints (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    fingerprint_hash      text NOT NULL,
    requirement_id        uuid REFERENCES regulatory_requirements(id),
    clause_category       text NOT NULL,
    statutory_ref         text NOT NULL,
    canonical_text        text,
    normalised_text       text,
    compliant_count       integer NOT NULL DEFAULT 0,
    minor_count           integer NOT NULL DEFAULT 0,
    major_count           integer NOT NULL DEFAULT 0,
    critical_count        integer NOT NULL DEFAULT 0,
    total_occurrences     integer NOT NULL DEFAULT 0,
    heat_score            numeric(5,3) NOT NULL DEFAULT 0,
    context_breakdown     jsonb NOT NULL DEFAULT '{}',
    tribunal_signal_count integer NOT NULL DEFAULT 0,
    first_seen_at         timestamptz NOT NULL DEFAULT now(),
    last_seen_at          timestamptz NOT NULL DEFAULT now(),
    UNIQUE(fingerprint_hash, requirement_id)
);

CREATE INDEX IF NOT EXISTS idx_clause_fp_hash      ON clause_fingerprints(fingerprint_hash);
CREATE INDEX IF NOT EXISTS idx_clause_fp_req       ON clause_fingerprints(requirement_id);
CREATE INDEX IF NOT EXISTS idx_clause_fp_category  ON clause_fingerprints(clause_category);
CREATE INDEX IF NOT EXISTS idx_clause_fp_heat      ON clause_fingerprints(heat_score DESC);
CREATE INDEX IF NOT EXISTS idx_clause_fp_critical  ON clause_fingerprints(critical_count DESC) WHERE critical_count > 0;

COMMENT ON TABLE clause_fingerprints IS 'Empirical clause pattern library. heat_score=(critical*4+major*2+minor*1)/total. Range 0.0–4.0. Auto-populated by trigger. Core input to AiLane Agent and Clause Heat Map.';
COMMENT ON COLUMN clause_fingerprints.heat_score IS 'Weighted severity: (critical*4+major*2+minor*1)/total_occurrences. 0=always compliant, 4=always critical.';

-- ── 3. TRIBUNAL CLAUSE SIGNALS ──────────────────────────────────
CREATE TABLE IF NOT EXISTS tribunal_clause_signals (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    clause_category     text NOT NULL,
    statutory_ref       text NOT NULL,
    acei_category       text NOT NULL,
    total_cases         integer NOT NULL DEFAULT 0,
    claimant_won        integer NOT NULL DEFAULT 0,
    claimant_lost       integer NOT NULL DEFAULT 0,
    settled             integer NOT NULL DEFAULT 0,
    avg_compensation    numeric,
    max_compensation    numeric,
    total_compensation  numeric,
    date_from           date,
    date_to             date,
    claimant_win_rate   numeric(5,3),
    last_computed_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE(clause_category, statutory_ref, acei_category)
);

CREATE INDEX IF NOT EXISTS idx_tcs_category  ON tribunal_clause_signals(clause_category);
CREATE INDEX IF NOT EXISTS idx_tcs_statutory ON tribunal_clause_signals(statutory_ref);
CREATE INDEX IF NOT EXISTS idx_tcs_win_rate  ON tribunal_clause_signals(claimant_win_rate DESC);

COMMENT ON TABLE tribunal_clause_signals IS 'Outcome intelligence from 130k tribunal decisions linked to compliance clause categories. Phase 2 will link individual clause fingerprints to specific case citations via tribunal PDF extraction.';

-- ── 4. MODEL PERFORMANCE LOG ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS model_performance_log (
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    engine_version       text NOT NULL,
    model_name           text NOT NULL,
    requirement_id       uuid REFERENCES regulatory_requirements(id),
    total_findings       integer NOT NULL DEFAULT 0,
    verified_findings    integer NOT NULL DEFAULT 0,
    severity_match_rate  numeric(5,3),
    over_critical_rate   numeric(5,3),
    under_critical_rate  numeric(5,3),
    period_start         date NOT NULL,
    period_end           date,
    created_at           timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mpl_engine ON model_performance_log(engine_version);
CREATE INDEX IF NOT EXISTS idx_mpl_model  ON model_performance_log(model_name);

COMMENT ON TABLE model_performance_log IS 'AI quality tracking across engine versions. under_critical_rate is the critical metric — missed criticals expose clients to undisclosed legal risk.';

-- ── 5. HELPER FUNCTION ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION generate_clause_fingerprint(clause_text text)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
    SELECT md5(lower(regexp_replace(regexp_replace(trim(clause_text),'[^a-zA-Z0-9 ]','','g'),'\s+',' ','g')))
$$;

COMMENT ON FUNCTION generate_clause_fingerprint IS 'Normalises clause text and returns md5 hash. Deterministic. Same clause always produces same fingerprint.';

-- ── 6. TRIGGER: auto-upsert clause fingerprints on finding insert ─
CREATE OR REPLACE FUNCTION upsert_clause_fingerprint()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_hash       text;
    v_normalised text;
BEGIN
    IF NEW.clause_text IS NULL
       OR NEW.clause_text IN ('[Not analysed]','[Not returned in analysis]','[Not found in document]','[Not reviewed]')
       OR length(trim(NEW.clause_text)) < 20
    THEN RETURN NEW; END IF;

    v_normalised := lower(regexp_replace(regexp_replace(trim(NEW.clause_text),'[^a-zA-Z0-9 ]','','g'),'\s+',' ','g'));
    v_hash       := md5(v_normalised);

    INSERT INTO clause_fingerprints (
        fingerprint_hash, requirement_id, clause_category, statutory_ref,
        canonical_text, normalised_text,
        compliant_count, minor_count, major_count, critical_count,
        total_occurrences, heat_score, first_seen_at, last_seen_at
    ) VALUES (
        v_hash, NEW.requirement_id, NEW.clause_category, NEW.statutory_ref,
        NEW.clause_text, v_normalised,
        CASE WHEN NEW.severity='compliant' THEN 1 ELSE 0 END,
        CASE WHEN NEW.severity='minor'     THEN 1 ELSE 0 END,
        CASE WHEN NEW.severity='major'     THEN 1 ELSE 0 END,
        CASE WHEN NEW.severity='critical'  THEN 1 ELSE 0 END,
        1,
        CASE NEW.severity WHEN 'critical' THEN 4.0 WHEN 'major' THEN 2.0 WHEN 'minor' THEN 1.0 ELSE 0.0 END,
        now(), now()
    )
    ON CONFLICT (fingerprint_hash, requirement_id) DO UPDATE SET
        compliant_count   = clause_fingerprints.compliant_count + CASE WHEN NEW.severity='compliant' THEN 1 ELSE 0 END,
        minor_count       = clause_fingerprints.minor_count     + CASE WHEN NEW.severity='minor'     THEN 1 ELSE 0 END,
        major_count       = clause_fingerprints.major_count     + CASE WHEN NEW.severity='major'     THEN 1 ELSE 0 END,
        critical_count    = clause_fingerprints.critical_count  + CASE WHEN NEW.severity='critical'  THEN 1 ELSE 0 END,
        total_occurrences = clause_fingerprints.total_occurrences + 1,
        heat_score = ROUND((
            (clause_fingerprints.critical_count + CASE WHEN NEW.severity='critical' THEN 1 ELSE 0 END)*4.0 +
            (clause_fingerprints.major_count    + CASE WHEN NEW.severity='major'    THEN 1 ELSE 0 END)*2.0 +
            (clause_fingerprints.minor_count    + CASE WHEN NEW.severity='minor'    THEN 1 ELSE 0 END)*1.0
        ) / NULLIF(clause_fingerprints.total_occurrences+1,0), 3),
        last_seen_at = now();

    UPDATE compliance_findings SET clause_fingerprint_hash = v_hash WHERE id = NEW.id;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_upsert_clause_fingerprint ON compliance_findings;
CREATE TRIGGER trg_upsert_clause_fingerprint
    AFTER INSERT ON compliance_findings
    FOR EACH ROW EXECUTE FUNCTION upsert_clause_fingerprint();

-- ── 7. ADD COLUMNS to compliance_findings ───────────────────────
ALTER TABLE compliance_findings
    ADD COLUMN IF NOT EXISTS engine_version          text,
    ADD COLUMN IF NOT EXISTS clause_fingerprint_hash text;

CREATE INDEX IF NOT EXISTS idx_cf_engine      ON compliance_findings(engine_version);
CREATE INDEX IF NOT EXISTS idx_cf_fingerprint ON compliance_findings(clause_fingerprint_hash) WHERE clause_fingerprint_hash IS NOT NULL;

-- ── 8. CLAUSE HEAT MAP VIEW ──────────────────────────────────────
CREATE OR REPLACE VIEW clause_heat_map AS
SELECT
    cf.clause_category,
    cf.statutory_ref,
    rr.requirement_name,
    SUM(cf.total_occurrences)                                                               AS total_occurrences,
    SUM(cf.critical_count)                                                                  AS total_critical,
    SUM(cf.major_count)                                                                     AS total_major,
    SUM(cf.minor_count)                                                                     AS total_minor,
    SUM(cf.compliant_count)                                                                 AS total_compliant,
    ROUND(SUM(cf.critical_count)::numeric / NULLIF(SUM(cf.total_occurrences),0)*100,1)     AS critical_rate_pct,
    ROUND(SUM(cf.major_count)::numeric    / NULLIF(SUM(cf.total_occurrences),0)*100,1)     AS major_rate_pct,
    ROUND(SUM(cf.compliant_count)::numeric/ NULLIF(SUM(cf.total_occurrences),0)*100,1)     AS compliant_rate_pct,
    ROUND(AVG(cf.heat_score), 3)                                                            AS avg_heat_score,
    MAX(cf.heat_score)                                                                      AS max_heat_score,
    MAX(tcs.total_cases)                                                                    AS tribunal_total_cases,
    MAX(tcs.claimant_win_rate)                                                              AS tribunal_claimant_win_rate,
    ROUND(MAX(tcs.avg_compensation)::numeric, 0)                                            AS tribunal_avg_compensation,
    ROUND(MAX(tcs.max_compensation)::numeric, 0)                                            AS tribunal_max_compensation,
    MIN(cf.first_seen_at)                                                                   AS first_seen_at,
    MAX(cf.last_seen_at)                                                                    AS last_seen_at
FROM clause_fingerprints cf
LEFT JOIN regulatory_requirements rr ON rr.id = cf.requirement_id
LEFT JOIN tribunal_clause_signals tcs ON tcs.clause_category = cf.clause_category AND tcs.statutory_ref = cf.statutory_ref
GROUP BY cf.clause_category, cf.statutory_ref, rr.requirement_name
ORDER BY avg_heat_score DESC, total_critical DESC;

COMMENT ON VIEW clause_heat_map IS 'Clause categories ranked by heat score. tribunal_claimant_win_rate connects contract risk to real financial exposure from 130k decisions. Primary feed for AiLane Agent and CEO dashboard.';

-- ── 9. TRIBUNAL SIGNALS: Phase 1 population ─────────────────────
INSERT INTO tribunal_clause_signals (
    clause_category, statutory_ref, acei_category,
    total_cases, claimant_won, claimant_lost, settled,
    avg_compensation, max_compensation, total_compensation,
    date_from, date_to, claimant_win_rate, last_computed_at
)
SELECT
    td.acei_category AS clause_category,
    CASE td.acei_category
        WHEN 'Unfair Dismissal'    THEN 'ERA 1996 ss.94-98'
        WHEN 'Wrongful Dismissal'  THEN 'ERA 1996 s.86'
        WHEN 'Redundancy'          THEN 'ERA 1996 ss.135-161'
        WHEN 'Discrimination'      THEN 'Equality Act 2010'
        WHEN 'Equal Pay'           THEN 'Equality Act 2010 ss.64-80'
        WHEN 'Wages'               THEN 'ERA 1996 s.13'
        WHEN 'Working Time'        THEN 'WTR 1998'
        WHEN 'TUPE'                THEN 'TUPE 2006'
        WHEN 'Whistleblowing'      THEN 'ERA 1996 s.103A'
        WHEN 'Maternity/Paternity' THEN 'ERA 1996 ss.71-85'
        WHEN 'Health and Safety'   THEN 'HSWA 1974'
        WHEN 'Breach of Contract'  THEN 'ERA 1996 s.13'
        ELSE 'ERA 1996'
    END AS statutory_ref,
    td.acei_category,
    COUNT(*),
    COUNT(*) FILTER (WHERE outcome ILIKE '%claimant%won%' OR outcome ILIKE '%upheld%' OR outcome ILIKE '%successful%' OR outcome ILIKE '%in favour of claimant%'),
    COUNT(*) FILTER (WHERE outcome ILIKE '%dismissed%' OR outcome ILIKE '%claimant%lost%' OR outcome ILIKE '%respondent%succeeded%' OR outcome ILIKE '%in favour of respondent%'),
    COUNT(*) FILTER (WHERE outcome ILIKE '%settle%' OR outcome ILIKE '%withdrawn%' OR outcome ILIKE '%consent%'),
    ROUND(AVG(compensation_awarded) FILTER (WHERE compensation_awarded > 0), 2),
    MAX(compensation_awarded),
    SUM(compensation_awarded),
    MIN(decision_date),
    MAX(decision_date),
    ROUND(
        COUNT(*) FILTER (WHERE outcome ILIKE '%claimant%won%' OR outcome ILIKE '%upheld%' OR outcome ILIKE '%successful%' OR outcome ILIKE '%in favour of claimant%')::numeric
        / NULLIF(COUNT(*),0), 3
    ),
    now()
FROM tribunal_decisions td
WHERE td.acei_category IS NOT NULL AND td.outcome IS NOT NULL
GROUP BY td.acei_category
ON CONFLICT (clause_category, statutory_ref, acei_category) DO UPDATE SET
    total_cases        = EXCLUDED.total_cases,
    claimant_won       = EXCLUDED.claimant_won,
    claimant_lost      = EXCLUDED.claimant_lost,
    settled            = EXCLUDED.settled,
    avg_compensation   = EXCLUDED.avg_compensation,
    max_compensation   = EXCLUDED.max_compensation,
    total_compensation = EXCLUDED.total_compensation,
    date_from          = EXCLUDED.date_from,
    date_to            = EXCLUDED.date_to,
    claimant_win_rate  = EXCLUDED.claimant_win_rate,
    last_computed_at   = now();

