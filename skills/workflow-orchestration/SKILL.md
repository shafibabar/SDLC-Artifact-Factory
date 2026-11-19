---
name: workflow-orchestration
description: >
  Design an orchestrated flow across services, once Richardson's rule says a
  flow should be orchestrated: confirm which trigger fired (branching, a long
  wait, one view of progress, or compensation across 4 or more services) or
  hand the flow back to choreography or a single local transaction; classify
  every step as compensatable, pivot or retriable and place exactly one pivot
  (two points of no return are two sagas); write each compensation as
  idempotent, always eventually applicable and built from data captured on the
  way forward; design the orchestrator as a persisted state machine that sends
  commands and does no business work; set timeouts and a path for stuck flows;
  name a semantic lock or another countermeasure for the missing isolation;
  choose a hand-rolled coordinator before a workflow engine. Use when
  designing, reviewing or changing an orchestrated Saga, its compensations or
  its coordinator. Cross-service queries are cqrs-pattern's. Used by
  enterprise-architect.
version: 2.0.0
phase: design
owner: enterprise-architect
created: 2026-07-31
tags: [design, architecture, orchestration, saga, process-manager, compensation, workflow]
produces: workflow-orchestration-design
domain: architecture
status: stable
related: [event-driven-patterns, integration-design, conductor-workflow-authoring, cqrs-pattern, container-diagram, multi-tenancy-design, command-catalog, domain-event-catalog, nfr-specification, glossary-management, methodology-review]
sources:
  - research/software-architecture/microservices-patterns-richardson.md
  - research/software-architecture/software-architecture-hard-parts-ford.md
  - research/software-architecture/designing-data-intensive-applications-kleppmann-part2-consistency-consensus.md
  - research/software-architecture/fundamentals-of-software-architecture-richards-ford.md
---

# Workflow Orchestration

## Purpose

Some flows cannot stay choreographed: they branch, wait for a person, or need undoing across several services in a set order. Without a design, the undo is improvised, a crash strands the flow, and nobody can say where one stands. This skill turns an orchestrated flow into a reviewable design: where the point of no return sits, what undoes each step, what the coordinator holds, and what happens when a step never answers. **Readers:** enterprise-architect, backend-engineer, the product owner (what a failed or stuck flow does to a customer). **Question:** for this flow, what is done, what is undone, and what happens when a step fails or never answers?

The output is a document, `artifacts/<product>/design/architecture/workflow-orchestration.md` (`./templates/workflow-orchestration-design.md`), with frontmatter. `event-driven-patterns` decides per flow whether it is orchestrated and hands it here; the code is the `go-*` skills, and the engine authoring (if an engine is chosen) is `conductor-workflow-authoring`. Cross-service queries are `cqrs-pattern`'s ladder, not decided here.

| Profile | What this document holds |
|---|---|
| Lean | Normally not produced (the requirement is "skip"): steps inside one deployable share a transaction, and a short flow stays choreographed. If a flow really needs it, one saga, short |
| Standard | Optional: one section per orchestrated saga, with steps, state machine, timeouts and isolation |
| Enterprise | As standard, plus a named owner per coordinator, the progress view, and how in-flight flows survive a change to the definition |

## Procedure

