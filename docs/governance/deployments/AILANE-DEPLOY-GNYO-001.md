# AILANE-DEPLOY-GNYO-001

**Related brief:** AILANE-CC-BRIEF-GNYO-001-P0a-v2
**Owner:** Director (Mark)
**Applies after:** Branch `claude/gnyo-001-p0a-v2` merged to `main`

## Order of operations (strict)

1. Apply Migration A via Supabase MCP `apply_migration` with name `gnyo_001_add_pipeline_registry_watermark`. Verify `pipeline_registry.last_high_watermark_ts` column present.
2. Apply Migration B with name `gnyo_001_create_govuk_news_intelligence`. Verify table exists, indices present, RLS enabled.
3. Apply Migration C with name `gnyo_001_retarget_news_pipeline`. Verify `target_table='govuk_news_intelligence'` on the `govuk_employment_news_daily` row.
4. Create Storage bucket `isrf-govuk` (private, no public access). Via Supabase Dashboard → Storage → New bucket.
5. Deploy `pipeline-govuk-news` v15 via Supabase Dashboard → Edge Functions → pipeline-govuk-news → Edit → paste §4 source → Deploy.
6. Deploy `pipeline-ticker-parliamentary` v13 via Supabase Dashboard → Edge Functions → pipeline-ticker-parliamentary → Edit → paste §6 source → Deploy.
7. Trigger a manual run of `pipeline-govuk-news` (Dashboard → Invoke). Observe `pipeline_runs` row: `status='success'`, `records_found >= 100` expected on first 90-day backfill.
8. Verify `govuk_news_intelligence` row count. Verify `pipeline_registry.last_high_watermark_ts` is populated (non-null).
9. Verify `isrf-govuk` bucket contains `<org-slug>/<yyyy>/<mm>/<dd>/*.json` objects.
10. Trigger a manual run of `pipeline-ticker-parliamentary`. Verify `ticker_briefings` rows appear with `source_table='govuk_news_intelligence'`.

## Rollback

If Migration B fails: Migrations A and C can stand alone (A adds an unused column; C updates a text field). No data loss.
If Migration B succeeds but Edge Function v15 fails: revert pipeline-govuk-news to v14 in Dashboard (previous version preserved automatically by Supabase).
If Migration C applied but v15 not yet deployed: v14 will break because `parliamentary_intelligence` receives items with `source_type='govuk_press_release'` which still satisfies its CHECK. **Therefore: apply Migration C AFTER deploying v15.** Correct order enforced in steps 1–6 above.

## Success criteria

- `public.govuk_news_intelligence` row count > `public.parliamentary_intelligence WHERE source_type='govuk_press_release'` count at time of v14's last run (indicates yield uplift from Lever D + broadened orgs).
- `isrf-govuk` bucket object count >= `govuk_news_intelligence` row count from runs after v15 deploy (some ISRF writes may fail; document failure rate).
- Ticker UI (ailane.ai/ticker/) continues to display items with no front-end change needed — `ticker_briefings.source_table` already pointer-based.
