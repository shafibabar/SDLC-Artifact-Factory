# Transactional Outbox over AMQP — Full Python Reference

The Transactional Outbox pattern adapted from Redpanda (`python-event-publisher`)
to RabbitMQ, in async Python over `asyncpg` + `aio-pika`. The *insert side* is
identical — `python-repository-pattern`'s `save` writes an outbox row in the same
`conn.transaction()` as the aggregate change. The *relay side* differs in three
ways, all traceable to one root cause: **AMQP has no log offset and no retained
log**.

| Concern | Redpanda relay (`python-event-publisher`) | AMQP relay (this skill) |
|---|---|---|
| Proof of delivery | `send_and_wait` returns an `aiokafka` ack → produced to a partition offset | **publisher confirm** — the awaited `aio-pika` `publish` returns without raising |
| Durability source | broker **retention** of the partition | **durability triple**: durable exchange + durable queue + persistent delivery |
| Extra failure mode | none — a produced record is always routable | **unroutable return** (`DeliveryError`): confirmed but routed to zero queues → topology bug, do **not** mark published |
| Replay of history | rewind the consumer offset | impossible — removed-on-ack; re-publish from the outbox instead |

Everything else — atomic insert, `FOR UPDATE SKIP LOCKED` claim, at-least-once,
idempotency keyed on the outbox row id — carries over unchanged.

---

## 1. The Outbox Table (unchanged from the Redpanda outbox)

```sql
CREATE TABLE outbox (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_id  uuid        NOT NULL,
    tenant_id     uuid        NOT NULL,
    event_type    text        NOT NULL,   -- becomes the AMQP routing key
    payload       jsonb       NOT NULL,
    occurred_at   timestamptz NOT NULL DEFAULT now(),
    published_at  timestamptz              -- NULL until the confirm arrives
);

CREATE INDEX outbox_unpublished_idx
    ON outbox (occurred_at)
    WHERE published_at IS NULL;
```

`id` is the **idempotency key**. It is stable across every re-publication — it
travels as the AMQP `message_id`, and the consumer deduplicates on it. Never mint
a fresh `uuid4()` per publish attempt; that would defeat dedup on a retry.

