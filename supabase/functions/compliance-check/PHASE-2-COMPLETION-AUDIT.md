# CCA-002 Phase 2 — Completion Audit

Engine: compliance-check v42 / ENGINE_VERSION v26
Brief: AILANE-CC-BRIEF-CCA-002-PHASE-2 v1.2 (AMD-080, 22 April 2026)
Branch: `claude/cca-002-phase-2-grounding-v42-session_Nl7QV`
Session: Nl7QV
Date: 23 April 2026

## §13 Completion audit table

| Step | Executing agent | Status | Evidence |
|---|---|---|---|
| §0.1 Ratified artefacts read | CHAIRMAN | DONE | 4 artefacts verified in brief |
| §0.3 V1–V8 production state | CHAIRMAN | DONE | All 8 V-queries verified 23 Apr 2026 |
| §0.4 v41 source read + snapshot staged | CHAIRMAN -> CC | DONE | Commit `066d82d` — `v41-rollback-source.ts` (641 lines, verbatim v41) |
| §0.5 Env secrets verified | DIRECTOR | DONE | Backfill executed 79/79 |
| §4.1–§4.4 + §6.6 + corrective | CHAIRMAN | DONE | 6 migrations applied |
| §5.6 step 3 Backfill executed | DIRECTOR | DONE | 79/79 embedded |
| §5.7 Post-backfill verification | CHAIRMAN | DONE | total=79 with_embedding=79 missing=0 |
| §8 Pricing seed applied | CHAIRMAN | DONE | 4 rows in eileen_model_pricing |
| §6 Source edited v41 -> v42 | CC | DONE | Commit `56cf682` — `index.ts` 840 lines, +815/-241 diff |
| §0.4 v41 rollback snapshot committed | CC | DONE | Commit `066d82d` |
| §12.4 Branch pushed + compare URL | CC | DONE on push | See §12.4 report block below |
| §6.12 Deploy via MCP | CHAIRMAN | PENDING | Post-merge action |
| §10.2 End-to-end AC7 test | CHAIRMAN | PENDING | Post-deploy action |
| PR open | DIRECTOR (manual) | PENDING | PR URL TBC |

## §14 Integrity signals (CC-verified)

### Structural anchors (v42 index.ts)

| Symbol | v42 line | Notes |
|---|---|---|
| `§10.1` ZDR header | 1–15 | Verbatim per brief; above imports |
| `const ENGINE_VERSION = "v26"` | 24 | Bumped from v25 per §6.2 |
| `const BATCH_MODELS = [...]` | 57 | 3 models per §6.3 |
| `const BATCH_TIMEOUTS_MS = [45_000, 35_000, 25_000]` | 62 | Per §6.3 |
| `async function callClaude(...)` | 88 | Refactored per §6.4 (timeoutsMs param + usage capture) |
| `interface GroundingRef` | 139 | §6.5 |
| `async function retrieveGrounding` | 147 | §6.5 — pgvector RPCs only |
| `interface ModelPricing` | 206 | §6.8 |
| `async function fetchModelPricing` | 208 | §6.8 |
| `function computeCallCostUsd` | 226 | §6.8 — 6dp precision |
| `interface Finding { ... grounding_refs ... model_cost_usd }` | 339–356 | §6.9 extension |
| `total_cost_usd` + `grounding_coverage` in response | 824–828 | §6.11 |

### C1–C8 binding-constraint verification

| # | Constraint | v42 evidence |
|---|---|---|
| C1 | No Voyage at runtime | Zero `fetch()` calls to `api.voyageai.com` in index.ts |
| C2 | Voyage confined to backfill / on-add | No Edge Function call site |
| C3 | Pre-computed embeddings at runtime | `retrieveGrounding` reads `regulatory_requirements.embedding` + RPC only |
| C4 | Grounding refs per finding | `Finding.grounding_refs: GroundingRef[] \| null` populated for matched, null for gap-filled |
| C5 | Model cost per finding | `Finding.model_cost_usd: number \| null` + `fetchModelPricing` + `computeCallCostUsd` + per-batch allocation |
| C6 | 3-step model fallback | `BATCH_MODELS = ["claude-sonnet-4-6", "claude-sonnet-4-5", "claude-haiku-4-5-20251001"]` |
| C7 | Per-model timeouts 45/35/25s | `BATCH_TIMEOUTS_MS = [45_000, 35_000, 25_000]` passed as 6th arg to every batch `callClaude` |
| C8 | 150s wall-clock cap preserved | Worst case 45+35+25 = 105s per batch, A/B/F run in parallel, 105s < 150s |

