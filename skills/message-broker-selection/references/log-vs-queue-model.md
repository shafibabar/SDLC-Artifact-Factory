# The Log Model and the Queue Model in Depth

This reference gives the enterprise-architect the full mechanics behind the one-line contrast in the skill body. It treats each model on its own terms, then compares them property-by-property, then works two real repo selections end to end. It is grounded in the Kafka/Redpanda log model and the AMQP 0-9-1 protocol (the spec RabbitMQ implements).

---

## Part 1 — The Log Model (Kafka API / Redpanda — the repo default)

### The core data structure is an append-only log

A **topic** is divided into **partitions**. Each partition is an ordered, immutable, append-only sequence of records. A record's position in its partition is its **offset** — a monotonically increasing integer assigned by the broker at append time. Nothing is ever removed on read; records live until a **retention** policy (time-based, e.g. 7 days, or size-based) evicts the oldest.

Key consequences:

- **Retained, not consumed-away.** Reading a record does not remove it. Ten different consumers can read the same record independently.
- **Offset is consumer-owned position, not broker state.** The broker does not track "who has read what." Each **consumer group** commits its own offset (typically to an internal offsets topic). A group that wants to re-read sets its offset backwards — this is **replay/rewind**, and it is free because the data was never deleted.
- **Ordering is per-partition, total within a partition, none across partitions.** Records with the same partition key land in the same partition and are read in offset order. There is no global order across partitions — that is the price of horizontal scale.

### Parallelism: the consumer group

A consumer group divides a topic's partitions among its members. With 6 partitions and 3 members, each member owns 2 partitions and reads them in offset order. Add a member → partitions rebalance. **Ordering is preserved** within each partition because exactly one member owns it at a time. Parallelism is bounded by partition count: more consumers than partitions leaves the extras idle.

This is the crucial difference from competing consumers on a queue: parallelism **without** sacrificing per-key ordering, as long as related records share a partition key.

### Fan-out: independent groups

Every consumer group reads the full retained stream independently. A `search-indexer` group and an `audit-writer` group both read every `DataAsset.Scanned` record from their own offsets, neither aware of the other. Adding a new consumer next year means creating a new group and rewinding to offset 0 — the history is still there.

### Retry on a log

There is no per-message ack to withhold. Retry idioms:

- **Don't advance the offset** — keep reprocessing the same record until it succeeds (blocks the partition; use with care).
- **Retry topic** — publish the failed record to a separate `*.retry` topic consumed with a delay, and a terminal `*.dlq` topic after N attempts. This is the log-world equivalent of a dead-letter queue, built from topics rather than from broker retry primitives.

### Go publish shape (Redpanda), for grounding

```go
// A Domain Event appended to a partition, keyed by tenant+asset for ordering.
rec := &kgo.Record{
    Topic: "data-asset.scanned",
    Key:   []byte(tenantID + ":" + assetID), // same key → same partition → ordered
    Value: protoBytes,                        // protobuf3-encoded DataAssetScanned
}
client.Produce(ctx, rec, func(r *kgo.Record, err error) {
    if err != nil { /* producer retry */ }
    // on success: r.Offset is the record's position — retained, replayable
})
```

---

## Part 2 — The Queue Model (AMQP 0-9-1 / RabbitMQ)

### The core structure is producer → exchange → binding → queue

A producer **never** publishes to a queue directly. It publishes to an **exchange** with a **routing key**. The exchange, using its **bindings**, decides which queues (if any) receive a copy. A **queue** holds messages until a consumer acks them, at which point they are **removed**.

**Exchange types are the routing algebra** — choosing the type *is* choosing delivery semantics:

- **direct** — deliver to queues whose binding key exactly equals the routing key (point-to-point, work queues).
- **topic** — the routing key is a dotted path matched against binding patterns. `*` matches exactly one word; `#` matches zero or more words. Example: `scan.gdrive.completed` is delivered by a binding of `scan.#` and by `scan.*.completed`, but not by `scan.*` (that is one word after `scan`).
- **fanout** — ignore the routing key; copy to every bound queue (broadcast).
- **headers** — match on message header attributes instead of the routing key.

