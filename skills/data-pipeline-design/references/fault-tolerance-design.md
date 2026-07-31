# Fault-Tolerance Design — Checkpoints, Replay, Idempotency, Exactly-Once, Backfill

Reference material for `data-pipeline-design`. Fault tolerance is a **design property** decided
here, not an implementation afterthought. The body carries the four design rules; this file
carries the full mechanism designs, the delivery-semantics choice, the dedup and outbox
contracts, the Dead Letter Queue design, and the backfill/reprocessing design.

Implementation of these designs is owned by `data-pipeline-implementation`; this file specifies
the contract that implementation builds to.

---

## 1. Delivery semantics — the design choice

Distributed pipelines cannot get exactly-once delivery for free. Choose the semantic per flow:

| Semantic | Guarantee | Cost | Use |
|---|---|---|---|
| At-most-once | May lose messages | Cheapest | Never — data loss is unacceptable here |
| **At-least-once** | Never loses; may duplicate | Moderate | **Default** — paired with idempotent consumers |
| Exactly-once | No loss, no duplicates | Expensive (transactions across broker + store) | Only where duplication is genuinely unsafe *and* idempotency cannot be achieved |

**Default: at-least-once delivery + idempotent consumers.** The broker guarantees no message is
lost; each consumer guarantees processing the same message twice has the same effect as once.
This is the standard, frugal, robust combination and it makes duplicates harmless without
paying broker-transaction cost.

---

## 2. Checkpoint boundary placement

A checkpoint is the point at which a stage durably records "I have fully processed up to here"
so that a crash resumes from the boundary rather than the start. **Placement rule:**

> Place a checkpoint boundary at each point where a stage atomically commits its derived state
> **and** records the offset/event-id it consumed, in the *same* transaction. Never advance the
> consumer offset before the derived state and its outbox row are committed.

Consequences of the rule:

- The checkpoint is the stage's state-commit, not a separate periodic flush. Offset advance and
  work commit are one atomic unit — either both happen or neither does, so a crash never leaves
  "offset moved but work not done" (silent loss) or "work done but offset not moved" that isn't
  covered by idempotency.
- Checkpoint granularity is per-event (or per-micro-batch); the coarser the batch, the more work
  a crash replays. Size the micro-batch so replay-on-crash is bounded and acceptable.
- A stage with an external non-transactional side effect (calling a third-party API) cannot put
  that effect inside the transaction — that is exactly the case where exactly-once matters
  (§4).

---

## 3. Idempotency at design level — which stages, and why

Because delivery is at-least-once, **every stage that mutates durable state must be idempotent**.
Redelivery is a certainty under at-least-once (the first consumer-group rebalance under load
guarantees it), not an edge case. Decide, at design time, the idempotency mechanism for each
stage:

| Stage class | Naturally idempotent? | Mechanism to specify |
|---|---|---|
| Pure derive → upsert by key (e.g. classification level) | Nearly — an upsert by a stable key is replay-safe | Upsert keyed by `data_asset_id`; last-writer by version |
| Append derived rows (e.g. extracted entities) | No — replay double-inserts | Dedup on consumed `eventId` before insert |
| Graph mutation (Apache AGE edges) | No — replay double-adds edges | `MERGE`-style upsert keyed by (src, rel, dst) |
| External side effect (notify, call API) | No, and not transactional | Idempotency key on the request; see §4 |

**Dedup contract** (append-style stages) — the design each such stage's implementation builds to:

```sql
CREATE TABLE processed_events (
    consumer_name  TEXT NOT NULL,
    event_id       UUID NOT NULL,
    processed_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (consumer_name, event_id)
);
```

```
on receive(event):
    begin transaction
        INSERT INTO processed_events (consumer_name, event_id) VALUES ($me, event.eventId)
            ON CONFLICT DO NOTHING       -- 0 rows → already processed → skip
        if inserted:
            do the work
            write any output (and its outbox row) in the SAME transaction
    commit
```

The dedup record and the work commit atomically — this *is* the checkpoint of §2.

**`processed_events` has a designed lifecycle, not an append-forever table.** Unpruned it grows
without bound and its primary-key index degrades every insert. Prune rows older than the
**redelivery horizon** = topic retention + longest tolerated consumer outage + margin. Prune
*earlier* than that horizon and a late redelivery slips past the dedup check, reintroducing the
double-processing the table exists to prevent. The pruning window is a designed number in the
stage contract.

---

## 4. Exactly-once as a design goal and its cost

