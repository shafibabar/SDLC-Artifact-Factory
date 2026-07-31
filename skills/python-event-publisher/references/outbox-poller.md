# The Outbox Poller — Schema, asyncio Poll Loop, SKIP LOCKED Claim, and the At-Least-Once Guarantee

Full worked material referenced from `SKILL.md`'s Purpose, "The Poll Loop and
Draining a Batch," and "Backpressure" sections. Self-contained — reads without the
parent body already in context. Covers: the exact `outbox` table schema, the exact
`FOR UPDATE SKIP LOCKED` SQL that claims a bounded batch of committed rows, the
`asyncio` poll loop that drains it against `asyncpg`, why the publish-before-mark
ordering produces at-least-once (never exactly-once) delivery, and the worked
`DataAsset` relay end to end.

---

## 1. The Problem the Outbox Solves: the Dual-Write

A service that changes state and then separately calls the broker has two writes that
cannot be made atomic by ordinary means:

```python
# UNSAFE — do not do this
await repo.save(asset)                  # asyncpg transaction committed
await producer.send_and_wait(topic, value=record)  # crash here: DB committed, broker never got it
```

If the process crashes between the two `await`s, the database commit already happened
and cannot be undone, but the event was never published — the event is **silently
lost**. A distributed (two-phase) transaction is the textbook fix, but Kafka/Redpanda
brokers do not participate in XA/2PC — there is no prepare/commit handshake to join.
The Transactional Outbox sidesteps this by making the *only* atomic operation a
**local** one: a second row written into the same `asyncpg` transaction as the
Aggregate's own write (`python-repository-pattern`'s `save`). Publishing is deferred
to this relay, which can retry indefinitely without threatening the correctness of the
already-committed first step.

---

## 2. The Outbox Table Schema

The relay reads a table whose shape is identical to `go-event-publisher`'s — Postgres
owns the guarantee regardless of client language, so the schema does not change
between the Go and Python relays.

```sql
-- 00012_create_outbox.sql  (Alembic revision, or raw SQL migration — python-migration)
CREATE TABLE outbox (
    id            uuid PRIMARY KEY,
    aggregate_id  uuid NOT NULL,
    tenant_id     uuid NOT NULL,          -- mandatory tenant scoping; becomes the partition key
    event_type    text NOT NULL,          -- past-tense Domain Event name (domain-event-catalog)
    payload       jsonb NOT NULL,         -- already-serialised envelope-body JSON
    occurred_at   timestamptz NOT NULL,   -- business time — when the Aggregate recorded the event
    published_at  timestamptz             -- NULL = unpublished; set once, by the relay, on success
);

-- Matches the claim query exactly: WHERE published_at IS NULL ORDER BY occurred_at.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_outbox_unpublished
    ON outbox (occurred_at)
    WHERE published_at IS NULL;
```

`published_at` is the *only* column the relay ever writes. Everything else is written
once, by the repository, inside the Aggregate's own transaction, and never touched
again — the outbox row is an immutable fact ("this event occurred") with one
append-only status bit on top.

---

## 3. The asyncpg Row and the Envelope

```python
# infrastructure/messaging/envelope.py
from __future__ import annotations
import dataclasses
import datetime as dt
import json
from uuid import UUID


@dataclasses.dataclass(frozen=True, slots=True)
class OutboxRow:
    """One claimed, unpublished outbox row, mapped from an asyncpg.Record."""
    id: UUID
    aggregate_id: UUID
    tenant_id: UUID
    event_type: str
    payload: dict
    occurred_at: dt.datetime


@dataclasses.dataclass(frozen=True, slots=True)
class Envelope:
    """The standard event envelope (domain-event-catalog's shape)."""
    event_id: str        # the outbox row id — the idempotency key
    event_type: str
    schema_version: int
    occurred_at: str     # ISO-8601
    aggregate_id: str
    tenant_id: str
    payload: dict

    def to_json(self) -> bytes:
        return json.dumps(dataclasses.asdict(self)).encode("utf-8")


def envelope_for(row: OutboxRow) -> Envelope:
    return Envelope(
        event_id=str(row.id),          # idempotency key = the row's own id, never uuid4()
        event_type=row.event_type,
        schema_version=1,
        occurred_at=row.occurred_at.isoformat(),
        aggregate_id=str(row.aggregate_id),
        tenant_id=str(row.tenant_id),
        payload=row.payload,           # already-deserialised jsonb from asyncpg
    )
```

`asyncpg` decodes a `jsonb` column to a Python `dict` automatically once a JSON codec
is registered on the pool (`await conn.set_type_codec("jsonb", encoder=json.dumps,
decoder=json.loads, schema="pg_catalog")`); the relay never re-parses the payload —
the repository, not the relay, knows the event's shape.

