# Consumer Loop and In-Transaction Idempotency

The full standard for the `aiokafka` consume loop, manual offset commit, and the `asyncpg`-backed `processed_events` dedup that runs in the same transaction as the business write. Everything here is self-contained — the `SKILL.md` body points to this file for the complete listings.

---

## 1. The `processed_events` dedup table

One table, shared by every consumer stage. The composite primary key is what makes the ledger safe to share:

```sql
CREATE TABLE processed_events (
    consumer_name TEXT        NOT NULL,
    event_id      UUID        NOT NULL,
    processed_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (consumer_name, event_id)
);

-- Retention: processed_events grows unbounded without a sweep. A daily job
-- deletes rows older than the topic's retention window — the same event_id
-- can never be redelivered once Redpanda has aged the record out, so a row
-- older than retention can never match again and is safe to drop.
CREATE INDEX processed_events_processed_at_idx ON processed_events (processed_at);
```

`consumer_name` scopes the ledger **per pipeline stage**. If the indexer and the classifier both consume `dataasset.discovered`, each records its own `(consumer_name, event_id)` row, so one stage replaying (after a rebalance, a restart, or a manual offset reset) never collides with another stage's dedup history. Keying on `event_id` alone would make the two stages fight over one ledger and drop legitimately-distinct processing.

`event_id` is the envelope's id — the outbox row id produced by `python-event-publisher`. It is **never re-derived** in the consumer (no hashing of the payload, no `uuid4()` at consume time): the publisher owns the idempotency-key contract, and re-deriving it here would break dedup the moment the two derivations disagreed.

---

## 2. The message envelope

Events arrive as a JSON envelope in the Kafka message value. Decoding is the first thing that can fail — a malformed value is a poison record and goes straight to the DLQ (see `worker-pools-and-dlq.md`), never a crash:

```python
from __future__ import annotations
import json
from dataclasses import dataclass
from uuid import UUID


@dataclass(frozen=True, slots=True)
class Envelope:
    event_id: UUID
    event_type: str
    tenant_id: UUID
    occurred_at: str
    payload: dict

    @classmethod
    def decode(cls, raw: bytes) -> "Envelope":
        d = json.loads(raw)
        return cls(
            event_id=UUID(d["event_id"]),
            event_type=d["event_type"],
            tenant_id=UUID(d["tenant_id"]),
            occurred_at=d["occurred_at"],
            payload=d["payload"],
        )
```

`slots=True` keeps the envelope cheap; `frozen=True` makes it a value object — nothing mutates an event after decode.

---

## 3. Consumer construction — manual commit is not optional

```python
from aiokafka import AIOKafkaConsumer


def build_consumer(topic: str, brokers: str, group_id: str) -> AIOKafkaConsumer:
    return AIOKafkaConsumer(
        topic,
        bootstrap_servers=brokers,
        group_id=group_id,
        enable_auto_commit=False,      # NEVER commit on a timer
        auto_offset_reset="earliest",  # a new group replays from the start, not "latest"
        max_poll_records=100,          # bounds one fetch; back-pressure lives in the pool, not here
    )
```

`enable_auto_commit=False` is the single most important setting. With auto-commit on, `aiokafka` advances the committed offset on a background interval regardless of whether `_handle` finished. A crash in the window between the auto-commit tick and completed processing loses every event in that window silently — they are marked consumed but were never applied. Manual commit closes that window: the offset only moves after the work is durable.

Redpanda speaks the Kafka protocol, so no Redpanda-specific client exists or is needed — `bootstrap_servers` points at the Redpanda brokers and `aiokafka` is none the wiser.

---

## 4. The consume loop and the in-transaction dedup

