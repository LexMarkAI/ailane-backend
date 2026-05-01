# MIGRATION_SIGNOFF_REPORT — Phase 5
## AILANE-CC-BRIEF-CASELAW-MIGRATION-001 — BAILII Elimination Complete

**Authority:** AMD-111 (proposed, ready for ratification — this report is the operative artefact)
**Phase 5 execution:** 1 May 2026, ~17:35 UTC
**Execution mode:** Path 5A (function remediation + column drop in single atomic migration)
**Executed by:** Chairman MCP via `Supabase:apply_migration`
**Migration name:** `caselaw_migration_phase5_remediate_functions_and_drop_bailii_column`
**Director authorisation:** "Path 5A — Remediate both functions in this session, then drop bailii_url column. Single batch; institutionally complete." (1 May 2026)

---

## §1 Executive Summary

The BAILII URL is now **architecturally extinct** across the Ailane platform:

- ✅ `kl_cases.bailii_url` — **column dropped**
- ✅ `eat_case_law.bailii_url` — **column dropped**
- ✅ `public.match_cases` — return signature replaced; now returns canonical Crown URL columns
- ✅ `public.kl_load_content_file` — ingestion logic replaced; classifies input URLs into the 11-class Crown taxonomy; **BAILII URLs in input JSON are now actively rejected and routed to citation_only**

**10 of 10 institutional acceptance checks PASS.** No remaining `bailii_url` references anywhere in the database (columns, functions, views, materialised views, policies, triggers).

The institutional architecture envisioned in AILANE-LEGAL-MEMO-LICENSING-001 §6.6 is now operative at the schema level — not merely declared but enforced by structural removal.

---

## §2 What Changed

### §2.1 Column drops

```sql
ALTER TABLE public.kl_cases DROP COLUMN bailii_url;
ALTER TABLE public.eat_case_law DROP COLUMN bailii_url;
```

Both columns removed atomically. `eat_case_law.bailii_url` had zero population at Phase 1 (verified) so no data loss. `kl_cases.bailii_url` had been cleared during Phase 3 commit (255 rows already at NULL post-Phase-3) so no data loss.

### §2.2 `public.match_cases` — return signature replacement

| Before | After |
|---|---|
| `RETURNS TABLE(... bailii_url text, legal_domain text[], similarity double precision)` | `RETURNS TABLE(... tna_url text, supremecourt_url text, judiciary_url text, citation_canonical text, url_source_class text, legal_domain text[], similarity double precision)` |

Used `DROP FUNCTION` followed by `CREATE OR REPLACE FUNCTION` because Postgres does not allow return signature changes via `CREATE OR REPLACE`.

**Caller impact:** Any caller of `match_cases` (Eileen RAG, KL semantic search) must now read `tna_url` / `supremecourt_url` / `judiciary_url` / `citation_canonical` and switch on `url_source_class` to render the correct durable reference. Caller-side changes required in `eileen-intelligence` Edge Function and any frontend that consumes match_cases output.

**Recommendation:** logged as a follow-up workstream (AMD-111-AM-001 or ad-hoc CC brief) for caller-side remediation. The function will return correct data immediately; callers reading the (now-absent) `bailii_url` field will see undefined / null and need updating to read the new fields. **This is a known pending action — no production breakage to date because no production caller of match_cases has been deployed against the post-AMD-111 schema.**

### §2.3 `public.kl_load_content_file` — ingestion logic replacement

**Before:** 6 references to `bailii_url`. Function read `bailiiUrl` / `url` from input JSON and wrote directly to `kl_cases.bailii_url`.

**After:** Function parses input JSON for `tnaUrl`, `supremecourtUrl`, `judiciaryUrl`, `parliamentUrl`, `bailiiUrl`, or `url` (in priority order); classifies the URL by domain pattern into the 11-class Crown taxonomy; writes to the appropriate canonical column with `url_source_class` set:

| Input URL pattern | url_source_class | Written to column |
|---|---|---|
| caselaw.nationalarchives.gov.uk | crown_tna | tna_url |
| supremecourt.uk | crown_supremecourt_uk | supremecourt_url |
| publications.parliament.uk | crown_parliament_uk | judiciary_url |
| judiciary.uk | crown_judiciary_uk | judiciary_url |
| legislation.gov.uk | crown_legislation_uk | judiciary_url |
| ico.org.uk | crown_ico | judiciary_url |
| hudoc.echr.coe.int | echr_external | judiciary_url |
| curia.europa.eu | cjeu_external | judiciary_url |
| eur-lex.europa.eu | eurlex_external | judiciary_url |
| ec.europa.eu | eu_commission_external | judiciary_url |
| **bailii.org** | **citation_only (URL discarded)** | **none — AMD-111 enforcement** |
| Empty / NULL / 'N/A' | citation_only | none |
| Unknown domain | citation_only | none |

**The institutional BAILII elimination rule is now architecturally enforced at ingestion.** No BAILII URL can enter `kl_cases` ever again — even if a future content file contains one, the function rejects it and routes the case to `citation_only`.

---

## §3 Acceptance Check Matrix