---

## 4. The asyncio Poll Loop and `drain_once`, in Full

The relay is a **polling** design, not CDC: a single supervised coroutine wakes on a
fixed interval, claims a bounded batch with `FOR UPDATE SKIP LOCKED`, publishes them,
and marks them published — all inside one `asyncpg` transaction per drain.

```python
# infrastructure/messaging/outbox_relay.py
import asyncio
import logging

import asyncpg
from aiokafka import AIOKafkaProducer

from .envelope import OutboxRow, envelope_for

log = logging.getLogger(__name__)

_CLAIM_SQL = """
    SELECT id, aggregate_id, tenant_id, event_type, payload, occurred_at
      FROM outbox
     WHERE published_at IS NULL
     ORDER BY occurred_at
     LIMIT $1
     FOR UPDATE SKIP LOCKED
"""

_MARK_SQL = "UPDATE outbox SET published_at = now() WHERE id = ANY($1::uuid[])"


class OutboxRelay:
    def __init__(
        self,
        pool: asyncpg.Pool,
        producer: AIOKafkaProducer,
        *,
        interval: float = 1.0,
        batch: int = 100,
    ) -> None:
        self._pool = pool
        self._producer = producer
        self._interval = interval
        self._batch = batch

    async def run(self) -> None:
        """Poll forever until cancelled. Started as an asyncio.Task in lifespan."""
        try:
            while True:
                try:
                    await self.drain_once()
                except asyncio.CancelledError:
                    raise
                except Exception:  # noqa: BLE001 — a transient failure must not kill the relay
                    log.exception("outbox drain failed; retrying next pass")
                await asyncio.sleep(self._interval)
        except asyncio.CancelledError:
            log.info("outbox relay cancelled; shutting down cleanly")
            raise

    async def drain_once(self) -> int:
        """Claim, publish, and mark one batch inside a single transaction."""
        async with self._pool.acquire() as conn:
            async with conn.transaction():  # commits on clean exit, rolls back on any raise
                records = await conn.fetch(_CLAIM_SQL, self._batch)
                if not records:
                    return 0

                rows = [
                    OutboxRow(
                        id=r["id"],
                        aggregate_id=r["aggregate_id"],
                        tenant_id=r["tenant_id"],
                        event_type=r["event_type"],
                        payload=r["payload"],
                        occurred_at=r["occurred_at"],
                    )
                    for r in records
                ]

                # Publish, then mark — never the reverse. A raise here rolls the
                # transaction back; published_at stays NULL; the row is re-claimed
                # next pass. That is at-least-once, by construction (see §5).
                await self._publish_batch(rows)

                await conn.execute(_MARK_SQL, [row.id for row in rows])
                return len(rows)

    async def _publish_batch(self, rows: list[OutboxRow]) -> None:
        """Await every send's broker ack. Any failure raises out of drain_once."""
        sends = [self._send(row) for row in rows]
        await asyncio.gather(*sends)  # aiokafka's async analog of Go's ProduceSync(records...)

    async def _send(self, row: OutboxRow) -> None:
        env = envelope_for(row)
        await self._producer.send_and_wait(
            topic=_topic_for(row.event_type),
            value=env.to_json(),
            key=row.tenant_id.bytes,           # partition affinity by tenant — see §6
            headers=_trace_headers(),          # W3C trace context; producer reference has the injector
        )


def _topic_for(event_type: str) -> str:
    # One outbox table serves every event type; route by the event_type column.
    return f"dataasset.{event_type}"


def _trace_headers() -> list[tuple[str, bytes]]:
    # Inject the current OpenTelemetry span context so the consumer continues the trace.
    from opentelemetry import propagate
    carrier: dict[str, str] = {}
    propagate.inject(carrier)
    return [(k, v.encode("utf-8")) for k, v in carrier.items()]
```

**Why `FOR UPDATE SKIP LOCKED`, precisely:** without it, a second relay replica's
`SELECT` would either block on the first replica's row locks (serialising every
replica behind the slowest) or, with no locking clause, read and publish the *same*
rows a concurrent replica just claimed — an ordinary-operation duplicate, not a
crash-recovery one. `SKIP LOCKED` makes each replica's claim non-blocking and disjoint:
rows already locked by another in-flight `drain_once` are silently skipped.

**Why the claim, the sends, and the mark share one transaction:** the claim
(`SELECT ... FOR UPDATE`) and the mark (`UPDATE ... published_at`) must be atomic with
each other for `SKIP LOCKED` to mean anything — separate transactions would let a crash
between them leave a row locked by nothing, claimed by no one. The `send_and_wait`
calls sit *between* the claim and the mark, inside the open transaction window but not
themselves part of what the transaction protects — §5 explains why that ordering, not
full atomicity across all three, is exactly the design.