1. **Read** the Integration Design and its Event-Driven Pattern Decisions (the orchestrated rows), the command and event catalogs (the commands each step sends), the container diagram, the NFR specification (how long a flow may run, what loss is tolerable) and the multi-tenancy design (the boundary the coordinator runs inside).
2. **Confirm the trigger** (`./references/saga-design.md`): a flow is orchestrated only when it branches or loops, runs long, needs one answer to "where is this one now?", or must compensate across 4 or more services in order. Name the one that fired. None fired: hand the flow back, choreographed (2 or 3 independent steps) or one local transaction (all steps in one deployable and one database). Say so plainly.
3. **List the steps** in order: the command, the context that owns it. Then **classify** each as compensatable, pivot or retriable and place the **one pivot**: the last step where abandoning the whole flow is still acceptable. Two points of no return means two sagas.
4. **Write each compensation**: semantic, never a rollback; idempotent; always eventually applicable (retried, escalated if it cannot be); built from data **captured on the way forward**; run in reverse order. A compensatable step with no written compensation is an unfinished design.
5. **Plan forward recovery after the pivot**: retriable steps are retried with backoff, never compensated; one that can fail for good goes to a manual-repair path while the flow stays visible.
6. **Design the orchestrator** (`./references/orchestrator-model.md`): states, transitions on replies, the command sent on entry to each state; the state change and the command committed in **one transaction** through the Transactional Outbox; every participant an Idempotent Consumer; **no business work** in the coordinator. Participants apply the rules.
7. **Set timeouts**: every wait (a reply, a human, an external signal) has a limit and a defined path when it expires. State how a stuck flow is found, and how the progress view answers "where is this one?".
8. **Name the isolation countermeasure** (`./references/isolation-countermeasures.md`): for each record the saga exposes mid-flight, the anomaly possible and the semantic lock (or another countermeasure), with what clears it and what releases a stale one. The record the saga's own commands change is always exposed and always gets a lock; `risk-accepted` is only for a record nobody outside the saga can read.
9. **Choose the coordinator**: a hand-rolled coordinator for one flow; a workflow engine only once many orchestrated flows have accumulated and visibility across them is the need. Only where the product is multi-tenant does tenancy enter: the coordinator then runs inside the boundary `multi-tenancy-design` chose. A single-tenant product has no such boundary; do not mention tenancy or assume it.
10. **Validate, then loop.** Run `./scripts/validate-workflow-orchestration.sh <file>`, fix every FAIL, re-run until clean; then `./resources/checklist.md`.
11. **Present** with the reason for every request declined (§ Gotchas). Open with the verdict: orchestrated or not, and the trigger that fired. State that steps after the pivot are retried and never compensated, and that every wait has a timeout and an expiry path. Say in one line that this is a document at `design/architecture/workflow-orchestration.md` and names the design, not code: **no code of any kind in the answer, not even a query or a statement, when describing what to do instead.** Answering in a reply: the declined requests and their reasons once, then the document once.

Examples: `./examples/01-lean-plant-swap-declined.md` (a two-step flow where the requested engine is declined), `./examples/02-standard-clinic-booking.md` (a six-step booking with a deposit pivot, captured compensations, a human wait and a semantic lock), `./examples/03-enterprise-policy-binding-two-sagas.md` (a 5-day approval flow whose two points of no return become two sagas).

## Gotchas

- **"Use a workflow engine for the two-step flow."** *Reason:* the coordinator is a component every participant depends on, and two or three independent steps do not need one. *Instead:* choreography, or one local transaction inside one deployable; say which condition would change the answer (a fourth step, branching, a long wait, a need for one view of progress), and that even then a hand-rolled coordinator comes first for one flow and an engine only once many orchestrated flows have accumulated.
- **"Make every step undoable; roll everything back."** *Reason:* a committed step is visible at once and cannot be rolled back; some effects (a payout sent, an email read) cannot be undone. *Instead:* choose the pivot; steps before it are undone by new, inverse actions, steps after it are retried forward.
- **"The compensation can look up what to undo."** *Reason:* current state may have changed since the step ran, and the lookup races concurrent changes. *Instead:* capture what the compensation needs when the step runs forward.
- **"Compensations are best effort."** *Reason:* a compensation that fails leaves a half-done flow no one owns. *Instead:* idempotent, retried until it succeeds, and escalated (alert, a manual queue) if it cannot.
- **"Keep the coordinator's state in memory."** *Reason:* a crash mid-flow loses it or sends a command twice. *Instead:* persist the state and the next command in one transaction (Outbox); resume from the last committed state.
- **"Let the orchestrator check the balance (or stock, or credit) itself."** *Reason:* it becomes a god service that bypasses the owning context's rules. *Instead:* the coordinator sends a command; the owner decides and replies.
- **"The flow has two points of no return."** *Reason:* "exactly one pivot" is what makes failure behaviour defined. *Instead:* split it into two sagas; the first ends at its pivot and its completion starts the second.
- **"Wait for the approval as long as it takes."** *Reason:* an unbounded wait strands resources and semantic locks. *Instead:* a timeout, and a stated path on expiry (cancel and compensate, or escalate).
- **"The dashboard can ask the orchestrator for data across services."** *Reason:* the coordinator holds flow state, not business data, and cross-service reads have their own ladder. *Instead:* progress comes from the coordinator's state; business queries follow `cqrs-pattern`.
- **"Lock the record in the database for the whole saga."** *Reason:* each step is a separate transaction, so no database lock can span them. *Instead:* a semantic lock: a state that says "mid-saga", honoured by every reader and writer.

## References

| Question | File |
|---|---|
| Richardson's trigger rule, step classes, the pivot, compensation rules, forward recovery, the three axes for an orchestrated flow | `./references/saga-design.md` |
| The state machine, persistence, idempotent participants, timeouts, in-flight versions, progress view, build or adopt an engine | `./references/orchestrator-model.md` |
| The three anomalies and five countermeasures | `./references/isolation-countermeasures.md` |
| The artifact | `./templates/workflow-orchestration-design.md` |
| Checking before hand-off | `./resources/checklist.md` |
