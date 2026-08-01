---
name: workflow-orchestration
description: >
  Teaches the enterprise-architect to design orchestration-based distributed
  workflows — the orchestration-vs-choreography decision (extends
  event-driven-patterns), the process-manager / persisted-state-machine model,
  the compensatable/pivot/retriable step classes, semantic locks and Saga
  isolation countermeasures, and the API-Composition-vs-CQRS query boundary.
  Positions a central orchestrator (e.g. Conductor, or a hand-rolled Go
  coordinator) as the deliberate exception to the repo choreography default for
  complex, long-running, visibility-critical flows. Used during Design when
  defining how a multi-step business process spanning Bounded Contexts is
  coordinated and how its cross-service queries are answered.
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-07-31
tags: ["design","architecture","orchestration","saga","process-manager","choreography","workflow"]
produces: workflow-orchestration-design
domain: architecture
status: stable
related: ["event-driven-patterns","integration-design","conductor-workflow-authoring","cqrs-pattern"]
---

# Workflow Orchestration

## Purpose

`event-driven-patterns` makes **choreography the platform default** and names orchestration as one row in its selection table. This skill owns the *orchestration half* as a design object: the orchestrator as a **persisted state machine**, the **compensatable/pivot/retriable** step classes as an authoring discipline, the **semantic-lock** and other countermeasures for the Saga's missing isolation, and the **API-Composition-vs-CQRS** decision for cross-service queries. It is knowledge, not reasoning: it holds the criteria and models. Applying them to a specific flow — where *this* pivot sits, which query graduates to a Read Model — is the enterprise-architect's job.

This skill is the **selector and design depth**; `conductor-workflow-authoring` is the concrete authoring target once orchestration is chosen.

---

## When Orchestration Beats Choreography

Orchestration is the **deliberate exception** to the choreography+Saga default — it adds a central component every participant depends on, which is a real cost against this repo's frugality constraint. Reach for it only when one or more triggers fire:

| Trigger | Why choreography fails here |
|---|---|
| **Complexity** — 4+ steps, branching, loops, parallel fan-out/join | Flow logic smears across N services; the implicit event ordering becomes untraceable |
| **Visibility** — "where is this process right now?" must be one query | Choreography answers it only by reading N services' logs |
| **Long-running** — waits for human approval, an external signal, or hours/days | No participant owns the flow's suspended state; it is lost between reactions |
| **Compensation breadth** — undo must span 4+ services in a defined reverse order | Reverse-order compensation across autonomous reactors has no coordinator to sequence it |

**Default holds** for simple flows: 2–3 services, independent reactions, no branching, no central-view requirement — keep those choreographed. Do not orchestrate by habit.

**Frugality order** once orchestration is chosen: prefer a **hand-rolled persisted-state-machine coordinator** (Go + `pgx` + Transactional Outbox, deployed per-tenant like everything else) for a single complex flow; justify pulling in **Netflix Conductor** as an open-source engine only when the number and complexity of orchestrated flows outgrows hand-rolled coordinators and central visibility across many workflows becomes the point.

---

## The Process-Manager Model

A Saga orchestrator is the **Process Manager** pattern (Hohpe) applied to a Saga: a state machine that holds the flow state choreography would scatter. Its three obligations:

1. **States + transitions.** Explicit states; transitions fire on **reply messages** from participants. Each state dispatches the next **Command** — never business logic. The orchestrator sends Commands and consumes replies; it must not call databases or apply domain rules (that would make it a god service that bypasses participants' invariants).
2. **Persisted, transactionally.** The state transition and the Command/event it emits are written in **one local transaction** via the Transactional Outbox, so a crash mid-Saga **resumes** at the right state rather than double-sending or losing the flow. An in-memory-only orchestrator is a defect.
3. **Idempotent participants.** Every task worker dedups on message/task id, because both the Outbox relay and Redpanda redeliver at-least-once.

Full state-machine model, transition table, and a worked coordinator: `references/orchestration-saga-design.md`.

---

## The Three Step Classes

A Saga cannot roll back — each committed local transaction is visible immediately. Designing a Saga **is** deciding where the **pivot** sits. Classify every step:

| Class | Definition | Obligation |
|---|---|---|
| **Compensatable** | Runs *before* the pivot; its effect can be semantically undone | Must have a written **compensating transaction** (semantic undo, run in reverse order) |
| **Pivot** | The point of no return — once it commits, the Saga runs **forward** to completion, never backward | Exactly one per Saga; its placement is the core design decision |
| **Retriable** | Runs *after* the pivot; must eventually succeed | Retried until success (with backoff), never compensated |

A Saga with **no identified pivot**, or a "compensatable" step whose compensation is **not written**, is an incomplete design — fail it in review. Worked DataAsset onboarding Saga with a compensation for each step: `references/orchestration-saga-design.md`.

---

## Saga Isolation Countermeasures

A Saga sacrifices **I** (isolation): it gives ACD (atomicity via compensation, consistency, durability) but *not* isolation, so concurrent transactions can read the intermediate, not-yet-fully-committed state. The anomalies (lost update, dirty read, fuzzy read) and their five countermeasures are the **biggest genuine gap** in this repo's Saga material.

The primary countermeasure is the **semantic lock**: an application-level flag/state (e.g. a DataAsset in `ONBOARDING_PENDING`) set by the first compensatable step and cleared by a later retriable step, signaling "this record is mid-Saga — treat it with care." Four further countermeasures (commutative updates, and others that reorder or re-check) complete the toolkit.

The anomalies, all five countermeasures, and which to reach for when: `references/saga-isolation-countermeasures.md`.

---

## The Cross-Service Query Boundary: API Composition vs. CQRS

Once each service owns its data, a query spanning services can no longer be one join. Two patterns, and a rule for choosing:

| | API Composition | CQRS (Read Model) |
|---|---|---|
| **How** | A composer (gateway/dedicated service) calls each owning service and joins **in memory** | A query-optimized **Read Model** fed by subscribing to source contexts' Domain Events off Redpanda |
| **Cost** | Bad for large datasets / wide fan-out; couples to N services' availability | Eventual consistency + replication machinery to build and maintain |
| **Choose when** | **Default** — small result, low fan-out | The join is over large data, fan-out is too wide, OR the same data must answer **many differently-shaped queries** |

**Rule: API Composition first; graduate to CQRS on a *named* trigger.** Do not build a Read Model speculatively — name the trigger in the design. CQRS mechanics themselves live in `cqrs-pattern`; this skill owns only the *decision to build one at all*.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Coordination justified | Orchestration chosen against a named trigger (complexity/visibility/long-running/compensation) | Orchestration by habit, or a 6-service flow left choreographed |
| Pivot identified | Exactly one pivot step named; steps before are compensatable, after are retriable | Saga with no pivot, or ambiguous step classes |
| Compensation written | Every compensatable step has a documented compensating transaction | "Compensations added later" |
| State persisted | Orchestrator state + emitted Command written in one Outbox transaction | In-memory-only orchestrator that loses the flow on crash |
| Isolation addressed | Each Saga names its semantic lock (or another countermeasure) for the anomalies it exposes | Intermediate state readable with no countermeasure named |
| Query graduated deliberately | Cross-service query defaults to API Composition; CQRS justified by a named trigger | Read Model built speculatively |

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Orchestrator doing the work** | Coordinator calls DBs / applies domain rules → god service bypassing invariants | Orchestrator only sends Commands, tracks state, triggers compensations |
| **In-memory orchestrator** | Crash mid-Saga loses or double-sends the flow | Persist state + Command in one Outbox transaction; resume on restart |
| **Pivot as afterthought** | No point-of-no-return means undefined behavior on late failure | Decide the pivot first; it *is* the Saga design |
| **Isolation ignored** | Concurrent readers see intermediate state (lost update, dirty/fuzzy read) | Set a semantic lock or another countermeasure per Saga |
| **Speculative Read Model** | CQRS replication machinery built before a query needs it | API Composition until a named trigger fires |
| **Conductor by reflex** | A central engine dependency added for a single simple flow | Hand-rolled Go coordinator first; Conductor only when flows multiply |

---

## References

- **`references/orchestration-saga-design.md`** — the process-manager persisted-state-machine model (states, transitions, per-state Command dispatch), the compensatable/pivot/retriable step classes with compensating transactions, a fully worked **DataAsset onboarding Saga** (register → scan → classify → compliance-check → index) with a compensation for each step and the pivot placement reasoned out, Go coordinator sketch on `pgx` + Outbox, and the written rule for when orchestration beats choreography.
- **`references/saga-isolation-countermeasures.md`** — the Saga's missing-isolation anomalies (lost update, dirty read, fuzzy/non-repeatable read) and all five countermeasures (semantic lock, commutative updates, pessimistic view, reread value, by-value), each with when-to-use, a DataAsset example, and Go/SQL sketches — the biggest gap in this repo's Saga material.

---

## Output Format

This skill produces design notes for the Integration Design and Container Diagram artifacts:

```markdown
## Orchestration Decision: [Flow Name]
| Trigger fired | Coordinator (hand-rolled Go / Conductor) | Why not choreography |
|---|---|---|

## Saga State Machine: [Saga Name]
| State | On reply | Command dispatched | Step class (comp/pivot/retry) | Compensation |
|---|---|---|---|---|

## Isolation Countermeasures
| Anomaly exposed | Countermeasure | Semantic-lock state (if any) |
|---|---|---|

## Cross-Service Queries
| Query | Pattern (API Composition / CQRS) | Graduation trigger (if CQRS) |
|---|---|---|
```
