# The Transactional Outbox Standard — Schema, Atomic Insert, Relay Loop, and the At-Least-Once Guarantee

Full worked material referenced from `SKILL.md`'s Purpose, "The Relay Loop," and
"Draining a Batch" sections. Self-contained — reads without the parent body already
in context. Covers: the exact `outbox` table schema, the exact SQL that inserts an
outbox row in the same transaction as the aggregate's state change, the exact
relay/poller loop that drains it, why this design produces at-least-once (never
exactly-once) delivery, and why a polling relay is used instead of Change Data
Capture (CDC) in this repo.

---

## 1. The Problem the Outbox Solves: the Dual-Write

A service that changes state and then separately calls the broker has two writes
that cannot be made atomic by ordinary means:

```go
// UNSAFE — do not do this
if err := repo.Save(ctx, asset); err != nil {
    return err
}
producer.ProduceSync(ctx, record) // crash here: DB committed, broker never got the event
```

If the process crashes between the two calls, the database commit already happened
and cannot be undone, but the event was never published — the event is **silently
lost**, with nothing in the system recording that it should have been sent. Wrapping
both calls in a distributed (two-phase) transaction is the classic textbook fix, but
Kafka/Redpanda brokers do not participate in the XA/2PC protocol at all — there is no
prepare/commit handshake to join. The Transactional Outbox sidesteps the problem
entirely by making the *only* atomic operation a **local** one: a second row written
into the same PostgreSQL transaction as the aggregate's own write. Publishing to the
broker is deferred to a separate step that can retry indefinitely without threatening
the correctness of the first, already-committed step.

---

## 2. The Outbox Table Schema

```sql
-- 00012_create_outbox.sql
-- +goose Up
CREATE TABLE outbox (
    id            uuid PRIMARY KEY,
    aggregate_id  uuid NOT NULL,
    tenant_id     uuid NOT NULL,          -- mandatory tenant scoping (multi-tenancy-design)
    event_type    text NOT NULL,          -- past-tense Domain Event name (go-domain-model)
    payload       jsonb NOT NULL,         -- already-marshalled envelope-body JSON
    occurred_at   timestamptz NOT NULL,   -- business time — when the Aggregate recorded the event
    published_at  timestamptz             -- NULL = unpublished; set once, by the relay, on success
);

-- Matches the relay's claim query exactly: WHERE published_at IS NULL ORDER BY
-- occurred_at. A partial index (go-migration's expand/contract convention) keeps the
-- claim query cheap regardless of how many published rows have accumulated.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_outbox_unpublished
    ON outbox (occurred_at)
    WHERE published_at IS NULL;

-- +goose Down
DROP INDEX CONCURRENTLY IF EXISTS idx_outbox_unpublished;
DROP TABLE outbox;
```

Every column exists for a reason a repository method or the relay actually reads:

| Column | Written by | Read by | Why it exists |
|---|---|---|---|
| `id` | repository `Save` (`uuid.New()`) | relay's `toRecord` — becomes the envelope `EventID` | The row's own identity doubles as the idempotency key (`references/batching-backpressure-and-idempotency.md`) |
| `aggregate_id` | repository `Save` | relay — copied into the envelope | Lets a consumer or operator trace an event back to the Aggregate instance that raised it |
| `tenant_id` | repository `Save` | relay — becomes the record's partition key | Physical/logical tenant isolation carried through to the broker (`multi-tenancy-design`) |
| `event_type` | repository `Save` | relay — selects the destination topic | One outbox table serves every event type; the relay routes by this column |
| `payload` | repository `Save` (already-marshalled) | relay — copied into the envelope body | The repository, not the relay, knows the event's shape; the relay never deserializes it |
| `occurred_at` | repository `Save` | relay's `ORDER BY` | Preserves emission order within a batch; business time, not publish time |
| `published_at` | relay's `UPDATE`, initially `NULL` | relay's claim `WHERE` | The only mutable column — the sole state transition this table records is "sent" |

`published_at` is deliberately the *only* column the relay ever writes to. Everything
else is written once, by the repository, inside the aggregate's own transaction, and
never touched again — the outbox row is an immutable fact ("this event occurred")
with one append-only status bit layered on top.

---

## 3. The Atomic Insert — Same Transaction as the Aggregate's Own Write

