-- Migration: 20260416224552_seed_pipeline_registry_scrapers_v2
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: seed_pipeline_registry_scrapers_v2

-- ─────────────────────────────────────────────────────────────────────
-- Seed pipeline_registry rows for the 6 Ailane scraper pipelines
-- Constitutional authority: ACEI Art. XI + AILANE-SPEC-DMSP-001
-- ─────────────────────────────────────────────────────────────────────

INSERT INTO public.pipeline_registry (
    pipeline_code, pipeline_name, description, constitutional_authority,
    cron_expression, timezone, is_active, run_on_weekends,
    source_type, source_url,
    batch_size, rate_limit_seconds, timeout_seconds, max_retries,
    alert_on_failure, failure_threshold,
    target_table, secondary_tables
) VALUES
(
    'fos_complaints_half_yearly',
    'Financial Ombudsman Service — Firm Complaints (half-yearly)',
    'Scrapes FOS half-yearly firm complaints data (CSV/XLSX downloads). Captures per-firm complaint volumes and uphold rates.',
    'ACEI Art. XI §2; AILANE-SPEC-DMSP-001',
    '0 6 * * MON',
    'UTC',
    true, false,
    'fos_complaints',
    'https://www.financial-ombudsman.org.uk/data-insight/half-yearly-complaints-data',
    500, 2.0, 180, 3,
    true, 2,
    'fos_firm_complaints',
    ARRAY['pipeline_runs','scraper_runs']
),
(
    'fca_complaints_half_yearly',
    'FCA — Firm-Level Complaints Data (half-yearly)',
    'Scrapes FCA firm-level complaints data (XLSX downloads). Captures per-firm, per-product complaint volumes, uphold rates, redress paid.',
    'ACEI Art. XI §2',
    '0 7 * * MON',
    'UTC',
    true, false,
    'fca_complaints',
    'https://www.fca.org.uk/data/complaints-data/firm-level',
    500, 2.0, 180, 3,
    true, 2,
    'fca_firm_complaints',
    ARRAY['pipeline_runs','scraper_runs']
),
(
    'tpr_penalties_quarterly',
    'The Pensions Regulator — Penalty Notices (quarterly)',
    'Scrapes TPR penalty notices table. Captures fixed/escalating/financial penalties against employers and schemes.',
    'ACEI Art. XI §2',
    '0 8 1 * *',
    'UTC',
    true, false,
    'tpr_penalties',
    'https://www.thepensionsregulator.gov.uk/en/document-library/enforcement-activity/penalty-notices',
    200, 2.0, 180, 3,
    true, 2,
    'tpr_penalty_notices',
    ARRAY['pipeline_runs','scraper_runs']
),
(
    'eat_decisions_ongoing',
    'Employment Appeal Tribunal — Decisions',
    'Scrapes EAT decisions from gov.uk. Captures case citations, judgment dates, judges, outcomes, full text where available.',
    'ACEI Art. XI §2',
    '0 9 * * *',
    'UTC',
    true, false,
    'eat_decisions',
    'https://www.gov.uk/employment-appeal-tribunal-decisions',
    100, 2.0, 180, 3,
    true, 3,
    'eat_case_law',
    ARRAY['pipeline_runs','scraper_runs']
),
(
    'fca_enforcement_ongoing',
    'FCA — Final Notices & Enforcement Actions',
    'Scrapes FCA decision/final/prohibition notices from news search. Captures firm/individual name, FRN, notice type, date, summary.',
    'ACEI Art. XI §2',
    '30 9 * * *',
    'UTC',
    true, false,
    'fca_enforcement',
    'https://www.fca.org.uk/news/search-results?np_category=decision-notices-and-final-notices',
    200, 2.0, 180, 3,
    true, 3,
    'fca_enforcement_notices',
    ARRAY['pipeline_runs','scraper_runs']
),
(
    'tpo_determinations_ongoing',
    'Pensions Ombudsman — Determinations',
    'Scrapes TPO determinations. Captures respondent (scheme/administrator), complainant (anonymised), outcome, determination date.',
    'ACEI Art. XI §2',
    '0 10 * * *',
    'UTC',
    true, false,
    'tpo_determinations',
    'https://www.pensions-ombudsman.org.uk/decisions',
    100, 2.0, 180, 3,
    true, 3,
    'tpo_determinations',
    ARRAY['pipeline_runs','scraper_runs']
)
ON CONFLICT (pipeline_code) DO UPDATE SET
    pipeline_name = EXCLUDED.pipeline_name,
    description = EXCLUDED.description,
    constitutional_authority = EXCLUDED.constitutional_authority,
    cron_expression = EXCLUDED.cron_expression,
    source_type = EXCLUDED.source_type,
    source_url = EXCLUDED.source_url,
    target_table = EXCLUDED.target_table,
    secondary_tables = EXCLUDED.secondary_tables,
    updated_at = now();