### Removed on ack — there is no offset, no replay

Once a consumer sends `basic.ack`, the message is deleted from the queue. There is **no retention window, no offset, no rewind, and no replay** for a late-arriving or newly-deployed consumer. A consumer that comes online tomorrow sees only messages published from that point on; it cannot read history because the broker did not keep it. This is the defining property that separates the queue model from the log.

### Consumer acknowledgements govern redelivery

- `autoAck=false` (manual ack): the message is held **unacknowledged** until the consumer sends `basic.ack`. If the consumer dies first, the broker **requeues** it → at-least-once.
- `basic.nack` / `basic.reject`: refuse a message. `requeue=true` puts it back on the queue; `requeue=false` discards it, or routes it to a dead-letter exchange if one is configured.
- `autoAck=true`: the message is considered delivered the instant it is pushed — a crash loses in-flight work → at-most-once.

### Parallelism: Competing Consumers destroys ordering by design

Multiple consumers subscribed to **one** queue each receive different messages — the broker load-balances across them. This is the **Competing Consumers** pattern. Ordering is **per-queue** and only guaranteed to a single consumer without requeues; the moment two consumers compete, message N and N+1 may be processed concurrently on different consumers, so **cross-message ordering is lost by design**. If you need ordering, you cannot scale a single queue with competing consumers.

**Prefetch / QoS is the fair-dispatch knob.** `basic.qos(prefetch_count=N)` caps how many unacked messages the broker pushes to one consumer channel before waiting for acks. `prefetch=1` gives fair dispatch — a slow consumer is not handed a backlog while a fast one starves. Raise it only when handler latency is low and uniform.

### Fan-out needs one queue per consumer

To deliver the same message to N independent consumers, bind **N queues** to a `fanout` exchange — each consumer owns its own queue and its own copy. There is no shared retained stream; each queue drains independently as its consumer acks.

### Retry/backoff is built from DLX + TTL topology

RabbitMQ has no offset to "leave and come back to," so delayed retry is **built** from topology:

- A queue configured with `x-dead-letter-exchange` republishes messages that are rejected with `requeue=false`, that expire via `x-message-ttl`, or that exceed `x-max-length`, to a designated **dead-letter exchange (DLX)**.
- Retry-with-backoff: the work queue dead-letters to a **retry queue** whose `x-message-ttl` is the backoff delay and whose own DLX points back at the work exchange. After the TTL, the message dead-letters back and is retried.
- After N cycles — tracked via the `x-death` header count the broker stamps on each dead-lettering — route the message to a terminal **parked** / DLQ queue instead of retrying forever.

### Producer accept signal: publisher confirms + mandatory flag

Plain `basic.publish` is fire-and-forget; the broker may drop it silently. **Publisher confirms** (`confirm.select`) make the broker return `basic.ack` once the message is safely enqueued → at-least-once producer guarantee. The **mandatory** flag additionally makes the broker return the message (`basic.return`) if it routed to **zero** queues — catching the silent-drop failure where a routing key matched no binding. Treat any `basic.return` as a hard configuration error surfaced in telemetry.

### Go publish shape (AMQP), for grounding

```go
// Publish to an exchange with a routing key; confirms + mandatory catch loss.
ch.Confirm(false)               // confirm.select — enable publisher confirms
err := ch.PublishWithContext(ctx,
    "reports.exchange",         // exchange (NOT a queue)
    "tenant.acme.report.generate", // routing key → topic binding decides the queue
    true,                       // mandatory: basic.return if zero queues match
    false,                      // immediate (deprecated; always false)
    amqp.Publishing{
        DeliveryMode: amqp.Persistent, // durable delivery (survives broker restart)
        Body:         jsonBytes,
    })
// then read the confirm (basic.ack) and any basic.return on the notify channels
```

