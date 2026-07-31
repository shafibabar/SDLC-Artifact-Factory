# Reference: Dead-Letter-Exchange + TTL Retry Topology

RabbitMQ has **no offset** to "leave and come back to," so delayed retry and
poison-message quarantine must be **built as topology**. This reference gives the
exchange/queue graph, the `x-death` max-retries mechanism, and the Go declaration
+ handler code. It realizes the repo's `Dead Letter Queue` glossary term in the
AMQP `x-dead-letter-exchange` (DLX) form.

## Why topology, not a flag

In Redpanda a failed message is retried by simply *not advancing the offset* — the
log retains it. RabbitMQ removes a message on ack; a rejected message is gone
unless the queue routes it somewhere. `x-dead-letter-exchange` is that "somewhere."
A queue **dead-letters** a message (re-publishes it to its DLX) on any of:

- `basic.reject` / `basic.nack` with `requeue=false`,
- message TTL expiry (`x-message-ttl` on the queue, or per-message `expiration`),
- queue overflow (`x-max-length` / `x-max-length-bytes` reached).

Delayed retry is assembled from the **TTL-expiry** trigger: a message parked in a
TTL queue that dead-letters *back to the work exchange* reappears after the delay,
with no busy-wait and no consumer holding it.

## The topology

```
                    publish (scan.gdrive.completed)
                              │
                    ┌─────────▼─────────┐
                    │ exchange: scan.events (topic/direct)
                    └─────────┬─────────┘
                              │ bind key: scan.gdrive.completed
                    ┌─────────▼──────────────────────┐
                    │ queue: scan.gdrive.work          │
                    │  x-dead-letter-exchange:         │
                    │      scan.retry                  │
                    │  x-dead-letter-routing-key:      │
                    │      scan.gdrive                 │
                    └─────────┬──────────────────────┘
                Reject(requeue=false) on failure
                              │
                    ┌─────────▼─────────┐
                    │ exchange: scan.retry (direct)     │
                    └─────────┬─────────┘
                              │ bind key: scan.gdrive
                    ┌─────────▼──────────────────────┐
                    │ queue: scan.gdrive.retry.30s     │
                    │  x-message-ttl: 30000            │  ← backoff delay
                    │  x-dead-letter-exchange:         │
                    │      scan.events                 │  ← points BACK to work
                    │  x-dead-letter-routing-key:      │
                    │      scan.gdrive.completed       │
                    └─────────┬──────────────────────┘
                 TTL expires (nobody consumes this queue)
                              │ dead-letters home
                    ┌─────────▼─────────┐
                    │ back to scan.events → scan.gdrive.work (retry)   │
                    └───────────────────┘

  after N retries (x-death count >= max) the handler routes instead to:
                    ┌───────────────────┐
                    │ queue: scan.gdrive.parked (terminal DLQ, alerted) │
                    └───────────────────┘
```

Key point: **nothing consumes the retry queue.** Its only job is to hold the
message for `x-message-ttl` milliseconds, then dead-letter it back to the work
exchange. That is the delayed-redelivery mechanism.

Multi-tier backoff = multiple retry queues with increasing TTL
(`retry.30s` → `retry.5m` → `retry.30m`), the handler choosing the tier by the
current retry count.

## The `x-death` header: how max-retries is counted

Every time a message is dead-lettered, RabbitMQ **prepends/updates an entry in an
`x-death` header** — an array of tables, one per (queue, reason) the message has
died at. Each entry carries a **`count`** field: the number of times this message
was dead-lettered from that queue for that reason. **This is your retry counter —
you do not maintain your own.**

An `x-death` entry looks like (AMQP field table):

```
x-death: [
  {
    "count":        3,                    // ← retries so far from this queue/reason
    "reason":       "rejected",           // "rejected" | "expired" | "maxlen"
    "queue":        "scan.gdrive.work",
    "exchange":     "scan.retry",
    "routing-keys": ["scan.gdrive"],
    "time":         <timestamp>,
    "original-expiration": "30000"
  }
]
```

The max-retries decision reads this `count`:

```go
const maxRetries = 5

// deathCount returns how many times this delivery has been dead-lettered from
// the named queue for the "rejected" reason, reading RabbitMQ's x-death header.
// Returns 0 when the header is absent (first delivery).
func deathCount(d amqp.Delivery, queue string) int {
	raw, ok := d.Headers["x-death"]
	if !ok {
		return 0
	}
	deaths, ok := raw.([]interface{})
	if !ok {
		return 0
	}
	for _, entry := range deaths {
		tbl, ok := entry.(amqp.Table)
		if !ok {
			continue
		}
		if tbl["queue"] == queue && tbl["reason"] == "rejected" {
			// count arrives as int64 over the wire.
			if n, ok := tbl["count"].(int64); ok {
				return int(n)
			}
		}
	}
	return 0
}
```

