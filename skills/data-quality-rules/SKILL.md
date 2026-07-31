---
name: data-quality-rules
description: >
  Define data-quality rules for a pipeline or dataset during the Data phase — the
  six DAMA data-quality dimensions (completeness, accuracy, consistency, timeliness,
  validity, uniqueness), how to express a checkable rule per dimension against the
  DataAsset/extracted_entities schema, per-entity-type confidence thresholds, the
  data-quality metrics and scorecard (per-dimension score, overall score, trending,
  threshold alerting), and the remediation workflow — quarantine, auto-correct,
  reject-to-DLQ, alert — implemented in Go at the pipeline boundary. Distinguishes a
  Dead Letter Queue from a quarantine store. Used by the data-engineer.
version: 2.0.0
phase: data
owner: data-engineer
created: 2026-07-20
tags: [data, data-quality, dama, completeness, accuracy, validation, remediation, go]
related: [data-classification, data-pipeline-design, data-pipeline-implementation, metrics-instrumentation-plan, data-lineage-design]
---

# Data Quality Rules

## Purpose

Data classification (`data-classification`) tells you how sensitive a piece of data is. Data quality tells you whether you can trust it at all. In a compliance product, bad data quality is not cosmetic: a finding built on a low-confidence extraction, a duplicated entity, or a stale sensitivity level is a wrong finding presented as evidence.

This skill defines the concrete rules that check quality at each pipeline stage, computes a scorecard that tracks trustworthiness *over time*, and routes a failing record to the right remediation path. Rules attach to the six DAMA data-quality dimensions; gates sit at the stage boundaries the data-architect designed (`data-pipeline-design`); pass/fail rates feed `metrics-instrumentation-plan`.

---

## The Six DAMA Data-Quality Dimensions

DAMA-DMBOK's Data Quality Management KA names six independently measurable dimensions. Each gets a concrete, checkable rule — "data should be accurate" is not a rule; a rule is something a `CHECK` constraint, a validation function, or a pipeline gate can evaluate.

| Dimension | One-line definition | Rule attaches as |
|---|---|---|
| **Completeness** | Is all required data present? | Required-field non-null check on the DataAsset |
| **Accuracy** | Does the data correctly represent reality? | Confidence-scored comparison against a trusted source / threshold |
| **Consistency** | Does the data agree with itself and related data? | Cross-field / cross-table invariant |
| **Timeliness** | Is the data current enough to be useful? | Age / staleness threshold |
| **Validity** | Does the data conform to its format/domain? | Schema / format / enum constraint |
| **Uniqueness** | Is the same real-world thing represented once? | Deduplication / natural-key uniqueness constraint |

**How a rule attaches to a dimension.** Every rule declares the one dimension it covers. This is not bookkeeping: naming the dimension makes gaps visible — a table can look "validated" while having no uniqueness or timeliness rule at all. A rule that cannot name its dimension is a smell. Implement each rule as close to the data as its certainty allows: a PostgreSQL constraint where the invariant is absolute (validity, hard uniqueness), a pipeline-stage check where the judgment is probabilistic (accuracy, timeliness, completeness that depends on upstream state).

Per-dimension depth — concrete rules on this repo's schema, thresholds, and DAMA grounding: **`references/dq-dimensions-catalogue.md`**.

> DAMA's six-dimension model is deliberately fuller than the three-characteristic framing (accuracy, completeness, timeliness) in *Fundamentals of Data Engineering* — keep all six; they catch failure modes the lighter model misses.

---

## The Data-Quality Scorecard

Individual gate outcomes answer "is this record trustworthy right now." They do not answer "is a rule silently degrading." DAMA's Data Quality KA is a continuous cycle, not a one-time gate design: profile, measure continuously, and trend a **scorecard** so a slow decline (e.g. falling OCR confidence on scanned PDFs) is caught as a *trend*, not by one analyst noticing.

The scorecard is a recurring artifact, distinct from `data-storytelling`'s one-off narrative. It reports, per dimension and overall, the pass rate over a rolling window, and it alerts when a dimension drops below its configured threshold.

- **Per-dimension score** — the fraction of evaluated records passing that dimension's rules in the window.
- **Overall score** — a weighted roll-up across the six dimensions (weights reflect compliance risk, not equal thirds).
- **Trend + alert** — a dimension falling below threshold, or trending down across windows, fires an alert.

Computation formulas, the scorecard table shape, trending, and threshold-alerting mechanics: **`references/dq-metrics-and-scorecard.md`**.