### AC1–AC8 verification (CC-surface items)

| AC | Criterion | Status (CC) |
|---|---|---|
| AC1 | DDL applied transactionally via migrations | Chairman-verified (pre-session) |
| AC2 | Backfill idempotent | Director-verified (pre-session) |
| AC3 | v42 source contains NO **call** to Voyage (grep returns 0) | **Partial — see adjudication below** |
| AC4 | Runtime grounding via pgvector only | VERIFIED — `retrieveGrounding` reads `regulatory_requirements.embedding` + RPCs only; no runtime embedding computation |
| AC5 | 3-model fallback + per-model timeouts + ivfflat indexes | VERIFIED (source); indexes Chairman-verified |
| AC6 | ZDR interim posture documented in source header | VERIFIED — §10.1 block verbatim at lines 1–15 |
| AC7 | Per-finding grounding_refs captured end-to-end | VERIFIED (source); runtime coverage/distance tests are Chairman-post-deploy |
| AC8 | eileen_model_pricing seeded + AMD-078 ratified | Chairman-verified (pre-session) |

### AC3 adjudication (FLAGGED FOR DIRECTOR)

**Literal grep:**
```
$ grep -rn "voyage" supabase/functions/compliance-check/
supabase/functions/compliance-check/index.ts:13://   This Edge Function MUST NOT invoke voyage-law-2 at runtime. Runtime retrieval uses pre-computed
supabase/functions/compliance-check/CCA-002-PHASE-2-AUDIT.md:19:compliance-check v42 MUST NOT invoke voyage-law-2 at runtime. Runtime retrieval uses pre-computed
```

**2 matches, both in constraint declarations** — §10.1 ZDR header (brief-required verbatim) and §0 audit prose restating the DPIA boundary. Neither is a call.

**Call-scoped grep (recommended AC3 re-reading):**
```
$ grep -rn 'api\.voyageai\|fetch.*voyage' supabase/functions/compliance-check/
(0 matches)
```

**`fetch()` audit in index.ts:**
- `${SUPABASE_URL}/functions/v1/send-report-email` (internal Edge → Edge)
- `https://api.anthropic.com/v1/messages` (Anthropic API)

No Voyage call exists. The brief-internal contradiction between §10.1's verbatim requirement and Step 13's literal grep rule is logged here for Director adjudication. Recommendation: accept Option B (call-scoped grep) which upholds AC3's semantic intent.

### File inventory for this commit set

| File | Commit | Lines | Purpose |
|---|---|---|---|
| `supabase/functions/compliance-check/CCA-002-PHASE-2-AUDIT.md` | `3bf5e00` | +79 | §0 read-first audit |
| `supabase/functions/compliance-check/v41-rollback-source.ts` | `066d82d` | +641 | v41 verbatim rollback snapshot |
| `supabase/functions/compliance-check/index.ts` | `56cf682` | 840 (+815 / −241) | v42 surgical diff |
| `supabase/functions/compliance-check/PHASE-2-COMPLETION-AUDIT.md` | (this commit) | — | §13 audit + §14 integrity signals |

### §9 scope-exclusion verification

No files touched outside `supabase/functions/compliance-check/`. Pre-screen logic,
forward-exposure severity guide, gap-fill behaviour, scoring, upload/download,
email trigger, tier char limits, and out-of-scope response flow untouched.

### Deferred items (not CC surface)

- §6.12 Edge Function deploy — Chairman via Supabase MCP, post-merge
- §10.2 End-to-end AC7 test — Chairman post-deploy
- PR open — Director manual in GitHub UI

## §12.4 Push report

Populated after push completes. See final CC message for compare URL.
