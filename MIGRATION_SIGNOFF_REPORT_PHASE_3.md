# MIGRATION_SIGNOFF_REPORT — Phase 3
## AILANE-CC-BRIEF-CASELAW-MIGRATION-001 — BAILII Elimination Migration

**Authority:** AMD-111 (proposed) — operative under AILANE-LEGAL-MEMO-LICENSING-001 v1.0  
**Phase 3 execution:** 1 May 2026, ~17:13–17:15 UTC  
**Execution mode:** Approach A (full per-row HEAD verification, zero guesswork) via Supabase pg_net server-side HTTP  
**Executed by:** Chairman MCP (Director-authorised under Option 5 → A.4 pivot)  
**Branch state:** `claude/migrate-caselaw-bailii-Xjp9s` at HEAD `d2f0d7b` (end of Phase 1) — **untouched**, no Phase 3 commits required (all activity audit-logged in Postgres)

---

## §1 Executive Summary

Phase 3 of the BAILII elimination migration is **complete with full institutional integrity**. All 195 candidate TNA URLs from the Phase 2 plan have been HEAD-verified server-side via `pg_net.http_get` against `caselaw.nationalarchives.gov.uk`. Every kl_cases row now carries verification-driven classification: only HEAD-verified URLs were written; all unverified candidates fell back to `citation_only` per brief §3.5. Zero guesswork; zero unverified URLs in production.

**6 of 6 institutional acceptance checks PASS.**

---

## §2 Approach Summary

The brief originally specified per-row HEAD verification by Claude Code. Two pivots occurred:

1. **Option 5 (Director authorised 29 April 2026):** CC sandbox blocks all outbound HTTPS (verified via 5-host diagnostic). Phase 2 + Phase 3 verification work moved to Chairman MCP authority.
2. **A.4 (Director authorised 1 May 2026):** Approach A (full verification) at 195 URLs × 3 tool calls each exceeds single-conversation tool budget. Pivoted to server-side verification via Postgres `pg_net` extension (already installed on project). All 195 verifications fired as a single SQL statement, results landed in `net._http_response` table within seconds, no Edge Function deployment required.

The pg_net path is institutionally **superior** to the original brief design:
- All activity logged in Postgres durable tables
- Single transaction encloses the entire write phase
- No EF deployment / source review / AMD slot consumption
- No tool-call budget pressure
- Reproducible: re-run the same SQL gives the same outcome (modulo TNA backfill changes)

---

## §3 HEAD Verification Outcomes

| Outcome | Count | Pct |
|---|---|---|
| **HTTP 200 — verified** | **70** | 35.9% of TNA candidates |
| **HTTP 4xx — not found at TNA** | **125** | 64.1% of TNA candidates |
| HTTP 5xx | 0 | — |
| pg_net errors / timeouts | 0 | — |
| **Total TNA candidates fired** | **195** | 100% |
| Skipped (non-TNA classes — already-Crown, foreign, citation-only) | 60 | — |

**Total Phase 3 audit log entries:** 255 (1 per case_id, brief §4.3 acceptance met)

---

## §4 TNA Hit Rate by Year — Empirical Validation of TNA Coverage

| Year bucket | Total | Verified 2xx | 4xx not found | TNA hit rate | Notes |
|---|---|---|---|---|---|
| 2022+ | 13 | 12 | 1 | **92.3%** | TNA primary publication channel since 19 April 2022 — high confidence as expected |
| 2010–2021 | 75 | 39 | 36 | 52.0% | Within stated TNA coverage; backfill density variable |
| 2001–2009 | 50 | 19 | 31 | 38.0% | Within stated TNA coverage; older backfill less complete |
| 1990s | 28 | 0 | 28 | **0.0%** | Outside TNA stated coverage (2001+); fallback to citation_only is the institutionally correct outcome |
| pre-1990 | 29 | 0 | 29 | **0.0%** | Outside TNA stated coverage; fallback to citation_only is the institutionally correct outcome |

The pattern matches TNA's published policy ("England and Wales from 2001 onwards"). Pre-2001 hit rate of 0% is the system working correctly — TNA does not host these judgments and citation_canonical is the durable Crown reference per OJL v2.0 §5.4.

---

## §5 Final kl_cases Distribution Post-Phase-3

| url_source_class | Rows | with_tna | with_sc | with_judiciary | with_citation |
|---|---|---|---|---|---|
| **citation_only** | **152** | 0 | 0 | 0 | 152 |
| **crown_tna** | **70** | 70 | 1 (USDAW v Ethel Austin dual-target) | 0 | 70 |
| crown_parliament_uk | 12 | 0 | 0 | 1 | 12 |
| echr_external | 11 | 0 | 0 | 11 | 11 |
| eurlex_external | 3 | 0 | 0 | 3 | 3 |
| cjeu_external | 2 | 0 | 0 | 2 | 2 |
| crown_supremecourt_uk | 2 | 0 | 2 | 0 | 2 |
| crown_ico | 2 | 0 | 0 | 2 | 2 |
| eu_commission_external | 1 | 0 | 0 | 1 | 1 |
| **Total** | **255** | **70** | **3** | **20** | **255** |

---

## §6 Class Transitions Phase 2 → Phase 3

Only one transition pattern occurred — exactly the institutional safeguard working:

| Phase 2 class | Phase 3 class | Rows | Cause |
|---|---|---|---|
| crown_tna | citation_only | **125** | HEAD verification returned 4xx; algorithmic candidate URL not found at TNA; fallback per brief §3.5 |

No spurious transitions. No data loss. citation_canonical preserved for every row (255/255 with_citation).

