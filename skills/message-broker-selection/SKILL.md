---
name: message-broker-selection
description: >
  Teaches the enterprise-architect to choose between a log-based broker
  (Kafka/Redpanda — the repo default) and a queue-based broker (AMQP/RabbitMQ)
  for a given messaging workload — the replay/retention/ordering/offset axis as
  the primary selection criterion, the fundamental model differences (message
  removed-on-ack vs. retained log; per-queue vs. per-partition ordering;
  competing-consumers vs. consumer-group offsets; fan-out topology), and the
  anti-pattern of treating the two as swappable "message queues." Used during
  Design whenever a messaging workload is introduced and a broker must be
  chosen or justified.
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-07-31
tags: [design, architecture, messaging, broker, kafka, rabbitmq, amqp, log-vs-queue]
related: [event-driven-patterns, go-event-publisher, go-event-consumer, go-amqp-publisher, go-amqp-consumer, integration-design]
---

# Message Broker Selection

## Purpose

Gives the enterprise-architect a forcing function to ask the right question **before** a messaging workload is bound to a broker: does this workload need to **replay/rewind history**, or is it **transient task dispatch** where a consumed message is genuinely done? The answer, not habit or the platform default, selects the broker.

This repo standardizes on **Redpanda** (Kafka API — a log-based broker). That standardization is deliberate, not automatic: this skill teaches *why* the log model is the right default for a data-estate/compliance platform built on Domain Events, and equally *when* a queue broker (AMQP/RabbitMQ) is the correct fit so a workload is not force-fit onto the wrong model.

This skill is knowledge, not reasoning: it holds the selection axis, the comparison, and the decision criteria. *Applying* them to a specific workload (does this scan-completion stream need replay? does this per-tenant report job?) is the enterprise-architect's job.

---

## The Primary Selection Axis: Replay/Retention vs. Consume-and-Discard

Classify every messaging workload on **one question first**, before anything else:

> **Does any consumer need to re-read messages it has already processed — for a new read model, a reindex, a bug-fix reprocessing, an audit, or event sourcing?**

- **Yes → log-based broker (Redpanda).** The broker retains messages for a configured window; every consumer group tracks its own **offset** and can **rewind and replay**. This is the repo default and the correct model for a **Domain Event stream** — an immutable, retained record of what happened, readable by many independent consumers now and in the future.
- **No — a consumed message is genuinely finished (RPC-style work, job dispatch) → queue-based broker (AMQP/RabbitMQ).** The message is **removed on ack** and gone. There is no offset, no retention window, no rewind. Parallelism comes from multiple consumers **competing** on one queue.

Everything else (ordering, fan-out, retry) is downstream of this axis. Decide it first.

---

## Redpanda (log) vs. RabbitMQ (queue) — the model contrast

| Property | Redpanda / Kafka (log) — **repo default** | RabbitMQ / AMQP 0-9-1 (queue) |
|---|---|---|
| **Broker/consumer role** | Dumb broker, smart consumer | Smart broker, dumb consumer |
| **Message lifetime** | **Retained** for a configured window (time/size) | **Removed on ack** — gone once consumed |
| **Replay / rewind** | Yes — any group re-reads from any offset | **No** built-in replay; history is not kept |
| **Position tracking** | Per-group **offset**, consumer-owned | None — the broker tracks unacked, not position |
| **Ordering guarantee** | **Per-partition** (ordered within a partition) | **Per-queue**, and only to a single consumer without requeues |
| **Parallelism model** | Consumer group — partitions split across members, ordering preserved | **Competing Consumers** on one queue — **destroys ordering** across the pool by design |
| **Addressing** | Caller addresses a **topic-partition** directly | Producer publishes to an **exchange** + routing key; **bindings** decide queues |
| **Fan-out** | Every group independently reads the same retained partitions | One **queue per consumer** bound to a `fanout` exchange |
| **Retry/backoff** | Often "don't advance the offset" and reprocess | Built from **DLX + TTL** topology (no offset to leave and return to) |
| **Producer accept signal** | Append to partition acknowledged by broker | **Publisher confirms** (`basic.ack`); `mandatory` flag + `basic.return` catch zero-route |

Full model-by-model treatment, worked repo examples, and Go/proto/JSON snippets are in `references/log-vs-queue-model.md`.

---

## The Anti-Pattern: treating the two as swappable "message queues"

