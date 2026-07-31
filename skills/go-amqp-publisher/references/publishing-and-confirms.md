# Publishing and Confirms — Full Go Reference

Runnable reference for a RabbitMQ producer in Go using the `amqp091-go` client
(`github.com/rabbitmq/amqp091-go`, imported as `amqp`). Covers connection and
channel setup, idempotent topology declaration, publisher confirms, the
`mandatory` flag with the `basic.return` handler, persistent delivery, and retry
on `nack`. All identifiers are real client API; no invented flags.

> This repo standardizes on Redpanda (Kafka API). Use this only when
> `message-broker-selection` has explicitly justified a queue broker for a
> workload (e.g. per-tenant RPC-style task dispatch). It is not a default.

---

## 1. Connection and Channel

A `Connection` is one TCP socket; `Channel`s are lightweight logical sessions
multiplexed over it. Open **one** connection per process and a channel per
concurrent unit of publishing work — a channel is **not** goroutine-safe, so do
not share one channel across goroutines.

```go
package amqppub

import (
	"context"
	"fmt"
	"sync"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

type Publisher struct {
	conn *amqp.Connection
	ch   *amqp.Channel

	mu       sync.Mutex
	returned chan amqp.Return // unroutable messages surface here
	confirms chan amqp.Confirmation
}

func Dial(url string) (*Publisher, error) {
	conn, err := amqp.Dial(url) // e.g. "amqp://user:pass@rabbit:5672/"
	if err != nil {
		return nil, fmt.Errorf("amqp dial: %w", err)
	}
	ch, err := conn.Channel()
	if err != nil {
		conn.Close()
		return nil, fmt.Errorf("open channel: %w", err)
	}
	return &Publisher{conn: conn, ch: ch}, nil
}
```

---

## 2. Idempotent Topology Declaration

Declare the exchange, the queue, and the binding on every startup. All three
declarations are idempotent — RabbitMQ no-ops a re-declare with identical
arguments and errors only on a *conflicting* re-declare, which is the behavior
you want (it catches drift). Set `durable: true` on both the exchange and the
queue — two of the three legs of the durability triple.

```go
func (p *Publisher) DeclareTopology(exchange, queue, bindingKey string) error {
	// Durable topic exchange — survives a broker restart.
	if err := p.ch.ExchangeDeclare(
		exchange,          // name
		amqp.ExchangeTopic, // "topic" — direct/fanout/headers are the alternatives
		true,              // durable
		false,             // auto-delete
		false,             // internal
		false,             // no-wait
		nil,               // args
	); err != nil {
		return fmt.Errorf("declare exchange %q: %w", exchange, err)
	}

	q, err := p.ch.QueueDeclare(
		queue,
		true,  // durable
		false, // auto-delete
		false, // exclusive
		false, // no-wait
		nil,   // args (e.g. x-dead-letter-exchange — see go-amqp-consumer)
	)
	if err != nil {
		return fmt.Errorf("declare queue %q: %w", queue, err)
	}

	if err := p.ch.QueueBind(q.Name, bindingKey, exchange, false, nil); err != nil {
		return fmt.Errorf("bind %q -> %q (%q): %w", q.Name, exchange, bindingKey, err)
	}
	return nil
}
```

`ExchangeDeclare`'s second argument is the exchange *type* string. The client
exposes `amqp.ExchangeDirect`, `amqp.ExchangeTopic`, `amqp.ExchangeFanout`, and
`amqp.ExchangeHeaders` — pick per the selection table in `SKILL.md`.

---

## 3. Enabling Confirms and the Return Listener

`Channel.Confirm` puts the channel in confirm mode (the `confirm.select` method
on the wire). `Channel.NotifyPublish` registers a Go channel that receives one
`amqp.Confirmation` per published message, in publish order, with `Ack: true` on
success or `Ack: false` on a broker `nack`. `Channel.NotifyReturn` registers the
Go channel that receives an `amqp.Return` for every message the broker could not
route to any queue (this only fires for messages published with `mandatory:
true`). Register both listeners **before** publishing.

```go
func (p *Publisher) EnableConfirms() error {
	if err := p.ch.Confirm(false /* no-wait */); err != nil {
		return fmt.Errorf("enter confirm mode: %w", err)
	}
	// Buffered so a slow reader does not block the broker's I/O goroutine.
	p.confirms = p.ch.NotifyPublish(make(chan amqp.Confirmation, 256))
	p.returned = p.ch.NotifyReturn(make(chan amqp.Return, 256))
	go p.drainReturns()
	return nil
}

// drainReturns treats every returned (unroutable) message as a hard config
// error: a routing key matched no binding. Never silently discard it.
func (p *Publisher) drainReturns() {
	for r := range p.returned {
		// Surface as an OTel span event / counter in real code.
		// r.ReplyCode == 312 (NO_ROUTE) is the usual reason.
		fmt.Printf("UNROUTABLE exchange=%q routingKey=%q reply=%d %q\n",
			r.Exchange, r.RoutingKey, r.ReplyCode, r.ReplyText)
	}
}
```

