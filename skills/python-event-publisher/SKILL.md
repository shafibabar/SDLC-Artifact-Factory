---
name: python-event-publisher
description: >
  Teaches the backend-engineer to build a Python outbox relay + aiokafka
  producer — an asyncio poller reading committed outbox rows via FOR UPDATE
  SKIP LOCKED (the same SQL as go-event-publisher, Postgres owns the
  guarantee), publishing at-least-once via aiokafka keyed by tenant_id for
  partition affinity, and marking rows published only after the broker ack.
  The Python analog of go-event-publisher. Covers the asyncio poll loop
  (while True + asyncio.sleep, or apscheduler), the batch-claim/mark-published
  drain against asyncpg, publish-before-mark ordering and why it yields
  at-least-once and never exactly-once, the idempotent-producer config
  (enable_idempotence, acks, max_in_flight) and keyed partitioning by
  tenant_id, backpressure via the outbox absorbing a slow or down broker, and
  the honest asyncio-vs-goroutine divergences (single relay coroutine, no
  errgroup, aiokafka send-and-await instead of ProduceSync). Full poll loop,
  SKIP LOCKED SQL, batch claim, and worked DataAsset relay in
  references/outbox-poller.md; full producer config, keyed partitioning,
  delivery/ack handling, retry, and idempotent-producer settings in
  references/aiokafka-producer.md. Used by the backend-engineer during Implement.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, python, asyncpg, aiokafka, outbox, redpanda, kafka, event-publishing, at-least-once, relay, backpressure, idempotency, asyncio, tenant]
produces: python-outbox-relay
domain: backend
status: stable
related: [go-event-publisher, python-event-consumer, python-repository-pattern, domain-event-catalog]
---

# Python Event Publisher

## Purpose

A service must publish a Domain Event whenever it changes state — reliably, even across crashes. Publishing directly from a FastAPI handler is unsafe: a crash between the `asyncpg` commit and the `aiokafka` send silently loses the event (the dual-write problem). The **Transactional Outbox** closes this gap by splitting the work: `python-repository-pattern`'s `save` writes the event into the `outbox` table in the *same* `conn.transaction()` as the Aggregate's state change, so recording an event is exactly as atomic as the write that caused it; this skill builds the **relay** — a separate, independently-failing `asyncio` coroutine that reliably drains that table to Redpanda via `aiokafka`. Full schema, poll loop, and SKIP LOCKED SQL: `references/outbox-poller.md`.

Decoupling *recording* (transactional, free) from *publishing* (network I/O, can fail, can be slow) is what makes at-least-once delivery achievable without a distributed transaction spanning PostgreSQL and the broker.

---

## The Poll Loop and Draining a Batch

The relay is a single supervised coroutine started in FastAPI's `lifespan` (`python-service-skeleton`) — it starts when the app starts and cancels the instant `lifespan` tears down, never leaving a transaction open across shutdown. `run` loops on a fixed `interval` (`while True: await asyncio.sleep(interval)`, or `apscheduler`'s `AsyncIOScheduler` for structured scheduling); each pass calls `drain_once`, which opens one `conn.transaction()`, claims up to `batch` unpublished rows with `SELECT ... FOR UPDATE SKIP LOCKED` (so concurrent relay *replicas* never double-claim a row), publishes them, marks them published, and commits. A failed drain logs and continues — never fatal, since a transient broker outage must not crash the process; the unpublished rows simply wait for the next pass (the mechanism behind the backpressure standard below). Full `run`/`drain_once` listing and the exact SQL: `references/outbox-poller.md`.

The claim query's own `LIMIT $1` bounds the drain to at most `batch` rows per pass. Python has no preallocated-slice concern (`list.append` amortises, and there is no `sync.Pool` analog to reach for — see the divergences below), so the batch bound is enforced by the SQL `LIMIT`, not by pre-sizing a buffer. The batch-size/interval latency tradeoff is otherwise identical to Go's.

**Publish, then mark — never the reverse.** `drain_once` `await`s the `aiokafka` send *and its broker ack* before the `UPDATE outbox SET published_at = now()`. If the process crashes after the ack but before commit, the transaction rolls back, `published_at` stays `NULL`, and the row is re-claimed and re-published next pass: at-least-once, by construction. Marking first would risk the opposite failure — a row marked published the broker never received — which is unacceptable. Full at-least-once reasoning and why exactly-once is not attempted: `references/outbox-poller.md`.

---

## Backpressure: Why a Slow or Down Broker Cannot Overflow Anything