Note there is **no outbox-offset equivalent**: durability comes from durable exchange + durable queue + persistent delivery mode, not from a retained log.

---

## Part 3 — Property-by-property comparison

| Property | Log (Redpanda) | Queue (RabbitMQ) |
|---|---|---|
| Unit of storage | Partition (append-only log) | Queue |
| Message lifetime | Retained until retention policy evicts | Removed on `basic.ack` |
| Replay / rewind | Yes — set offset backwards | No — history not kept |
| Position tracking | Consumer-group offset (consumer-owned) | Broker tracks unacked, not position |
| Ordering scope | Per-partition, total | Per-queue, single-consumer only |
| Adding a consumer later | New group rewinds to offset 0 | Sees only messages from now on |
| Parallelism | Consumer group over partitions (ordering kept) | Competing consumers on one queue (ordering lost) |
| Fan-out | Every group reads the retained stream | One queue per consumer on a `fanout` exchange |
| Addressing | Caller addresses topic-partition | Producer → exchange + routing key → binding → queue |
| Routing flexibility | Partition key only | direct / topic / fanout / headers exchanges |
| Retry primitive | Don't advance offset, or retry topic | DLX + TTL retry queue + `x-death` count |
| Producer accept | Broker ack of partition append | Publisher confirm; `basic.return` on zero-route |
| Back-pressure knob | Consumer poll rate / max.poll.records | `basic.qos` prefetch_count |
| At-most-once footgun | Commit offset before processing | `autoAck=true` |

---

## Part 4 — Worked selection for two repo workloads

### Workload A — DataAsset event stream → **log (Redpanda)**

`DataAsset.Scanned`, `Classification.Applied`, `SensitiveDataFound` are **Domain Events**: an immutable record of what happened in the data-estate domain. Consumers today: a search indexer, a compliance-audit writer, a graph loader (Apache AGE). Consumers tomorrow: unknown — a new report engine, a reindex after a schema change, a bug-fix reprocessing run.

Apply the replay question: **yes**, consumers must re-read history (reindex, audit, future consumers rewinding from offset 0). → **Redpanda**. Partition by `tenantID:assetID` so all events for one asset stay ordered; each consumer group reads independently; per-tenant physical isolation via per-tenant topic prefix or cluster. The protobuf3 event contract:

```proto
message DataAssetScanned {
  string tenant_id  = 1;
  string asset_id   = 2;
  string source     = 3; // "gdrive" | "s3"
  int64  scanned_at = 4; // unix millis
}
```

### Workload B — per-tenant report-generation dispatch → **queue (RabbitMQ)**

A tenant requests a PDF/DOCX/XLSX report. A worker pool generates it and uploads the result; once generated, the job is **done** — nobody replays "generate this report again" from history. Requirements: per-tenant routing, fair dispatch across a worker pool, retry-with-backoff on a transient generation failure, a parked queue for poison jobs.

Apply the replay question: **no** — a completed job is finished; there is no reindex-from-history use case. → **RabbitMQ**. A `topic` exchange routes `tenant.<id>.report.generate` to per-tenant queues (physical isolation via vhost or queue); competing consumers drain the pool with `prefetch=1` fair dispatch; a DLX + TTL retry queue handles backoff; `x-death` count caps retries before the parked queue. The job payload:

```json
{
  "tenant_id": "acme",
  "report_id": "r-8842",
  "format": "pdf",
  "asset_query": "classification = 'PII' AND source = 's3'"
}
```

### The lesson

Same platform, same team, **two different brokers** — because the two workloads answer the replay question differently. Forcing both onto one broker is the swappable-queue anti-pattern: Workload A on a queue loses reindex/audit; Workload B on a log pays for retention and partitioning it never uses and loses per-tenant routing flexibility.
