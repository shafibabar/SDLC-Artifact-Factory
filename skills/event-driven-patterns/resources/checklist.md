# Checklist: Event-Driven Pattern Decisions

Resource for `event-driven-patterns`. Run after `./scripts/validate-event-driven-patterns.sh` is clean; the script checks structure, this list checks judgement.

## Need and size
- [ ] Each flow that stays inside one deployable uses an in-process publisher, not a broker.
- [ ] A broker, topics and a Dead Letter Queue appear only where a flow crosses a process boundary, needs history, or fans out widely.
- [ ] The profile's size is respected: lean is short; lighter choices at standard are risk-accepted with a reason.

## Classification and coordination
- [ ] Every flow has communication, consistency and coordination, each decided separately.
- [ ] No flow is atomic and choreographed.
- [ ] Every orchestrated flow names the Richardson trigger that fired and points to `workflow-orchestration`; no orchestration by habit.
- [ ] The event-flow graph has no cycle.
- [ ] A choreographed saga has 3 steps or fewer, each with its compensation, captured on the way forward.
- [ ] Every synchronous exception names why a current answer is needed.
- [ ] No distributed transaction.

## Publication and consumption
- [ ] A service that emits an event with its own write uses the Transactional Outbox; no dual write.
- [ ] Change Data Capture appears only for a source that cannot publish, with the reason.
- [ ] Every consumer commits its dedup mark and its effect in one transaction, on the envelope's event id.
- [ ] Retry and Backoff covers transient failures only; permanent failures go to the Dead Letter Queue.
- [ ] Every Dead Letter Queue has an alert on depth, an owner and a re-drive path.
- [ ] No claim of exactly-once beyond a topic-to-topic transform inside one cluster.

## Ordering
- [ ] Every topic names its partition key and what that key keeps in order.
- [ ] The key is not `tenant_id` by habit: a single-tenant product has none, and a hot tenant has a fallback.
- [ ] The guarantee states its limit (within one partition; none across Aggregates or topics).
- [ ] "Competing Consumers" is used only for a queue; a log's sharing is a consumer group.

## Hand-off
- [ ] Orchestration handed to `workflow-orchestration`, the broker to `message-broker-selection`, the envelope to `event-schema-design`, code to `go-event-publisher` and `go-event-consumer`.
- [ ] A consequential choice (Change Data Capture on a business table, a synchronous exception on a critical path) has an ADR.
