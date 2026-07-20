---
name: analytics-requirements
description: >
  Teaches how to elicit analytics requirements from stakeholders before any metric,
  dashboard, or report is built — starting from the decision the metric must inform,
  not the metric itself. Covers the requirements-elicitation template (decision →
  metric → data source → cadence → owner), a vanity-metric detection checklist, and
  traceability from analytics requirements to OKRs and the North Star Metric. This is
  the analytics discipline's discovery step — it precedes `dashboard-specification`,
  `reporting-spec`, and `metrics-instrumentation-plan`. Used by the data-engineer
  during Data.
version: 1.0.0
phase: data
owner: data-engineer
created: 2026-07-20
tags: [data, analytics, requirements, metrics, okr, stakeholder-elicitation, vanity-metrics]
---

# Analytics Requirements

## Purpose

The most common failure in analytics work is not a wrong number — it is a right number nobody needed. A dashboard gets built because "we should track that," a report gets scheduled because a stakeholder once asked for it in a meeting, and six months later nobody opens either. Analytics requirements elicitation exists to prevent this: before any metric is defined, a data source is queried, or a widget is drawn, this skill establishes **what decision the number will change**.

This is a requirements-discipline skill, not a build skill. It produces the analytics requirements document that `dashboard-specification`, `reporting-spec`, and `metrics-instrumentation-plan` then implement. It does not design widgets, write SQL aggregations, or wire instrumentation — those are downstream.

---

## Start From the Decision, Not the Metric

The wrong question is "what should we measure?" The right question is **"what decision is currently being made blindly, or on a guess, that this data would inform?"**

```
Wrong order:  "Let's track extraction confidence."
                    → build a chart → nobody changes behaviour because of it

Right order:  "Maya needs to know whether she can trust an automated
               classification enough to skip manual review."
                    → decision: review-skip threshold
                    → metric: extraction confidence distribution by entity type
                    → the chart exists because the decision needs it
```

Every analytics requirement traces backward from a decision. If no one can name the decision, the request is not yet a requirement — it is a curiosity, and curiosities do not justify a maintained pipeline, dashboard widget, or report.

**The elicitation question, asked of every stakeholder request:** *"When you look at this number, what will you do differently depending on what it says?"* If the honest answer is "nothing, I'll just know it," the metric is either informational (fine, but low priority — do not build a pipeline for it) or a vanity metric (see below).

---

## The Requirements Template

Every analytics requirement is captured in this structure before build work starts:

| Field | Meaning | Example |
|---|---|---|
| **Question** | The question the stakeholder actually needs answered, in their words | "Which of my data sources have the most unreviewed Restricted-sensitivity gaps?" |
| **Decision it informs** | What action changes based on the answer | Prioritise which source to remediate before the audit window closes |
| **Metric** | The precise, unambiguous quantity that answers the question | Count of `ComplianceGapReport` entries with `sensitivityLevel = Restricted` and `status = open`, grouped by `data_source_id` |
| **Data source** | The Read Model, event stream, or table the metric is computed from | `compliance_gap_summary` Read Model (see `read-model-design`) |
| **Refresh cadence** | How often the number must update to remain decision-useful | Every 15 minutes (matches the compliance engine's evaluation cadence) |
| **Owner** | Who is accountable for the metric's correctness and continued relevance | data-engineer (computation), Maya Chen persona (consumption) |

A requirement missing any of these six fields is not ready to build. "We'll figure out the refresh cadence later" is how a report ships stale and nobody notices for a quarter.

---

## Elicitation Method

1. **Ask for the decision first.** Do not ask "what do you want to see?" — stakeholders answer that with chart ideas, not decisions. Ask "what are you currently unsure about, and what would you do differently if you knew?"
2. **Restate the question back in the Ubiquitous Language.** A stakeholder says "show me our risky files" — restate as "data assets with `sensitivityLevel = Restricted` and no closed compliance gap." Confirm the restatement before proceeding; mismatched vocabulary here becomes a wrong metric later.
3. **Trace to an existing data source before inventing a new one.** Most analytics requirements are answerable from an existing Read Model or event stream (`event-schema-design`, `read-model-design`). A new requirement that needs a new pipeline stage or a new projection is a bigger commitment — flag it explicitly rather than let it hide inside "just add a query."
4. **Set the refresh cadence to the decision's tempo, not the maximum technically possible.** A monthly board report does not need 15-minute freshness; a live remediation-triage dashboard does. Over-refreshing wastes compute and pipeline load for no decision benefit (see `data-pipeline-implementation` for load implications); under-refreshing makes the number wrong when it is checked.
5. **Name one owner.** A metric with no owner drifts silently — its definition changes, its source table gets migrated, and nobody notices the number is now wrong. The owner is who gets paged when the metric looks implausible.
6. **Run the vanity-metric check** (below) before committing to build.

---

## Vanity-Metric Detection Checklist

A vanity metric looks impressive, moves in a reassuring direction, and drives no decision. Reject or reframe a requirement that fails any of these:

| Check | Fail signal |
|---|---|
| **Actionability** | No one can name what they would do differently at a different value |
| **Comparability** | The number has no baseline, target, or comparison period — "1,204 files scanned" means nothing without a denominator or trend |
| **Denominator honesty** | A raw count is presented where a rate would reveal the real story ("500 gaps closed" vs. "500 of 8,000 gaps closed, 6% closure rate") |
| **Gameable in isolation** | The metric can go up while the underlying outcome gets worse (e.g., "files scanned" rises while "files correctly classified" falls) |
| **Survives disaggregation** | An aggregate that looks good only because it hides a bad segment (overall extraction confidence is high because 90% of files are simple .txt, masking poor PDF performance) |

This checklist mirrors the OKR discipline's Key Result criteria (`okr-authoring`) — a metric that would fail as a Key Result usually fails as a dashboard metric for the same reasons: it measures activity, not outcome.

---

## Traceability to OKRs and the North Star Metric

Every analytics requirement should be traceable to one of two things:

- **A Key Result** from the current OKR set (`okr-authoring`) — the metric is one of the ways progress toward a committed outcome is measured, or
- **An operational decision** a named role makes repeatedly (Maya Chen's weekly triage, a steward's daily review queue) — the metric is not strategic but is still decision-load-bearing.

A requirement tracing to neither is the clearest vanity-metric signal there is. Record the trace explicitly in the requirements document — it is what lets a later cleanup pass ask "does anyone still use this?" against something more durable than institutional memory.

The **North Star Metric** (the single metric capturing the core value delivered to customers, set during Strategy — `okr-authoring`) sits above individual analytics requirements. When several requirements are competing for the data-engineer's limited build capacity, the one that most directly moves or explains the North Star Metric wins the priority argument.

---

## Worked Example — Compliance Officer's Audit-Prep Dashboard

Maya Chen (Compliance Officer persona, `user-persona`) is preparing for a SOC 2 Type II audit window. Elicitation session:

**Raw ask:** "I need a dashboard that shows me our compliance posture."

**Elicitation dialogue:**
- *"What decision will you make from it?"* — "Which gaps to close first before the auditor's evidence request, and whether we're going to make the deadline."
- *"What does 'compliance posture' mean precisely, in terms you'd defend to an auditor?"* — "Open gaps against SOC 2 CC6 and CC7, weighted by how severe they are, and how many are still Restricted-sensitivity and unreviewed."

**Resulting requirements:**

| Question | Decision it informs | Metric | Data source | Cadence | Owner |
|---|---|---|---|---|---|
| How many open CC6/CC7 gaps remain, by severity? | Prioritise remediation order before audit close | Count of open `ComplianceGap` entries grouped by `framework_control`, `severity` | `compliance_gap_summary` Read Model | 15 min | data-engineer |
| Are we trending toward zero open gaps by the audit date? | Decide whether to escalate for more remediation resources | Open-gap count over time vs. a linear burn-down to the audit date | `compliance_gap_summary` (time series) | Daily | data-engineer |
| Which data sources carry unreviewed Restricted gaps? | Choose which source owner to contact first | Count of open, `sensitivityLevel = Restricted` gaps by `data_source_id` | `compliance_gap_summary` Read Model | 15 min | data-engineer |

Each of these three feeds directly into `dashboard-specification`'s per-widget metric definitions. None was accepted until the decision was named — a fourth ask ("show total files scanned") was declined: no decision changed based on that count, and it failed the actionability check.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Decision-first | Every requirement states the decision it informs, elicited before the metric | Metric named before any decision is identified |
| Template complete | All six fields (question, decision, metric, source, cadence, owner) present | Any field missing or "TBD" |
| Vanity check applied | Every requirement passes the actionability, comparability, denominator, gameability, and disaggregation checks | A requirement shipped without running the checklist |
| Traceable | Requirement links to a Key Result or a named recurring operational decision | Requirement with no OKR or decision trace |
| Ubiquitous Language | Question and metric restated in canonical glossary terms | Stakeholder's informal phrasing carried through unchanged |
| Cadence matches decision tempo | Refresh interval justified by how often the decision is made | Cadence set to "as fast as possible" with no justification |
| Named owner | Exactly one accountable owner per metric | No owner, or "the team" as owner |

---

## Anti-Patterns

- **Metric-first elicitation.** Asking stakeholders "what do you want to see on a dashboard?" produces a wishlist of charts, not requirements. Always ask for the decision first; the chart follows.
- **The "just in case" metric.** Building a metric because it might be useful someday, with no current decision or owner. Every unused widget is pipeline load, storage, and cognitive clutter that outlives its justification.
- **Silent vanity metrics.** Shipping a big, reassuring number (files scanned, sources connected) because it is easy to compute and looks good in a demo, without running the vanity-metric checklist against it.
- **Cadence inflation.** Defaulting every requirement to "real-time" because it sounds better, when the underlying decision is made weekly. Over-refreshing costs pipeline capacity for zero decision benefit (see `data-pipeline-implementation`).
- **Ownerless metrics.** Requirements captured without an accountable owner drift: definitions change silently, source tables get migrated, and the number quietly becomes wrong with nobody positioned to notice.
- **Skipping the restatement.** Taking a stakeholder's informal phrasing ("risky files," "our numbers") straight into a metric definition without restating it in Ubiquitous Language first — ambiguity baked in at requirements time surfaces as a wrong dashboard months later.

---

## Output Format

```markdown
---
name: analytics-requirements
product: [product name]
version: 1.0.0
phase: data
created: [date]
owner: data-engineer
---

# Analytics Requirements

## Requirements Table
| Question | Decision it informs | Metric | Data source | Refresh cadence | Owner |
|---|---|---|---|---|---|

## Vanity-Metric Review
| Candidate metric | Actionable? | Comparable? | Honest denominator? | Gameable? | Survives disaggregation? | Verdict |
|---|---|---|---|---|---|---|

## OKR / Decision Traceability
| Requirement | Traces to (Key Result or named recurring decision) |
|---|---|

## Deferred / Rejected Requests
[Requests that failed the decision test or the vanity-metric check, and why]
```