## Poison-message parking in the handler

When retries are exhausted, stop feeding the retry loop and route the message to a
terminal **parked** queue that is monitored/alerted and never auto-consumed. Do it
by publishing to a parked exchange and then acking the poison delivery (so it
leaves the work queue), rather than rejecting it back into the retry cycle.

```go
func (c *Consumer) handleWithRetryCap(ctx context.Context, ch *amqp.Channel, d amqp.Delivery) {
	if err := c.business(ctx, d); err == nil {
		_ = d.Ack(false)
		return
	}

	if deathCount(d, "scan.gdrive.work") >= maxRetries {
		// Exhausted: park it. Publish to the terminal DLQ, THEN ack the
		// original so it leaves the work queue and does not re-enter retry.
		_ = ch.PublishWithContext(ctx,
			"scan.parked",       // terminal exchange
			"scan.gdrive",       // routing key
			false, false,
			amqp.Publishing{
				Body:         d.Body,
				Headers:      d.Headers,     // carry x-death forensics forward
				DeliveryMode: amqp.Persistent,
				ContentType:  d.ContentType,
			},
		)
		_ = d.Ack(false)
		return
	}

	// Not yet exhausted: reject WITHOUT requeue so the work queue's DLX
	// (scan.retry) dead-letters it into the TTL retry queue for a delayed
	// redelivery. requeue=false is essential — requeue=true would bypass the
	// DLX and hot-loop.
	_ = d.Reject(false)
}
```

## Declaring the retry topology in Go

Declare all of it at startup; declaration is idempotent.

```go
func declareRetryTopology(ch *amqp.Channel) error {
	// Exchanges
	if err := ch.ExchangeDeclare("scan.events", "topic", true, false, false, false, nil); err != nil {
		return err
	}
	if err := ch.ExchangeDeclare("scan.retry", "direct", true, false, false, false, nil); err != nil {
		return err
	}
	if err := ch.ExchangeDeclare("scan.parked", "direct", true, false, false, false, nil); err != nil {
		return err
	}

	// Work queue: dead-letters rejected messages to the retry exchange.
	if _, err := ch.QueueDeclare("scan.gdrive.work", true, false, false, false, amqp.Table{
		"x-dead-letter-exchange":    "scan.retry",
		"x-dead-letter-routing-key": "scan.gdrive",
	}); err != nil {
		return err
	}
	if err := ch.QueueBind("scan.gdrive.work", "scan.gdrive.completed", "scan.events", false, nil); err != nil {
		return err
	}

	// Retry queue: no consumer. Holds for TTL, then dead-letters BACK to work.
	if _, err := ch.QueueDeclare("scan.gdrive.retry.30s", true, false, false, false, amqp.Table{
		"x-message-ttl":             int32(30000), // 30s backoff
		"x-dead-letter-exchange":    "scan.events",
		"x-dead-letter-routing-key": "scan.gdrive.completed",
	}); err != nil {
		return err
	}
	if err := ch.QueueBind("scan.gdrive.retry.30s", "scan.gdrive", "scan.retry", false, nil); err != nil {
		return err
	}

	// Terminal parked queue: monitored, alerted, manually drained.
	if _, err := ch.QueueDeclare("scan.gdrive.parked", true, false, false, false, nil); err != nil {
		return err
	}
	return ch.QueueBind("scan.gdrive.parked", "scan.gdrive", "scan.parked", false, nil)
}
```

## Design notes and pitfalls

- **`requeue=false` is what triggers dead-lettering.** `Nack(_, true)` / `Reject(true)` requeue in place and **never reach the DLX** — the single most common retry-topology bug.
- **Per-message TTL vs queue TTL.** Setting `expiration` on the `Publishing` gives per-message backoff but a subtle catch: a message only expires when it reaches the *head* of the queue (TTL is checked at the head). A single TTL value per retry queue avoids head-of-line TTL surprises, so prefer distinct fixed-TTL queues per backoff tier over per-message expiration.
- **`x-death` count is per (queue, reason).** Read the entry for the *work* queue with reason `rejected`; the retry queue's own `expired` entries are a different counter.
- **Carry `d.Headers` forward when parking** so the `x-death` audit trail (how many times, from where, why) survives into the DLQ for a compliance operator to inspect.
- **This substitutes for offset-hold, it is not equal to it.** A log lets an unrelated new consumer replay history; this topology only re-delivers *failed* messages to *this* pipeline. If a workload needs true replay, that is a `message-broker-selection` signal to use Redpanda, not to extend this topology.