This is `go-repository-pattern`'s `Save` method, restated here because the
Transactional Outbox's entire correctness claim rests on this one property: the
`UPDATE`/`INSERT` on the aggregate's own table and the `INSERT` into `outbox` share
one `pgx.Tx`, opened and committed by the application-layer command handler, never by
the repository itself (`go-repository-pattern`'s Transaction-Boundary Standard).

```go
func (r *DataAssetRepo) Save(ctx context.Context, a *domain.DataAsset) error {
    ct, err := r.q.Exec(ctx, `
        UPDATE data_assets
           SET sensitivity_level = $1, classified_by = $2, classified_at = $3,
               version = version + 1, updated_at = now()
         WHERE id = $4 AND tenant_id = $5 AND version = $6`,
        string(a.Sensitivity()), a.ClassifiedBy(), a.ClassifiedAt(),
        a.ID(), a.TenantID(), a.Version(),
    )
    if err != nil {
        return translatePgError(fmt.Errorf("updating data asset %s: %w", a.ID(), err), nil)
    }
    if ct.RowsAffected() == 0 {
        return fmt.Errorf("data asset %s: %w", a.ID(), domain.ErrConcurrentModification)
    }
    for _, e := range a.PullEvents() {
        payload, mErr := json.Marshal(e)
        if mErr != nil {
            return fmt.Errorf("marshalling %s: %w", e.EventType(), mErr)
        }
        if _, err = r.q.Exec(ctx, `
            INSERT INTO outbox (id, aggregate_id, tenant_id, event_type, payload, occurred_at)
            VALUES ($1,$2,$3,$4,$5, now())`,
            uuid.New(), a.ID(), a.TenantID(), e.EventType(), payload,
        ); err != nil {
            return translatePgError(fmt.Errorf("writing outbox %s: %w", e.EventType(), err), nil)
        }
    }
    return nil
}
```

Both statements run against `r.q` — whichever `Querier` (`*pgxpool.Pool` or `pgx.Tx`)
this repository value was constructed or `WithTx`-rebound with. Neither statement
opens or commits anything; the caller's `defer tx.Rollback(ctx)` / `tx.Commit(ctx)`
governs both. If the `UPDATE` succeeds but an `outbox INSERT` fails (a marshal error,
a constraint violation), the whole transaction rolls back — the aggregate's state
change and its event are atomic *together*, or neither happens. There is no
intermediate state where the asset is reclassified but no event was recorded, and
none where an event exists for a state change that was rolled back.

---

## 4. The Relay/Poller Loop, in Full

The relay is a **polling** design, not CDC (Change Data Capture): a supervised
goroutine wakes on a fixed interval, claims a bounded batch of unpublished rows with
`FOR UPDATE SKIP LOCKED`, publishes them, and marks them published — all inside one
`pgx.Tx` per drain.

```go
func (r *OutboxRelay) Run(ctx context.Context) error {
    ticker := time.NewTicker(r.interval)
    defer ticker.Stop()
    for {
        select {
        case <-ctx.Done():
            return nil
        case <-ticker.C:
            if err := r.drainOnce(ctx); err != nil {
                slog.ErrorContext(ctx, "outbox drain failed", "err", err)
            }
        }
    }
}

func (r *OutboxRelay) drainOnce(ctx context.Context) error {
    tx, err := r.pool.Begin(ctx)
    if err != nil {
        return fmt.Errorf("begin: %w", err)
    }
    defer tx.Rollback(ctx) //nolint:errcheck // no-op after commit

    rows, err := tx.Query(ctx, `
        SELECT id, aggregate_id, tenant_id, event_type, payload, occurred_at
          FROM outbox
         WHERE published_at IS NULL
         ORDER BY occurred_at
         LIMIT $1
         FOR UPDATE SKIP LOCKED`, r.batch)
    if err != nil {
        return fmt.Errorf("select outbox: %w", err)
    }

    records := make([]*kgo.Record, 0, r.batch) // preallocated — see the batching standard
    ids := make([]uuid.UUID, 0, r.batch)
    for rows.Next() {
        var m outboxRow
        if err := rows.Scan(&m.id, &m.aggregateID, &m.tenantID, &m.eventType, &m.payload, &m.occurredAt); err != nil {
            rows.Close()
            return fmt.Errorf("scan: %w", err)
        }
        records = append(records, r.toRecord(ctx, m))
        ids = append(ids, m.id)
    }
    rows.Close()
    if len(records) == 0 {
        return nil
    }

    if err := r.producer.ProduceSync(ctx, records...).FirstErr(); err != nil {
        return fmt.Errorf("produce: %w", err) // batch retries next tick; nothing marked
    }

    if _, err := tx.Exec(ctx,
        `UPDATE outbox SET published_at = now() WHERE id = ANY($1)`, ids); err != nil {
        return fmt.Errorf("mark published: %w", err)
    }
    return tx.Commit(ctx)
}
```

**Why `FOR UPDATE SKIP LOCKED`, precisely:** without it, a second relay replica's
`SELECT` would either block on the first replica's row locks (serializing every
replica behind the slowest one) or, without any locking clause at all, would read and
publish the *same* rows a concurrent replica just claimed — a duplicate publish, not
a crash-recovery duplicate but an ordinary-operation one. `SKIP LOCKED` makes each
replica's claim non-blocking and disjoint: rows already locked by another in-flight
`drainOnce` are silently skipped, not waited on or double-read.

