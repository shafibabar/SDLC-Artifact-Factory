---
name: value-stream-map
description: >
  Maps the factory's own concept-to-production delivery pipeline — process
  time versus wait time at each of the eight SDLC phases, waste from approval
  gates, rework loops, and handoff friction, and flow efficiency as the
  headline metric — to drive continuous improvement of the factory itself,
  not the product it builds. Consulted by Shafi during retrospectives and by
  any agent proposing a change to phase sequencing, gate criteria, or
  handoff structure.
version: 1.0.0
phase: cross-cutting
owner: factory-governance
created: 2026-07-20
tags: [governance, value-stream-map, flow-efficiency, lean, continuous-improvement, cross-cutting]
---

# Value Stream Map

## Purpose

This skill maps how long it actually takes a unit of work — a user story, an epic slice — to travel from a problem statement to a customer validating it works, through this plugin's own eight phases: Strategy → Ideate → Design → Implement → Data → Quality → Deploy → Customer Validation. It measures the factory's delivery pipeline, not the product's runtime behavior and not the customer's business process.

A value stream map exists to answer one question honestly: **of the total time a story takes to ship, how much of that time is someone actually working on it, and how much is it sitting, waiting?** That ratio — flow efficiency — is usually far lower than intuition suggests, and it is the single highest-leverage number for improving how this factory operates.

## Scope: The Factory's Pipeline, Not the Customer's

This is easy to confuse with two other skills in this plugin, because all three produce a map with boxes and arrows. They map different things:

| Skill | Maps | Actors | Used for |
|---|---|---|---|
| `impact-mapping` (`skills/discovery/`) | The customer's business goal → actors → impacts → deliverables | The customer's organization and its users | Deciding what to build, and why it matters to the customer's business |
| `jtbd-analysis` (`skills/discovery/`) | The customer's job-to-be-done — what progress the customer is trying to make in their own life or work | The customer | Understanding customer motivation before defining requirements |
| `value-stream-map` (this skill) | This plugin's own concept-to-production pipeline — how a story moves through Strategy→...→Customer Validation | Agents, hooks, commands, and Shafi | Improving how fast and how efficiently *this factory* delivers, independent of what is being delivered |

If you are mapping the customer's business process, their workflow, or their pain points — that is `impact-mapping` or `jtbd-analysis`, and it is out of scope for this skill. If you are mapping how a story moves through this plugin's phases, agents, and gates — that is this skill, and customer business process is out of scope for it.

## Process Time vs. Wait Time

Every phase a story passes through has two components:

- **Process time** — time an agent is actively working: analyzing, designing, writing code, writing tests. Value is being added.
- **Wait time** — time the story is sitting idle: waiting for Shafi's approval at a chunk gate, waiting for a prerequisite artifact from another phase, waiting in a queue behind other work. No value is being added, but time is still passing.

**Lead time** = process time + wait time, summed across every phase the story passes through, including any time spent in rework loops. Lead time is what the customer (or Shafi) experiences as "how long did this take." Process time is what the factory actually spent working on it.

## The Eight Phases as Value Stream Stages

Each phase is one stage in the map. For a given story, record entry timestamp, exit timestamp, process time, and wait time per stage:

| Phase | Typical process activity | Typical wait source |
|---|---|---|
| Strategy | Confirming the story aligns with an existing OKR/roadmap item | Waiting for a strategy artifact to exist if this is the first story touching a new area |
| Ideate | Writing the user story, acceptance criteria, example mapping | Waiting for Shafi's prioritization call (MoSCoW) |
| Design | Event storming, bounded context assignment, ADRs, API contracts | Waiting for a chunk-gate approval before Design work starts |
| Implement | TDD cycle: tests, then Go/React code, BDD feature files | Waiting on a prerequisite service/schema from another agent's slice |
| Data | Data model, event schema, pipeline wiring for the story's data needs | Waiting for the Design-phase event schema to be finalized |
| Quality | Test execution, methodology review, mutation/contract tests | Rework loop — waiting for a defect fix and re-review |
| Deploy | Helm chart / pipeline changes, runbook updates | Waiting for a deployment window or infra dependency |
| Customer Validation | UAT scenario execution, beta feedback collection | Waiting for the pilot customer's availability |

