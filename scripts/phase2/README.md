# Phase 2 backfill scripts

## backfill-requirement-embeddings.ts

One-time job: populates `regulatory_requirements.embedding` with voyage-law-2 embeddings.

### Run

```bash
deno run --allow-env --allow-net --allow-read scripts/phase2/backfill-requirement-embeddings.ts
```

### Env vars required

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `VOYAGE_API_KEY`

### Idempotency

Processes only rows `WHERE embedding IS NULL`. Safe to re-run.

### Governance

Part of AILANE-CC-BRIEF-CCA-002-PHASE-2 §5.
Ratified under AMD-076 (CCA-002 v1.1). DPIA §4.2 boundary: this is the ONLY Voyage invocation path.
