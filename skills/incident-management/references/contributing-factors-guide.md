# Contributing Factors Guide

This file is self-contained. Use it without needing the parent `SKILL.md` in context.

---

## What Contributing Factors Are

Contributing factors are the **systemic conditions** that, in combination, made an incident possible or made it worse. They are states of the system — gaps in design, missing safeguards, incorrect assumptions baked into configuration — not actions taken by individuals.

The discipline of identifying contributing factors correctly is the operational core of blameless culture. Get this wrong and the postmortem becomes a blame document wearing a blameless label.

---

## Why Multiple Factors — Never a Single Root Cause

Complex systems fail through the simultaneous presence of several latent conditions, not through a single cause. James Reason's "Swiss Cheese Model" (widely cited in SRE literature) captures this: each defensive layer has holes; an incident occurs when the holes happen to align. Identifying a single root cause means picking one hole and ignoring all the others.

The practical consequence of single-root-cause thinking:

1. The factor you pick as "root" is usually the most recent human action, which re-introduces individual blame.
2. The upstream conditions that made the action possible remain unfixed, guaranteeing a repeat.
3. The postmortem produces one action item instead of three to six — a less complete corrective-action set.

The counter-intuitive result confirmed by both Etsy's and Google's postmortem practice: teams that run blameless postmortems with multiple contributing factors report *more* near-misses and low-severity incidents over time, not fewer. Visibility increases because people are not hiding mistakes; incident rate does not increase.

---

## The 5-Whys Method — Adapted for Blameless Culture

The 5-Whys technique traces causality by asking "why" repeatedly until the chain reaches a systemic condition. The standard technique collapses to a single linear chain; for blameless postmortems, branch the tree at each "why" to capture multiple independent contributing factors.

### Standard (problematic) 5-Whys

```
Why did the service fail?
  → Because the schema migration broke the consumer.
Why did the schema migration break the consumer?
  → Because the engineer applied a non-backward-compatible schema.
Why did the engineer apply a non-backward-compatible schema?
  → Because they forgot to check.
```

Stop here and you have a single root cause and an implicit blame attribution.

### Branching 5-Whys (blameless version)

```
Why did the service fail?
  → Because the consumer could not deserialize messages written with the new schema.

Branch A: Why could the consumer not deserialize?
  → The new schema added a required field with no default value.
  → Why was a non-backward-compatible schema allowed?
    → The schema registry compatibility mode was set to NONE.
    → [Factor 1: schema registry compatibility enforcement was not configured]

Branch B: Why was there no immediate detection?
  → The consumer error handler returned HTTP 202 on deserialization failure.
  → [Factor 2: deserialization errors were masked as successes to callers]

Branch C: Why did it take 29 minutes to detect?
  → The consumer group lag alert threshold was set to >100,000 messages.
  → Why was the threshold that high?
    → It was set at initial configuration and never revised against actual traffic.
  → [Factor 3: alert threshold not calibrated to observed traffic baseline]

Branch D: Why was there no safety gate in deployment?
  → The CI/CD pipeline applied the schema before deploying the updated consumer.
  → Why was there no compatibility check in the pipeline?
    → No such gate was ever implemented.
  → [Factor 4: deployment pipeline had no schema compatibility enforcement gate]
```

This tree yields four distinct contributing factors instead of one, each pointing to a systemic gap with a specific corrective action.

---

## Phrasing Rules

### The Systemic Condition Test

Before writing a contributing factor, apply this test:

> "If a different person — with the same skills and the same information available — had been in the same situation, is it plausible they would have made the same decision or overlooked the same thing?"

If yes: it is a **systemic condition** (a missing guard, an ambiguous procedure, an absent alert). Write it as a contributing factor.

If no: investigate further. Either you have identified a genuine unusual error (rare) or you have stopped the "why" chain too early and need to branch further to find the upstream systemic gap.

### Phrasing by Category

**Missing safeguard:** "The [system/pipeline/configuration] had no [guard/gate/alert/check] for [condition]."
- Example: "The schema registry had no compatibility enforcement gate between schema versions on the `document-ingest-value` subject."

**Missing feedback signal:** "No [alert/log/metric/status signal] was produced when [condition] occurred, leaving the [system/operator/caller] unaware."
- Example: "No alert was configured for consumer group lag on the `document-ingest` topic below 100,000 messages; a sustained stall at 2,100 messages produced no page and no status signal to the caller."

**Incorrect assumption baked into configuration:** "The [configuration value/threshold/policy] was set assuming [condition A], but actual behavior was [condition B]."
- Example: "The consumer group lag alert threshold was set assuming high-throughput pipeline volumes (>100,000 messages) — the `document-ingest` topic's actual daily volume is ~3,000 messages, making the threshold unreachable within a 24-hour incident window."

**Missing operational procedure:** "The [runbook/deployment gate/checklist] had no step for [verification/check/rollback trigger]."
- Example: "The deployment procedure had no step to verify schema backward-compatibility before promoting the migration to production."

**Incorrect error propagation:** "When [failure condition], [component] returned [wrong signal] rather than [correct signal], causing [downstream effect]."
- Example: "When schema deserialization failed, the consumer returned HTTP 202 Accepted to the caller, masking the error as a success and preventing caller-side retry or detection."

---

## Anti-Patterns That Reintroduce Blame

These phrasings appear blameless but encode blame. Catch and rephrase them.

### Anti-Pattern 1: Passive voice with an implied actor

**Blameful:** "The schema was applied without checking backward compatibility."
**Why it's a problem:** Implies someone chose not to check. The implied actor is an individual.
**Blameless:** "The pipeline had no automated backward-compatibility check; the deploy succeeded without one."