## Flow Efficiency — the Headline Metric

```
Flow Efficiency = Total Process Time / Total Lead Time × 100%
```

This is the single number that matters most. A story with 6 hours of process time and 30 hours of lead time has 20% flow efficiency — the story was actively worked on one-fifth of the time it took to ship. Flow efficiency below roughly 15–25% is typical even in healthy pipelines (most software delivery pipelines sit in this range); the value of measuring it is not hitting some target percentage, but making waste visible so it can be deliberately reduced.

## Identifying Waste

Waste in this factory's value stream generally falls into three buckets:

1. **Approval-gate waiting** — a story sits idle between Design and Implement because it is waiting for Shafi's "go" per the chunk-gate rule in CLAUDE.md's Session Startup section. This wait is often necessary (Shafi's review is the point of the gate) but its *duration* is still wait time worth measuring — a gate that takes five minutes to clear is very different from one that takes three days.
2. **Rework loops** — a story fails `methodology-compliance-check` or `pre-phase-advance` and cycles back to the producing agent for correction, adding a second pass through part of a phase. Every rework loop is waste by definition: the same work is done twice because it wasn't done right (or specified clearly enough) the first time.
3. **Handoff friction** — time lost at the boundary between two agents' work, e.g. `enterprise-architect`'s API contract isn't in a state `backend-engineer` can start from without clarification, so time passes with neither agent actively adding value to the story.

## Worked Example

Value stream map for one user story: *"As a compliance officer, I want an alert when a DataAsset's SensitivityLevel changes without an approved change record, so I can investigate potential unauthorized reclassification."*

| Phase | Enter | Exit | Process Time | Wait Time | Notes |
|---|---|---|---|---|---|
| Strategy | Day 0, 09:00 | Day 0, 09:15 | 15 min | 0 | Confirmed alignment with existing OKR (compliance detection coverage); no new strategy artifact needed |
| Ideate | Day 0, 09:15 | Day 1, 14:00 | 45 min | ~28 h | Story + AC written same day; **wait point 1** — sat in the MoSCoW-prioritized backlog awaiting Shafi's "go" on this chunk |
| Design | Day 1, 14:00 | Day 2, 11:00 | 3 h | ~18 h | Event storming (SensitivityLevelChanged already cataloged), ADR for alert trigger rule; **wait point 2** — overnight wait for Shafi's chunk-gate approval before Implement |
| Implement | Day 2, 11:00 | Day 3, 16:00 | 5 h | ~24 h | TDD cycle for the rule-engine check and alert publish; **wait point 3 (rework loop)** — first pass failed `methodology-compliance-check` (missing BDD feature file for the alert scenario); 1.5 h rework after the defect was returned |
| Data | Day 3, 16:00 | Day 3, 18:00 | 2 h | 0 | Event schema already existed from Design; only the alert payload schema was new — minimal wait, work started immediately |
| Quality | Day 3, 18:00 | Day 4, 10:00 | 2.5 h | ~13.5 h | Test execution and methodology review passed on first submission this time |
| Deploy | Day 4, 10:00 | Day 4, 13:00 | 1.5 h | ~1.5 h | Helm values update, runbook note added; short wait for deployment window |
| Customer Validation | Day 4, 13:00 | Day 6, 09:00 | 1 h | ~46 h | UAT scenario executed same day; **wait point 4** — waiting on pilot customer availability to confirm the alert fired as expected in their environment |

**Totals:** Process time ≈ 15.75 h. Lead time ≈ 130 h (day 0, 09:00 → day 6, 09:00). **Flow efficiency ≈ 12%.**

**Waste identified:**
1. The Ideate→Design wait (wait point 1, ~28 h) is chunk-gate waiting — expected under the working agreement, but worth tracking: is Shafi's turnaround time trending up as more chunks queue?
2. The Implement rework loop (wait point 3) — a missing BDD feature file is a mechanical, checkable defect. This is a candidate for a `pre-code-generation` or `tdd-gate` hook check to catch before submission, not after — turning a rework loop into a self-caught error.
3. The Customer Validation wait (wait point 4, ~46 h, the single largest wait) is external to the factory — pilot customer availability. It's real lead time but not something the factory's own process can shorten; useful to distinguish from internal waste when reporting the number.

## Feeding Continuous Improvement of the Factory

The value stream map is not produced once and filed away. Its purpose is to feed changes to how this factory itself operates:

- A recurring rework loop at the same check (e.g. missing BDD feature files) is a signal to strengthen a hook (`pre-code-generation`, `tdd-gate`) so the defect is caught before submission, not after.
- A consistently long approval-gate wait is a signal to discuss whether the chunk-gate granularity (per CLAUDE.md's `chunk_gate` working agreement) is right, or whether smaller/larger chunks would reduce wait without weakening the review.
- A consistently long external wait (customer availability, third-party dependency) is not factory waste — it's worth naming so it isn't mistaken for something the factory controls, and so parallel work can be scheduled into that window instead of idling.

Value stream maps should be produced periodically (e.g. one per chunk, or one per notable story) rather than once at product launch — a single map is a snapshot; a series of maps over time is what reveals whether the factory is actually getting faster.

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Actual process, not ideal | Timestamps and durations reflect what actually happened, including waits and rework | Map shows the "happy path" as if no waiting or rework ever occurs |
| Process vs. wait distinguished | Every phase entry separates process time from wait time explicitly | A single "duration" number per phase with no split |
| Flow efficiency computed | Total process time / total lead time is stated as the headline metric | Durations reported with no efficiency ratio calculated |
| Waste points named | At least the largest waste sources are identified with a specific cause | "There was some waiting" with no named cause |
| Feeds an action | The map results in at least one concrete factory-improvement idea (hook, gate change, process change) | Map produced and filed with no resulting action considered |
| Out-of-scope boundary respected | Map covers only the factory's pipeline — no customer business-process content that belongs in `impact-mapping`/`jtbd-analysis` | Map conflates the customer's workflow with the factory's delivery pipeline |

## Anti-Patterns

- **Mapping the ideal instead of the actual** — drawing the process as it's documented to work rather than timing what actually happened for a real story. This produces a map that flatters the factory and hides the waste it exists to find.
- **No wait/process distinction** — reporting only total duration per phase erases the one distinction that makes the map useful. "Design took 21 hours" says nothing; "3 hours of process, 18 hours of wait" says what to fix.
- **One-and-done mapping** — producing a single value stream map at product kickoff and never again. Flow efficiency only becomes useful as a trend; a lone data point can't show whether a process change helped.
- **Scope creep into customer process** — starting to map the pilot customer's internal approval workflow inside this map. That belongs to `impact-mapping` or `jtbd-analysis`; keep this skill scoped to the factory's own eight phases.
- **Blaming without a mechanism** — naming a waste point ("Shafi took too long to approve") without proposing a mechanism that could reduce it (smaller chunks, async notification, a checklist that speeds review). A waste point without an improvement candidate is just a complaint.
- **Averaging away outliers** — reporting only average flow efficiency across many stories and discarding the worst cases. The worst cases are usually where the most instructive waste lives.

## Output Format

This skill's output is a standard Markdown artifact with frontmatter:

```markdown
---
name: value-stream-map-<story-id>
version: 1.0.0
phase: cross-cutting
owner: factory-governance
created: <YYYY-MM-DD>
---

# Value Stream Map — <Story or Slice Name>

## Summary

| Field | Value |
|---|---|
| Story / slice | <name and id> |
| Lead time | <total> |
| Process time | <total> |
| Flow efficiency | <process/lead × 100%> |
| Largest waste point | <one line> |

## Phase-by-Phase

| Phase | Enter | Exit | Process Time | Wait Time | Notes |
|---|---|---|---|---|---|
| Strategy | | | | | |
| Ideate | | | | | |
| Design | | | | | |
| Implement | | | | | |
| Data | | | | | |
| Quality | | | | | |
| Deploy | | | | | |
| Customer Validation | | | | | |

## Waste Identified

<!-- One entry per waste point, with a proposed improvement mechanism -->

1. <waste point> — <proposed factory-improvement action>

## Trend

<How this map compares to prior maps for similar stories, if any exist. First map for a product: state "baseline — no prior comparison.">
```

Stored at: `artifacts/[product]/governance/value-stream-maps/[story-id]-vsm.md`. One file per mapped story or slice; reviewed together at retrospectives to spot trends.
