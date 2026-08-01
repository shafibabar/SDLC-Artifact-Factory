---
name: python-amqp-consumer
description: >
  Teaches the backend-engineer to consume from RabbitMQ (AMQP 0-9-1) in Python
  with the aio-pika client — the manual-ack contract (message.ack() only after
  the handler succeeds, message.nack(requeue=True) vs message.nack/reject(
  requeue=False) to dead-letter), prefetch/QoS tuning via channel.set_qos(
  prefetch_count) for a Competing Consumers pool and the ordering cost competing
  consumers impose, the dead-letter-exchange (x-dead-letter-exchange) + TTL
  (x-message-ttl) delayed-retry topology that substitutes for Kafka's "don't
  advance the offset," poison-message parking with a max-retries count read from
  the x-death header, and the crash-safety reasoning that an unacked delivery
  auto-requeues (no_ack=False) which replaces offset-commit reasoning. Covers
  Message.ack/nack/reject, requeue flags, the Message.process() context manager
  and its ack-timing trap, queue.iterator() consume loop, connect_robust
  auto-reconnect, and graceful drain of in-flight unacked deliveries. The Python
  analog of go-amqp-consumer — no consumer-group offset, no replay, removed-on-ack.
  Used by the backend-engineer during Implement for any RabbitMQ consumer.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, backend, rabbitmq, amqp, consumer, python, aio-pika, dead-letter-exchange, prefetch]
produces: python-amqp-consumer
domain: backend
status: stable
related: [go-amqp-consumer, python-amqp-publisher, message-broker-selection, python-event-consumer]
---

# Python AMQP Consumer

## Purpose

A RabbitMQ consumer drains a **queue** — not a partitioned log. The defining
difference from `python-event-consumer` (Redpanda/aiokafka): a message is
**removed on ack**. There is no offset, no retention window, no rewind, no
replay. Correctness under failure is governed by the **manual acknowledgement
contract**, not by when an offset is committed. This skill teaches that contract
with `aio-pika` (async, over asyncio), prefetch tuning for a Competing Consumers
pool, and the dead-letter-exchange + TTL retry topology you must *build* because
there is no offset to leave and come back to. Every correctness property carries
over from `go-amqp-consumer` unchanged; only the client changes.

> This repo standardizes on Redpanda. Reach for RabbitMQ only when a workload is
> transient task dispatch that genuinely needs queue semantics (per-tenant
> RPC-style jobs, complex broker-side routing) — a decision owned by
> `message-broker-selection`, not made here.

This is `aio-pika`-direct — no Celery, no framework wrapper. `aio-pika` wraps
`aiormq` and speaks AMQP 0-9-1 to RabbitMQ over asyncio.

## The manual-ack contract (non-negotiable)

Consume with `no_ack=False` (the default). A delivery is held **unacknowledged**
by the broker until you resolve it exactly one of three ways:

| Outcome | Call | Effect |
|---|---|---|
| Handler succeeded | `await message.ack()` | Message removed. |
| Transient failure, retry now | `await message.nack(requeue=True)` | Requeued at (near) head — **risk: instant hot-loop** on a persistent fault. |
| Permanent/poison, or retry-later | `await message.nack(requeue=False)` or `await message.reject(requeue=False)` | Dropped **or** routed to the DLX if the queue declares `x-dead-letter-exchange`. |

Rules that are defects if violated:
- **Ack after the side effect is durable**, never before. Acking first then crashing loses the message — there is no offset to replay it from.
- **Never `no_ack=True`** for work that matters: a crash with no-ack loses every in-flight delivery silently.
- **Never `requeue=True` for a poison message.** `nack(requeue=True)` on a deterministically-failing message is an infinite redelivery loop that pins a CPU. Requeue is only for *transient* faults you expect to clear.
- **One channel per consumer task.** An `aio_pika` channel is a logical session; give each concurrent consumer its own channel — delivery tags are channel-scoped.

## The `Message.process()` trap — the honest Python-vs-Go divergence

`aio-pika` offers a convenience the Go `amqp091-go` client has no equivalent for:
the `async with message.process():` context manager auto-acks on clean exit and
auto-nacks on exception. It is ergonomic but **hides ack timing** — the ack fires
when the `with` block exits, which is only correct if the durable side effect
completed *inside* the block. For the manual-ack contract this skill teaches,
prefer **explicit** `await message.ack()` after the DB commit so the ordering is
visible in the code, not implied by indentation. If you do use `process()`, pass
`requeue=False` and put the entire durable write inside it. See
`references/consuming-and-ack.md`.

