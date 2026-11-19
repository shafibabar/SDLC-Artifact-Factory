# Checklist: Broker Selection Rationale

Resource for `message-broker-selection`. Run after `./scripts/validate-broker-selection.sh` is clean; the script checks structure, this list checks judgement.

## Need and size
- [ ] "Is a broker needed at all?" was asked first; flows inside one deployable use in-process events.
- [ ] A broker appears only where a flow crosses a process boundary, a consumer needs history, or fan-out is wide.
- [ ] Lean has no broker unless a flow leaves the deployable, and then one broker, short.
- [ ] The condition that would change a "no broker" answer is named.

## Replay and model
- [ ] Every workload has a written replay answer, with who would re-read.
- [ ] A workload needing replay, audit or a late-joining consumer is on a log; the log and the queue are not called interchangeable.
- [ ] A queue workload is genuinely done once handled.
- [ ] Secondary criteria break ties only; none overturns a replay need.
- [ ] Competing Consumers appears only for the queue model; a log scales with a consumer group, with the partition-count limit stated.

## The decision
- [ ] One broker unless two workloads answer the replay question differently; each extra broker has its reason and operating cost.
- [ ] The default (Redpanda) is justified by the workload and `sdlc-config.json` is respected; the product's industry is not a reason.
- [ ] Hosting, owner and retention (with the reason) are stated.
- [ ] No business logic in the broker: routing by key or topic only.
- [ ] An ADR is written, or the reason none is needed.

## Delivery
- [ ] Both models are at-least-once; acknowledgement or offset commit happens after the work is durable; no auto-acknowledge for business messages.
- [ ] Every consumer is idempotent; no claim of exactly-once beyond a topic-to-topic transform inside one cluster.
- [ ] Retry covers transient failures only, built the broker's way; a Dead Letter Queue has an owner, a re-drive path and an alert.

## Scope and vocabulary
- [ ] No code of any kind; code is the `go-*` and `python-*` skills.
- [ ] Tenancy appears only if the product is multi-tenant, and follows `multi-tenancy-design`.
- [ ] "Consumer-Driven Contract" is never abbreviated to CDC.
