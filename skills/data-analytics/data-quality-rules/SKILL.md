---
name: data-quality-rules
description: >
  Teaches how to define and enforce data quality rules across the pipeline — the
  six data quality dimensions (completeness, accuracy, consistency, timeliness,
  validity, uniqueness) each with a concrete rule pattern, extraction confidence
  thresholds tied to `data-classification`'s propagation model, gate placement in
  the pipeline (reject/quarantine/pass with confidence-band routing), the
  distinction between a Dead Letter Queue and a quarantine store, and how data
  quality metrics feed `metrics-instrumentation-plan`. Used by the data-engineer
  during Data.
version: 1.0.0
phase: data
owner: data-engineer
created: 2026-07-20
tags: [data, analytics, data-quality, confidence, validation, quarantine, dlq]
---

# Data Quality Rules

## Purpose

Data classification (`data-classification`) tells you how sensitive a piece of data is. Data quality tells you whether you can trust it at all — whether it's complete, accurate, consistent, timely, valid, and not duplicated. In a compliance product, bad data quality is not a cosmetic problem: a compliance finding built on a low-confidence extraction, a duplicated entity, or a stale sensitivity level is a wrong finding presented as evidence.

This skill defines the concrete rules that check data quality at each stage of the pipeline, sets the extraction confidence thresholds that decide whether automated output can be trusted, and places quality gates in the pipeline topology the data-architect designed (`data-pipeline-design`). It is implemented as part of the pipeline stage workers (`data-pipeline-implementation`) and its pass/fail rates feed the quality metrics tracked in `metrics-instrumentation-plan`.

---

## The Six Data Quality Dimensions

Each dimension gets a concrete, checkable rule — not a vague aspiration. "Data should be accurate" is not a rule; a rule is something a `CHECK` constraint, a validation function, or a pipeline gate can evaluate.