A slow or unavailable broker is ordinary operation, not an incident, for this design: a failed `send`/ack just means `drain_once` raises, the transaction rolls back, nothing is marked published, and the rows stay exactly where they were — durable rows in a Postgres table, not messages in a fixed-capacity in-memory queue. Nothing upstream of the outbox ever talks to the broker directly (the Aggregate save already committed and returned before the relay's next pass), so there is no buffer to overflow and no caller blocked on a publish. The outbox *is* the backpressure mechanism: unpublished rows accumulate as backlog until the broker recovers, drained at whatever rate it can sustain. The one caller-visible growth this shifts responsibility to is outbox table size under sustained outage — observe it, do not add a retry loop or circuit breaker to the relay. Full standard: `references/outbox-poller.md`.

---

## The Envelope, Partition Key, and Idempotency Key

Each outbox row becomes one Redpanda record carrying the standard envelope (`domain-event-catalog`) with W3C trace context injected into headers so the consumer continues the same trace. `aiokafka`'s `send_and_wait(topic, value=..., key=..., headers=...)` produces one record and awaits its ack.

- **Idempotency key = the outbox row's own `id`**, carried as the envelope's `event_id` — never a fresh `uuid4()` at publish time. This is what makes a crash-replay safe: the same row re-published after a rollback carries the *same* `event_id`, so the consumer's `processed_events` dedup insert (`python-event-consumer`) conflicts and the duplicate is a no-op. A fresh id per attempt would make every replay look like a new event and defeat Idempotency entirely.
- **Partition key = `tenant_id`**, passed as `key=row.tenant_id.bytes` so `aiokafka`'s default hashing partitioner routes all of one tenant's events to the same partition — preserving per-tenant ordering and giving Competing Consumers a natural parallelism boundary. Random or absent keys scatter a tenant's events across partitions, destroying ordering and isolation in one stroke.

Full envelope construction, keyed partitioning, header injection, and the two things that must never be used as the key: `references/aiokafka-producer.md`.

---

## The aiokafka Producer Config

The producer is created once at `lifespan` startup and `await producer.start()`/`await producer.stop()` bound its life. It must be configured for **at-least-once with in-broker dedup of retries**: `enable_idempotence`, `acks`, and a bounded `max_in_flight_requests_per_connection` together stop a client-side retry from silently duplicating or reordering a record *at the broker* (the outbox already handles cross-crash duplicates; this handles within-send retries). Full producer construction, every config value and why, delivery/ack handling, and retry semantics: `references/aiokafka-producer.md`.

---

## Honest Python-vs-Go Divergences

These are real gaps, not syntax differences — name them, do not soften them:

- **One coroutine, not an `errgroup` member.** Go's relay is a supervised goroutine in the composition root's `errgroup`; Python's is a single `asyncio.Task` created in `lifespan`. There is no `errgroup` — sibling-cancel-on-failure comes from `asyncio.TaskGroup` (3.11+) if the relay is grouped with other tasks, but a lone relay just needs its `CancelledError` handled on shutdown.
- **`send_and_wait`, not `ProduceSync`.** `aiokafka` sends are `async` and awaited; the ack is an `await`, not a synchronous blocking call. Batching a produce means `await asyncio.gather(*sends)`, not a variadic `ProduceSync(records...)`.
- **No preallocation / no `sync.Pool`.** Go preallocates `make([]T, 0, batch)`; Python has no idiomatic object-pool for records and no slice-capacity concern. The `LIMIT` bounds the batch; `list.append` is fine. GC-pressure reduction, where it matters, means avoiding churn in the hot loop — the same conclusion `python-performance-optimization` reaches.
- **The GIL is irrelevant here — this is pure I/O.** The relay only waits on Postgres and the broker; the GIL is released during those waits, so a single-threaded `asyncio` relay saturates the I/O path exactly as well as a goroutine would. No `ProcessPoolExecutor` belongs anywhere near the relay.

---

## Rules

- **Publish before mark.** Never set `published_at` before the `send` ack returns.
- **`FOR UPDATE SKIP LOCKED`** so replicas never double-claim a row; safe horizontal scaling.
- **`event_id` = outbox row id, always.** The one fact the entire idempotency chain depends on.
- **Partition by `tenant_id`.** Ordering, isolation, and parallelism from one key choice.
- **Inject trace context** into record headers — the trace must survive the broker hop.
- **Graceful cancel on shutdown.** Handle `CancelledError`; no transaction left open across teardown.
- **Idempotent-producer config is mandatory.** `enable_idempotence`, `acks`, bounded `max_in_flight` — see the producer reference.
- **The relay ships rows; it never decides what to ship.** Filtering or suppressing events here is a defect — the repository already decided what happened.

---

## Quality Criteria

| Criterion | Pass | Fail | How to verify |
|---|---|---|---|
| Atomic outbox insert | Outbox `INSERT` shares the Aggregate write's `conn.transaction()` (`python-repository-pattern`'s `save`) | An `INSERT INTO outbox` outside that transaction | Read `save`; both writes inside one `async with conn.transaction()` |
| At-least-once, never mark-then-publish | `drain_once` `await`s the send ack before `UPDATE ... published_at` | `published_at` set before or without a confirmed ack | Read `drain_once` top to bottom; the `UPDATE` textually follows an awaited, checked send |
| Concurrent-safe drain | `SELECT ... FOR UPDATE SKIP LOCKED` in the claim query | Plain `SELECT` with no locking clause | Read the claim query for `FOR UPDATE SKIP LOCKED` |
| Batch bounded by SQL | Claim query has `LIMIT $1` | Unbounded `SELECT` streamed into memory | Read the claim query for `LIMIT` |
| Backpressure needs no new code path | A failed send raises out of `drain_once` and nothing else | A retry loop, buffer, or circuit breaker bolted onto the relay | Read the send-error path — it rolls back and returns, nothing more |
| Stable idempotency key | Envelope `event_id` = outbox row `id` | `uuid4()` (or any fresh id) built inside the relay | `grep -n "uuid4\|uuid.uuid4" ` over the relay — no hits in the publish path |
| Tenant partitioning | `send_and_wait(..., key=row.tenant_id.bytes)` | Random, absent, or event-id key | Read the send call's `key=` argument |
| Idempotent producer | `enable_idempotence=True`, `acks="all"`, bounded `max_in_flight` | Defaults (`acks=1`, no idempotence) | Read the `AIOKafkaProducer(...)` construction |
| Trace continuity | Trace context injected into headers on every record | No header injection on some path | Read the send call for injected `headers=` |
| Graceful shutdown | `run` handles `CancelledError`, rolls back any open transaction | A path where cancellation leaves a transaction open | Read `run`'s cancel handling and `drain_once`'s `async with conn.transaction()` |
| No business logic in the relay | `drain_once` only reads, serialises, and publishes rows | A conditional that decides *whether* a row publishes based on content | Read the full drain for an `if` that skips a row without raising |

