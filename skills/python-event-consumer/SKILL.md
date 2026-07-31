---
name: python-event-consumer
description: >
  Teaches the backend-engineer to build an idempotent aiokafka consumer in
  Python — async consume loop over a Redpanda topic, manual offset commit
  (enable_auto_commit=False, commit after success), an asyncpg-backed
  processed_events idempotency check in the same transaction as the write,
  an asyncio.Semaphore-bounded worker pool for I/O-bound per-message work vs
  a ProcessPoolExecutor for CPU-bound work (entity extraction/classification),
  DLQ topic routing, and graceful drain. The Python analog of
  go-event-consumer.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, python, aiokafka, consumer, redpanda, kafka, idempotent, worker-pool, processpool, dlq, offset-commit, tenant]
related: [go-event-consumer, python-event-publisher, python-async-concurrency, python-repository-pattern]
---

# Python Event Consumer

## Purpose

A consumer reacts to Domain Events from Redpanda — one stage in the choreographed pipeline. Because delivery is at-least-once, the consumer **must be idempotent**: processing the same event twice has the same effect as once. It commits offsets only after success, routes poison messages to a Dead Letter Queue, and drains cleanly on shutdown. Every correctness property carries over from `go-event-consumer` unchanged; only the client (`aiokafka` instead of `franz-go`) and the concurrency primitive change. The concurrency primitive is where the honest divergence lives, and it is the reason this skill exists rather than a line-for-line port.

This is `aiokafka`-direct, `asyncpg`-direct — no framework wrapper. Redpanda speaks the Kafka protocol, so `aiokafka` talks to it with no Redpanda-specific client.

---

## The Async Consume Loop and Manual Offset Commit

The consumer is an `async for msg in consumer:` loop over an `AIOKafkaConsumer` constructed with `enable_auto_commit=False`. Offsets are **never** advanced on a timer — a crash between an auto-commit tick and completed processing silently loses the in-flight event. The commit happens *after* the record is durably processed or DLQ'd, and only then:

```python
consumer = AIOKafkaConsumer(
    topic, bootstrap_servers=brokers, group_id="dataasset-indexer",
    enable_auto_commit=False, auto_offset_reset="earliest",
)
async for msg in consumer:
    await self._handle(msg)              # durably processed or DLQ'd inside
    await consumer.commit()              # then, and only then
```

`asyncio.CancelledError` (raised into the loop when the task is cancelled on shutdown) is the cancellation analog to Go's `ctx.Done()` — but unlike a `context.Context` it carries no values, so tenant/trace state travels in a `contextvars.ContextVar`, not the cancellation signal. Full consumer construction, per-message vs batched commit tradeoff, and the worked `DataAsset` consumer: `references/consumer-loop-and-idempotency.md`.

---

## The Idempotent-Consumer Pattern

The dedup record and the business write commit in **one `asyncpg` transaction**. Insert into `processed_events (consumer_name, event_id)` first; if it conflicts the event was already handled — commit empty and return; otherwise run the business logic and let the block commit both together:

```python
async with pool.acquire() as conn, conn.transaction():
    status = await conn.execute(
        """INSERT INTO processed_events (consumer_name, event_id)
           VALUES ($1, $2) ON CONFLICT DO NOTHING""",
        self.name, envelope.event_id,
    )
    if status == "INSERT 0 0":           # conflict — already processed
        return                           # transaction commits empty
    await self._apply(conn, envelope)    # business logic, same transaction
```

`event_id` is the envelope's id — always `python-event-publisher`'s outbox row id, never re-derived here (that contract is owned by that skill). `consumer_name` scopes the dedup ledger per pipeline stage so one stage's replay never collides with another's. Every query the business logic runs is scoped to `tenant_id` — the application-layer backstop behind physical per-tenant isolation. Full schema, the `"INSERT 0 0"` status-string check, retention, and why the insert must precede business logic in the same transaction: `references/consumer-loop-and-idempotency.md`.

---

## Semaphore for I/O-bound, ProcessPool for CPU-bound (the key divergence)

**This is the one place where naively porting Go is wrong.** Go's bounded worker pool (`errgroup.SetLimit`) handles both I/O-bound and CPU-bound per-message work identically, because goroutines get true multi-core parallelism from the runtime scheduler. Python cannot: the **GIL** lets only one thread execute Python bytecode at a time, so the correct primitive depends on what the work *is*:

| Per-message work | Correct primitive | Why |
|---|---|---|
| **I/O-bound** — DB writes, S3/Drive fetches, HTTP calls | `asyncio.Semaphore(N)`-bounded coroutines, dispatched with `asyncio.TaskGroup` | The GIL is released during I/O waits; coroutines are cheap (like goroutines). A Semaphore caps in-flight work so a burst can't exhaust memory. |
| **CPU-bound** — entity extraction, classification, parsing | `ProcessPoolExecutor` via `loop.run_in_executor` | Pure-Python CPU work under the GIL runs **fully serial** no matter how many coroutines you spawn. Only separate OS processes give real parallelism. |

