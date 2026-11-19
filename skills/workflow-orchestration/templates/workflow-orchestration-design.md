---
name: workflow-orchestration-design
product: [product slug]
version: 1.0.0
phase: design
owner: enterprise-architect
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: which flows are orchestrated, where each saga's point of no return sits, and what undoes each step]
traces-to: [design/architecture/integration-design.md, design/architecture/container-diagram.md, ideate/nfr-specification.md]
---

# Workflow Orchestration Design for [Product]

<!-- Path: artifacts/<product>/design/architecture/workflow-orchestration.md.
     Lean: normally not produced (skip). Standard and enterprise: optional, only when a flow is orchestrated
     (Richardson's rule, event-driven-patterns). One "## Saga:" section per orchestrated flow.
     Names the design, never code. Cross-service queries are cqrs-pattern's, not decided here.
     Write coordination as "async · eventual · orchestrated"; no saga archetype names as vocabulary.
     "CDC" means Change Data Capture only; write "Consumer-Driven Contract" in full. -->

**Readers:** [enterprise-architect, backend-engineer, the product owner]
**Question it answers:** for each orchestrated flow, what is done, what is undone, and what happens when a step fails or never answers?

- **Profile:** [lean | standard | enterprise]

## Orchestration Decision

| Flow | Trigger that fired | Why not choreography | Coordinator |
|---|---|---|---|
| [flow name, from the Event-Driven Pattern Decisions] | [branching or looping / long-running / one view of progress / compensation across 4+ services] | [what breaks if the services only react to each other's events] | [hand-rolled, or the engine and why many flows justify it] |

## Saga: [Flow Name]

**Pivot:** [the step, and why abandoning the flow is acceptable up to here and not after]
**Coordinator:** [where it runs, inside the boundary multi-tenancy-design chose; owner]
**State persistence:** [state row and the command it sends in one transaction through the Transactional Outbox; one writer per flow]
**Business logic in the coordinator:** [none: it sends commands and records replies; the owning context decides]

### Steps

| # | Step (command) | Owner | Class | Compensation | Captured on the way forward | Lock set or cleared |
|---|---|---|---|---|---|---|
| 1 | [command] | [context] | [compensatable / pivot / retriable] | [the compensating command; "none" for the pivot and retriable steps] | [what the compensation needs, recorded when the step runs] | [state set or cleared, or "none"] |

<!-- Compensations are idempotent, retried until they succeed, escalated if they cannot (name the escalation), and run in reverse order. -->

### State Machine

| State | Command sent on entry | On success | On failure |
|---|---|---|---|
| [state] | [command] | [next state] | [next state: compensation before the pivot; retry then Needs repair after it] |

### Timeouts

| Wait | Timeout | When it expires |
|---|---|---|
| [a reply, a human, an external signal; or "none: no step waits"] | [the limit] | [the path: retry, compensate, escalate to a named role; locks released] |

### Isolation

| Record exposed | Anomaly possible | Countermeasure | Cleared by, and how a stale one is released |
|---|---|---|---|
| [record] | [lost update / dirty read / fuzzy read] | [semantic lock (state name) / commutative updates / pessimistic view / reread value / by value, or "risk-accepted: reason"] | [the step or path that clears it; the limit after which it is released] |

### Progress and Repair

- **Progress view:** [how "where is this flow now?" is answered: the coordinator's record per flow]
- **Needs repair:** [which steps can fail for good, the owner, and the alert]
- **Definition changes:** [enterprise: in-flight flows finish under the version they started with, or the migration]

## Open Questions

- [A question for the product owner or a named role, with an owner; or "none"]
