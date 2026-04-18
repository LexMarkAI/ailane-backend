-- Migration: 20260307042233_daily_intelligence_pipeline_schema
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: daily_intelligence_pipeline_schema


-- ============================================================
-- AILANE DAILY INTELLIGENCE PIPELINE SCHEMA
-- Constitutional basis: ACEI Art. II, XI | CCI Art. V | RRI Art. III
-- Adopted: 2026-03-07
-- ============================================================

-- 1. PIPELINE REGISTRY
CREATE TABLE IF NOT EXISTS pipeline_registry (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    pipeline_code           TEXT NOT NULL UNIQUE,
    pipeline_name           TEXT NOT NULL,
    description             TEXT,
    constitutional_authority TEXT,
    cron_expression         TEXT,
    timezone                TEXT NOT NULL DEFAULT 'UTC',
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    run_on_weekends         BOOLEAN NOT NULL DEFAULT FALSE,
    source_type             TEXT NOT NULL CHECK (source_type IN (
                                'govuk_tribunal','parliament_bills','parliament_hansard',
                                'parliament_committees','govuk_news','legislation_govuk',
                                'bbc_parliament','companies_house','eu_eurlex',
                                'hse_enforcement','ico_enforcement','ehrc_enforcement',
                                'acas_guidance','custom'
                            )),
    source_url              TEXT,
    source_api_key_ref      TEXT,
    batch_size              INTEGER DEFAULT 100,
    rate_limit_seconds      NUMERIC(4,1) DEFAULT 1.5,
    timeout_seconds         INTEGER DEFAULT 120,
    max_retries             INTEGER DEFAULT 3,
    backup_pipeline_code    TEXT,
    backup_enabled          BOOLEAN DEFAULT FALSE,
    alert_on_failure        BOOLEAN DEFAULT TRUE,
    failure_threshold       INTEGER DEFAULT 3,
    last_run_at             TIMESTAMPTZ,
    last_success_at         TIMESTAMPTZ,
    last_failure_at         TIMESTAMPTZ,
    consecutive_failures    INTEGER DEFAULT 0,
    total_runs              INTEGER DEFAULT 0,
    total_records_collected BIGINT DEFAULT 0,
    target_table            TEXT NOT NULL,
    secondary_tables        TEXT[],
    CONSTRAINT pipeline_code_format CHECK (pipeline_code ~ '^[a-z][a-z0-9_]*$')
);

COMMENT ON TABLE pipeline_registry IS
    'Central registry of all Ailane automated intelligence pipelines. '
    'All pipelines must be registered here before deployment. '
    'Constitutional authority: ACEI Art. XI (data governance).';

-- 2. PIPELINE RUNS
CREATE TABLE IF NOT EXISTS pipeline_runs (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    pipeline_code       TEXT NOT NULL REFERENCES pipeline_registry(pipeline_code),
    started_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at        TIMESTAMPTZ,
    status              TEXT NOT NULL DEFAULT 'running' CHECK (status IN (
                            'running','success','partial','failed','timeout','skipped'
                        )),
    records_found       INTEGER DEFAULT 0,
    records_new         INTEGER DEFAULT 0,
    records_duplicate   INTEGER DEFAULT 0,
    records_failed      INTEGER DEFAULT 0,
    records_queued      INTEGER DEFAULT 0,
    elapsed_seconds     NUMERIC(10,2),
    avg_rate_per_minute NUMERIC(8,2),
    error_message       TEXT,
    error_code          TEXT,
    retry_count         INTEGER DEFAULT 0,
    trigger_type        TEXT DEFAULT 'scheduled' CHECK (trigger_type IN (
                            'scheduled','manual','webhook','retry','backfill'
                        )),
    triggered_by        TEXT,
    metadata            JSONB DEFAULT '{}'
);

CREATE INDEX idx_pipeline_runs_code_started ON pipeline_runs(pipeline_code, started_at DESC);
CREATE INDEX idx_pipeline_runs_status ON pipeline_runs(status) WHERE status IN ('running','failed');

COMMENT ON TABLE pipeline_runs IS
    'Unified execution log for all Ailane pipelines. Full audit trail per constitutional requirement.';