An `asyncio.Semaphore`-bounded "worker pool" of coroutines is **not** a substitute for a `ProcessPoolExecutor` on CPU-bound work — it silently degrades to serial execution under real CPU load. A `ProcessPoolExecutor` is categorically heavier than a goroutine: each worker is a full interpreter process with its own memory, task inputs and results cross the boundary by pickling, and there is no shared memory by default — so the pool is long-lived and bounded, sized to **per-process memory cost, not core count**. For this product the frugal default is to *not* solve CPU-bound work inside the consumer at all: document parsing / OCR / classification stays a separately-scaled service (the pipeline's escalation discipline), so most consumers only ever need the Semaphore path. Full worked Semaphore pool, the `ProcessPoolExecutor` path with its pickling constraints, and the sizing rule: `references/worker-pools-and-dlq.md`.

---

## DLQ and Graceful Drain

Transient failures retry with exponential backoff + jitter; records that exhaust retries or are undecodable route to `<topic>.dlq`, the original message value forwarded **byte-for-byte unchanged**, with an `x-retry-count` header and failure metadata carried only in headers — never re-serialised. A single poison record goes to the DLQ; it never fails the surrounding batch or blocks the partition head.

On shutdown the loop stops fetching, lets in-flight work finish, commits final offsets, then calls `await consumer.stop()`. `aiokafka`'s `consumer.stop()` performs the group-leave and final flush; the drain must `await` it inside a bounded `asyncio.wait_for` under the pod grace period. A commit that fails during drain just means re-delivery on restart — dedup covers it. Full DLQ producer, the retry-then-route logic, `x-retry-count` convention, and the drain sequence: `references/worker-pools-and-dlq.md`.

---

## Rules

- **Idempotent always.** Dedup on `(consumer_name, event_id)` in the same transaction as the work, dedup first.
- **Manual commit only.** `enable_auto_commit=False`; commit after the record is durably processed or DLQ'd, never on a timer.
- **Match the primitive to the work.** `asyncio.Semaphore` for I/O-bound; `ProcessPoolExecutor` for CPU-bound. Never a coroutine pool for CPU work.
- **Bounded concurrency.** A Semaphore (or pool `max_workers`) caps in-flight work; no unbounded `create_task` per message.
- **Per-message failure ≠ batch failure.** One bad record goes to the DLQ; the loop proceeds.
- **DLQ, never drop.** `<topic>.dlq`, value unchanged, `x-retry-count` set once per push.
- **Tenant scope every query.** `tenant_id` in every `WHERE`, read from a `contextvars.ContextVar`, even under physical isolation.
- **Graceful drain** via `await consumer.stop()` inside a bounded `wait_for` under the pod grace period.

---

## Quality Criteria

| Criterion | Pass | Fail | How to verify |
|---|---|---|---|
| Idempotency | Dedup + business write share one `conn.transaction()`, dedup first | Work applied before/without dedup, or dedup in a separate transaction | Read `_handle` for one `async with conn.transaction()` spanning both |
| Dedup key scope | `(consumer_name, event_id)` composite key | `event_id` alone | Read `processed_events`' `PRIMARY KEY` clause |
| Offset discipline | `enable_auto_commit=False`; commit only after `_handle` returns | Auto-commit enabled, or commit before processing completes | `grep -n "enable_auto_commit\|\.commit()" ` over the consumer |
| Correct primitive | I/O-bound → `asyncio.Semaphore`; CPU-bound → `ProcessPoolExecutor` | A coroutine/Semaphore pool wrapping CPU-bound work | Read the dispatch site — CPU work goes through `run_in_executor` |
| Bounded concurrency | `Semaphore(N)` or pool `max_workers` present | Unbounded `create_task` per message | `grep -n "Semaphore\|max_workers" ` over the consumer |
| Poison handling | Undecodable/exhausted → DLQ, value unchanged | Infinite retry, silent drop, or DLQ value re-serialised | Read the DLQ push — `value=msg.value`, not a re-encoded object |
| DLQ topic naming | `<topic>.dlq` | Any other naming, or one shared DLQ topic | `grep -n "dlq" ` over the DLQ producer |
| Tenant scoping | Every business query filters `tenant_id` | A query missing the tenant filter | Read every `WHERE` in `_apply` for `tenant_id` |
| Graceful drain | `await consumer.stop()` inside a bounded `wait_for` | Hard process exit, or an unbounded stop that can hang shutdown | Read the shutdown path for `wait_for(consumer.stop(), ...)` |

---

## Anti-Patterns

- **Auto-commit** — offsets advanced on a timer regardless of outcome; a crash between the tick and completion silently loses events.
- **A coroutine/Semaphore pool for CPU-bound work** — degrades to fully serial execution under the GIL; the throughput you think you have does not exist.
- **A `ProcessPoolExecutor` spun up per message** — process startup and pickling cost dwarf the work; the pool must be long-lived and bounded.
- **Dedup in memory or a separate transaction** — resets on restart, invisible to other instances, or reintroduces the dual-write race the pattern closes.
- **Retrying poison messages forever, or failing the loop on one bad record** — the first blocks the partition head; the second stops healthy processing over one failure.
- **A shared DLQ topic, or a DLQ value that isn't the original bytes** — the first makes DLQ depth ambiguous; the second discards the one thing an undecodable record can still preserve.

---

## Output Format

Python source built exactly to the standards above, plus an integration test against real Redpanda and PostgreSQL via `testcontainers-python` (`python-integration-test` owns the harness):

```
infrastructure/events/consumer.py            (AIOKafkaConsumer, run loop, _handle, _apply, drain)
infrastructure/events/dlq.py                 (DLQ producer, dlq_topic, x-retry-count)
tests/infrastructure/test_consumer.py        (written first — TDD; includes a duplicate-delivery test)
```

Full standards: `references/consumer-loop-and-idempotency.md` (consumer construction, manual commit, `processed_events` in-transaction dedup, tenant scoping, worked `DataAsset` consumer) and `references/worker-pools-and-dlq.md` (Semaphore I/O pool vs `ProcessPoolExecutor` CPU pool with pickling constraints, DLQ routing after N retries, graceful drain).