## Crash-safety replaces offset-commit reasoning

aiokafka: "commit the offset only after success." RabbitMQ: **do nothing** — an
unacked delivery is **automatically requeued** when the channel/connection drops
(consumer crash, network partition). At-least-once falls out of the ack contract
itself. The redelivered copy arrives with `message.redelivered == True`; treat
that as the signal to check idempotency, exactly as the log consumer does on
replay. `aio_pika.connect_robust()` transparently re-establishes the connection,
channel, and consumer after a drop — a genuine divergence from Go, where you hand-
write the `NotifyClose` reconnect loop. See `references/consuming-and-ack.md`.

## Prefetch / QoS and the ordering cost

`await channel.set_qos(prefetch_count=N)` caps unacked messages the broker pushes
to one channel before it waits for acks. This is the **single most important knob**
for a Competing Consumers pool sharing one queue:

- `prefetch_count=1` → **fair dispatch**: a slow consumer is not handed a backlog while a fast one starves. Start here for long/uneven handlers.
- Higher prefetch → throughput over fairness; only raise it when handler latency is low and uniform. Measure unacked depth to tune.
- **The ordering cost is structural**: multiple consumers competing on one queue process in parallel, so *cross-message ordering is destroyed by design*. If you need per-key order, you cannot use a shared competing-consumers queue — route each key to its own queue (consistent-hash exchange) and run one consumer per queue. Full tuning worked example: `references/consuming-and-ack.md`.

## Retry as topology: DLX + TTL (the offset-hold substitute)

There is no "don't advance the offset." Delayed retry is **built** from queues:

1. Work queue declares `x-dead-letter-exchange` → a retry exchange.
2. `reject(requeue=False)` dead-letters the message to a **retry queue** carrying `x-message-ttl` = the backoff delay, whose *own* DLX points back at the work exchange. When the TTL expires the message dead-letters home — a delayed redelivery with no busy-wait.
3. RabbitMQ stamps an `x-death` header array; its `count` is the retry counter. After N cycles, route the message to a terminal **parked/DLQ** queue instead of retrying.

This is the AMQP realization of the repo's `Dead Letter Queue` term. Exchanges,
TTL values, the `x-death` max-retries read, poison parking, and the full aio-pika
+ topology diagram live in `references/dlx-retry-topology.md`.

## Graceful shutdown

On SIGTERM: stop pulling new deliveries (exit the `queue.iterator()` async
context / cancel the consumer), let in-flight handlers finish and ack, *then*
close the channel and connection. Any delivery not acked at close is auto-requeued
by the broker — safe, but idempotency must absorb the redelivery. Drive
cancellation with an `asyncio.Event` set by a `loop.add_signal_handler`. Worked
drain loop: `references/consuming-and-ack.md`.

## Observability

Emit OpenTelemetry span attributes that make the queue model visible to a
data-estate/compliance operator: `messaging.rabbitmq.delivery_tag`,
`messaging.rabbitmq.routing_key`, exchange, `messaging.message.redelivered`, and
the `x-death` retry count. Extract trace context from message headers exactly as
`python-event-consumer` does. Make the **absence of an offset / no-replay**
property explicit in telemetry, not folklore.

## References

- `references/consuming-and-ack.md` — full aio-pika consumer: `connect_robust`, `set_qos`, queue + binding declare, `queue.iterator()` delivery loop, explicit `ack`/`nack`/`reject` with requeue semantics vs the `message.process()` context manager, `message.redelivered` idempotency, per-tenant physical isolation, graceful signal-driven drain of unacked deliveries.
- `references/dlx-retry-topology.md` — dead-letter-exchange + TTL delayed-retry topology, poison-message parking, max-retries via the `x-death` header `count`, worked topology diagram and aio-pika declaration/handler code.

## Applies with

`python-event-consumer` (the Redpanda/aiokafka analog and its idempotency
contract), `go-amqp-consumer` (the Go analog with identical correctness rules),
`message-broker-selection` (when a queue broker is the right choice at all), and
`python-amqp-publisher` (the producing side: exchanges, routing keys, publisher
confirms, the mandatory flag).
