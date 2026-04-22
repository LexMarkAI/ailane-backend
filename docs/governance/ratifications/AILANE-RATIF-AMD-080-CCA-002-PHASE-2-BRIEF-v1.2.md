# AILANE-RATIF-AMD-080

**CEO ratification instrument**
**Document reference:** AILANE-RATIF-AMD-080
**Amendment register entry:** AMD-080
**Instrument ratified:** AILANE-CC-BRIEF-CCA-002-PHASE-2 v1.2
**Ratification date:** 22 April 2026
**Status:** Draft — awaiting CEO signature

---

## §1 Scope of ratification

This instrument ratifies `AILANE-CC-BRIEF-CCA-002-PHASE-2` at version **v1.2** as the controlling build brief for Phase 2 of compliance-check architecture CCA-002. Upon signature, v1.2 governs the execution protocol for all three executing agents (Chairman-on-Claude.ai, Claude Code, Director) through to completion audit (brief §13) and final delivery report (brief §14).

v1.0 and v1.1 of the brief are superseded but preserved per AMD-079 Rule 5. v1.2 is the sole operative version.

## §2 Governing amendments in force

| Amendment | Instrument | Ratified | Relation to this ratification |
|---|---|---|---|
| AMD-076 | AILANE-SPEC-CCA-002 v1.1 | 22 April 2026 | Defines the Phase 2 scope this brief implements |
| AMD-078 | AILANE-DPIA-CCA-002-PHASE-2 v1.3 | 22 April 2026 | Controlling instrument (lex posterior). §4.2 design boundary and §5.2 G1–G8 are binding on the build |
| AMD-079 | AILANE-SKILL-ailane-review-cycle | 22 April 2026 | Governs filename discipline during multi-cycle review |
| **AMD-080** | **This ratification of brief v1.2** | **22 April 2026 (on signature)** | **Authorises execution of the Phase 2 build under the brief's three-agent chain** |

## §3 Director decisions locked by this ratification

The following decisions were resolved during v1.1 → v1.2 review and are binding for the duration of the Phase 2 build. Re-opening any of them requires a new amendment, not a v1.3 brief revision.

1. **`verify_jwt` posture for compliance-check v42 deploy:** preserve production `false` per ailane-cc-brief RULE 4 (pipeline/orchestration categorisation). Spec-drift logged as amendment-queue item **A-01** for post-build batch resolution; spec §3.1 will be amended to `false` with footnote rationale, not the other way round.
2. **Phase numbering precedence:** DPIA v1.3 ordering controls. "Phase 2" in the brief means the Knowledge Library grounding build at compliance-check v42 / engine v26. Spec §9 drift (spec labels this work as Phase 3) logged as amendment-queue item **A-02**.
3. **COP §4.5 verbatim verification:** skipped. DPIA v1.3 controls under lex posterior — no re-verification of spec §4.5 clause-by-clause required before build start.
4. **AM-001 spec amendment batching:** deferred to post-build amendment batch. Build does not wait on spec reconciliation.
5. **On-add embedding automation:** deferred to `horizon-change-applier` Edge Function build (scope exclusion X16 in brief §9). Until then, on-add embedding is a manual re-invocation of `scripts/phase2/backfill-requirement-embeddings.ts` by Director against any newly-added or materially-edited `regulatory_requirements` row.

## §4 Binding constraints re-stated

The eight binding constraints in brief §2 (C1–C8) derive from DPIA v1.3 and are not negotiable under this ratification. The single most load-bearing constraint, reproduced here for signature clarity:

> **compliance-check v42 MUST use pre-computed embeddings at runtime. It MUST NOT invoke voyage-law-2 at runtime.** Voyage invocation is confined to the backfill script and future on-add events. Runtime retrieval is pgvector cosine similarity against `regulatory_requirements.embedding` — a Postgres operation, not an external API call.

Violation of C1–C8 during execution is a DPIA breach and blocks deployment regardless of other acceptance status.

## §5 Acceptance authority

No deploy of compliance-check v42 is authorised until all 8 Acceptance Criteria AC1–AC8 (brief §10) are evidenced, each cross-referencing the DPIA v1.3 §5.2 G-gate it evidences. AC evidence is reported in the completion audit (brief §13) and the final delivery integrity report (brief §14). Director is the sole authority on merge and deploy sign-off.

## §6 Amendment queue carried forward

The following items are deferred to a post-build amendment batch at Director signal. They do not block ratification or build start.

| Queue item | Subject | Resolution target |
|---|---|---|
| A-01 | `verify_jwt` spec-vs-production drift | Amend spec §3.1 to match live `false` posture |
| A-02 | Phase-numbering drift (brief uses DPIA ordering, spec §9 labels work as Phase 3) | Reconcile spec §9 to DPIA ordering |
| A-03 – A-05 | Reserved for additional drift items surfaced during execution | Per Chairman working-surface amendment queue |

## §7 Re-review triggers

This ratification remains in force through brief v1.2 execution unless one of the following re-review triggers fires (per DPIA v1.3 §11):

- Material change to the on-add embedding cadence (X16 scope exclusion unblocked before `horizon-change-applier` build)
- Anthropic pricing change altering `eileen_model_pricing` seed by >20% on any row between seed time and deploy
- Any AC1–AC8 failure that cannot be resolved by a surgical brief clarification (i.e. requiring a structural change to the execution model)
- Any discovery that production state (brief §0.3 V1–V8) has drifted from the snapshot this brief is built on

Any trigger halts execution and requires Chairman to issue a v1.3 brief, with a fresh ratification instrument superseding this AMD-080.

## §8 Rollback authority

Rollback procedures in brief §11 are pre-authorised under this ratification. Chairman may execute Edge Function rollback (§11.1) without further Director sign-off if a production incident is detected post-deploy. Schema rollback (§11.2) requires explicit Director escalation, given schema changes are additive and non-breaking with v41.

## §9 CEO signature

By signature below, the CEO ratifies AILANE-CC-BRIEF-CCA-002-PHASE-2 v1.2 as the controlling build brief, confirms AMD-080 entry into AILANE-AMD-REG-001, and authorises Chairman, Claude Code, and Director to commence execution per the brief's three-agent chain.

| Field | Value |
|---|---|
| Name |  |
| Role | Chief Executive Officer, Ailane |
| Signature |  |
| Date signed |  |

On signature, Chairman updates AILANE-AMD-REG-001 to record AMD-080 as ratified and circulates the final ratified brief text to all three executing agents as the build-start signal.

---

**End of AILANE-RATIF-AMD-080**
