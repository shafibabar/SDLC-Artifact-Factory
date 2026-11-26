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
-- deletes rows older than the longest time the same event_id can arrive again:
-- the topic's retention PLUS the longest replay path (a Dead Letter Queue replay,
-- an outbox relay re-publish). Topic retention alone is too short.
CREATE INDEX processed_events_processed_at_idx ON processed_events (processed_at);
```

`consumer_name` scopes the ledger **per pipeline stage**. If the indexer and the classifier both consume `dataasset.discovered`, each records its own `(consumer_name, event_id)` row, so one stage replaying (after a rebalance, a restart, or a manual offset reset) never collides with another stage's dedup history. Keying on `event_id` alone would make the two stages fight over one ledger and drop legitimately-distinct processing.

`event_id` is the envelope's id — the outbox row id produced by `python-event-publisher`. It is **never re-derived** in the consumer (no hashing of the payload, no `uuid4()` at consume time): the publisher owns the idempotency-key contract, and re-deriving it here would break dedup the moment the two derivations disagreed.

---

## 2. The message envelope

Events arrive as the JSON envelope `python-event-publisher`'s relay writes into the message value. Decoding is the first thing that can fail — a malformed value is a poison record and goes straight to the DLQ (see `worker-pools-and-dlq.md`), never a crash:

```python
# src/classification/entrypoints/event_consumer.py
import asyncio
import json
import logging
import signal
from dataclasses import dataclass
from datetime import datetime
from typing import Any
from uuid import UUID

import asyncpg
from aiokafka import AIOKafkaConsumer, AIOKafkaProducer, ConsumerRecord

from classification.entrypoints.dead_letter import DLQProducer, is_transient, with_retry
from classification.domain.context import current_tenant


@dataclass(frozen=True, slots=True)
class Envelope:
    event_id: UUID
    event_type: str
    aggregate_id: UUID
    tenant_id: UUID
    occurred_at: datetime        # asyncpg needs a datetime for timestamptz, not a string
    payload: dict[str, Any]

    @classmethod
    def decode(cls, raw: bytes) -> "Envelope":
        d = json.loads(raw)
        return cls(
            event_id=UUID(d["event_id"]),
            event_type=d["event_type"],
            aggregate_id=UUID(d["aggregate_id"]),
            tenant_id=UUID(d["tenant_id"]),
            occurred_at=datetime.fromisoformat(d["occurred_at"]),
            payload=d["payload"],
        )
```

The `DLQProducer`, `with_retry` and `is_transient` imported here are shown in `worker-pools-and-dlq.md`.

`slots=True` keeps the envelope cheap; `frozen=True` makes it a value object — nothing mutates an event after decode.

---

## 3. Consumer construction — manual commit is not optional

```python
# src/classification/entrypoints/event_consumer.py  (continued)
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
# src/classification/entrypoints/event_consumer.py  (continued)
log = logging.getLogger("dataasset.consumer")


