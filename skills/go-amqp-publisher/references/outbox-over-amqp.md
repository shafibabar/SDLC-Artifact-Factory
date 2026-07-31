# Transactional Outbox over AMQP — Full Reference

The Transactional Outbox pattern adapted from Redpanda (`go-event-publisher`) to
RabbitMQ. The *insert side* is identical — `go-repository-pattern`'s `Save`
writes an outbox row in the same DB transaction as the aggregate change. The
*relay side* differs in three ways, all traceable to one root cause: **AMQP has
no log offset and no retained log**.

| Concern | Redpanda relay (`go-event-publisher`) | AMQP relay (this skill) |
|---|---|---|
| Proof of delivery | `ProduceSync` returns → produced to a partition offset | **publisher confirm** (`basic.ack`) received |
| Durability source | broker **retention** of the partition | **durability triple**: durable exchange + durable queue + persistent delivery |
| Extra failure mode | none — a produced record is always routable | **`basic.return`**: confirmed but routed to zero queues → topology bug, do **not** mark published |
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
travels as the AMQP `MessageId`, and the consumer deduplicates on it. Never mint
a fresh UUID per publish attempt; that would defeat dedup on a retry.

Per-tenant physical isolation (this repo's model): the outbox lives in the
tenant's own schema/database, so `tenant_id` is a sanity column, not a routing
partition, and there is no cross-tenant data in a single relay's claim.

---

## 2. The Relay Loop

The relay is a supervised component in the composition root's `errgroup`. Each
tick claims a batch, publishes each row in **confirm mode with mandatory +
persistent**, and marks a row published **only after its confirm `ack`
arrives**. A `basic.return` for a row means "confirmed but unroutable" — leave
`published_at` NULL, alarm, and do not retry blindly (the fix is topology, not a
resend).

```go
func (r *Relay) drainOnce(ctx context.Context) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return fmt.Errorf("begin: %w", err)
	}
	defer tx.Rollback(ctx)

	rows, err := tx.Query(ctx, `
		SELECT id, tenant_id, event_type, payload
		  FROM outbox
		 WHERE published_at IS NULL
		 ORDER BY occurred_at
		 LIMIT $1
		 FOR UPDATE SKIP LOCKED`, r.batch)
	if err != nil {
		return fmt.Errorf("claim batch: %w", err)
	}

	// Preallocated to the query's own LIMIT — bounded, never append-grown.
	claimed := make([]outboxRow, 0, r.batch)
	for rows.Next() {
		var m outboxRow
		if err := rows.Scan(&m.id, &m.tenantID, &m.eventType, &m.payload); err != nil {
			rows.Close()
			return fmt.Errorf("scan: %w", err)
		}
		claimed = append(claimed, m)
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return fmt.Errorf("iterate: %w", err)
	}

	published := make([]uuid.UUID, 0, len(claimed))
	for _, m := range claimed {
		env := r.envelope(ctx, m)
		body, _ := json.Marshal(env)

		// Publish to the exchange with the event type as routing key.
		// r.pub.Publish blocks on the confirm and returns non-nil on nack.
		if err := r.pub.PublishConfirmed(ctx, r.exchange, m.eventType, m.id, body); err != nil {
			// nack or transient error: stop this batch, roll back, retry next tick.
			// Rows stay unpublished — this IS the backpressure mechanism.
			return fmt.Errorf("publish outbox %s: %w", m.id, err)
		}
		published = append(published, m.id)
	}

	if len(published) > 0 {
		if _, err := tx.Exec(ctx,
			`UPDATE outbox SET published_at = now() WHERE id = ANY($1)`,
			published); err != nil {
			return fmt.Errorf("mark published: %w", err)
		}
	}
	return tx.Commit(ctx)
}
```

**Publish, then mark — never the reverse.** If the process crashes after the
confirm but before `Commit`, the transaction rolls back, `published_at` stays
NULL, and the row is re-claimed and re-published next tick. At-least-once by
construction; the consumer dedups on `MessageId == outbox.id`.

`PublishConfirmed` is the confirm-mode publish from
`references/publishing-and-confirms.md` (mandatory + `amqp.Persistent`), returning
non-nil on a `nack` so the relay leaves the batch unpublished.

---

## 3. Handling basic.return in the Relay

A returned message is **confirmed** (the broker accepted it) but reached **zero
queues**. That row must **not** be marked published — but the confirm already
arrived, so a naive `PublishConfirmed` that only watches confirms would mark it
done. Correlate returns to the in-flight batch by `MessageId` and fail the row:

```go
// In the publisher: a return arrived for MessageId => this delivery is a
// routing failure even though a confirm ack also arrived.
func (p *Publisher) PublishConfirmed(ctx context.Context, exchange, rk string, id uuid.UUID, body []byte) error {
	p.trackReturn(id.String()) // registers id in the set drainReturns checks
	if err := p.publishMandatoryPersistent(ctx, exchange, rk, id.String(), body); err != nil {
		return err
	}
	c := <-p.confirms
	if !c.Ack {
		return fmt.Errorf("nacked %s", id)
	}
	if p.wasReturned(id.String()) {
		// Confirmed-but-unroutable: topology bug, alarm, leave unpublished.
		return fmt.Errorf("unroutable %s: routing key %q matched no binding", id, rk)
	}
	return nil
}
```

The relay returning this error leaves `published_at` NULL — correct: the event
was **not** delivered anywhere. Redpanda's relay never needs this branch because
a produced record is always routable to its partition.

---

## 4. Worked DataAsset Example

A `DataAssetClassified` domain event must publish whenever a data asset's
sensitivity classification changes, atomically with the classification write.

1. **Repository writes both in one transaction** (`go-repository-pattern`):

```go
func (r *AssetRepo) SaveClassification(ctx context.Context, tx pgx.Tx, a DataAsset) error {
	if _, err := tx.Exec(ctx,
		`UPDATE data_asset SET classification=$1, updated_at=now() WHERE id=$2`,
		a.Classification, a.ID); err != nil {
		return err
	}
	payload, _ := json.Marshal(dataAssetClassifiedV1{
		AssetID:        a.ID,
		Classification: a.Classification, // e.g. "pii"
	})
	_, err := tx.Exec(ctx,
		`INSERT INTO outbox (aggregate_id, tenant_id, event_type, payload)
		 VALUES ($1, $2, 'dataasset.classified', $3)`,
		a.ID, a.TenantID, payload)
	return err // same tx as the UPDATE — atomic
}
```

2. **Topology** (declared idempotently at startup): a durable **topic** exchange
   `dataasset.events`, a durable queue `search-index` bound `dataasset.#`, a
   durable queue `compliance-audit` bound `dataasset.classified`.

3. **Relay publishes** routing key `dataasset.classified` → both queues match →
   two confirms, zero returns → row marked published.

4. **Failure drill:** a typo binds the audit queue `dataasset.classfied`. The
   relay publishes `dataasset.classified`; only `search-index` matches. With
   `mandatory: true` the message still routes to `search-index` (one queue), so
   **no** return fires — returns only fire on **zero** routes. The missing audit
   copy is a *binding* bug caught by a consumer-lag / expected-fan-out check, not
   by `basic.return`. This is the AMQP subtlety: `mandatory` catches *zero*
   routes, not *fewer than expected* routes. Document expected fan-out per event
   so a monitor can assert it.

---

## 5. Idempotency and Ordering Notes

- **Idempotency key** = `outbox.id`, carried as AMQP `MessageId`. The consumer
  keeps a processed-id set (or a unique constraint) and drops duplicates from
  at-least-once redelivery. See `go-amqp-consumer`.
- **Ordering** is per-queue and only holds for a single consumer without
  requeues. A Competing Consumers pool on one queue destroys ordering by design
  — do not rely on outbox `occurred_at` order surviving to a parallel consumer.
  If per-aggregate order matters, route one aggregate's events to one queue with
  one consumer, or fold ordering into the payload (a version number the consumer
  checks).
- **No replay.** A new consumer cannot rewind history — removed-on-ack. To
  rebuild a read model, re-publish from the outbox (or a snapshot), never "seek
  to offset 0." This is the standing cost of a queue broker and the reason
  `message-broker-selection` prefers Redpanda for replay-needing flows.
