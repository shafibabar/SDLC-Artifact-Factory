# The Idempotent-Consumer Standard — Dedup Schema, Exact Insert, and Placement

Full worked material referenced from `SKILL.md`'s "The Idempotent-Consumer Pattern"
section. Self-contained — reads without the parent body already in context. Covers:
the exact `processed_events` table schema, why `consumer_name` is part of the key and
not just `event_id`, the exact dedup `INSERT` and precisely where it runs relative to
business logic, and the retention concern the table introduces.

---

## 1. Why the Consumer Must Be Idempotent at All

Redpanda/Kafka delivery is at-least-once: a rebalance mid-batch (`references/rebalance-handling.md`),
a crash between processing and offset commit (`references/offset-commit-standard.md`),
or the publisher's own at-least-once guarantee (`go-event-publisher`'s outbox relay —
see `references/transactional-outbox-standard.md` in that skill, §5) can each cause the
same record to be delivered to `handleRecord` more than once. **Idempotency** means
processing it twice has the same effect as processing it once — the property this
standard exists to guarantee mechanically, not by convention.

---

## 2. The `processed_events` Table Schema

```sql
-- 00019_create_processed_events.sql
-- +goose Up
CREATE TABLE processed_events (
    consumer_name text        NOT NULL,   -- this consumer's stage name, e.g. "classification-projector"
    event_id      uuid        NOT NULL,   -- the envelope's EventID (go-event-publisher's outbox row id)
    processed_at  timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (consumer_name, event_id)
);

-- +goose Down
DROP TABLE processed_events;
```

**Why `consumer_name` is part of the key, not just `event_id`.** In a choreographed
pipeline (`data-pipeline-design`), the same Domain Event is routed to more than one
independent consumer stage — each stage decides for itself whether it has already
handled a given event. A key on `event_id` alone would make one stage's dedup
insert collide with a completely unrelated stage's dedup insert for the same event,
producing a false "already processed" skip in whichever stage loses the race. Scoping
the key to `(consumer_name, event_id)` gives every stage its own independent dedup
ledger against the same event stream, which is what "one stage's failure or replay
must not affect another stage's processing" actually requires.

**Where `event_id` comes from.** The value inserted here is read directly off the
decoded envelope's `EventID` field, which is itself the outbox row's own primary-key
`id`, unchanged across every re-publication of that row (`go-event-publisher`'s
Idempotency-Key Construction Rule, `references/batching-backpressure-and-idempotency.md`
§4 in that skill). This consumer never constructs or derives an event identity — it
only reads the one the publisher already committed to.

---

## 3. The Exact Insert, and Exactly Where It Runs

```go
ct, err := tx.Exec(ctx,
    `INSERT INTO processed_events (consumer_name, event_id) VALUES ($1,$2)
     ON CONFLICT DO NOTHING`, c.name, env.EventID)
if err != nil {
    return err
}
if ct.RowsAffected() == 0 {
    return tx.Commit(ctx) // duplicate — nothing to do
}
// business logic runs here, using the same tx
```

**Placement, stated as a rule:** the dedup `INSERT` is the *first* statement inside
`handleRecord`'s transaction — before any business-logic read or write runs — and it
shares that same `pgx.Tx` with the business logic that follows it. `RowsAffected() ==
0` means a row with this exact `(consumer_name, event_id)` pair already exists, which
can only happen if this consumer already committed the business-logic effect for this
event in an earlier delivery; the correct response is to commit the (otherwise empty)
transaction and return, doing no further work.

**Bare `ON CONFLICT DO NOTHING`, not `ON CONFLICT (consumer_name, event_id) DO
NOTHING`, and why that is still correct.** Postgres's bare form applies to a conflict
on *any* unique or exclusion constraint on the table; here the table has exactly one —
the composite primary key — so the bare form and the explicit-target form are
behaviorally identical. This skill keeps the bare form specifically because
`go-event-publisher`'s `references/batching-backpressure-and-idempotency.md` §4
already quotes this exact statement verbatim when describing the consumer side of the
idempotency-key contract; keeping the same literal SQL text in both places means the
two skills describe one contract with one sentence, not two independently-worded
approximations of it that could drift.

**Same transaction, not two.** The dedup insert and the business-logic write commit
or roll back together. If the process crashes after the dedup insert commits but
before the business logic finishes, that is impossible by construction — they are one
transaction, so a crash mid-way rolls back the dedup row along with everything else,
and the next delivery of the same event finds no dedup row and processes normally.
Splitting these into two transactions (dedup committed first, business logic second)
reopens exactly the dual-write race the Transactional Outbox exists to close on the
publish side — this standard is the same atomicity discipline applied on the
consume side.

---

## 4. Retention: `processed_events` Grows Without Bound Otherwise

Every successfully processed event leaves one permanent row. Unlike `go-event-publisher`'s
`outbox` table (where a `published_at` retention job sweeps old *published* rows —
`references/transactional-outbox-standard.md` in that skill, §7), `processed_events`
has no natural "this row is now safe to delete" signal from the schema alone — deleting
a row re-opens the exact window it exists to close, for however long redelivery of that
specific event remains possible.

**The retention rule:** a row is safe to delete once it is older than the maximum
plausible redelivery window for this consumer group — in practice, a small multiple of
the broker's message retention period for the source topic (redelivery of a message the
broker itself has already expired cannot happen) or, if shorter, a defensible upper
bound on how long a stuck consumer instance could plausibly be down and later resume
from an old committed offset. A scheduled cleanup job
(`DELETE FROM processed_events WHERE processed_at < now() - interval '30 days'`, tuned
to the product's actual topic retention) keeps the table's size proportional to recent
throughput rather than the service's entire lifetime — a Data Lifecycle Management
concern distinct from, and independent of, the correctness guarantee this table
provides while a row still exists.