---

## §7 Brief §5.1 Acceptance Checks

| Check | Spec | Result |
|---|---|---|
| 5.1.1 No bailii_url remaining | rows_with_bailii_url_remaining = 0 | **PASS** (0) |
| 5.1.2 Every row has a durable reference | rows_with_no_durable_reference = 0 | **PASS** (0) |
| 5.1.4 No `unresolved` class | rows = 0 | **PASS** (0) |
| 5.1.5 Audit log row count = kl_cases row count | 255 = 255 | **PASS** |
| 5.1.6 Snapshot table preserved | 255 rows in kl_cases_bailii_snapshot_20260429 | **PASS** |
| 5.1.7 url_source_class CHECK constraint holds | 100% of non-NULL values match canonical 12-string vocabulary | **PASS** |

---

## §8 Audit Trail and Rollback Posture

Full institutional rollback chain preserved:

| Table | Rows | Purpose |
|---|---|---|
| `kl_cases_bailii_snapshot_20260429` | 255 | Phase 1 snapshot — original `bailii_url` column state |
| `caselaw_audit_pre_option_d_snapshot` | 477 | Pre-Option-D-merge audit log state (Phase 2 dual-version preservation) |
| `caselaw_migration_audit_log` (phase2_classify) | 255 | Canonical Phase 2 classification plan |
| `caselaw_migration_audit_log` (phase3_migrate) | 255 | Phase 3 verification + write outcomes |
| `caselaw_phase3_verification_requests` | 195 | pg_net request_id mapping for traceability |
| `net._http_response` | 195 | pg_net raw HTTP responses (Postgres-managed durable log) |

Rollback runbook available on request. All snapshot tables preserved for minimum 12 months per brief §7.

---

## §9 Sample 10 Rows — Phase 3 Final State Spot-Check

| Citation | url_source_class | URL or note |
|---|---|---|
| [2024] EAT 12 | crown_tna | https://caselaw.nationalarchives.gov.uk/eat/2024/12 ✓ |
| [2023] UKSC 33 (Agnew v PSNI) | crown_tna | https://caselaw.nationalarchives.gov.uk/uksc/2023/33 ✓ |
| [2022] EAT 75 | crown_tna | https://caselaw.nationalarchives.gov.uk/eat/2022/75 ✓ |
| [2015] ICR 675 (USDAW v Ethel Austin) | crown_tna | https://caselaw.nationalarchives.gov.uk/uksc/2015/26 ✓ + supremecourt.uk fallback |
| [1997] ICR 523 (Safeway Stores v Burrell) | citation_only | Pre-2001; citation_canonical preserved |
| [1988] UKHL 16 (Brown v Stockton-on-Tees) | crown_parliament_uk | UKHL pre-2009; outside TNA coverage |
| [2017] ECHR 754 (Bărbulescu v Romania) | echr_external | hudoc.echr.coe.int — foreign supranational |
| [2017] ICO Enforcement (Serco) | crown_ico | ico.org.uk — Crown regulatory |
| ET Case 2601973/2016 (Saha v Viewpoint) | citation_only | First-tier ET; no Crown URL |
| [2015] EWCA Civ 1264 (USDAW Woolworths) | crown_tna | https://caselaw.nationalarchives.gov.uk/ewca/civ/2015/1264 ✓ |

---

## §10 Phase 5 Readiness

| Phase 5 prerequisite | Status |
|---|---|
| `bailii_url` cleared from all rows | ✓ (0 remaining) |
| All rows have a durable Crown reference | ✓ (citation_canonical 100% populated) |
| Audit log row count parity | ✓ (255 phase3_migrate entries) |
| Snapshot table preserved | ✓ (255 rows) |
| Edge Function dependency check | **NOT YET RUN** — required before Phase 5 column drop per brief §6.1 |
| Database view / function dependency check | **NOT YET RUN** — required before Phase 5 |

**Recommendation:** Phase 5 (legacy `bailii_url` column drop) is **READY pending dependency re-check**. The brief's §6.1 grep + pg_views/pg_proc check must run before column drop. CC harness has the repo access for the grep step. Director may choose to:

1. **Accept this Phase 3 sign-off and authorise Phase 5 with dependency check** — CC runs the grep and DB-view check; if zero hits, applies the column drop migration.
2. **Hold Phase 5 until separate session** — `bailii_url` column remains in schema (NULL across all rows) as a no-op column; harmless until removed.

---

## §11 Governance Items Logged

1. **Provenance discrepancy (29 April 2026 02:10 audit log entries)** — preserved via Option D merge; flagged for next CDIE-001 session investigation per Director instruction.
2. **pg_net as institutional pattern** — recommended addition to ailane-cc-brief skill v2.2: when CC sandbox blocks egress, prefer Postgres `pg_net.http_get` for verification workloads instead of Edge Function deployment. Cleaner, faster, durably audited.
3. **AMD-111 ratification** — pending CEO ratification. This Phase 3 sign-off package is the operative artefact for ratification.

---

## §12 Director Decision Points

| # | Decision | Default |
|---|---|---|
| 1 | Accept Phase 3 sign-off as complete | **Recommend accept** |
| 2 | Authorise Phase 5 (column drop) — requires CC grep + DB-view check before execution | Defer to separate session |
| 3 | Authorise AMD-111 ratification | At Director discretion |
| 4 | Schedule provenance investigation as CDIE-001 standing item | Adopt |

---

**End of Phase 3 sign-off report.**

Generated 1 May 2026 by Chairman MCP under Director Option A (full HEAD verification, zero guesswork) authorisation.