```python
import asyncio
import contextvars
import logging

import asyncpg

log = logging.getLogger("dataasset.consumer")

# tenant/trace state travels here, NOT on the cancellation signal — asyncio's
# CancelledError carries no values, unlike Go's context.Context.
current_tenant: contextvars.ContextVar[str] = contextvars.ContextVar("current_tenant")


class DataAssetConsumer:
    def __init__(self, consumer: AIOKafkaConsumer, pool: asyncpg.Pool, dlq, name: str):
        self.consumer = consumer
        self.pool = pool
        self.dlq = dlq
        self.name = name

    async def run(self) -> None:
        await self.consumer.start()
        try:
            async for msg in self.consumer:
                try:
                    await self._handle(msg)
                except Exception:                       # noqa: BLE001 — see worker-pools-and-dlq.md
                    log.exception("handling failed; routing to DLQ")
                    await self.dlq.route(msg, reason="handler-exception")
                await self.consumer.commit()            # AFTER durably processed or DLQ'd
        except asyncio.CancelledError:
            raise                                       # drain path handles stop(); re-raise
        finally:
            await self._drain()

    async def _handle(self, msg) -> None:
        envelope = Envelope.decode(msg.value)           # ValueError/KeyError -> caught above -> DLQ
        token = current_tenant.set(str(envelope.tenant_id))
        try:
            async with self.pool.acquire() as conn, conn.transaction():
                status = await conn.execute(
                    """INSERT INTO processed_events (consumer_name, event_id)
                       VALUES ($1, $2) ON CONFLICT DO NOTHING""",
                    self.name, envelope.event_id,
                )
                # asyncpg returns the command tag as a string. A no-op INSERT
                # (the ON CONFLICT fired) reports "INSERT 0 0" — the event was
                # already processed, so commit the empty transaction and stop.
                if status == "INSERT 0 0":
                    log.info("duplicate %s; skipping", envelope.event_id)
                    return
                await self._apply(conn, envelope)       # business logic, SAME transaction
        finally:
            current_tenant.reset(token)
```

The dedup insert **precedes** the business logic and shares its transaction. Ordering matters: if business logic ran first and the dedup insert failed, or if they were in separate transactions, a crash between them would either re-apply the work on redelivery or mark an event processed that never actually applied. One transaction, dedup first, makes "processed the event" and "recorded that we processed it" a single atomic fact. On any exception the `async with conn.transaction()` block rolls back both, and the offset is never committed — so the event is redelivered and retried cleanly.

---

## 5. The business write — tenant-scoped, worked `DataAsset`

```python
    async def _apply(self, conn: asyncpg.Connection, envelope: Envelope) -> None:
        tenant_id = current_tenant.get()
        if envelope.event_type == "DataAssetDiscovered":
            p = envelope.payload
            await conn.execute(
                """INSERT INTO data_asset_index
                       (asset_id, tenant_id, source, path, discovered_at)
                   VALUES ($1, $2, $3, $4, $5)
                   ON CONFLICT (asset_id, tenant_id) DO UPDATE
                       SET path = EXCLUDED.path,
                           discovered_at = EXCLUDED.discovered_at""",
                UUID(p["asset_id"]), tenant_id, p["source"], p["path"], envelope.occurred_at,
            )
        else:
            log.warning("unhandled event_type %s", envelope.event_type)
```

`tenant_id` appears in the `INSERT`'s value list and the conflict target. Under this product's **physical** per-tenant isolation each tenant already has its own database, but the tenant filter stays in every statement as the application-layer backstop — a missing tenant id must fail loudly (`current_tenant.get()` raises `LookupError` if unset), never silently write cross-tenant. The tenant id is read from the `ContextVar`, never a module global, so concurrent messages for different tenants never bleed state.

---

## 6. Per-message vs batched commit — the tradeoff

The loop above commits after **every** message: maximum safety, lowest throughput (a network round-trip per record). Two alternatives trade safety for throughput:

- **Per-batch commit** — process all records from one `getmany()` fetch, then a single `commit()`. Fewer round-trips; on a crash mid-batch the whole batch is redelivered, but dedup makes redelivery a no-op, so correctness holds. This is the usual production choice.
- **Per-interval commit** — commit on a time boundary regardless of batch edges. Highest throughput, largest redelivery window on crash; only acceptable because dedup absorbs the redelivery.

All three are correct **only because dedup is in place** — the commit cadence tunes how much redundant reprocessing a crash triggers, never whether an event can be lost or double-applied. Without the `processed_events` check, none of the batched options would be safe.

For the batched shape, replace the `async for` with an explicit poll:

```python
batch = await self.consumer.getmany(timeout_ms=1000, max_records=100)
for tp, messages in batch.items():
    for msg in messages:
        await self._handle_or_dlq(msg)
await self.consumer.commit()     # one commit for the whole fetch
```

---

## 7. The graceful drain hook

Referenced from the `run` loop's `finally`; the full drain including `consumer.stop()` bounding lives in `worker-pools-and-dlq.md` §4:

```python
    async def _drain(self) -> None:
        # stop fetching, let in-flight finish, final commit, then leave the group
        await asyncio.wait_for(self.consumer.stop(), timeout=20.0)
```