---

## 5. Why At-Least-Once, and Why Exactly-Once Is Not Attempted

**The guarantee is at-least-once: every outbox row is published one or more times,
never zero.** The proof is the ordering inside `drain_once`: every `send_and_wait` is
awaited (its broker ack confirmed) *before* the `UPDATE ... published_at` runs. Walk
every point the process can crash:

| Crash point | State left behind | Consequence |
|---|---|---|
| Before the last `send_and_wait` ack returns | Row still `published_at IS NULL`, transaction never committed | Rolled back; row reclaimed next pass — never published, correctly, since it never was |
| After all acks succeed, before the transaction commits | Broker has the messages; the transaction (including the mark) rolls back | Rows re-claimed and re-published next pass — a **duplicate** delivery, not a lost one |
| After commit | Rows durably `published_at` non-null | Done; no further action |

The middle row is why this is at-least-once and not exactly-once: there is no way to
make "the broker received the message" and "the local transaction committed" a single
atomic unit, because they are two systems with no shared coordinator (§1).
**Exactly-once across a database and a broker is not attempted** — it requires
distributed-consensus infrastructure this pattern exists to avoid. The tradeoff taken
instead: accept an occasional duplicate at the broker, and push the responsibility for
making a duplicate harmless onto the consumer, where an `INSERT ... ON CONFLICT DO
NOTHING` into `processed_events` inside the consumer's own transaction
(`python-event-consumer`) makes it cheap and mechanical. Idempotency is the correct
place to pay for this tradeoff, not a workaround for a design that fell short.

---

## 6. Ordering, Partitioning, and Their Limits

`key=row.tenant_id.bytes` routes all of one tenant's events to one partition, so
`aiokafka`'s default hashing partitioner preserves per-tenant ordering while letting
different tenants publish in parallel. `ORDER BY occurred_at` preserves emission order
*within* a batch, and per-aggregate order as a consequence.

Ordering is **not** guaranteed **across replicas**: running more than one relay replica
trades strict cross-batch ordering for throughput, since two replicas can claim and
publish adjacent batches for the same tenant concurrently. If a stream's consumers
require strict total order, run exactly one relay replica for that deployment — the
design supports either, and the choice is operational, not a code change. This is also
why `enable_idempotence=True` on the producer matters (see `references/aiokafka-producer.md`):
it prevents a *within-send retry* from reordering or duplicating a record at the broker,
which is a separate concern from the cross-crash duplicate §5 accepts.

---

## 7. The Worked DataAsset Relay, Wired into `lifespan`

The relay is created and supervised in FastAPI's `lifespan` (`python-service-skeleton`),
alongside the producer it depends on. Cancellation on shutdown is what stops it cleanly.

```python
# app/lifespan.py
import asyncio
from contextlib import asynccontextmanager

from infrastructure.messaging.outbox_relay import OutboxRelay
from infrastructure.messaging.producer import build_producer


@asynccontextmanager
async def lifespan(app):
    pool = app.state.pool                     # asyncpg pool built earlier in startup
    producer = build_producer()               # producer reference owns this construction
    await producer.start()

    relay = OutboxRelay(pool, producer, interval=1.0, batch=100)
    relay_task = asyncio.create_task(relay.run(), name="outbox-relay")

    try:
        yield
    finally:
        relay_task.cancel()                   # request cooperative cancellation
        try:
            await relay_task                  # let run()'s CancelledError handler complete
        except asyncio.CancelledError:
            pass
        await producer.stop()                 # flush and close after the relay has stopped
```

The teardown order is deliberate and mirrors the reverse-of-startup shutdown Go's
service skeleton does explicitly: cancel the relay *first* (so no new `drain_once`
begins), await its clean exit, then `producer.stop()` (which flushes any buffered
sends) — never stop the producer while a `drain_once` might still call it.

---

## 8. Why a Polling Relay, Not Change Data Capture (CDC)

CDC — streaming row-level changes out of Postgres's WAL via Debezium rather than
polling — is a legitimate alternative *mechanism* for the same Transactional Outbox
*pattern*: the table shape (§2) and atomicity guarantee are identical either way. This
repo polls, not CDC, on the frugality constraint (`CLAUDE.md`): CDC requires operating a
second piece of infrastructure (a Debezium connector plus Kafka Connect) with its own
deployment, upgrade, and failure surface, to solve a problem a single `asyncio`
coroutine on a sleep loop already solves completely at these batch sizes and latencies.
CDC's real advantage — lower publish latency — is not a requirement anywhere in this
product context. If a future requirement narrows acceptable outbox-to-broker latency
below what a short poll interval delivers, that is a deliberate, ADR-backed decision to
revisit, not a defect in the polling relay as built.