**Why the claim, the produce, and the mark share one transaction:** the claim
(`SELECT ... FOR UPDATE`) and the mark (`UPDATE ... published_at`) must be atomic with
each other for `SKIP LOCKED` to mean anything — if they were separate transactions, a
crash between them would leave a row locked by nothing, claimed by no one, and
re-claimable by the next replica while this one still believes it owns it. The
`ProduceSync` call sits *between* the claim and the mark, inside the transaction's
open window but not itself part of what the transaction protects — see §5 for why
that ordering, not full atomicity across all three, is exactly the design.

---

## 5. Why At-Least-Once, and Why Exactly-Once Is Not Attempted

**The guarantee this design produces is at-least-once delivery: every outbox row is
published one or more times, never zero.** The proof is the ordering inside
`drainOnce`: `ProduceSync` is checked and must succeed *before* the `UPDATE ...
published_at` statement runs. Walk every point the process can crash:

| Crash point | State left behind | Consequence |
|---|---|---|
| Before `ProduceSync` returns | Row still `published_at IS NULL`, transaction never committed | Rolled back on restart; row is unclaimed and reclaimed next tick — never published, correctly, since it never was |
| After `ProduceSync` succeeds, before `tx.Commit` | Broker has the message; the transaction (including the `UPDATE`) rolls back | Row is re-claimed and re-published next tick — a **duplicate** delivery, not a lost one |
| After `tx.Commit` | Row is durably `published_at` non-null | No further action; this row is done |

The second row is the entire reason this is at-least-once and not exactly-once:
there is no way to make "the broker received the message" and "the local transaction
committed" a single atomic unit of work, because they are two different systems with
no shared coordinator (§1). **Exactly-once delivery across a database and a message
broker is not attempted because it requires distributed consensus infrastructure
(XA/2PC across heterogeneous systems, or a broker-native transactional-produce
protocol coupled to the same store as the outbox) that this pattern's entire value
proposition is designed to avoid.** The tradeoff this design deliberately makes
instead: accept an occasional duplicate delivery at the broker, and push the
responsibility for making a duplicate harmless onto the consumer side, where it is
cheap and mechanical to do correctly — a dedup `INSERT ... ON CONFLICT DO NOTHING`
inside the consumer's own processing transaction (`go-event-consumer`'s
idempotent-consumer pattern), rather than expensive and fragile to do at the
publisher/broker boundary. **Idempotency is the correct place to pay for this
tradeoff, not a workaround for a design that fell short of exactly-once.**

---

## 6. Why a Polling Relay, Not Change Data Capture (CDC)

Change Data Capture — streaming row-level changes out of PostgreSQL's write-ahead log
via a tool such as Debezium, rather than polling — is a legitimate alternative
implementation of the same Transactional Outbox *pattern*: the outbox table's shape
(§2) and the atomicity guarantee (§3) are identical either way; only the *mechanism*
that notices an unpublished row and forwards it differs. This repo uses the polling
relay in this skill, not CDC, for a reason grounded in the plugin's own frugality
constraint (`CLAUDE.md`'s Budget and Frugality section: prefer simpler solutions when
outcomes are equivalent; every added dependency must justify its presence): CDC
requires operating a second piece of infrastructure (a Debezium connector plus Kafka
Connect, or an equivalent WAL-streaming component) with its own deployment, upgrade,
and failure-mode surface, to solve a problem a single Go goroutine polling on a
ticker already solves completely, at the batch sizes and latencies this pattern
targets (§ batching standard, `references/batching-backpressure-and-idempotency.md`).
CDC's real advantage — lower publish latency, since it reacts to the WAL instead of
waiting for the next poll tick — is not a requirement anywhere in this plugin's
product context. If a future product requirement narrows the acceptable
outbox-to-broker latency below what a short poll interval can deliver, that is a
deliberate, documented decision to revisit (an ADR, not a silent swap), not a defect
in the polling relay as built.

---

## 7. Ordering Guarantees and Their Limits

Ordering is preserved **per batch** by `ORDER BY occurred_at`, and **per aggregate**
as a consequence (nothing reorders rows produced by the same aggregate call).
Ordering is **not** guaranteed **across replicas**: running more than one relay
replica trades strict cross-batch ordering for throughput, since two replicas can
claim and publish adjacent batches for the same tenant concurrently, in whichever
order each happens to finish. If a specific event stream's consumers require strict
total order and cannot tolerate this, run exactly one relay replica for that
deployment — the design supports either, and the choice is an operational one, not a
code change.