The `NotifyReturn` channel is the **only** way a producer learns a message went
nowhere. Without `mandatory: true` and this listener, a routing key that matches
no binding is discarded by the broker with no error anywhere — the silent-loss
failure mode this skill exists to prevent.

---

## 4. Publishing with Mandatory + Persistent Delivery

`PublishWithContext` carries `mandatory` as its third positional argument. The
message body's `DeliveryMode` field is the third leg of the durability triple:
`amqp.Persistent` (value `2`) writes the body to disk; the default
`amqp.Transient` (value `1`) keeps it in memory only and loses it on restart even
on a durable queue.

```go
func (p *Publisher) Publish(ctx context.Context, exchange, routingKey string, body []byte) error {
	p.mu.Lock()
	defer p.mu.Unlock()

	err := p.ch.PublishWithContext(ctx,
		exchange,
		routingKey,
		true,  // mandatory — return the message if it routes to zero queues
		false, // immediate — deprecated; always false
		amqp.Publishing{
			ContentType:  "application/json",
			DeliveryMode: amqp.Persistent, // = 2; the durability-triple leg set per message
			MessageId:    routingKey,      // real code: the outbox row id (idempotency key)
			Timestamp:    time.Now().UTC(),
			Body:         body,
		},
	)
	if err != nil {
		return fmt.Errorf("publish to %q (%q): %w", exchange, routingKey, err)
	}

	// Block for this message's confirmation. NotifyPublish delivers confirms
	// in publish order, so one publish + one receive keeps them correlated.
	select {
	case c := <-p.confirms:
		if !c.Ack {
			return fmt.Errorf("broker nacked delivery tag %d", c.DeliveryTag)
		}
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}
```

For throughput, do not block per message: publish a batch, then read N
confirmations and correlate by `DeliveryTag` (a monotonic per-channel counter).
The one-in/one-out form above is the correctness baseline.

---

## 5. Retry on Nack

A `nack` (`Confirmation.Ack == false`) is rare — it signals an internal broker
error, not a routing miss (that is `basic.return`). Retry the **same** message
with bounded backoff; the message's `MessageId` is stable so a consumer
deduplicates a double-delivery from a retry that actually succeeded broker-side.

```go
func (p *Publisher) PublishWithRetry(ctx context.Context, exchange, rk string, body []byte) error {
	const maxAttempts = 5
	backoff := 100 * time.Millisecond
	for attempt := 1; ; attempt++ {
		err := p.Publish(ctx, exchange, rk, body)
		if err == nil {
			return nil
		}
		if attempt == maxAttempts {
			return fmt.Errorf("publish failed after %d attempts: %w", attempt, err)
		}
		select {
		case <-time.After(backoff):
			backoff *= 2
		case <-ctx.Done():
			return ctx.Err()
		}
	}
}
```

Retrying on `nack` gives at-least-once **from the broker's acceptance point**.
Combined with an idempotent consumer keyed on `MessageId`, the end-to-end
guarantee is at-least-once with dedup — the same contract `go-event-publisher`
provides over Redpanda, reached by a different mechanism.

---

## 6. Worked Routing Examples (topic exchange)

A `topic` exchange matches a dotted routing key against binding patterns where
`*` matches exactly one word and `#` matches zero or more words.

| Published routing key | Binding `scan.#` | Binding `scan.*.completed` | Binding `scan.gdrive.*` |
|---|---|---|---|
| `scan.gdrive.completed` | ✓ | ✓ | ✓ |
| `scan.s3.completed` | ✓ | ✓ | ✗ |
| `scan.gdrive.started` | ✓ | ✗ | ✓ |
| `ingest.gdrive.completed` | ✗ | ✗ | ✗ |

A message published `ingest.gdrive.completed` to an exchange whose only binding
is `scan.#` routes to **zero** queues → with `mandatory: true` it returns via
`NotifyReturn`; without it, it is silently lost. This is exactly why the
mandatory flag is non-optional for any message that matters.

---

## 7. Clean Shutdown

```go
func (p *Publisher) Close() error {
	// Closing the channel closes the confirms/returns notify channels,
	// ending drainReturns cleanly.
	if err := p.ch.Close(); err != nil {
		return err
	}
	return p.conn.Close()
}
```

Never close the connection while confirmations are still outstanding — drain the
`confirms` channel first, or you may report a publish as failed that the broker
actually accepted.
