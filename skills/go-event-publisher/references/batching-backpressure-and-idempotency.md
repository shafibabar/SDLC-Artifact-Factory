# Batching, Backpressure, and Idempotency-Key Standards

Full worked material referenced from `SKILL.md`'s "Draining a Batch," "Backpressure,"
and "The Envelope, Partition Key, and Idempotency Key" sections. Self-contained —
reads without the parent body already in context. Covers: the memory-bounded batching
standard the `drainOnce` preallocation fix generalizes, the batch-size/batch-timeout
latency tradeoff, what actually happens to the outbox under a sustained broker
outage and how to observe it, and the deterministic idempotency-key construction
rule a downstream consumer's dedup depends on.

---

## 1. The Memory-Bounded Batching Standard

**Any slice or map whose maximum size is knowable before the loop that fills it
starts must be preallocated to that bound — never declared as a bare `var` and grown
by `append`/index-assignment alone.** This is `go-performance-optimization`'s
Preallocate Slices and Maps rule, and the relay's `drainOnce` is its canonical
instance in this skill:

```go
// The claim query already bounds rows.Next() to at most r.batch iterations —
// LIMIT $1 is the same r.batch passed here. The bound is known before the loop.
records := make([]*kgo.Record, 0, r.batch)
ids := make([]uuid.UUID, 0, r.batch)
```

versus the anti-pattern this fix replaced:

```go
// BEFORE — the bug this skill's prior pass fixed. Correct output, wrong cost.
var records []*kgo.Record
var ids []uuid.UUID
for rows.Next() {
    // ... same scan logic ...
    records = append(records, r.toRecord(ctx, m)) // growth-and-copy: 0→1→2→4→8...
    ids = append(ids, m.id)
}
```

**Why this is a real cost, not a style nit.** Go's `append` grows a nil/undersized
slice by successive reallocation-and-copy (roughly doubling below a threshold, ~1.25×
above it) every time capacity is exceeded. For a batch of `r.batch = 500`, the
unbounded version performs on the order of `log2(500) ≈ 9` reallocations per drain,
each copying the entire slice built so far — call this at the relay's tick interval,
continuously, for the life of the process, and it is a steady, avoidable source of
both CPU (copying) and garbage-collector pressure (every intermediate array becomes
garbage the instant the next one replaces it). The fix costs nothing: the exact
capacity is already sitting in `r.batch`, the same value already passed as the
query's `LIMIT $1` — using it a second time as `make`'s capacity argument is free
information, not a new computation.

**The generalization this fix is one instance of:** any time a loop's iteration count
is bounded by a value already in scope — a `LIMIT`, a fixed worker count, a
known-length input slice being mapped 1:1 — preallocate to that bound. The rule does
*not* apply when the final size is genuinely unknown ahead of time (e.g., filtering
an unbounded stream down to matches); forcing a guessed capacity in that case can
either waste memory (guessed too high) or provide no benefit at all (guessed too low,
still triggers growth). The relay's batch loop is squarely the first case: the `LIMIT`
*is* the bound, not an estimate of one.

---

## 2. The Batch-Size / Batch-Timeout Tradeoff

Two configuration values govern the relay, and they trade off against each other in
opposite directions:

| Parameter | Field | Increasing it | Decreasing it |
|---|---|---|---|
| Batch size | `r.batch` (the `LIMIT`) | Fewer round trips to Postgres and the broker per event; higher peak memory per drain (bounded, per §1, but the bound itself is larger); a single slow/failing produce call blocks a larger set of events from being marked published | Lower peak memory per drain; more round trips per unit of events published; a failing produce call blocks fewer events |
| Poll interval | `r.interval` (the ticker period) | Fewer wakeups, lower steady-state Postgres query load from the relay itself; higher worst-case publish latency (an event can wait up to a full interval before the next drain even looks at it) | Lower worst-case publish latency; more frequent polling load on Postgres, most of it querying zero unpublished rows during quiet periods |

**There is no universally correct pair of values — the right choice is a function of
the product's actual latency tolerance for "state changed" → "event visible to a
consumer," weighed against how much idle-poll load on Postgres is acceptable.** A
starting point that is defensible without product-specific tuning: `r.batch = 500`,
`r.interval = 1 * time.Second` — small enough that peak memory per drain (§1) stays
in the low tens of megabytes even for large payloads, frequent enough that
under normal (non-outage) operation the outbox rarely holds more than one interval's
worth of backlog. Tune from there against two observed signals, not intuition:

- **Outbox backlog depth** — `SELECT count(*) FROM outbox WHERE published_at IS NULL`
  (or, cheaper at scale, an index-only scan against the partial index from
  `references/transactional-outbox-standard.md`'s §2), exported as a gauge. A backlog
  that stays near zero between ticks means the current `(batch, interval)` pair
  comfortably keeps up; a backlog that climbs steadily under steady-state load (not
  during a broker outage — see §3) means `batch` is too small, `interval` is too
  long, or the broker itself is the bottleneck.
- **`drainOnce` duration** — if a single drain routinely takes longer than
  `r.interval` to complete, ticks start queuing behind each other (Go's
  `time.Ticker` does not itself block, but the `select` loop only re-enters the
  `ticker.C` case after the current `drainOnce` returns) and the effective poll
  interval is silently larger than configured. This is a signal to lower `r.batch`,
  not to shorten `r.interval` further — shortening the interval on a relay that is
  already running behind does nothing but pile up more missed ticks.

---

## 3. Backpressure in Depth: What the Outbox Absorbs, and Its One Limit

`SKILL.md`'s Backpressure section states the mechanism: a failed `ProduceSync`
returns an error, nothing is marked published, and the unpublished rows simply wait
for the next successful drain — no in-memory buffer to overflow, no caller blocked.
This section covers the one thing that mechanism does *not* make free: **the outbox
table itself grows for the duration of a sustained broker outage**, and unbounded
growth of *any* table is not actually free, even though no single write to it is ever
rejected.

**What grows, and how fast:** every successful aggregate write still inserts its
outbox row(s) — the outbox insert is part of the aggregate's own transaction (§3 of
the outbox standard reference), completely independent of whether the relay can reach
the broker. During a broker outage, the write path is unaffected; only the *drain*
side stalls. The backlog therefore grows at exactly the rate of state-changing writes
to the service, for as long as the outage lasts.

