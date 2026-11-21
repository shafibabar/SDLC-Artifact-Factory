# Checklist: Integration Design

Resource for `integration-design`. Run after `./scripts/validate-integration-design.sh` is clean; the script checks structure, this list checks judgement.

## Coverage
- [ ] Every cross-process arrow on the container diagram and every external system has an inventory row (lean: the external calls only).
- [ ] No module-to-module call inside one deployable is treated as a remote integration.

## Shape, consistency, coordination
- [ ] Each row's shape follows from the criteria (needs the answer now; co-availability; spread of failure; fan-out).
- [ ] Events are the default across Bounded Contexts; each sync row says why.
- [ ] Consistency recorded separately from shape; no atomic-and-choreographed flow.
- [ ] No request/reply over the broker.
- [ ] Multi-step flows name choreography or orchestration, pointing to `event-driven-patterns` or `workflow-orchestration`.

## Contracts
- [ ] Strictness recorded per row; HTTP consumers are tolerant readers.
- [ ] Every row has a Consumer-Driven Contract or event-schema test, or a reason it has none; "CDC" never used for it.
- [ ] Only fields a named consumer uses are sent and translated.
- [ ] No business rules in the broker, gateway or topics.

## Resilience
- [ ] Every external call has a timeout, at every profile.
- [ ] Writes retried only with an idempotency key; otherwise reconcile.
- [ ] Standard and enterprise cross-service and external calls: breaker and bulkhead per downstream, observable fallback.
- [ ] Chains have timeout budgets that exceed the downstream retry envelopes.
- [ ] Every lighter choice recorded as risk-accepted, with its reason.
- [ ] No synchronous external call unprotected inside an event consumer's critical path.

## Data and models
- [ ] Every foreign model enters through an anti-corruption layer; the domain sees only its port.
- [ ] Every cross-context read names API composition, event replication or Change Data Capture, and why.
- [ ] Change Data Capture only where the source can't publish events.
- [ ] No shared database between services (or between modules' schemas in a monolith).

## Hand-off
- [ ] Consequential choices have ADRs; async mechanics handed to `event-driven-patterns`, code to the `go-*` skills.
