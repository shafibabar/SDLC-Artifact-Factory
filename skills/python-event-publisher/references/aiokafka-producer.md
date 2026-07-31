# The aiokafka Producer — Idempotent Config, Keyed Partitioning, Delivery, and Retry

Full worked material referenced from `SKILL.md`'s "The Envelope, Partition Key, and
Idempotency Key" and "The aiokafka Producer Config" sections. Self-contained. Covers:
the exact `AIOKafkaProducer` construction and every config value it must carry, why
`key=tenant_id` gives partition affinity, how delivery/ack works with
`send_and_wait`, retry semantics, and the idempotent-producer settings that stop a
within-send retry from duplicating or reordering a record at the broker.

---

## 1. Building the Producer — Every Config Value and Why

The producer is built once at `lifespan` startup and shared by the relay. `aiokafka`
speaks the Kafka wire protocol, so it talks to Redpanda unchanged.

```python
# infrastructure/messaging/producer.py
import os

from aiokafka import AIOKafkaProducer


def build_producer() -> AIOKafkaProducer:
    return AIOKafkaProducer(
        bootstrap_servers=os.environ["REDPANDA_BROKERS"],   # e.g. "redpanda-0:9092,redpanda-1:9092"

        # --- Idempotent-producer settings: the heart of correct at-least-once ---
        enable_idempotence=True,          # broker de-duplicates client retries by (PID, seq); no dupes/reorders from a retry
        acks="all",                       # wait for every in-sync replica; implied by idempotence, set explicitly for clarity
        max_in_flight_requests_per_connection=5,  # idempotence permits up to 5 without losing ordering; >5 would reorder

        # --- Retry / durability ---
        request_timeout_ms=30_000,        # per-request broker timeout before the send is retried or fails
        retry_backoff_ms=100,             # wait between retries so a transient blip is absorbed inside one send

        # --- Batching (throughput; does not affect correctness) ---
        linger_ms=5,                      # brief coalescing window so a burst of sends shares fewer broker requests
        compression_type="lz4",           # cheap wire-size win for JSON envelopes; Redpanda decompresses natively

        # value/key are already bytes when the relay calls send_and_wait — no serializer needed
    )
```

**Why `enable_idempotence=True` is non-negotiable here.** Without it, `aiokafka`'s own
internal retry of a timed-out send can land the *same* record on the broker twice, or
land two in-flight records out of order. The Transactional Outbox's at-least-once
guarantee (`references/outbox-poller.md` §5) already accepts a *cross-crash* duplicate
that the consumer dedups on `event_id`; the idempotent producer closes a *different*
gap — a *within-send* duplicate or reorder that would otherwise happen even with no
crash at all. The broker assigns each producer a Producer ID (PID) and a per-partition
sequence number, and rejects a retried record whose sequence it has already committed.

**Why `max_in_flight_requests_per_connection=5`, not higher.** With idempotence enabled,
the broker can still guarantee ordering with up to 5 unacknowledged requests in flight
per connection (it buffers and reorders by sequence number). Above 5, ordering is no
longer guaranteed even with idempotence on — so 5 is the ceiling, and the relay keeps
it. `acks="all"` and `enable_idempotence=True` are the pair that make this safe;
setting `acks=1` (the library default) would silently weaken durability.

---

## 2. Keyed Partitioning by Tenant

```python
await producer.send_and_wait(
    topic=_topic_for(row.event_type),
    value=envelope_for(row).to_json(),
    key=row.tenant_id.bytes,      # <-- partition affinity
    headers=_trace_headers(),
)
```

`aiokafka`'s default partitioner hashes the record key (`murmur2`, matching the Java
client and Redpanda) to choose a partition. Passing `key=row.tenant_id.bytes` means
**every event for a given tenant hashes to the same partition**, which buys three
things at once:

- **Per-tenant ordering.** Kafka/Redpanda guarantees order *within a partition*. One
  tenant's events, all on one partition, are delivered to the consumer in the order the
  relay published them.
- **Tenant isolation carried to the broker.** This product's physical per-tenant
  isolation is preserved through the messaging layer — a tenant's event stream is a
  contiguous slice of one partition, never interleaved across all of them.
- **A natural Competing-Consumers parallelism boundary.** Different tenants land on
  different partitions, so a consumer group scales out across tenants without breaking
  any single tenant's ordering.

**The two things that must never be used as the key instead:**

