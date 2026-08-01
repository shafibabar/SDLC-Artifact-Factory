---
name: go-amqp-publisher
description: >
  Teaches the backend-engineer to publish to RabbitMQ from Go — the
  exchange/routing-key/binding routing model (a producer publishes to an
  Exchange with a routing key; bindings, not the caller, decide which Queues
  receive a copy), exchange-type selection (direct / topic / fanout / headers)
  as a delivery-semantics design decision not a config detail, publisher
  confirms (confirm.select → basic.ack) plus the mandatory flag and
  basic.return for zero-route unroutable messages as the at-least-once producer
  contract, the durability triple (durable exchange + durable queue +
  persistent delivery mode) that makes a message survive a broker restart, and
  the Transactional Outbox adapted to AMQP where durability comes from that
  triple and not from a retained log offset. The AMQP analog of
  go-event-publisher (which targets Redpanda's log). Full Go publisher, confirm
  handling, exchange-type worked routing, and nack retry in
  references/publishing-and-confirms.md; the Outbox-over-AMQP standard with a
  worked DataAsset example in references/outbox-over-amqp.md. Used by the
  backend-engineer during Implement for RabbitMQ producers.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, backend, rabbitmq, amqp, publisher, go, exchange, publisher-confirms]
produces: go-amqp-publisher
domain: backend
status: stable
related: [go-event-publisher, message-broker-selection, event-driven-patterns, go-amqp-consumer]
tools: [Bash]
---

# Go AMQP Publisher

## Purpose

A producer publishing to RabbitMQ does **not** address a queue. It publishes to
an **Exchange** with a **routing key**; broker-side **Bindings** decide which
**Queues** (if any) receive a copy. This indirection is the structural
difference from Redpanda, where a producer addresses a topic-partition directly.
Three consequences shape everything this skill teaches:

1. A `basic.publish` can route to **zero queues** and vanish silently — a
   routing key that matches no binding is a *loss*, not an error, unless you ask
   the broker to tell you.
2. Plain publish is **fire-and-forget** — the broker may drop a message it
   accepted. Only **publisher confirms** turn a publish into an acknowledged,
   at-least-once operation.
3. There is **no offset and no retained log** (the central contrast with
   `go-event-publisher`). Durability is a property you *build* from a durable
   exchange, a durable queue, and persistent delivery — not something the broker
   keeps for you to rewind into.

This is the AMQP analog of `go-event-publisher`; `message-broker-selection`
governs *whether* a queue broker is even the right choice (usually it is not —
this repo standardizes on Redpanda).

---

## The Exchange / Routing-Key / Binding Model

The producer owns three declarations, all idempotent and safe to re-run on every
startup: declare the exchange, declare the queue, bind the queue to the exchange
with a binding key. The caller then publishes with a routing key; the exchange
type is the *algorithm* that matches routing key against binding key. Choosing
the exchange type **is** choosing the delivery semantics — do it as a design
step, not a default. Full declaration + publish Go code:
`references/publishing-and-confirms.md`.

### Exchange-type selection

| Exchange type | Routing rule | Use when | DataAsset example |
|---|---|---|---|
| **direct** | exact routing-key == binding-key | point-to-point, work queues, one logical destination | `dataasset.reindex` → the reindex worker queue |
| **topic** | dotted routing key matched against patterns with `*` (one word) and `#` (zero-or-more words) | selective fan-out by hierarchical event name | `scan.gdrive.completed` delivered to a queue bound `scan.#` |
| **fanout** | ignores routing key, copies to **every** bound queue | broadcast — each consumer needs its **own** queue | a DataAsset change fanned to audit + search-index + cache queues |
| **headers** | matches on message header attributes, not the routing key | routing on structured metadata (e.g. `tenant`, `classification`) rather than a string path | route by `x-match=all` on `{classification: pii}` |

Anti-pattern: reaching for fanout to get multiple consumers of the *same* work.
Fanout means each queue gets a **copy** (broadcast); competing consumers sharing
one queue is a *single* direct/topic queue with multiple subscribers. See
`go-amqp-consumer` for the consume side.

---

## Publisher Confirms + Mandatory = the At-Least-Once Producer Contract

Two independent mechanisms, both required for any message that matters:

- **`confirm.select`** puts the channel in confirm mode. The broker then returns
  `basic.ack` once the message is safely enqueued (or persisted, for a durable
  queue) — this is the producer's at-least-once signal. A `basic.nack` (rare —
  internal broker error) means the publish failed and must be **retried**.
- **The `mandatory` flag** makes the broker return the message via
  `basic.return` if it routed to **zero** queues. Treat every returned message as
  a **hard configuration error** surfaced in telemetry (an OTel span event /
  counter), never a silent drop — it means a routing key matched no binding.

A publish is "done" only after the confirm `ack` is received **and** no return
fired for it. Do not treat the local `Publish` call returning as success. The
full confirm-tracking loop (correlating deferred confirmations to messages,
handling nack with retry, and wiring the return handler) is in
`references/publishing-and-confirms.md`.

> Contrast with `go-event-publisher`: there, "published" means "appended to a
> partition and `ProduceSync` returned." Here, "published" means "confirmed
> **and** provably routed." The unroutable failure mode does not exist in Kafka
> and is the single most important thing this skill adds.

---

## The Durability Triple

A message survives a broker restart only if **all three** hold — any one missing
silently discards on restart:

1. **Durable exchange** — `durable: true` at declare time, so the exchange
   definition survives.
2. **Durable queue** — `durable: true` at declare time, so the queue and its
   bindings survive.
3. **Persistent delivery mode** — set per message at publish time, so the
   message body is written to disk rather than held only in memory.

Missing (3) is the common trap: durable exchange + durable queue + a
**transient** message is still lost on restart. The exact Go field and the
persistent-delivery constant are in `references/publishing-and-confirms.md`.

---

## No Offset: the Outbox Adapts, It Does Not Transfer

The dual-write problem is identical to `go-event-publisher`'s — a crash between
the DB commit and the broker publish loses the event — and the **Transactional
Outbox** is still the answer: `go-repository-pattern`'s `Save` writes the event
into an `outbox` table in the *same transaction* as the aggregate change, and a
separate relay drains it to RabbitMQ. What does **not** transfer is the meaning
of "durably published": there is **no log offset** to mark. The relay's proof of
delivery is the **publisher confirm** (not a produced-offset), and message
survival depends on the **durability triple** above (not on broker retention).
`basic.return` adds a second failure the Kafka relay never has — a confirmed-but
-unroutable message must **not** be marked published; it is a topology bug to
alarm on. Full outbox-over-AMQP standard, idempotency-key rule, and a worked
DataAsset relay: `references/outbox-over-amqp.md`.

---

## Applying This Skill

1. Pick the exchange type from the semantics you need (table above) — design
   step, record it.
2. Declare durable exchange + durable queue + binding idempotently at startup.
3. Publish in confirm mode with the `mandatory` flag and **persistent** delivery.
4. Track confirms; retry on nack; alarm on every `basic.return`.
5. If the event must be atomic with a DB write, drain it through the
   Outbox-over-AMQP relay, not a direct publish from the handler.

Runnable Go for all of the above: `references/publishing-and-confirms.md` and
`references/outbox-over-amqp.md`.