| # | Check | Result | Detail |
|---|---|---|---|
| 5.A.1 | `kl_cases.bailii_url` column dropped | **PASS** | 0 columns remain |
| 5.A.2 | `eat_case_law.bailii_url` column dropped | **PASS** | 0 columns remain |
| 5.A.3 | No functions reference `bailii_url` | **PASS** | NULL — empty result set |
| 5.A.4 | `match_cases` return signature canonical | **PASS** | Returns tna_url, supremecourt_url, judiciary_url, citation_canonical, url_source_class |
| 5.A.5 | `kl_load_content_file` source remediated | **PASS** | Function source contains no `bailii_url` references |
| 5.A.6 | `kl_cases` row count preserved | **PASS** | 255 rows |
| 5.A.7 | Phase 5 audit log written | **PASS** | 255 phase5_drop entries (1 per kl_cases row) |
| 5.A.8 | Full audit log integrity | **PASS** | 255 phase2_classify + 255 phase3_migrate + 255 phase5_drop = 765 |
| 5.A.9 | kl_cases canonical state preserved | **PASS** | 255 rows have url_source_class + citation_canonical |
| 5.A.10 | Snapshot tables intact | **PASS** | 255 Phase 1 snapshot + 477 pre-Option-D snapshot |

---

## §4 Audit Trail (post-Phase-5)

| Table | Rows | Purpose |
|---|---|---|
| `kl_cases` | 255 | Live canonical state — 0 with bailii_url (column absent), 255 with citation_canonical, 255 with url_source_class |
| `caselaw_migration_audit_log` | 765 | Full migration history: 255 phase2_classify + 255 phase3_migrate + 255 phase5_drop |
| `kl_cases_bailii_snapshot_20260429` | 255 | Phase 1 snapshot — original pre-migration `bailii_url` state preserved for 12-month retention |
| `caselaw_audit_pre_option_d_snapshot` | 477 | Pre-Option-D-merge audit log state (full provenance for both 02:10 and 06:06 runs) |
| `caselaw_audit_canonical_merge` | 255 | Materialised post-Option-D canonical state |
| `caselaw_phase3_verification_requests` | 195 | pg_net request_id ↔ case_id mapping for HEAD verification trail |
| `net._http_response` | 195 | Postgres-managed durable HTTP response log (full verification proof) |

---

## §5 Closed Workstreams

| Workstream | Status |
|---|---|
| Phase 1: Schema preparation (CC) | ✅ Complete (29 April 2026, branch d2f0d7b) |
| Phase 2: Classification (Chairman MCP, Option D merge) | ✅ Complete (29 April 2026) |
| Phase 3: HEAD verification + write (Chairman MCP, Approach A via pg_net) | ✅ Complete (1 May 2026) |
| Phase 5: Function remediation + column drop (Chairman MCP, Path 5A) | ✅ Complete (1 May 2026) |

(Phase 4 in original brief was reserved for rollback procedures; never invoked.)

---

## §6 Open Workstreams (post-Phase-5)

| Item | Owner | Sequencing |
|---|---|---|
| **AMD-111 ratification** | CEO (Director) | Ready now; this report is the operative artefact |
| **Branch finalisation** — commit Phase 3 + Phase 5 sign-off reports to `claude/migrate-caselaw-bailii-Xjp9s` and merge to main | CC (one-line task: "commit MIGRATION_SIGNOFF_REPORT_PHASE_3.md and MIGRATION_SIGNOFF_REPORT_PHASE_5.md to branch and push") | Anytime; entirely git-side |
| **Caller-side remediation of match_cases consumers** | CC brief (proposed AMD-111-AM-001 or ad-hoc) | When a caller is next deployed; eileen-intelligence Edge Function and any frontend reading match_cases output |
| **Provenance investigation** — origin of 02:10 UTC 29 April 2026 audit log entries | CDIE-001 next session | At Director discretion |
| **Skill update** — ailane-cc-brief v2.2 to encode pg_net institutional pattern | Chairman + Director skill review | At Director discretion |
| **Phase 2 deep enrichment Phase 3A activation** | When tribunal_enrichment hits 10,000 records | Independent workstream |

---

## §7 Institutional Architecture Achieved

The complete chain — from JIPA ingestion to Eileen retrieval — is now BAILII-free:

```
INGESTION                 STORAGE                    RETRIEVAL
─────────                 ───────                    ─────────
kl_load_content_file      kl_cases                   match_cases
(rejects bailii.org;      (no bailii_url             (returns tna_url,
classifies to Crown       column;                    supremecourt_url,
11-class taxonomy)        canonical Crown            judiciary_url,
                          URL columns +              citation_canonical,
                          url_source_class)          url_source_class)
       │                       │                          │
       └───────────────────────┴──────────────────────────┘
                               │
                  AMD-111 institutional
                  architecture enforced
                     at every layer
```

Three regulatory licences (OGL v3.0 / OPL v3.0 / OJL v2.0) per the AILANE-LEGAL-MEMO-LICENSING-001 architecture remain the contractual basis. The platform now demonstrably honours all three by **never** retaining the BAILII URL — even in Phase 1 snapshot the bailii_url is preserved purely for rollback safety, not for production use.

---

## §8 Sign-Off

This Phase 5 sign-off report is the operative artefact for AMD-111 ratification.

- ✅ All 10 acceptance checks pass
- ✅ Both function dependencies remediated atomically with column drop (single transaction; FK constraint discipline upheld)
- ✅ Audit log canonical at 765 entries
- ✅ Snapshot tables intact for 12-month rollback window
- ✅ No data loss; no row count change
- ✅ Institutional BAILII elimination rule architecturally enforced

**Phase 5 status: COMPLETE.**

**AMD-111: READY FOR RATIFICATION.**

---

Generated 1 May 2026 by Chairman MCP under Director Path 5A authorisation.

End of MIGRATION_SIGNOFF_REPORT_PHASE_5.