**What this costs, mechanically, if the outage is long enough to matter:**

- **Index and table bloat** on `outbox` and its partial index (`idx_outbox_unpublished`
  from the outbox standard reference) — more rows to scan even with the index, and
  more MVCC dead-tuple accumulation once the backlog is eventually drained and those
  rows' `published_at` is updated (an `UPDATE`, not an `INSERT`, so it leaves a dead
  tuple behind for autovacuum).
- **Longer individual drains once the broker recovers** — the first several ticks
  after recovery each claim a full `r.batch`-sized backlog slice, at whatever
  `drainOnce` costs per batch (§2); a long enough outage means many ticks' worth of
  catch-up before the backlog returns to near-zero, not instant recovery on the next
  tick.

**Neither of these is a correctness problem — at-least-once delivery holds
throughout, and no data is lost or corrupted.** They are capacity-planning and
observability concerns: the backlog-depth gauge from §2 is the signal that
distinguishes "the relay is comfortably keeping up" from "a broker outage is
building backlog" from "the relay itself is undersized for steady-state load" —
the same metric, read against different baselines. A retention/archival job for
already-published rows (referenced in `SKILL.md`'s Anti-Patterns as the correct
alternative to deleting rows outright) keeps the *published* side of the table from
growing without bound over the service's lifetime; it is a separate, lower-urgency
concern from the *unpublished* backlog an outage produces, and does not touch rows
this relay still needs to claim.

---

## 4. The Idempotency-Key Construction Rule

**Construction rule, stated precisely: a published record's idempotency key —
carried as the envelope's `EventID` field — is always, and only, the outbox row's own
primary-key `id` column, copied unchanged (`EventID: m.id` in `toRecord`).** No
hashing, no derivation from the payload, no combination of fields: the outbox row
already has a stable, unique, database-generated identity (`uuid.New()`, assigned once
by the repository's `Save`, §3 of the outbox standard reference), and reusing that
identity as the message-level dedup key is what makes the two ends of the pipeline —
the row that might be re-published and the message a consumer might see twice — the
same identity, without any additional bookkeeping.

**Why this is the only correct choice, walked against the two plausible
alternatives:**

| Candidate key | What breaks |
|---|---|
| A fresh `uuid.New()` generated inside `toRecord` at publish time | Every re-publication of the same outbox row (§5 of the outbox standard reference: the crash-after-produce-before-commit case) mints a *different* `EventID`. The consumer's dedup insert (`INSERT INTO processed_events (consumer_name, event_id) VALUES ($1,$2) ON CONFLICT DO NOTHING`, `go-event-consumer`) sees no conflict — it looks like a brand-new event, and the duplicate is processed twice. This silently defeats Idempotency and is the single most damaging mistake this standard exists to prevent. |
| A hash of the payload (e.g., `sha256(payload)`) | Two *genuinely distinct* events with identical payload content (a real, if rare, case — e.g., two consecutive `DataAssetClassified` events that happen to set the same sensitivity level twice, once by a human, once by an automated reclassification job) collide and one is wrongly treated as a duplicate of the other by the consumer's dedup logic. A content hash conflates "same content" with "same occurrence," which is exactly the distinction Idempotency's dedup key must preserve. |

The outbox row `id` has neither failure mode: it is assigned once, at row-insert time,
before any publish is attempted, and it never changes across however many times that
same row is re-claimed and re-published by `drainOnce`. Two distinct events — even
with identical payloads — get two distinct outbox rows and therefore two distinct
`id`s, because `Save` calls `uuid.New()` once per drained `DomainEvent`, not once per
distinct payload shape.

**The consumer side of this contract** (owned in full by `go-event-consumer`, cited
here only so this standard is checkable end-to-end): the dedup table's key is
`event_id`, populated directly from the envelope's `EventID` field this skill writes.
If a future change ever renamed or reshaped the envelope's identity field, both this
skill's `toRecord` and `go-event-consumer`'s dedup insert would need to change
together — they are two ends of one contract, not two independently-evolvable pieces.

**Partition key, for completeness (not itself an idempotency mechanism):**
`Key: m.tenantID[:]` in `toRecord` is a *routing* decision — which partition a
record lands on, for per-tenant ordering and Competing-Consumers parallelism
(`data-pipeline-design`) — and must never be conflated with the idempotency key. A
partition key groups related records together on the broker; the idempotency key is
what a consumer checks to decide whether it has already done the work a record
describes. Using the same value for both (e.g., partitioning by `EventID`) would
scatter every event randomly across partitions, since no two `EventID`s are ever
equal, destroying the per-tenant ordering the partition key exists to provide.
