---
name: python-amqp-publisher
description: >
  Teaches the backend-engineer to publish to RabbitMQ from Python with aio-pika
  — the exchange/routing-key model, exchange-type selection, publisher confirms +
  mandatory/basic.return for unroutable messages, durable exchange+queue+persistent
  delivery for durability (no log offset), and the Outbox adapted to AMQP. The
  Python analog of go-amqp-publisher; contrast with python-event-publisher (Kafka-API
  log). A producer publishes to an Exchange with a routing key; broker-side Bindings —
  not the caller — decide which Queues receive a copy, so a publish can route to zero
  queues and vanish unless mandatory is set. aio-pika's connect_robust auto-reconnects
  and folds an unroutable basic.return into the awaited publish as a raised exception,
  where Go's amqp091 needs a separate NotifyReturn channel. Full async aio-pika publisher
  (robust connection, confirm mode, mandatory + on-return, exchange types with routing
  examples) in references/publishing-and-confirms.md; the Outbox-over-AMQP standard with
  a worked DataAsset example in references/outbox-over-amqp.md. Used by the
  backend-engineer during Implement for RabbitMQ producers.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, backend, python, rabbitmq, amqp, aio-pika, publisher, exchange, publisher-confirms, asyncio, durability, outbox]
produces: python-amqp-publisher
domain: backend
status: stable
related: [go-amqp-publisher, python-amqp-consumer, message-broker-selection, python-event-publisher]
---

# Python AMQP Publisher

## Purpose

A producer publishing to RabbitMQ does **not** address a queue. It publishes to
an **Exchange** with a **routing key**; broker-side **Bindings** decide which
**Queues** (if any) receive a copy. This indirection is the structural
difference from Redpanda, where a producer addresses a topic-partition directly.
Three consequences shape everything this skill teaches:

1. A publish can route to **zero queues** and vanish silently — a routing key
   that matches no binding is a *loss*, not an error, unless you ask the broker
   to tell you (the `mandatory` flag).
2. Plain publish is **fire-and-forget** — the broker may drop a message it
   accepted. Only **publisher confirms** turn a publish into an acknowledged,
   at-least-once operation. `aio-pika` opens channels with confirms **on by
   default**, so an `await exchange.publish(...)` already waits for the broker
   `ack` — the confirm is the return value of the await, not a side channel.
3. There is **no offset and no retained log** (the central contrast with
   `python-event-publisher`). Durability is a property you *build* from a durable
   exchange, a durable queue, and persistent delivery — not something the broker
   keeps for you to rewind into.

This is the AMQP analog of `go-amqp-publisher`; `message-broker-selection`
governs *whether* a queue broker is even the right choice (usually it is not —
this repo standardizes on Redpanda).

---

## The Exchange / Routing-Key / Binding Model

The producer owns three declarations, all idempotent and safe to re-run on every
startup: declare the exchange, declare the queue, bind the queue to the exchange
with a binding key. In `aio-pika`: `channel.declare_exchange`, `channel.declare_queue`,
`queue.bind(exchange, routing_key=...)`. The caller then publishes with a routing key;
the exchange **type** is the *algorithm* that matches routing key against binding key.
Choosing the exchange type **is** choosing the delivery semantics — do it as a design
step, not a default. Full async declaration + publish: `references/publishing-and-confirms.md`.

### Exchange-type selection

| Exchange type | Routing rule | Use when | DataAsset example |
|---|---|---|---|
| **direct** | exact routing-key == binding-key | point-to-point, work queues, one logical destination | `dataasset.reindex` → the reindex worker queue |
| **topic** | dotted routing key matched against patterns with `*` (one word) and `#` (zero-or-more words) | selective fan-out by hierarchical event name | `scan.gdrive.completed` delivered to a queue bound `scan.#` |
| **fanout** | ignores routing key, copies to **every** bound queue | broadcast — each consumer needs its **own** queue | a DataAsset change fanned to audit + search-index + cache queues |
| **headers** | matches on message header attributes, not the routing key | routing on structured metadata (e.g. `tenant`, `classification`) rather than a string path | route by `x-match=all` on `{classification: pii}` |

`aio-pika` names these `aio_pika.ExchangeType.DIRECT / TOPIC / FANOUT / HEADERS`.
Anti-pattern: reaching for fanout to get multiple consumers of the *same* work.
Fanout means each queue gets a **copy** (broadcast); competing consumers sharing
one queue is a *single* direct/topic queue with multiple subscribers. See
`python-amqp-consumer` for the consume side.

---

## Publisher Confirms + Mandatory = the At-Least-Once Producer Contract

Two independent mechanisms, both required for any message that matters:

- **Publisher confirms** (the `confirm.select` method on the wire) put the channel
  in confirm mode. `aio-pika` enables this by default when you open a channel, so
  the broker returns an `ack` once the message is safely enqueued (or persisted, for
  a durable queue) — this is the producer's at-least-once signal, delivered as the
  awaited `publish` completing without raising. A broker `nack` (rare — internal
  error) surfaces as a raised exception and must be **retried**.
- **The `mandatory` flag** (`publish(..., mandatory=True)`) makes the broker return
  the message via `basic.return` if it routed to **zero** queues. Under confirms,
  `aio-pika` correlates that return to the delivery and **raises on the same awaited
  publish** — you do not drain a separate channel and correlate by id as in Go.
  Treat every such raise as a **hard configuration error** surfaced in telemetry (an
  OTel span event / counter), never a silent drop — it means a routing key matched no
  binding.

A publish is "done" only after the awaited `publish` returns **without raising**.
Do not treat scheduling the coroutine as success. The exact exception type, the
on-return handling, and confirm/nack retry are in `references/publishing-and-confirms.md`.

> Contrast with `python-event-publisher`: there, "published" means "`send_and_wait`
> returned an `aiokafka` broker ack for a partition offset." Here, "published" means
> "confirmed **and** provably routed." The unroutable failure mode does not exist in
> Kafka and is the single most important thing this skill adds.

---

## The Durability Triple

A message survives a broker restart only if **all three** hold — any one missing
silently discards on restart:

1. **Durable exchange** — `durable=True` at declare time, so the exchange
   definition survives.
2. **Durable queue** — `durable=True` at declare time, so the queue and its
   bindings survive.
3. **Persistent delivery mode** — set per message at publish time
   (`aio_pika.DeliveryMode.PERSISTENT`), so the body is written to disk rather than
   held only in memory.

Missing (3) is the common trap: durable exchange + durable queue + a **transient**
message is still lost on restart. The exact `aio-pika` `Message` field is in
`references/publishing-and-confirms.md`.

---

## No Offset: the Outbox Adapts, It Does Not Transfer

The dual-write problem is identical to `python-event-publisher`'s — a crash between
the `asyncpg` commit and the broker publish loses the event — and the **Transactional
Outbox** is still the answer: `python-repository-pattern`'s `save` writes the event
into an `outbox` table in the *same* `conn.transaction()` as the aggregate change, and
a separate `asyncio` relay drains it to RabbitMQ. What does **not** transfer is the
meaning of "durably published": there is **no log offset** to mark. The relay's proof
of delivery is the **publisher confirm** (not a produced-offset), and message survival
depends on the **durability triple** above (not on broker retention). An unroutable
message adds a second failure the Kafka relay never has — a confirmed-but-unroutable
publish must **not** be marked published; it is a topology bug to alarm on. Full
outbox-over-AMQP standard, idempotency-key rule, and a worked DataAsset relay:
`references/outbox-over-amqp.md`.

---

## Honest Python-vs-Go Divergences

Real gaps, not syntax differences — name them, do not soften them:

- **`basic.return` is a raised exception, not a side channel.** Go's `amqp091`
  surfaces returns on a separate `NotifyReturn` channel while the confirm `ack` still
  arrives, so the relay must correlate return→confirm by `MessageId` itself. `aio-pika`
  under confirms folds the return into the awaited `publish` and raises — cleaner, and
  the correlation code Go needs simply does not exist here. Exact type: the reference.
- **`connect_robust` auto-reconnects; Go's `Dial` does not.** `aio-pika`'s robust
  connection reopens the socket and **re-declares topology** after a broker blip; the
  `amqp091` client gives you a raw connection and you build reconnection yourself.
- **One coroutine, no goroutine + buffered confirm channel.** Go registers a buffered
  `NotifyPublish` channel and a drain goroutine; Python `await`s each publish's confirm
  inline. Batched throughput is `await asyncio.gather(*publishes)`, not a buffered
  channel read.
- **The GIL is irrelevant here — pure I/O.** A publish only waits on the broker socket;
  the GIL is released during the await, so a single-threaded `asyncio` publisher
  saturates the I/O path as well as a goroutine would. No thread pool belongs near it.

---

## Applying This Skill

1. Pick the exchange type from the semantics you need (table above) — design step,
   record it.
2. Declare durable exchange + durable queue + binding idempotently at startup, over a
   `connect_robust` connection.
3. Publish with `mandatory=True` and `DeliveryMode.PERSISTENT`; confirms are on by
   default, so the `await` is the at-least-once wait.
4. Treat any raise from `publish` as failure: retry a nack with bounded backoff; alarm
   on an unroutable return — never mark it published.
5. If the event must be atomic with a DB write, drain it through the Outbox-over-AMQP
   relay, not a direct publish from the FastAPI handler.

Runnable async Python for all of the above: `references/publishing-and-confirms.md`
and `references/outbox-over-amqp.md`.