-- 3. PARLIAMENTARY INTELLIGENCE
CREATE TABLE IF NOT EXISTS parliamentary_intelligence (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    source_type             TEXT NOT NULL CHECK (source_type IN (
                                'bill_reading','bill_amendment','statutory_instrument',
                                'select_committee_report','select_committee_evidence',
                                'select_committee_inquiry','hansard_debate',
                                'hansard_oral_questions','written_question',
                                'ministerial_statement','early_day_motion',
                                'royal_assent','bbc_parliament_news','govuk_press_release'
                            )),
    parliament_id           TEXT,
    bill_id                 TEXT,
    bill_stage              TEXT,
    chamber                 TEXT CHECK (chamber IN ('commons','lords','joint','n/a')),
    committee_name          TEXT,
    member_name             TEXT,
    member_party            TEXT,
    title                   TEXT NOT NULL,
    summary                 TEXT,
    full_text               TEXT,
    url                     TEXT,
    parliament_url          TEXT,
    published_date          DATE,
    event_date              DATE,
    next_stage_date         DATE,
    acei_categories         TEXT[],
    acei_category_primary   TEXT,
    legislative_urgency     TEXT DEFAULT 'monitor' CHECK (legislative_urgency IN (
                                'critical','high','elevated','monitor','archived'
                            )),
    ticker_eligible         BOOLEAN DEFAULT TRUE,
    ticker_tier             TEXT DEFAULT 'all' CHECK (ticker_tier IN ('all','governance','institutional')),
    briefing_generated      BOOLEAN DEFAULT FALSE,
    briefing_id             UUID,
    content_hash            TEXT UNIQUE,
    CONSTRAINT parl_intel_title_not_empty CHECK (LENGTH(TRIM(title)) > 0)
);

CREATE INDEX idx_parl_intel_source_type ON parliamentary_intelligence(source_type);
CREATE INDEX idx_parl_intel_published ON parliamentary_intelligence(published_date DESC);
CREATE INDEX idx_parl_intel_acei ON parliamentary_intelligence USING GIN(acei_categories);
CREATE INDEX idx_parl_intel_ticker ON parliamentary_intelligence(ticker_eligible, briefing_generated)
    WHERE ticker_eligible = TRUE AND briefing_generated = FALSE;
CREATE INDEX idx_parl_intel_urgency ON parliamentary_intelligence(legislative_urgency)
    WHERE legislative_urgency IN ('critical','high');

COMMENT ON TABLE parliamentary_intelligence IS
    'Unified parliamentary intelligence layer. Bills, Select Committees, Hansard, '
    'Written Questions, Ministerial Statements. Feeds ticker briefings pipeline and '
    'ACEI forward exposure register. Constitutional authority: ACEI Art. II §2.3.';

-- 4. GOVUK DAILY QUEUE
CREATE TABLE IF NOT EXISTS govuk_daily_queue (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    decision_id         UUID NOT NULL REFERENCES tribunal_decisions(id) ON DELETE CASCADE,
    pipeline_run_id     UUID REFERENCES pipeline_runs(id),
    queue_status        TEXT NOT NULL DEFAULT 'pending' CHECK (queue_status IN (
                            'pending','processing','complete','failed','skip'
                        )),
    priority            INTEGER DEFAULT 5,
    queued_at           TIMESTAMPTZ DEFAULT now(),
    processing_started  TIMESTAMPTZ,
    processing_completed TIMESTAMPTZ,
    error_message       TEXT,
    CONSTRAINT govuk_queue_unique_decision UNIQUE (decision_id)
);

CREATE INDEX idx_govuk_queue_pending ON govuk_daily_queue(priority, queued_at)
    WHERE queue_status = 'pending';

COMMENT ON TABLE govuk_daily_queue IS
    'Queue linking daily GOV.UK tribunal scraper to deep enrichment pipeline. '
    'New decisions auto-inserted; enrichment pipeline polls for pending records.';

-- 5. REGISTER ALL PIPELINES
INSERT INTO pipeline_registry (
    pipeline_code, pipeline_name, description, constitutional_authority,
    cron_expression, source_type, source_url,
    batch_size, rate_limit_seconds,
    target_table, secondary_tables,
    run_on_weekends, alert_on_failure
) VALUES
('govuk_tribunal_daily',
 'GOV.UK Daily Tribunal Decisions',
 'Scrapes new UK employment tribunal decisions published on GOV.UK each working day. Auto-queues for deep enrichment.',
 'ACEI Art. II §2.1',
 '0 6 * * 1-5', 'govuk_tribunal',
 'https://www.gov.uk/employment-tribunal-decisions',
 100, 1.5, 'tribunal_decisions', ARRAY['govuk_daily_queue','pipeline_runs'],
 FALSE, TRUE),

