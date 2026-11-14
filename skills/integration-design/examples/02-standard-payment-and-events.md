# Example 2 — Standard: A Payment Call with the Full Stack, Events, and an Anti-Corruption Layer

Self-contained. **BoxFresh** delivers weekly meal kits. **Standard** profile, three deployables: `subscriptions` (plans, skips, billing), `kitchen` (menus, packing), `delivery` (slots, courier hand-off). External systems: **Adyen** (payments) and **RouteRunner** (a courier company's API, with its own odd vocabulary). Default stack.

## Input

> **User:** "Delivery should ask Kitchen 'is this box packed yet?' by publishing a question on Redpanda and waiting for the answer event. And let Delivery read Kitchen's packing table directly, it's faster. We'll write CDC tests for the contracts."

## Working it

- **Delivery needs packing status:** declined request/reply over the broker (it keeps the coupling and loses timeouts). Delivery needs the status often and can tolerate seconds of lag, so **event replication**: Kitchen publishes `BoxPacked`; Delivery keeps its own read model.
- **Declined:** reading Kitchen's table. Neither could change the schema alone; the boundary would be shared.
- **"CDC tests":** spelled out as **Consumer-Driven Contract** tests; CDC here means Change Data Capture.
- **Billing → Adyen:** request/response, full stack at standard; the charge carries an idempotency key (the billing period id).
- **Delivery → RouteRunner:** request/response through an anti-corruption layer; full stack.

## Output: `artifacts/boxfresh/design/architecture/integration-design.md`

````markdown
---
name: integration-design
product: boxfresh
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-05-19
summary: BoxFresh charges through Adyen with the full resilience stack and an idempotency key, books couriers through an anti-corruption layer, and replicates packing state by events.
traces-to: [design/context-map.md, design/architecture/container-diagram.md, ideate/nfr-specification.md]
---

# Integration Design for BoxFresh

**Readers:** enterprise-architect, backend-engineer, platform-engineer, the product owner
**Question it answers:** for every integration, how does it talk, what does it promise, and what happens when the other side is slow or down?

- **Profile:** standard

## Integration Inventory

| From | To | Shape | Consistency | Protocol | Contract strictness | Contract test | Resilience |
|---|---|---|---|---|---|---|---|
| Subscriptions | Adyen (charge) | request/response | atomic per charge via idempotency key; eventual for the subscription state | HTTPS/JSON | loose (tolerant reader) | recorded-response test of the fields read; Adyen API version pinned | timeout, retry (idempotency key = billing period id), breaker, bulkhead, fallback |
| Delivery | RouteRunner (book courier) | request/response | eventual | HTTPS/JSON | loose (tolerant reader) | Consumer-Driven Contract agreed with RouteRunner | timeout, retry (booking reference as idempotency key), breaker, bulkhead, fallback |
| Kitchen | `box-packed` topic | event | eventual | Kafka protocol | strict (registered schema) | event schema compatibility check | Transactional Outbox |
| Delivery | `box-packed` topic | event | eventual | Kafka protocol | strict (registered schema) | event schema compatibility check | idempotent consumer, retry, DLQ |
| Subscriptions | `subscription-skipped` topic | event | eventual | Kafka protocol | strict (registered schema) | event schema compatibility check | Transactional Outbox |
| Kitchen | `subscription-skipped` topic | event | eventual | Kafka protocol | strict (registered schema) | event schema compatibility check | idempotent consumer, retry, DLQ |

## Synchronous Integrations

### Subscriptions → Adyen

- **Why sync:** a weekly charge must succeed or fail before the box is released to the kitchen
- **Timeout:** 4 s per attempt; billing run budget 15 s per subscription
- **Retry:** 2 retries on 5xx and timeouts, 200 ms ×2 with jitter, always with the billing period id as idempotency key; a final unknown outcome is reconciled by Adyen's notification
- **Circuit breaker:** 50% of at least 20 calls in 30 s; reset 30 s
- **Bulkhead:** own client, 20 concurrent calls
- **Fallback:** the subscription is marked "payment pending" and retried in the next billing window; a metric and an alert on pending older than 6 hours

### Delivery → RouteRunner

- **Why sync:** a slot is confirmed to the customer only once a courier accepts it
- **Timeout:** 2 s per attempt
- **Retry:** 2 retries with jitter, keyed by the booking reference
- **Circuit breaker:** 50% of at least 10 calls in 60 s; reset 60 s
- **Bulkhead:** own client, 10 concurrent calls
- **Fallback:** the slot is held as "courier pending" and the booking queued for retry; visible on the operations dashboard

## Asynchronous Integrations

| Topic | Publisher (mechanism) | Consumers (group) | Idempotency | Retry and DLQ |
|---|---|---|---|---|
| `box-packed` | Kitchen (Transactional Outbox) | Delivery (`delivery.packing`) | event id | 1 s, 5 s, 30 s; then `delivery.packing.dlq` |
| `subscription-skipped` | Subscriptions (Transactional Outbox) | Kitchen (`kitchen.planning`) | event id | 1 s, 5 s, 30 s; then `kitchen.planning.dlq` |

## Coordination

- Weekly cycle (charge, pack, deliver) is choreographed: each context reacts to the previous event; eventual (Anthology saga). No step needs to undo another.

## Anti-Corruption Layers

| Foreign system or context | Domain port | Adapter | What is translated |
|---|---|---|---|
| RouteRunner | `CourierBooking` (book a pickup for a slot) | courier adapter | RouteRunner's job, leg and depot codes to our slot and box ids; its status codes to booked / refused / pending |
| Adyen | `PaymentGateway` | payments adapter | PSP reference, result codes to domain outcomes |

## Cross-Context Reads

| Reader | Data owned by | Option | Why not the others |
|---|---|---|---|
| Delivery | Kitchen (packing status) | event replication | API composition adds a sync hop on every slot check; Change Data Capture would read Kitchen's tables, which Kitchen can publish events for instead |

## Consumer-Driven Contract Plan

| Consumer | Provider | Contract | Where the test runs | Gate |
|---|---|---|---|---|
| Delivery | RouteRunner | booking request and the four response fields read | RouteRunner's sandbox pipeline | shared contract; their release checks it |
| Delivery | Kitchen (`box-packed`) | box id, slot id, packed at | Kitchen build | schema compatibility check fails Kitchen's build |

## Related ADRs

- ADR-009: Event replication of packing status instead of a shared table

## Open Questions

- none
````

## Why this is right

- The broker request/reply and the shared table were replaced by event replication, with the reason.
- "CDC" was spelled out: Consumer-Driven Contract tests, not Change Data Capture.
- Both external calls get the full stack at standard, with keyed retries and observable fallbacks.
- Async rows name their mechanisms and leave the design to event-driven-patterns.
- `validate-integration-design.sh` exits clean on the artifact.