class DataAssetConsumer:
    def __init__(self, consumer: AIOKafkaConsumer, pool: asyncpg.Pool,
                 dlq: DLQProducer, name: str, max_attempts: int = 3) -> None:
        self.consumer = consumer
        self.pool = pool
        self.dlq = dlq
        self.name = name
        self.max_attempts = max_attempts
        self._stopping = asyncio.Event()

    def request_stop(self) -> None:
        """Finish the record in hand, commit it, then leave the loop."""
        self._stopping.set()

    async def run(self) -> None:
        await self.consumer.start()
        try:
            while not self._stopping.is_set():
                batches = await self.consumer.getmany(timeout_ms=1000, max_records=100)
                for tp, messages in batches.items():
                    for msg in messages:
                        if self._stopping.is_set():
                            return                       # unhandled records are redelivered
                        await self._handle_or_dlq(msg)
                        # AFTER durably processed or DLQ'd, and only up to this record.
                        await self.consumer.commit({tp: msg.offset + 1})
        finally:
            await self._drain()

    async def _handle_or_dlq(self, msg: ConsumerRecord) -> None:
        try:
            await with_retry(lambda: self._handle(msg), max_attempts=self.max_attempts)
        except Exception as exc:  # noqa: BLE001 — CancelledError is not an Exception
            # Transient failures got here only after exhausting their attempts.
            attempts = self.max_attempts if is_transient(exc) else 0
            log.exception("handling failed; routing to DLQ")
            # If this send fails it raises, the offset stays uncommitted, nothing is lost.
            await self.dlq.route(msg, reason=type(exc).__name__, retry_count=attempts)

    async def _handle(self, msg: ConsumerRecord) -> None:
        envelope = Envelope.decode(msg.value)      # malformed -> not transient -> DLQ
        token = current_tenant.set(envelope.tenant_id)
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
# src/classification/entrypoints/event_consumer.py  (continued: methods of DataAssetConsumer)
    async def _apply(self, conn: asyncpg.Connection, envelope: Envelope) -> None:
        tenant = current_tenant.get()
        if envelope.event_type == "DataAssetRegistered":
            await conn.execute(
                """INSERT INTO data_asset_index
                       (asset_id, tenant_id, source_id, registered_at)
                   VALUES ($1, $2, $3, $4)
                   ON CONFLICT (tenant_id, asset_id) DO NOTHING""",
                envelope.aggregate_id, tenant,
                UUID(envelope.payload["source_id"]), envelope.occurred_at,
            )
        elif envelope.event_type == "DataAssetClassified":
            status = await conn.execute(
                """UPDATE data_asset_index SET sensitivity = $1
                    WHERE tenant_id = $2 AND asset_id = $3""",
                envelope.payload["sensitivity"], tenant, envelope.aggregate_id,
            )
            if status == "UPDATE 0":     # never record an event as processed without applying it
                raise LookupError(f"asset {envelope.aggregate_id} not indexed yet")
        else:
            log.warning("unhandled event_type %s", envelope.event_type)
```

The projection table:

```sql
CREATE TABLE data_asset_index (
    tenant_id     uuid NOT NULL,
    asset_id      uuid NOT NULL,
    source_id     uuid NOT NULL,
    sensitivity   text,
    registered_at timestamptz NOT NULL,
    PRIMARY KEY (tenant_id, asset_id)
);
```

`tenant_id` appears in every statement and in the primary key. That holds whichever isolation model the tenancy design chose: it is the application-layer backstop — a missing tenant fails loudly (`current_tenant.get()` raises `LookupError`), never writes unscoped. The tenant is read from the `ContextVar`, so concurrent messages for different tenants never bleed state. A single-tenant product drops it.

---

## 6. Per-message vs batched commit — the tradeoff

The loop above commits after **every** message: maximum safety, lowest throughput (a network round-trip per record). Two alternatives trade safety for throughput:

- **Per-batch commit** — process all records from one `getmany()` fetch, then a single `commit()`. Fewer round-trips; on a crash mid-batch the whole batch is redelivered, but dedup makes redelivery a no-op, so correctness holds. This is the usual production choice.
- **Per-interval commit** — commit on a time boundary regardless of batch edges. Highest throughput, largest redelivery window on crash; only acceptable because dedup absorbs the redelivery.

All three are correct **only because dedup is in place** — the commit cadence tunes how much redundant reprocessing a crash triggers, never whether an event can be lost or double-applied. Without the `processed_events` check, none of the batched options would be safe.

For the batched shape, move the commit out of the inner loop:

```python
# Illustration
batches = await self.consumer.getmany(timeout_ms=1000, max_records=100)
for tp, messages in batches.items():
    for msg in messages:
        await self._handle_or_dlq(msg)
await self.consumer.commit()     # one commit for the whole fetch, after ALL of it
```

---

## 7. The graceful drain hook

Called from the `run` loop's `finally`; the process-level shutdown sequence is in `worker-pools-and-dlq.md` §4. With auto-commit off, `stop()` leaves the group and commits nothing.

```python
# src/classification/entrypoints/event_consumer.py  (continued: method of DataAssetConsumer)
    async def _drain(self) -> None:
        await asyncio.wait_for(self.consumer.stop(), timeout=8.0)
```