---

## Anti-Patterns

- **Publishing directly from the FastAPI handler** — the dual-write problem the Transactional Outbox exists to solve.
- **Mark-then-publish** — updating `published_at` before the ack converts a crash into a *lost* event, not a harmless duplicate.
- **A fresh `uuid4()` per publish attempt** — makes every crash-replay look like a new event and defeats Idempotency downstream (`python-event-consumer`).
- **Random or absent partition key** — scatters one tenant's events across partitions, destroying per-tenant ordering and isolation.
- **Deleting outbox rows instead of marking them published** — loses the audit trail and replay capability; sweep old *published* rows with a retention job.
- **Bolting retry/circuit-breaker logic onto the relay** — the outbox already is the backpressure mechanism; the next pass retries for free.
- **Reaching for `ProcessPoolExecutor` or extra threads "to go faster"** — the relay is pure I/O; the GIL is released on every await, and parallelism here buys nothing but complexity.
- **Business decisions in the relay** — filtering, transforming, or suppressing events at publish time. The repository decided what happened; the relay only ships it.

---

## Output Format

Python source built exactly to the standards above, plus integration tests run against real PostgreSQL and Redpanda via `testcontainers-python` (`python-integration-test` owns the harness):

```
infrastructure/messaging/outbox_relay.py            (OutboxRelay, run, drain_once, _to_record)
infrastructure/messaging/producer.py                (AIOKafkaProducer construction — idempotent config)
infrastructure/messaging/envelope.py                (Envelope dataclass — domain-event-catalog's shape)
tests/infrastructure/test_outbox_relay.py           (written first — TDD)
```

Full standards: `references/outbox-poller.md` (outbox schema, asyncio poll loop, SKIP LOCKED SQL, batch claim, mark-published, at-least-once reasoning, worked DataAsset relay) and `references/aiokafka-producer.md` (producer config, keyed partitioning by tenant, delivery/ack handling, retry, idempotent-producer settings).