Per-tenant physical isolation (this repo's model): the outbox lives in the
tenant's own schema/database, so `tenant_id` is a sanity column, not a routing
partition, and there is no cross-tenant data in a single relay's claim.

---

## 2. The Relay Loop

The relay is a single supervised coroutine started in FastAPI's `lifespan`
(`python-service-skeleton`) — it starts when the app starts and cancels the
instant `lifespan` tears down. Each pass claims a batch, publishes each row in
**confirm mode with mandatory + persistent**, and marks a row published **only
after its awaited `publish` returns without raising**. A `DeliveryError` for a row
means "confirmed but unroutable" (or nacked): leave `published_at` NULL, alarm,
and do not retry an unroutable row blindly (the fix is topology, not a resend).

```python
import asyncpg

from aio_pika.exceptions import DeliveryError


class Relay:
    def __init__(self, pool: asyncpg.Pool, pub: "Publisher",
                 exchange: str, batch: int = 100) -> None:
        self._pool = pool
        self._pub = pub
        self._exchange = exchange
        self._batch = batch

    async def drain_once(self) -> None:
        async with self._pool.acquire() as conn:
            async with conn.transaction():
                rows = await conn.fetch(
                    """
                    SELECT id, tenant_id, event_type, payload
                      FROM outbox
                     WHERE published_at IS NULL
                     ORDER BY occurred_at
                     LIMIT $1
                     FOR UPDATE SKIP LOCKED
                    """,
                    self._batch,
                )

                published: list = []
                for row in rows:
                    body = self._envelope(row)
                    try:
                        # Publish to the exchange with event_type as routing key.
                        # Confirms are on -> the await is the at-least-once wait;
                        # mandatory=True -> DeliveryError on a zero-route message.
                        await self._pub.publish(
                            routing_key=row["event_type"],
                            body=body,
                            message_id=str(row["id"]),
                        )
                    except DeliveryError:
                        # nack or unroutable: stop this batch, let the
                        # transaction roll back, retry next pass. Rows stay
                        # unpublished — this IS the backpressure mechanism.
                        raise
                    published.append(row["id"])

                if published:
                    await conn.execute(
                        "UPDATE outbox SET published_at = now() WHERE id = ANY($1)",
                        published,
                    )
```

**Publish, then mark — never the reverse.** If the process crashes after the
confirm but before the `UPDATE` commits, the transaction rolls back,
`published_at` stays NULL, and the row is re-claimed and re-published next pass.
At-least-once by construction; the consumer dedups on `message_id == outbox.id`.

`self._pub.publish` is the confirm-mode publish from
`references/publishing-and-confirms.md` (mandatory + `DeliveryMode.PERSISTENT`),
which raises `DeliveryError` on a nack or unroutable return so the relay leaves
the batch unpublished.

---

## 3. The Poll Loop and Graceful Cancel

```python
import asyncio


async def run(relay: Relay, interval: float = 1.0) -> None:
    try:
        while True:
            try:
                await relay.drain_once()
            except Exception:  # transient broker/DB error — never fatal
                # log.exception(...); unpublished rows wait for the next pass.
                pass
            await asyncio.sleep(interval)
    except asyncio.CancelledError:
        # lifespan teardown — no transaction is left open (drain_once's
        # `async with conn.transaction()` has already exited on each pass).
        raise
```

A failed `drain_once` logs and continues — never fatal, since a transient broker
outage must not crash the process. This is the same backpressure standard as the
Redpanda relay: unpublished rows accumulate as durable backlog in Postgres until
the broker recovers, drained at whatever rate it can sustain. Do not add a retry
loop or circuit breaker to the relay — the next pass retries for free.

---

## 4. Handling the Unroutable Return in the Relay

A returned message is **confirmed** (the broker accepted it) but reached **zero
queues**. In `aio-pika` this is not a naive success that slips past a
confirm-only check — the awaited `publish` raises `DeliveryError`, so the relay's
`except DeliveryError: raise` already leaves `published_at` NULL. This is
strictly simpler than Go, where the confirm `ack` and the return arrive on
separate channels and the relay must correlate them by `MessageId` before it
knows the row is unroutable.

The relay leaving `published_at` NULL is correct: the event was **not** delivered
anywhere. Redpanda's relay never needs this branch because a produced record is
always routable to its partition. Alarm on a sustained unroutable rate — it means
a routing key matched no binding, a topology bug a resend cannot fix.

---

## 5. Worked DataAsset Example

A `DataAssetClassified` domain event must publish whenever a data asset's
sensitivity classification changes, atomically with the classification write.

1. **Repository writes both in one transaction** (`python-repository-pattern`):

```python
async def save_classification(conn: asyncpg.Connection, asset) -> None:
    async with conn.transaction():
        await conn.execute(
            "UPDATE data_asset SET classification=$1, updated_at=now() WHERE id=$2",
            asset.classification, asset.id,
        )
        await conn.execute(
            """
            INSERT INTO outbox (aggregate_id, tenant_id, event_type, payload)
            VALUES ($1, $2, 'dataasset.classified', $3)
            """,
            asset.id, asset.tenant_id,
            json.dumps({"asset_id": str(asset.id),
                        "classification": asset.classification}),  # e.g. "pii"
        )  # same transaction as the UPDATE — atomic
```

2. **Topology** (declared idempotently at startup): a durable **topic** exchange
   `dataasset.events`, a durable queue `search-index` bound `dataasset.#`, a
   durable queue `compliance-audit` bound `dataasset.classified`.

3. **Relay publishes** routing key `dataasset.classified` → both queues match →
   two broker copies, no `DeliveryError` → row marked published.

4. **Failure drill:** a typo binds the audit queue `dataasset.classfied`. The
   relay publishes `dataasset.classified`; only `search-index` matches. With
   `mandatory=True` the message still routes to `search-index` (one queue), so
   **no** `DeliveryError` is raised — returns fire only on **zero** routes. The
   missing audit copy is a *binding* bug caught by a consumer-lag / expected
   fan-out check, not by the mandatory flag. This is the AMQP subtlety:
   `mandatory` catches *zero* routes, not *fewer than expected* routes. Document
   expected fan-out per event so a monitor can assert it.

---

## 6. Idempotency and Ordering Notes

- **Idempotency key** = `outbox.id`, carried as AMQP `message_id`. The consumer
  keeps a `processed_events` set (or a unique constraint) and drops duplicates
  from at-least-once redelivery. See `python-amqp-consumer`.
- **Ordering** is per-queue and only holds for a single consumer without
  requeues. A Competing Consumers pool on one queue destroys ordering by design —
  do not rely on outbox `occurred_at` order surviving to a parallel consumer. If
  per-aggregate order matters, route one aggregate's events to one queue with one
  consumer, or fold ordering into the payload (a version number the consumer
  checks).
- **No replay.** A new consumer cannot rewind history — removed-on-ack. To rebuild
  a read model, re-publish from the outbox (or a snapshot), never "seek to offset
  0." This is the standing cost of a queue broker and the reason
  `message-broker-selection` prefers Redpanda for replay-needing flows.
- **The relay ships rows; it never decides what to ship.** Filtering or
  suppressing events at publish time is a defect — the repository already decided
  what happened.
