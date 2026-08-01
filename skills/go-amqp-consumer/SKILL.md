---
name: go-amqp-consumer
description: >
  Teaches the backend-engineer to consume from RabbitMQ (AMQP 0-9-1) in Go with
  the amqp091-go client — the manual-ack contract (basic.ack only after the
  handler succeeds, basic.nack/basic.reject with requeue=true vs requeue=false-to-
  dead-letter), prefetch/QoS tuning via basic.qos(prefetch_count) for a Competing
  Consumers pool and the ordering cost that competing consumers impose, the
  dead-letter-exchange (x-dead-letter-exchange) + TTL (x-message-ttl) delayed-retry
  topology that substitutes for Kafka's "don't advance the offset," poison-message
  parking with a max-retries count read from the x-death header, and the crash-
  safety reasoning that an unacked delivery auto-requeues (autoAck=false) which
  replaces offset-commit reasoning. Covers Delivery.Ack/Nack/Reject, multiple/
  requeue flags, channel-per-consumer, graceful shutdown draining in-flight
  unacked deliveries, and context cancellation of the delivery loop. The AMQP
  analog of go-event-consumer — no consumer-group offset, no replay, removed-on-ack.
  Used by the backend-engineer during Implement for any RabbitMQ consumer.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, backend, rabbitmq, amqp, consumer, go, dead-letter-exchange, prefetch]
produces: go-amqp-consumer
domain: backend
status: stable
related: [go-event-consumer, message-broker-selection, event-driven-patterns, go-amqp-publisher]
tools: [Bash]
---

# Go AMQP Consumer

## Purpose

A RabbitMQ consumer drains a **queue** — not a partitioned log. The defining
difference from `go-event-consumer` (Redpanda): a message is **removed on ack**.
There is no offset, no retention window, no rewind, and no replay. Correctness
under failure is therefore governed by the **manual acknowledgement contract**,
not by when an offset is committed. This skill teaches that contract, prefetch
tuning for a Competing Consumers pool, and the dead-letter-exchange + TTL retry
topology you must *build* because there is no offset to leave and come back to.

> This repo standardizes on Redpanda. Reach for RabbitMQ only when a workload is
> transient task dispatch that genuinely needs queue semantics (per-tenant
> RPC-style jobs, complex broker-side routing) — a decision owned by
> `message-broker-selection`, not made here.

## The manual-ack contract (non-negotiable)

Always consume with `autoAck=false`. A delivery is held **unacknowledged** by the
broker until you resolve it exactly one of three ways:

| Outcome | Call | Effect |
|---|---|---|
| Handler succeeded | `d.Ack(false)` | Message removed. `multiple=false` acks this delivery only. |
| Transient failure, retry now | `d.Nack(false, true)` | Requeued at (near) head — **risk: instant hot-loop** on a persistent fault. |
| Permanent/poison, or retry-later | `d.Nack(false, false)` or `d.Reject(false)` | Dropped **or** routed to the DLX if the queue declares `x-dead-letter-exchange`. |

Rules that are defects if violated:
- **Ack after the side effect is durable**, never before. Acking first then crashing loses the message — there is no offset to replay it from.
- **Never `autoAck=true`** for work that matters: a crash with auto-ack loses every in-flight delivery silently.
- **Never `requeue=true` for a poison message.** `Nack(_, true)` on a deterministically-failing message is an infinite redelivery loop that pins a CPU. Requeue is only for *transient* faults you expect to clear.
- **One channel per consumer goroutine.** `*amqp.Channel` is not safe for concurrent use; acks are channel-scoped and carry a per-channel delivery tag.

## Crash-safety replaces offset-commit reasoning

Redpanda: "commit the offset only after success." RabbitMQ: **do nothing** — an
unacked delivery is **automatically requeued** when the channel/connection drops
(consumer crash, network partition). At-least-once falls out of the ack contract
itself. The redelivered copy arrives with `d.Redelivered == true`; treat that as
the signal to check idempotency, exactly as the log consumer does on replay. See
`references/consuming-and-ack.md` for the full Go consumer including reconnect.

## Prefetch / QoS and the ordering cost

`ch.Qos(prefetchCount, 0, false)` caps unacked messages the broker pushes to one
channel before it waits for acks. This is the **single most important knob** for a
Competing Consumers pool sharing one queue:

- `prefetch_count=1` → **fair dispatch**: a slow consumer is not handed a backlog while a fast one starves. Start here for long/uneven handlers.
- Higher prefetch → throughput over fairness; only raise it when handler latency is low and uniform. Measure unacked depth to tune.
- **The ordering cost is structural**: multiple consumers competing on one queue process in parallel, so *cross-message ordering is destroyed by design*. If you need per-key order, you cannot use a shared competing-consumers queue — route each key to its own queue (consistent-hash exchange) and run one consumer per queue. Full tuning worked example: `references/consuming-and-ack.md`.

## Retry as topology: DLX + TTL (the offset-hold substitute)

There is no "don't advance the offset." Delayed retry is **built** from queues:

1. Work queue declares `x-dead-letter-exchange` → a retry exchange.
2. `Reject(requeue=false)` dead-letters the message to a **retry queue** carrying `x-message-ttl` = the backoff delay, whose *own* DLX points back at the work exchange. When the TTL expires the message dead-letters home — a delayed redelivery with no busy-wait.
3. RabbitMQ stamps an `x-death` header array; its `count` is the retry counter. After N cycles, route the message to a terminal **parked/DLQ** queue instead of retrying.

This is the AMQP realization of the repo's `Dead Letter Queue` term. Exchanges,
TTL values, the `x-death` max-retries read, poison parking, and the full Go +
topology diagram live in `references/dlx-retry-topology.md`.

## Graceful shutdown

On SIGTERM: stop pulling new deliveries (`ch.Cancel(consumerTag, false)`), let
in-flight handlers finish and ack, *then* close the channel and connection. Any
delivery not acked at close is auto-requeued by the broker — safe, but idempotency
must absorb the redelivery. Cancel the delivery loop via `context.Context`. Worked
drain loop: `references/consuming-and-ack.md`.

## Observability

Emit OpenTelemetry span attributes that make the queue model visible to a
data-estate/compliance operator: `messaging.rabbitmq.delivery_tag`,
`messaging.rabbitmq.routing_key`, exchange, `messaging.message.redelivered`, and
the `x-death` retry count. Extract trace context from message headers exactly as
`go-event-consumer` does. Make the **absence of an offset / no-replay** property
explicit in telemetry, not folklore.

## References

- `references/consuming-and-ack.md` — full Go consumer: queue + binding declare, `Qos`, `Consume` delivery loop, Ack/Nack/Reject with flag semantics, `d.Redelivered` idempotency, context-cancelled loop, graceful drain of unacked deliveries, reconnect, prefetch tuning.
- `references/dlx-retry-topology.md` — dead-letter-exchange + TTL delayed-retry topology, poison-message parking, max-retries via the `x-death` header `count`, worked topology diagram and Go declaration/handler code.

## Applies with

`go-event-consumer` (the Redpanda/log analog and its idempotency contract),
`message-broker-selection` (when a queue broker is the right choice at all),
`event-driven-patterns`, and `go-amqp-publisher` (the producing side: exchanges,
routing keys, publisher confirms, the mandatory flag).