| Dimension | Question | Rule pattern | Example check |
|---|---|---|---|
| **Completeness** | Is required data present? | Required-field non-null check | `data_assets.source_id IS NOT NULL` — every asset must trace to a source |
| **Accuracy** | Does the data correctly represent reality? | Confidence-scored comparison against ground truth or a trusted source | Extraction confidence score ≥ threshold for the entity type (see below) |
| **Consistency** | Does the data agree with itself and related data? | Cross-field / cross-table invariant check | An asset's `sensitivity_level` is never lower than the max of its contained entities' levels (see `data-classification`'s propagation rule) |
| **Timeliness** | Is the data current enough to be useful? | Age/staleness threshold | `data_assets.last_scanned_at` within the source's configured scan interval, or the asset is flagged stale |
| **Validity** | Does the data conform to its expected format/domain? | Schema/format/enum constraint | `sensitivity_level IN ('Public','Internal','Confidential','Restricted')`; `email` field matches RFC 5322 shape before being trusted as a detected entity |
| **Uniqueness** | Is the same real-world thing represented once? | Deduplication key / natural-key uniqueness constraint | No two `Entity` rows for the same `(data_asset_id, entity_type, normalized_value)` — see `lineage_edges`' natural-key pattern in `data-lineage-design` for the same idea applied to lineage |

Each rule is implemented as close to the data as possible: a PostgreSQL constraint where the invariant is absolute (validity, some uniqueness), and a pipeline-stage check where the judgment is probabilistic (accuracy, timeliness, completeness that depends on upstream state).

```sql
-- Validity: sensitivity level domain constraint
ALTER TABLE data_assets
  ADD CONSTRAINT valid_sensitivity_level
  CHECK (sensitivity_level IN ('Public','Internal','Confidential','Restricted'));

-- Uniqueness: one entity per (asset, type, normalized value)
ALTER TABLE extracted_entities
  ADD CONSTRAINT uniq_entity_per_asset
  UNIQUE (data_asset_id, entity_type, normalized_value);

-- Consistency: an asset's stored level is never below its computed minimum
-- (enforced in application logic at write time, not a CHECK constraint,
-- because the computation spans a join — see the propagation rule)
```

---

## Extraction Confidence Thresholds

Automated extraction (entity detection, classification) produces a confidence score, not certainty. `data-classification` already established the core rule: **below a configured threshold, the result is not auto-applied — it is flagged for review.** This skill makes that threshold concrete and ties it to specific entity-type risk.

| Entity type / signal | Confidence threshold | Below threshold → |
|---|---|---|
| `EMAIL`, `PHONE`, `PERSON_NAME` (general PII) | ≥ 0.85 | Flag for steward review; provisional level not auto-applied |
| `SSN`, `NATIONAL_ID`, `PASSPORT` (strong identifiers) | ≥ 0.90 (higher bar — false negative here is a compliance miss, false positive is costly review load) | Flag for steward review |
| `HEALTH_TERM`, `DIAGNOSIS` (special-category) | ≥ 0.90 | Flag for steward review |
| Document-level classification (aggregate of contained entities) | Inherits the lowest confidence of any contributing entity that drove the level | Asset-level flag for review |

The threshold is not a single global number — it is set per entity-type by the risk of getting it wrong, exactly as `data-classification`'s detection table implies. A data-quality rule that applies one blanket confidence threshold to every entity type either over-flags low-risk types (wasting steward time) or under-flags high-risk ones (the actual compliance failure mode).

**Thresholds are configuration, not code.** They are tuned over time as extraction models improve — store them in a lookup table or config, not a hardcoded constant, so a threshold change doesn't require a pipeline redeploy.

---

## Quality Gate Placement in the Pipeline

Every pipeline stage (from `data-pipeline-design`'s topology) that produces data other stages or humans depend on has a quality gate at its output. The gate has three possible outcomes — never just pass/fail:

| Outcome | Meaning | What happens next |
|---|---|---|
| **Pass** | Meets all quality rules and confidence thresholds for its type | Proceeds to the next pipeline stage normally |
| **Quarantine** | Fails a quality rule or falls below a confidence threshold, but is not malformed | Routed to a quarantine store for human review; does NOT proceed downstream until resolved |
| **Reject** | Malformed, undecodable, or violates a hard invariant (e.g., missing `tenant_id`) | Routed to the Dead Letter Queue — this is a processing failure, not a data-quality judgment call |

```
                         ┌─ confidence ≥ threshold ──► PASS ──► next stage
Entity Extraction output ┤
                         ├─ confidence < threshold ──► QUARANTINE ──► steward review queue
                         │
                         └─ undecodable / malformed ──► REJECT ──► DLQ (see data-pipeline-implementation)
```

Placing the gate at the stage boundary — not deep inside the next stage — means a downstream consumer never has to re-derive "is this trustworthy." It either received the record because it passed, or it didn't receive it at all.

---

## Dead Letter Queue vs. Quarantine

These are frequently conflated but serve different purposes. Getting this distinction right matters because they have different SLOs, different owners, and different resolution paths.

| | Dead Letter Queue (DLQ) | Quarantine |
|---|---|---|
| Cause | Processing failure — the message couldn't be handled at all (undecodable, exhausted retries, poison message) | Data quality failure — the message was processed successfully but the *result* doesn't meet a quality bar |
| What it holds | The original, unprocessed (or unprocessable) message | The processed output, with its quality-check result attached |
| Who resolves it | Engineering (data-engineer) — usually a bug or an upstream format change | Domain expert (Data Steward, per `data-classification`) — usually a judgment call |
| Resolution path | Fix the root cause, replay from DLQ (`data-pipeline-design`'s DLQ disposition) | Review, then either confirm/correct and release, or reject permanently |
| Is it expected? | No — a growing DLQ signals a defect | Yes — some rate of low-confidence extraction is normal and expected, especially for scanned/degraded source documents |
| Alerting posture | Alert on any sustained growth (`data-pipeline-design`'s DLQ-depth alert) | Alert on queue *age* (items sitting unreviewed too long), not on volume alone |

A quarantined record is not broken — it's a record the automated pipeline correctly declined to trust on its own. Routing a quarantine case to the DLQ (or vice versa) sends it to the wrong owner: an engineer cannot resolve "is this really an SSN," and a steward cannot fix a malformed event schema.

---

## Data Quality Metrics Feeding Instrumentation

Every quality gate emits a signal that becomes a product metric, defined fully in `metrics-instrumentation-plan`:

| Signal | Rolls up into |
|---|---|
| Pass/quarantine/reject counts per stage | Data quality pass rate (by stage, by entity type) |
| Confidence score distribution | Extraction-confidence-trend metric (see `metrics-instrumentation-plan`'s worked example) |
| Quarantine queue age | Review-latency metric — how long low-confidence findings sit before a steward resolves them |
| Steward override rate (quarantine resolved as "confirm" vs. "correct" vs. "reject") | Model-accuracy proxy — a high correction rate suggests the extraction model itself needs work, not just threshold tuning |

These are **data quality metrics about the pipeline's own trustworthiness**, distinct from the system RED/USE metrics of `opentelemetry-instrumentation` (request rate, error rate, latency) and distinct from end-user product metrics like activation or gap-closure rate. A data quality metric answers "can I trust what came out of the pipeline," not "is the pipeline infrastructure healthy" or "is the customer succeeding."

---

## Worked Example — Entity Extraction Confidence-Band Routing

A scanned (image-based) PDF is processed by the Entity Extraction stage. Four entities are detected:

```
Entity 1: EMAIL "j.smith@acme.com"        confidence 0.97
Entity 2: PERSON_NAME "J. Smith"          confidence 0.91
Entity 3: SSN "0XX-XX-XXXX" (masked)      confidence 0.62
Entity 4: PHONE "+1-555-..."              confidence 0.79

Routing decision (per the threshold table):
  Entity 1 (EMAIL, threshold 0.85):     0.97 ≥ 0.85  → PASS
  Entity 2 (PERSON_NAME, threshold 0.85): 0.91 ≥ 0.85  → PASS
  Entity 3 (SSN, threshold 0.90):       0.62 < 0.90  → QUARANTINE
  Entity 4 (PHONE, threshold 0.85):     0.79 < 0.85  → QUARANTINE

Document-level classification:
  Passed entities alone would imply: Confidential (PII: email, name)
  Quarantined entities, if confirmed, would imply: Restricted (strong identifier)
  → provisional level = Confidential (from passed entities only)
  → asset flagged: "pending review — possible SSN and phone detected
    at low confidence, may escalate to Restricted"

This is exactly data-classification's rule: automated detection only
ever escalates on confirmed evidence, and a below-threshold signal
does not silently set (or silently withhold) the higher level — it
triggers review, which is the quarantine path this skill defines the
mechanics of.

Steward reviews the quarantined entities:
  Entity 3 confirmed as a real SSN     → manual_override_level = Restricted
  Entity 4 confirmed as a real phone   → contributes to Confidential (already covered)
  → DataAssetReclassified emitted: Confidential → Restricted
  → quarantine queue entry closed, resolution = "confirmed"
  → this resolution counts toward the model-accuracy proxy metric
```

Nothing was silently dropped, nothing was silently auto-escalated past its confidence, and the eventual Restricted classification is fully traceable to an audited human decision layered on top of the automated evidence — satisfying both this skill's gate-placement rule and `data-classification`'s propagation rule.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| All six dimensions covered | Completeness, accuracy, consistency, timeliness, validity, uniqueness each have at least one concrete rule | A dimension left as an aspiration with no checkable rule |
| Thresholds per entity-type risk | Confidence thresholds vary by the cost of being wrong for that type | One blanket threshold for all extraction |
| Three-way gate outcome | Every gate distinguishes pass / quarantine / reject | Gates that only pass/fail, conflating processing failure with quality judgment |
| DLQ vs. quarantine separated | Different stores, different owners, different resolution paths | Quality failures and processing failures routed to the same queue |
| Thresholds configurable | Stored as data/config, not hardcoded | Threshold buried in code, requiring a redeploy to tune |
| Metrics wired to instrumentation | Every gate outcome feeds a named metric in `metrics-instrumentation-plan` | Quality gates with no observable pass/fail rate |
| Consistent with data-classification | Rules never silently escalate or de-escalate outside the documented propagation model | A quality rule that bypasses the manual-override/escalation rules already established |

---

## Anti-Patterns

- **The blanket confidence threshold.** One number applied to every entity type regardless of the cost of a false negative. An SSN and a phone number are not equally risky to get wrong — the threshold reflects that.
- **Binary pass/fail gates.** Collapsing "this is malformed" and "this is probably wrong" into one failure bucket. They have different owners and different fixes; conflating them sends quarantine cases to engineers who can't judge them and DLQ cases to stewards who can't fix them.
- **Silent auto-escalation on partial evidence.** Computing a document's classification level as if quarantined (unconfirmed) entities were already confirmed. Only passed, confidence-cleared entities feed the provisional level; quarantined entities feed the review flag, not the level itself.
- **Quarantine as a black hole.** A quarantine queue nobody ages out or alerts on. Unlike a DLQ (alert on volume), quarantine is alerted on *age* — a growing backlog of unreviewed low-confidence findings is a steward-capacity problem, not a pipeline bug, but it is still a problem that needs visibility.
- **Hardcoded thresholds.** Baking a confidence cutoff into application code so that tuning it requires a full deploy cycle, discouraging the iteration that improving extraction models actually needs.
- **Quality metrics that don't roll up.** Emitting pass/fail counts from a gate with no defined path into a named product metric (`metrics-instrumentation-plan`). An unmeasured quality gate can silently degrade for months with nobody noticing the trend.
- **Dimension-blind validation.** Writing "data validation" as one undifferentiated check instead of naming which of the six dimensions it covers. This makes gaps invisible — a table can look "validated" while having no uniqueness or timeliness check at all.

---

## Output Format

```markdown
---
name: data-quality-rules
product: [product name]
version: 1.0.0
phase: data
created: [date]
owner: data-engineer
---

# Data Quality Rules

## Dimension Rules
| Dimension | Rule | Implementation (constraint / stage check) |
|---|---|---|

## Confidence Thresholds
| Entity type / signal | Threshold | Below-threshold outcome |
|---|---|---|

## Gate Placement
| Pipeline stage | Gate outcome options | Downstream routing |
|---|---|---|

## DLQ vs. Quarantine
| Store | Cause | Owner | Resolution path | Alerting posture |
|---|---|---|---|---|

## Metrics Feed
| Gate signal | Metric (see metrics-instrumentation-plan) |
|---|---|
```
