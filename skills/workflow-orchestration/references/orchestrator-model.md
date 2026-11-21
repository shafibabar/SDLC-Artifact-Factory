# The Orchestrator: a Persisted State Machine

Reference for `workflow-orchestration` steps 6, 7 and 9. Design level only; code is the `go-*` skills and, for an engine, `conductor-workflow-authoring`. Grounded in Richardson (the saga orchestrator as a persistent state machine, the Transactional Outbox) and Kleppmann (idempotence and effectively-once delivery). The pattern is also known as a process manager.

## What it holds and does

A coordinator for one saga type holds **one record per running flow**, keyed by a correlation id, and does three things:

- **Holds state:** the current step of this flow.
- **Sends commands:** on entering a state, one command to the context that owns that step.
- **Consumes replies:** a success or failure reply moves it to the next state, or onto the compensation path.

It does **no business work.** It never reads a participant's data, never applies a domain rule, never decides whether a balance is enough. A coordinator that "just checks one thing" becomes a god service that bypasses the owning context's invariants. The owning context decides; the coordinator records the reply.

## State machine as data

Write the saga as a table, not as branches buried in a handler: the states, the command sent on entry to each, and for each state the next state on success and on failure.

| State | Command sent on entry | On success | On failure |
|---|---|---|---|
| Each forward step | The step's command | The next step | The compensation for the previous compensatable step (before the pivot) |
| The pivot | The pivot's command | The first retriable step | The first compensation |
| Each retriable step | The step's command | The next, or Completed | Retry; after the limit, Needs repair |
| Each compensation state | The compensating command | The previous compensation, then Compensated | Retry; after the limit, Needs repair and an alert |

Terminal states: Completed, Compensated, Needs repair (owned and visible). The next-state function has no side effects, so every state and reply pair can be tested exhaustively.

## Persisting it

The state change and the command it sends are written in **one local transaction** (the Transactional Outbox: a state row and an outbox row), and a relay publishes the command at least once. A crash resumes from the last committed state; it neither loses the flow nor sends a command twice that the participant cannot absorb. An orchestrator held only in memory is a defect.

- **One writer per flow.** Replies for the same flow are applied one at a time (a lock on the flow's record), so two replies cannot move it in two directions.
- **Participants are Idempotent Consumers** (`event-driven-patterns`): the command id is the dedup key, because the relay and the broker deliver at least once.
- **Replies carry the flow's correlation id and the step they answer**, so a late or repeated reply is recognised and ignored.

## Timeouts and stuck flows

Every wait has a limit and a defined path on expiry.

- **A reply that never comes:** a per-step timeout. On expiry, retry (idempotent commands only), then treat as a failure: compensate before the pivot, or Needs repair after it.
- **A human wait:** a deadline and an expiry path (cancel and compensate, or escalate to a named role). Semantic locks held by the flow are released by the same path.
- **Finding a stuck flow:** a flow in a state longer than its limit raises an alert. Name the owner of Needs repair.

## Progress view

"Where is this flow right now?" is one read of the coordinator's record for that correlation id: state, step, time in state, and the outcome so far. That is the only data the coordinator serves. Business data across services is `cqrs-pattern`'s question.

## Changing a definition with flows in flight

Flows already running were started under an older definition. At enterprise scale state the rule: in-flight flows finish under the version they started with (the record holds the definition version), and a new version applies to new flows only. A change that cannot wait names a migration for the in-flight records.

## Build or adopt an engine

A coordinator is code the team owns and runs. Prefer a **hand-rolled coordinator** for one orchestrated flow: a table, a record per flow, the Outbox. Consider a **workflow engine** (such as Netflix Conductor) only once orchestrated flows have multiplied and one view across all of them is the operational point, because an engine is another component to run, upgrade and secure. Authoring for an engine is `conductor-workflow-authoring` (Implement). In a multi-tenant product the coordinator runs inside the boundary `multi-tenancy-design` chose, and a saga does not span tenants. A single-tenant product has no such boundary, and nothing here assumes one.
