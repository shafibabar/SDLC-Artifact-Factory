# Example 3 — Enterprise: An Event-Sourced Context, Regional Views, Read-Your-Writes

Self-contained. **Quillmark** runs on-screen marking for national examination boards: 30,000 examiners mark scanned scripts; boards publish results on one day each summer. **Enterprise** profile, multi-tenant (each board is a tenant), served from two regions. Services: **Marking**, **Moderation**, **Candidates** and **Results**.

## Input

> **User:** "Examiners keep re-marking because their submitted marks don't show up straight away. Put the examiner dashboard on the regional replicas, but make it real-time. Also, before accepting a mark, check the examiner's quota against the dashboard so nobody marks over their allocation. And on results day, the candidate results page should call Marking, Moderation and Candidates live for every request."

## Working it

- **Marking is event-sourced** (decided in `aggregate-design` § 6): appeals must show every mark and change on a script, and who made it, as it stood on any date. So there is no current-state table to query: **projections are required** for Marking's views. That is the trigger, not a choice.
- **"Real-time" on regional replicas:** declined as stated. A projection served from two regions is eventually consistent; promising real-time would be false. The business accepts 10 seconds for the examiner dashboard (it shows progress, not decisions).
- **Why examiners re-mark:** read-your-writes is missing. The SubmitMark Command will return the script's new version, and the examiner's own dashboard shows the script as *submitted, updating* until the view has applied it. Examiners stop re-marking because they see their mark accepted.
- **Monotonic reads:** an examiner's requests can land in either region; a second request hitting the region further behind would make a submitted mark vanish. Each examiner's session is pinned to one region, and the view's version is compared with the last version the examiner saw.
- **Quota check against the dashboard:** declined. The dashboard lags, so two submissions in the same seconds could both pass and exceed the allocation. The quota is a rule on the examiner's Allocation Aggregate, checked when the mark is submitted.
- **Results-day page calling three services live:** declined. Results day brings about 2 million candidates in four hours (NFR-12), and each page would fan out to three services, so any one being slow fails every page. A CQRS view in the Results service, fed by Marking's `ScriptMarked`, Moderation's `MarksAdjusted` and Candidates' `CandidateRegistered` published events, answers from one store. Results are frozen the night before, so staleness is not a concern on the day itself.
- **Moderation:** moderators review samples, a few hundred reads an hour. No trigger: Simple Read Model.

## Output: `design/architecture/cqrs-decisions.md` (excerpt)

```markdown
---
name: cqrs-design
product: quillmark
version: 2.1.0
phase: design
owner: enterprise-architect
created: 2026-07-20
summary: Marking is event-sourced with regional examiner views and read-your-writes; Moderation stays on a Simple Read Model; Results keeps a results-day view fed by events.
profile: enterprise
traces-to: [design/marking/aggregates.md, design/marking/domain-event-catalog.md, ideate/nfr-specification.md, design/architecture/container-diagram.md]
---

# CQRS Decisions: Quillmark

Version 2.1.0: read-your-writes and region pinning added for the examiner dashboard after examiners re-marked submitted scripts.

## Contexts

| Bounded Context | Read side | Trigger | Staleness accepted |
|---|---|---|---|
| Marking | projections | event-sourced Aggregates | 10 seconds |
| Moderation | simple read model | none — rung 1 | immediate |

## Context: Marking

| Field | Value |
|---|---|
| **Read side** | projections |
| **Business-logic pattern** | Event-sourced Domain Model |
| **Event sourced** | yes — Script; projections are required |
| **Trigger** | the Script Aggregate is event-sourced (appeals need every mark as it stood on any date, aggregate-design § 6), so no current-state table exists to query |
| **Staleness accepted** | 10 seconds — the dashboard shows progress; no decision is taken from it |
| **Read-your-writes** | SubmitMark returns the script's version; the examiner's dashboard shows "submitted, updating" until the view has applied it |
| **Replicas or regions** | two regions; each examiner's session is pinned to one region and the view's version is compared with the last one the examiner saw (monotonic reads) |
| **Revisit when** | dashboard lag at peak exceeds 10 seconds, or a board needs a new view over past seasons (a rebuild from the stream) |

### Queries

| Query (screen or question) | Served by | Why |
|---|---|---|
| Examiner dashboard (scripts marked, remaining) | projection: ExaminerProgress | event-sourced context |
| Script history for an appeal | projection: ScriptHistory | every mark and change, by date |
| Remaining allocation before submitting | write side (cannot lag) | the quota rule is checked in the Allocation Aggregate |

## Context: Moderation

| Field | Value |
|---|---|
| **Read side** | simple read model |
| **Business-logic pattern** | Domain Model |
| **Event sourced** | no |
| **Trigger** | none — a Simple Read Model serves every query |
| **Staleness accepted** | immediate |
| **Read-your-writes** | immediate (same tables) |
| **Replicas or regions** | one copy per tenant's home region |
| **Revisit when** | moderators need marking data combined with their samples on one screen |

### Queries

| Query (screen or question) | Served by | Why |
|---|---|---|
| Samples awaiting review | simple read model | one query |

## Cross-service queries

| Query | Services | Approach | Trigger | Owner of the view |
|---|---|---|---|---|
| Candidate results page on results day | Marking, Moderation, Candidates | CQRS view | about 2 million candidates in four hours (NFR-12); a three-way live fan-out per page fails whenever one source is slow | Results, fed by ScriptMarked, MarksAdjusted and CandidateRegistered |
| Examiner's own marking summary for a board | Marking, Candidates | API Composition | none — composition | — |

## Open questions

- Should examiners see a mark the moderator adjusted before the board confirms it? (product owner)
```

## Why this is right

- Projections came from event sourcing, a forced trigger, not a preference.
- "Real-time" was replaced by a stated lag, read-your-writes for the examiner and region pinning for monotonic reads, which fixes the re-marking.
- The quota stays a rule in an Aggregate, never a check against a lagging view.
- The results-day view names its evidence, its owner and its feeding events.
- `validate-cqrs-decisions.sh` exits clean on the excerpt.