('parliament_bills_daily',
 'Parliament Bills Tracker',
 'Employment-related Bills through all parliamentary stages. Readings, amendments, Royal Assent.',
 'ACEI Art. II §2.3',
 '0 8 * * *', 'parliament_bills',
 'https://bills-api.parliament.uk/api/v1/Bills',
 50, 1.0, 'parliamentary_intelligence', ARRAY['pipeline_runs'],
 TRUE, TRUE),

('parliament_committees_daily',
 'Select Committee Monitor',
 'Work and Pensions, Women and Equalities, Business and Trade. Reports, inquiries, evidence sessions.',
 'ACEI Art. II §2.3',
 '30 8 * * *', 'parliament_committees',
 'https://committees.parliament.uk',
 50, 1.0, 'parliamentary_intelligence', ARRAY['pipeline_runs'],
 TRUE, TRUE),

('parliament_hansard_daily',
 'Hansard Employment Law Monitor',
 'Monitors Hansard for employment keywords: unfair dismissal, zero hours, fire and rehire, TUPE, discrimination.',
 'ACEI Art. II §2.3',
 '0 9 * * *', 'parliament_hansard',
 'https://hansard.parliament.uk',
 100, 1.5, 'parliamentary_intelligence', ARRAY['pipeline_runs'],
 TRUE, FALSE),

('govuk_employment_news_daily',
 'GOV.UK Employment News and Guidance',
 'GOV.UK press releases, guidance updates, ACAS updates, HMRC employer bulletins.',
 'ACEI Art. II §2.3',
 '0 7 * * *', 'govuk_news',
 'https://www.gov.uk/search/news-and-communications',
 100, 1.0, 'parliamentary_intelligence', ARRAY['pipeline_runs'],
 TRUE, FALSE),

('bbc_parliament_news_daily',
 'BBC Parliament News Feed',
 'BBC Parliament RSS feed — employment-related parliamentary news. Secondary editorial signal.',
 'ACEI Art. II §2.3',
 '0 10 * * *', 'bbc_parliament',
 'https://feeds.bbci.co.uk/news/politics/rss.xml',
 50, 0.5, 'parliamentary_intelligence', ARRAY['pipeline_runs'],
 TRUE, FALSE),

('legislation_govuk_weekly',
 'legislation.gov.uk New Instruments',
 'New statutory instruments and primary legislation with employment relevance. Feeds Knowledge Library.',
 'ACEI Art. II §2.2',
 '0 8 * * 1', 'legislation_govuk',
 'https://www.legislation.gov.uk',
 50, 2.0, 'legislation_library', ARRAY['pipeline_runs'],
 FALSE, TRUE)

ON CONFLICT (pipeline_code) DO NOTHING;

-- 6. RLS
ALTER TABLE pipeline_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE pipeline_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE parliamentary_intelligence ENABLE ROW LEVEL SECURITY;
ALTER TABLE govuk_daily_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service_role_all_pipeline_registry" ON pipeline_registry FOR ALL TO service_role USING (TRUE);
CREATE POLICY "service_role_all_pipeline_runs" ON pipeline_runs FOR ALL TO service_role USING (TRUE);
CREATE POLICY "service_role_all_parl_intel" ON parliamentary_intelligence FOR ALL TO service_role USING (TRUE);
CREATE POLICY "service_role_all_govuk_queue" ON govuk_daily_queue FOR ALL TO service_role USING (TRUE);

CREATE POLICY "authenticated_read_pipeline_registry" ON pipeline_registry FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "authenticated_read_pipeline_runs" ON pipeline_runs FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "authenticated_read_govuk_queue" ON govuk_daily_queue FOR SELECT TO authenticated USING (TRUE);

-- Parliamentary intelligence — tier-gated
CREATE POLICY "authenticated_read_parl_intel" ON parliamentary_intelligence
    FOR SELECT TO authenticated USING (
        ticker_tier = 'all'
        OR EXISTS (
            SELECT 1 FROM app_users au
            JOIN organisations o ON o.id = au.org_id
            WHERE au.id = auth.uid()
            AND o.tier IN ('governance','institutional')
        )
    );