Exactly-once end-to-end across a broker and an external store requires a distributed transaction
or a transactional-outbox equivalent, and it is expensive. **Reserve it for effects that are
externally visible and not naturally idempotent** — sending a notification, charging money,
calling a third-party API that itself is not idempotent. For everything internal, at-least-once
+ idempotent consumers already makes duplicates harmless, so exactly-once buys nothing but cost.

Where a genuinely non-idempotent external effect exists, the frugal design is **not** broker
transactions across every stage but an **idempotency key on the external call**: pass a stable
key (the consumed `eventId`) to the external system so *it* deduplicates, turning an
at-least-once delivery into an effectively-once effect at the boundary. This localises the cost
to the one stage that needs it.

### The Transactional Outbox at stage boundaries

A stage must not "do its work, then publish the next event" as two separate operations — a crash
between them loses the event, or (publish-first) announces work that rolled back. Each stage
writes its output event to an **outbox table in the same transaction** as its state change; a
separate relay publishes outbox rows to the next topic.

```
[Entity Extraction transaction]
    INSERT extracted_entities (...)            -- state change
    INSERT outbox (event=EntityExtracted, ...) -- next event, same transaction
    COMMIT
                    │
        [Outbox relay] ──reads committed outbox rows──► publishes to (Topic: entity-extracted)
```

This guarantees the pipeline never loses an event between stages and never publishes an event for
work that rolled back. Pattern detail: architecture `event-driven-patterns`; the outbox table
schema: `domain-event-catalog`.

---

## 5. Dead Letter Queue design

A message that cannot be processed after a bounded number of retries is routed to a **Dead Letter
Queue (DLQ)** — it must never block the pipeline or be silently dropped.

| Concern | Design |
|---|---|
| Retry policy | Retry with exponential backoff + jitter; cap attempts (e.g. 5) |
| What goes to DLQ | Messages that exhaust retries, or fail a poison-message check (malformed, un-decodable) |
| DLQ topic | One DLQ topic per stage: `<stage>-dlq`, carrying the original message + failure metadata |
| Tenant isolation | DLQ messages retain `tenant_id`; DLQ inspection is tenant-scoped |
| Disposition | Operator runbook: inspect, fix root cause, replay from DLQ or discard with audit record |

A DLQ with no monitoring is silent data loss with extra steps — dead-lettered messages are
unprocessed customer data. DLQ depth is an alerting metric (see `alerting-rules-design`).

---

## 6. Replay and reprocessing design

The Redpanda topic *is* a replayable history: a consumer group can reset its offset to the start
and reconsume the full topic. This is the mechanism for two scenarios the design must anticipate:

- **A stage's logic changed** (a corrected extraction rule, a new classification threshold).
- **A stage was added after go-live** (a new derived Read Model that needs history).

Because every stage is already checkpointed and idempotent, **reprocessing needs no new code
path**: reset the consumer group's offset and let the existing worker consume from the start.
Idempotency makes the replay safe (re-derived rows upsert rather than duplicate); the checkpoint
makes it resumable if the replay itself is interrupted.

### The per-topic retention decision (design-time, easy to miss)

Replay only works if the history still exists. Each stage's topic contract must choose between
two Redpanda retention policies, and this is a **deliberate design decision**, not a default:

| Policy | Keeps | Choose when |
|---|---|---|
| **Time-based retention** | Full history for a window (e.g. 30 days) | Downstream may need to reprocess/backfill from history |
| **Log compaction** | Only the latest record per key | Downstream needs current state per key, not history |

A stage silently left log-compacted has **no history to replay against** — the backfill gap is
cheap to close now (state the retention policy per topic) and expensive to discover later.

### Backfill design

A backfill is a bounded reprocessing run against a specific time range or key set. Design it as:

1. Provision a *new, separate* consumer group for the backfill so it does not disturb the live
   group's offsets or SLAs.
2. Bound the range (offsets or timestamps) and rate-limit the backfill producer so it does not
   starve live traffic (same backpressure regime as the bulk scan — see
   `references/orchestration-and-observability.md`).
3. Rely on idempotency: the backfill upserts derived state; live and backfill writes to the same
   key converge because every mutating stage is idempotent by §3.

### The erasure caveat (forward-looking)

Not all derived data can be surgically erased. If this product ever trains a model or bakes an
aggregate on extracted/classified data, deleting a source record does *not* remove its influence
from that derived artifact — only recomputation does, and for some artifacts that is expensive or
imprecise. Erasure requests against such an artifact must not be assumed as cheap as a `DELETE` or
a crypto-shred (see `data-retention-policy`). No such artifact exists today; record the caveat so
it is not missed the day one appears.
