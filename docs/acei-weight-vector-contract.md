# ACEI Weight Vector — Contract Summary

**Column:** `public.tribunal_enrichment.acei_weight_vector` (`jsonb`, nullable)
**View:** `public.v_tribunal_enrichment_acei_signature`
**Governance:** AILANE-SPEC-EILEEN-009 v1.0 (Cornerstone, AMD-072); ACEI Founding Constitution v1.0 Article II §2.11.
**Authority for this contract:** AILANE-CC-BRIEF-ENRICHMENT-ACEI-WEIGHTS-001 (scope pared by Director rulings, 2026-04-19).

## Purpose

`acei_weight_vector` carries a twelve-key proportional distribution describing the ACEI-category composition of the tribunal matter represented by the row, plus a provenance block identifying who computed the distribution, when, and with what stated confidence. It reflects the composition estimated by the enrichment agent; it is intelligence, not legal advice.

The scalar columns `acei_primary_category` (`integer`, 1–12) and `acei_secondary_categories` (`integer[]`) remain untouched and continue to be authoritative for single-category projection paths. The weight vector augments, it does not replace.

## Twelve canonical ACEI categories

The twelve keys of the weight vector correspond verbatim to the categories in the ACEI Founding Constitution v1.0 Article II §2.11, in the ordering fixed by AILANE-CC-BRIEF-ENRICHMENT-ACEI-WEIGHTS-001 §3.1:

| Key  | Category                                 |
| ---- | ---------------------------------------- |
| c1   | Unfair Dismissal                         |
| c2   | Discrimination                           |
| c3   | Wages / Working Time / Holiday           |
| c4   | Whistleblowing                           |
| c5   | Employment Status                        |
| c6   | Redundancy                               |
| c7   | Parental / Family                        |
| c8   | Trade Union                              |
| c9   | Breach of Contract                       |
| c10  | Health & Safety                          |
| c11  | Data Protection                          |
| c12  | Business Transfers / Insolvency          |

All twelve keys MUST be present on every non-null vector. Use `0` for categories with no bearing; do not omit.

## Shape and numerical rules

- `acei_weight_vector` is a JSON object.
- Each `c1..c12` is numeric in `[0, 1]`, expressed with up to four decimal places.
- The twelve values sum to `1.0` within a tolerance of `±0.005`. If an initial estimate falls outside tolerance it is renormalised proportionally before emission.
- A `provenance` object is always present alongside the twelve keys.

## Provenance triplet

The `provenance` object carries exactly three fields:

| Field           | Type         | Meaning                                                                                                 |
| --------------- | ------------ | ------------------------------------------------------------------------------------------------------- |
| `source`        | string       | Identifier of the producer — e.g. `enrichment.haiku.v<MAJOR>.<MINOR>` for agent output, `backfill.scalar_synthesis.v1.0` for deterministic synthesis, `<producer>.uniform_fallback` for uniform fallbacks. |
| `computed_at`   | ISO-8601 UTC | Timestamp at which the distribution was produced.                                                       |
| `confidence`    | numeric      | `[0, 1]`. The producer's confidence that the distribution faithfully represents the record. Calibrated conservatively. |

`provenance.confidence` is distinct from the scalar `acei_classification_confidence` column; the former binds only the weight vector, the latter binds the legacy scalar `acei_primary_category`.

## Database constraints

Four `CHECK` constraints are enforced on the column. Each is trivially satisfied when the column is null, so existing rows that have not yet been enriched remain valid.

| Constraint                                                   | Enforces                                                                                            |
| ------------------------------------------------------------ | --------------------------------------------------------------------------------------------------- |
| `tribunal_enrichment_acei_weight_vector_shape_chk`           | Object shape — twelve `c1..c12` keys plus a `provenance` object with `source` / `computed_at` / `confidence`. |
| `tribunal_enrichment_acei_weight_sum_chk`                    | `abs(sum(c1..c12) - 1.0) <= 0.005`.                                                                 |
| `tribunal_enrichment_acei_weight_bounds_chk`                 | Each `cN` lies in `[0, 1]`.                                                                         |
| `tribunal_enrichment_acei_weight_confidence_chk`             | `provenance.confidence` lies in `[0, 1]`.                                                           |

A GIN index (`tribunal_enrichment_acei_weight_vector_gin_idx`) supports key-presence and containment projections from downstream consumers.

## Read-side projection

Downstream consumers project via the view `public.v_tribunal_enrichment_acei_signature`, which exposes the weight vector alongside its provenance triplet, the legacy scalar category fields, and the joined `tribunal_decisions.case_number`. The view filters out rows with a null vector; zero rows is the correct initial state until enrichment begins emitting vectors. RLS is inherited from `tribunal_enrichment`; no separate policies are required.

## Out of scope for this brief

Two pieces of the weight-vector contract live in an external code path that is not mirrored in `LexMarkAI/ailane-backend`:

- The Haiku enrichment agent system-prompt extension that causes every enriched row to emit `acei_weight_vector`.
- The enrichment INSERT template that validates the emitted object client-side and binds it to the column.

Both are deferred to **AILANE-CC-BRIEF-ENRICHMENT-ACEI-WEIGHTS-002**, which will target the repository that actually hosts the enrichment agent and inserter. Backfill of existing rows is likewise deferred to that brief, because it depends on the insertion pathway.

The column being nullable is deliberate: it lets this schema change ship ahead of the prompt and inserter work without breaking the existing pipeline.

## Summary for downstream implementers

- Project through `public.v_tribunal_enrichment_acei_signature`, not directly off the raw column, to keep the provenance triplet and category keys consistently shaped.
- Treat `weight_confidence < 0.1` with a `uniform_fallback` `weight_source` as a signal the record was insufficiently described for genuine estimation.
- Treat `weight_source = 'backfill.scalar_synthesis.v1.0'` (once brief 002 lands) as deterministically synthesised from scalar categories with a fixed confidence of `0.5`.
- The twelve-key schema, sum tolerance, and provenance triplet are the contract; changes require a new AILANE-SPEC-EILEEN-009 revision.
