-- AILANE GNYO-001 — Migration C
-- Retarget the existing news pipeline row to the new dedicated table.

UPDATE public.pipeline_registry
SET target_table = 'govuk_news_intelligence',
    description = 'GOV.UK news & employment-adjacent agency communications. Expanded orgs (DBT, ACAS, HSE, EHRC, ICO, TPR) + HMRC-narrow. Incremental sync via last_high_watermark_ts.',
    updated_at = now()
WHERE pipeline_code = 'govuk_employment_news_daily';