1. **The `event_id` (the row id).** Every event would get a distinct key, scattering one
   tenant's events uniformly across all partitions and destroying per-tenant ordering —
   the exact failure the tenant key exists to prevent.
2. **No key at all (`key=None`).** `aiokafka` then round-robins records across
   partitions, which is *worse* than random for this product: even two events from the
   same tenant emitted microseconds apart can land on different partitions and be
   consumed out of order.

`tenant_id.bytes` (the 16-byte big-endian form of the UUID) is used rather than the
string form so the key is compact and matches whatever a Go or Node relay for the same
topic would produce — `uuid.UUID.bytes` is stable and language-neutral.

---

## 3. Delivery and Ack Handling with `send_and_wait`

`aiokafka` exposes two produce calls; this relay uses **`send_and_wait`**, not
fire-and-forget `send`:

```python
# send_and_wait: awaits the broker ack; raises on failure. This is what the relay uses.
metadata = await producer.send_and_wait(topic, value=v, key=k, headers=h)
# metadata.partition, metadata.offset — where the record actually landed

# send: returns a future immediately; the ack is not awaited here. NOT used by the relay,
# because the relay must know every record was acked before it marks the batch published.
fut = await producer.send(topic, value=v, key=k)   # do not use in the drain path
```

The relay's `drain_once` batches sends with `await asyncio.gather(*[self._send(row)
for row in rows])` — each `_send` is a `send_and_wait`, so `gather` returns only once
**every** record in the batch has a broker ack. If any single send raises (broker down,
timeout exhausted, record too large), `gather` propagates that exception, `drain_once`'s
`async with conn.transaction()` rolls back, nothing is marked published, and the whole
batch is re-claimed next pass. This is the publish-before-mark ordering that makes the
outbox at-least-once — the mark (`UPDATE ... published_at`) is only reached if every ack
in the batch already returned.

**A note on partial-batch failure.** Because the sends run concurrently under `gather`,
some records in a failing batch may have been acked before another raised. Those acked
records are *not* marked published (the transaction rolled back), so they are
re-published next pass — a duplicate the consumer dedups on `event_id`. This is the
at-least-once contract working as designed, not a bug: re-publishing an already-delivered
record is always safe here; *failing to* re-publish one that was never marked is what
would be a lost event.

---

## 4. Retry Semantics — Where Each Layer of Retry Lives

There are three distinct retry layers, and conflating them is the usual source of bugs:

| Layer | Mechanism | Handles | Config |
|---|---|---|---|
| Within a single send | `aiokafka` internal retry of a timed-out request | A transient broker blip during one produce | `retry_backoff_ms`, `request_timeout_ms`, made safe by `enable_idempotence` |
| Across a failed drain | The next poll pass re-claims the un-marked batch | A broker outage lasting longer than one send's timeout | `interval` (the poll loop's `asyncio.sleep`) — no code, the outbox *is* the retry |
| Across a crash | A restarted relay re-claims rows still `published_at IS NULL` | Process death mid-drain | None — durable Postgres state, `references/outbox-poller.md` §5 |

The relay itself **adds no retry loop, no circuit breaker, no backoff of its own** on
top of these. A `send_and_wait` failure is allowed to raise straight out of `drain_once`;
the poll loop's own next pass is the retry, and the outbox table is the buffer that
absorbs a slow or down broker (the backpressure standard in `references/outbox-poller.md`).
Bolting a retry loop onto the relay duplicates what the next pass already does for free
and risks holding a transaction open across a long broker outage — the one thing the
poll-then-rollback design specifically avoids.

---

## 5. Testing the Producer Path

Integration tests run against a real Redpanda via `testcontainers-python` (the
`RedpandaContainer`, or a generic `KafkaContainer` pointed at Redpanda's image), paired
with `pytest-asyncio` for the async fixtures — `python-integration-test` owns the harness
mechanics. The producer-specific things worth asserting:

- **Same-tenant events land on one partition.** Publish several events for one
  `tenant_id`, consume the topic, assert every record's `partition` is identical and
  their order matches emission order.
- **A duplicate `event_id` is a consumer-side no-op.** Force a re-publish (a rolled-back
  drain) and assert the consumer's `processed_events` dedup swallows the second copy —
  the end-to-end proof that at-least-once plus idempotent consumption equals
  effectively-once *processing*.
- **`enable_idempotence` is actually set.** A unit-level assertion on the constructed
  producer's config guards against a future edit silently dropping it back to the
  library default and reintroducing within-send duplicates.