The single most common and costly mistake is calling both "a message queue" and assuming a workload can be moved between them by swapping a client library. **They answer different questions.** Swapping breaks in ways that do not show up until production:

- **Log → queue** loses replay: a new read model or reindex that assumed it could rewind history now has no history to read. Retention and audit guarantees silently disappear.
- **Queue → log** over-serves transient work: an RPC-style task stream gets a retained, partitioned log it does not need — paying for retention, partition-count planning, and offset management for messages that are done the instant they are handled; and competing-consumer routing flexibility (per-message routing keys, per-tenant queues) is lost.
- **Ordering assumptions break both ways**: code that relied on per-partition ordering breaks under competing-consumers; code that relied on per-queue FIFO breaks when moved to a partitioned log with more than one partition.

State the broker choice as an **explicit selection decision** in the design artifact, with the replay question answered on the record — never as a defaulted config detail.

---

## When each wins (quick guide)

| Workload shape | Broker | Why |
|---|---|---|
| Domain Event stream (`DataAsset.Scanned`, `Classification.Applied`) consumed by many contexts, now and future | **Redpanda (log)** | Retained, replayable, per-partition ordered; new consumers rewind from offset 0 |
| Reindex / rebuild a read model from history | **Redpanda (log)** | Only a retained log can be re-read |
| Audit / compliance trail of what happened | **Redpanda (log)** | Immutable retained record; core to a compliance product |
| Per-tenant report-generation job dispatch (RPC-style, done on completion) | **RabbitMQ (queue)** | Transient work; competing consumers; per-tenant routing via exchange/routing key; no replay needed |
| Complex content-based routing to different handlers | **RabbitMQ (queue)** | `topic`/`headers` exchanges route broker-side without caller addressing |
| Fair-dispatch work pool where a slow handler must not be handed a backlog | **RabbitMQ (queue)** | `basic.qos` prefetch is the fair-dispatch knob |

Per-tenant physical isolation applies to **either** broker: a per-tenant Redpanda topic-prefix/cluster, or a per-tenant RabbitMQ vhost/queue — isolation is an orthogonal decision, covered in `references/selection-decision-guide.md`.

---

## Delivery guarantees (both brokers reach at-least-once — differently)

Neither model gives exactly-once for free. Both reach **at-least-once**, so **Idempotent Consumers** are required regardless (see `event-driven-patterns`):

- **Redpanda**: producer acks + consumer commits offset only after successful processing → at-least-once; commit-before-process would be at-most-once.
- **RabbitMQ**: publisher confirms (`confirm.select`) + consumer manual `basic.ack` after success → at-least-once; `autoAck=true` is at-most-once (a crash loses in-flight work).

The full delivery-guarantee mapping and the migration/coexistence notes (running both brokers, bridging a queue workload onto the log later) are in `references/selection-decision-guide.md`.

---

## How to Use This Skill

1. State the workload in one sentence and answer the **replay question** explicitly.
2. Walk the decision tree in `references/selection-decision-guide.md` from workload characteristics to a broker.
3. Record the choice, the replay answer, and the delivery guarantee in the design artifact — cite this skill.
4. If the choice is RabbitMQ, hand off to `go-amqp-publisher` / `go-amqp-consumer`; if Redpanda, to `go-event-publisher` / `go-event-consumer`.
5. Never present the two brokers as interchangeable; never let a broker be chosen by default without the replay question on the record.

---

## References

- `references/log-vs-queue-model.md` — the two models in depth: the log (retained, offset, partition-ordered, consumer groups, replay) and the queue (removed-on-ack, per-queue order, competing consumers, exchange/binding routing, DLX+TTL retry); full property-by-property comparison; worked selection for two repo workloads with Go/proto/JSON snippets.
- `references/selection-decision-guide.md` — the decision tree from workload characteristics to broker; the delivery-guarantee mapping for both brokers; per-tenant isolation on each; migration and coexistence notes.

## Related Skills

- `event-driven-patterns` — the pattern catalogue (Choreography, Saga, Idempotent/Competing Consumers, Outbox, CDC, DLQ) layered on top of the chosen broker.
- `go-event-publisher` / `go-event-consumer` — Redpanda (log) implementation once the log is selected.
- `go-amqp-publisher` / `go-amqp-consumer` — RabbitMQ (queue) implementation once the queue is selected.
- `integration-design` — where the broker choice is recorded as part of a Bounded Context integration.
