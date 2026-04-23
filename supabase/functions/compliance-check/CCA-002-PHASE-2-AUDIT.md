# CCA-002 Phase 2 — §0 Read-First Audit Report

Engine: compliance-check v41 → v42 (ENGINE_VERSION v25 → v26)
Brief: AILANE-CC-BRIEF-CCA-002-PHASE-2 v1.2 (ratified AMD-080, 22 April 2026)
Session: Nl7QV
Date: 23 April 2026

## §0.1 Ratified governing artefacts

| Artefact | Status |
|---|---|
| AILANE-SPEC-CCA-002 v1.1 (AMD-076) | Binding excerpts reproduced in brief |
| AILANE-DPIA-CCA-002-PHASE-2 v1.3 (AMD-078) | Controlling instrument; §4.2 design boundary bound |
| AILANE-AMD-REG-001 | Master register (context only) |
| ailane-review-cycle skill (AMD-079) | Not invoked this session |

## §0.2 §4.2 DPIA design boundary

compliance-check v42 MUST NOT invoke voyage-law-2 at runtime. Runtime retrieval uses pre-computed
embeddings + pgvector cosine similarity only. Voyage is confined to backfill / on-add events (no
Edge Function call site in this build).

## §0.3 Production state (Chairman-verified 23 April 2026)

| Check | Result |
|---|---|
| compliance-check deployed | v41 / ENGINE_VERSION v25 |
| regulatory_requirements.embedding | Added + backfilled 79/79 |
| compliance_findings.grounding_refs / model_cost_usd | Columns added |
| kl_provisions embeddings | 401/401 (1024-dim) |
| kl_cases embeddings | 240/240 (1024-dim) |
| pgvector | 0.8.0 |
| eileen_model_pricing | Seeded (4 rows) |
| ivfflat indexes | Created on all three embedding columns |
| kl_grounding_search_provisions / _cases RPCs | Live, smoke-tested |

## §0.4 v41 source read

v41 index.ts received verbatim from Director (session-opening paste). Anchors confirmed:

| Symbol | v41 line |
|---|---|
| `ENGINE_VERSION = "v25"` | 9 |
| `BATCH_MODELS` array | 41–44 |
| `callClaude` function | 67–106 |
| `Finding` interface | 144–159 |

v41 snapshot staged verbatim at `supabase/functions/compliance-check/v41-rollback-source.ts`
(pre-deploy rollback artefact, committed before v42 edits).

Note on repo drift: the pre-existing repo index.ts was 266 lines and did not match deployed v41.
This build anchors on the deployed v41 paste, not the drifted repo file, per authority hierarchy
item 3 of the session-opening note.

## §0.5 Environment secrets

| Secret | Location | Status |
|---|---|---|
| VOYAGE_API_KEY | Director local .env | Backfill already executed (not used at runtime) |
| SUPABASE_SERVICE_ROLE_KEY | Director local .env | Confirmed |
| ANTHROPIC_API_KEY | Supabase Edge Function secrets | Confirmed |

## §2 Binding constraints C1–C8 — acknowledged

| # | Constraint | Implementation surface |
|---|---|---|
| C1 | No Voyage at runtime | Verified by AC3 grep (0 matches) |
| C2 | Voyage confined to backfill / on-add | No Edge Function call site |
| C3 | Pre-computed embeddings only | `retrieveGrounding` reads `regulatory_requirements.embedding` then RPCs |
| C4 | Grounding refs per finding | `Finding.grounding_refs: GroundingRef[] \| null` |
| C5 | Model cost per finding | `Finding.model_cost_usd: number \| null`; `computeCallCostUsd` + per-finding allocation |
| C6 | 3-step model fallback | `BATCH_MODELS = [sonnet-4-6, sonnet-4-5, haiku-4-5]` |
| C7 | Per-model timeouts 45/35/25s | `BATCH_TIMEOUTS_MS = [45_000, 35_000, 25_000]` + `callClaude` `timeoutsMs` param |
| C8 | 150s wall-clock cap preserved | Parallel A/B/F, worst case 45+35+25 = 105s per batch, parallel |

## §9 Scope exclusions X1–X16 — acknowledged

No edits outside `supabase/functions/compliance-check/`. Pre-screen, forward-exposure path,
gap-fill, scoring, upload/download, email, and frontend are untouched.