---

## The Remediation Decision

When a record fails a rule, the gate does not simply "fail" it. It selects one of four remediation paths. Collapsing these into a binary pass/fail is the central anti-pattern — the four paths have different owners and different fixes.

| Path | When to select it | Owner |
|---|---|---|
| **Quarantine** | Processed successfully, but the *result* fails a quality rule or falls below a confidence threshold; needs a judgment call | Data Steward (`data-classification`) |
| **Auto-correct** | The failure is deterministically fixable by a known rule (trim, canonicalize, normalize casing, dedupe on natural key) | Automated — no human |
| **Reject** | Malformed, undecodable, or violates a hard invariant (missing `tenant_id`) — a processing failure, not a quality judgment | Engineering (data-engineer), via DLQ |
| **Alert** | A rule's failure *rate* crosses a threshold — the individual record's path is orthogonal; this signals a systemic problem | On-call / steward, depending on rule |

**Selection principle:** try auto-correct first only for failures with a deterministic, lossless fix; never "auto-correct" a probabilistic judgment (that is quarantine). Route malformed input to reject, never quarantine — a steward cannot fix a broken schema. Alert is not exclusive with the other three: a record quarantines *and* contributes to a rate that may alert.

**DLQ vs. quarantine** are frequently conflated but have different SLOs, owners, and resolution paths. A DLQ holds the original unprocessable message (engineering fixes the root cause and replays); a quarantine holds the processed output with its quality result attached (a steward confirms/corrects/rejects). A growing DLQ signals a defect (alert on volume); some quarantine rate is normal (alert on *age*).

Full remediation workflow — the quarantine table, the auto-correct rule catalogue, reject-to-DLQ wiring, alerting, and the Go validation implementation at the pipeline boundary: **`references/remediation-and-go.md`**.

---

## Where This Sits

- Gates go at each stage *output* (`data-pipeline-design`'s topology), so a downstream consumer never re-derives "is this trustworthy" — it received the record because it passed, or not at all.
- Confidence thresholds are **per entity-type risk**, not one blanket number, and are **configuration, not code** (tunable without a redeploy) — see `data-classification`'s propagation model and `references/dq-dimensions-catalogue.md`.
- Every gate outcome and scorecard signal rolls up into a named metric in `metrics-instrumentation-plan`. An unmeasured gate can degrade for months unnoticed.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| All six dimensions covered | Each of the six has ≥1 concrete, checkable rule | A dimension left as an aspiration |
| Rule names its dimension | Every rule declares the one dimension it covers | Undifferentiated "data validation" |
| Four-way remediation | Gates select quarantine / auto-correct / reject / alert | Binary pass/fail, conflating processing failure with quality judgment |
| DLQ vs. quarantine separated | Different stores, owners, resolution paths | Both failure types in one queue |
| Thresholds per entity-type risk, configurable | Vary by cost-of-being-wrong; stored as data | One blanket hardcoded threshold |
| Scorecard trends over time | Pass rate per dimension trended on a rolling window with alerting | Only point-in-time gate outcomes |
| Metrics wired to instrumentation | Every outcome feeds a named metric | Gates with no observable rate |

---

## Anti-Patterns

- **The blanket confidence threshold.** One number for every entity type — an SSN and a phone are not equally risky to get wrong.
- **Binary pass/fail gates.** Collapsing "malformed" and "probably wrong" into one bucket sends quarantine cases to engineers who can't judge them and DLQ cases to stewards who can't fix them.
- **Auto-correcting a judgment call.** "Correcting" a probabilistic extraction instead of quarantining it silently manufactures wrong evidence.
- **Quarantine as a black hole.** A queue nobody ages out or alerts on — quarantine is alerted on *age*, not volume.
- **Point-in-time only, no scorecard.** Correct per-record gates with no trend artifact; a rule degrades slowly and nobody sees it.
- **Hardcoded thresholds.** Baking a cutoff into code so tuning needs a full deploy, discouraging the iteration extraction models need.
- **Dimension-blind validation.** One undifferentiated check that never names which dimension it covers, making gaps invisible.

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

## Confidence Thresholds
| Entity type / signal | Threshold | Below-threshold remediation path |

## Scorecard
| Dimension | Weight | Window | Pass-rate | Alert threshold |

## Remediation Routing
| Failure kind | Path (quarantine/correct/reject/alert) | Store | Owner |

## Metrics Feed
| Gate signal | Metric (see metrics-instrumentation-plan) |
```