### Anti-Pattern 2: "Forgot to" or "failed to"

**Blameful:** "The on-call engineer failed to notice the consumer lag metric."
**Why it's a problem:** Directly attributes the failure to an individual's attention.
**Blameless:** "No alert was configured to surface consumer lag below the 100,000-message threshold; the relevant metric required manual Grafana inspection to observe."

### Anti-Pattern 3: "Should have known" / "should have checked"

**Blameful:** "The engineer deploying the migration should have known to check the consumer compatibility mode."
**Why it's a problem:** States what a person should have done, implying they chose not to.
**Blameless:** "The schema registry compatibility mode was not visible in the deployment pipeline's pre-deploy summary; no automated check surfaced the NONE setting before migration."

### Anti-Pattern 4: Naming the individual

**Blameful:** "Alice deployed the new schema version without running a dry-run."
**Why it's a problem:** Names the person, making the postmortem searchable by name and creating a permanent record associating the person with the failure.
**Blameless:** "The deployment pipeline applied the new schema without a dry-run step; no gate enforced a dry-run before production schema changes."

### Anti-Pattern 5: Single-cause conclusion masquerading as a contributing factor

**Blameful:** "The root cause was the non-backward-compatible schema migration."
**Why it's a problem:** Frames a single event as the cause, collapsing the causal chain.
**Blameless:** Break this into the conditions that made the migration possible and the conditions that prevented early detection — that is four contributing factors, not one.

### Anti-Pattern 6: Vague systemic language that implies personal negligence

**Blameful:** "Insufficient attention was paid to schema compatibility."
**Why it's a problem:** "Insufficient attention" is personal negligence in systemic clothing.
**Blameless:** Name the missing system: "No automated tool checked schema compatibility at deploy time; compatibility validation depended on manual awareness."

---

## Calibrating the Number of Contributing Factors

| Count | Likely diagnosis | What to do |
|---|---|---|
| 1 | Analysis stopped too early; single root cause found, not systemic conditions | Branch the 5-Whys further; apply the Systemic Condition Test to the one factor you have |
| 2–3 | Appropriate for a simple, contained incident | Sufficient; confirm each factor has a corresponding action item |
| 4–6 | Appropriate for a multi-component incident with detection and response failures | Target range for a complex incident |
| 7+ | Contributing factors may not be grouped at the right abstraction level | Consolidate factors that share the same upstream systemic gap into one |

---

## Grouping Related Factors

When two contributing factors share the same root systemic gap, they should be stated as one factor with two effects, not as two separate items.

**Over-split (7 factors, two are duplicates in disguise):**
- "The deployment pipeline had no schema compatibility gate"
- "The deployment pipeline applied the migration before checking backward compatibility"

These are the same gap stated twice. Merge:
- "The deployment pipeline had no gate to verify schema backward-compatibility before applying a migration; the pipeline proceeded regardless of schema compatibility mode"

**Correctly split (where two genuinely distinct systemic conditions both contributed):**
- "The schema registry compatibility mode was set to `NONE`, allowing non-backward-compatible schemas to be registered without error"
- "The CI/CD pipeline applied the schema migration before deploying the updated consumer binary, eliminating any graceful transition window"

These are two distinct system configurations — one in the schema registry, one in the pipeline — and both need independent corrective actions.

---

## Contributing Factor to Action Item Mapping

Every contributing factor should map to at least one action item. If a contributing factor has no action item, either:
1. The team decided the risk is acceptable and no remediation is warranted — record that decision explicitly ("Accepted risk: [rationale]") rather than leaving the factor without a follow-up.
2. The action item was missed — go back and add it.

| Contributing Factor Category | Typical Action Item |
|---|---|
| Missing safeguard (no gate/check) | Add the gate to the pipeline, deployment procedure, or configuration |
| Missing feedback signal (no alert) | Add the alert in `alerting-rules-design` with a calibrated threshold and paging route |
| Incorrect configuration | Change the configuration value and add a validation check to prevent reversion |
| Incorrect error propagation | Change the error handler to surface the correct signal; add a test for the error path |
| Missing operational procedure | Add the step to the relevant runbook in `runbook-authoring` |
| Threshold miscalibrated to actual traffic | Calibrate the threshold against observed traffic data and schedule regular recalibration |

---

## Completed Example: Contributing Factors for the Schema Migration Incident

(Drawn from the worked example in `postmortem-template.md`)

**Factor 1:** The schema registry compatibility mode for the `document-ingest-value` subject was set to `NONE`, allowing a non-backward-compatible schema version to be registered and applied without an error or a warning.
- *Action: Set compatibility mode to `BACKWARD_TRANSITIVE`; add a validation check that prevents NONE from being set on production subjects.*

**Factor 2:** The CI/CD pipeline applied the schema migration before deploying the updated consumer binary. Consumers running the previous binary version encountered the new required field immediately, with no graceful transition period and no default value to fall back on.
- *Action: Add a deployment ordering gate: schema compatibility must be verified before the consumer binary is promoted.*

**Factor 3:** The consumer's deserialization error handler returned HTTP 202 Accepted on schema mismatch failures rather than surfacing an error to the caller. The caller received a false success signal and had no mechanism to detect that the submitted document had been dropped.
- *Action: Change the error handler to return HTTP 422; emit a structured ERROR log entry.*

**Factor 4:** The consumer group lag alert threshold was configured at >100,000 messages, calibrated to a high-throughput pipeline scenario. The `document-ingest` topic's actual daily volume is approximately 3,000 messages; at the observed stall rate, the existing alert would not have fired for approximately 33 days.
- *Action: Add a separate alert at >500 messages sustained for 5 minutes on the `document-ingest` topic; initiate a monthly alert threshold recalibration review.*
