# Reference: Consuming and Acknowledging (amqp091-go)

Full worked RabbitMQ consumer in Go using `github.com/rabbitmq/amqp091-go`
(the maintained successor to `streadway/amqp`; the API surface is identical for
everything here). This is the manual-ack analog of `go-event-consumer`'s
Redpanda consume loop. It assumes per-tenant physical isolation — one connection
per tenant vhost — consistent with the repo's isolation model.

## 1. Connection, channel, and QoS

A `*amqp.Connection` is one TCP socket; `*amqp.Channel` is a lightweight logical
session multiplexed over it. **One channel per consumer goroutine** — a channel
is not safe for concurrent use, and delivery tags (used by Ack/Nack) are scoped
to the channel that delivered them.

```go
package consumer

import (
	"context"
	"errors"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/trace"
)

type Handler func(ctx context.Context, d amqp.Delivery) error

type Consumer struct {
	url         string
	queue       string
	consumerTag string
	prefetch    int
	handle      Handler
	tracer      trace.Tracer
}

func New(url, queue, tag string, prefetch int, h Handler) *Consumer {
	return &Consumer{
		url: url, queue: queue, consumerTag: tag,
		prefetch: prefetch, handle: h,
		tracer: otel.Tracer("amqp-consumer"),
	}
}
```

`Qos` is set **on the channel, before `Consume`**:

```go
func (c *Consumer) openChannel(conn *amqp.Connection) (*amqp.Channel, error) {
	ch, err := conn.Channel()
	if err != nil {
		return nil, err
	}
	// prefetchCount caps unacked deliveries pushed to THIS channel.
	// prefetchSize=0 means "no byte limit"; global=false applies the
	// count per-consumer (RabbitMQ's interpretation), which is what a
	// Competing Consumers pool wants.
	if err := ch.Qos(c.prefetch, 0, false); err != nil {
		_ = ch.Close()
		return nil, err
	}
	return ch, nil
}
```

## 2. Declaring the queue and binding (idempotent)

Declaration is idempotent — declaring an existing queue with matching arguments
is a no-op, so a consumer safely re-declares on every (re)connect. The
`x-dead-letter-exchange` argument wires poison/rejected messages to the retry
topology described in `dlx-retry-topology.md`.

```go
func (c *Consumer) declare(ch *amqp.Channel) error {
	_, err := ch.QueueDeclare(
		c.queue,
		true,  // durable — survives broker restart
		false, // autoDelete
		false, // exclusive
		false, // noWait
		amqp.Table{
			"x-dead-letter-exchange":    "scan.retry",     // reject/expire → retry exchange
			"x-dead-letter-routing-key": "scan.gdrive",    // routing key used on dead-letter
		},
	)
	if err != nil {
		return err
	}
	return ch.QueueBind(c.queue, "scan.gdrive.completed", "scan.events", false, nil)
}
```

## 3. The delivery loop with correct ack/nack/reject

`Consume` returns a Go channel of `amqp.Delivery`. `autoAck` is **false** — the
whole point. The loop is cancelled by `context.Context`; the range ends when the
broker closes the delivery channel (channel/connection drop → the broker
auto-requeues every unacked delivery).

```go
func (c *Consumer) consume(ctx context.Context, ch *amqp.Channel) error {
	deliveries, err := ch.Consume(
		c.queue, c.consumerTag,
		false, // autoAck=false — MANUAL ACK. Never true for work that matters.
		false, // exclusive
		false, // noLocal
		false, // noWait
		nil,
	)
	if err != nil {
		return err
	}

	for {
		select {
		case <-ctx.Done():
			// Graceful stop: cancel the consumer so the broker stops
			// pushing. In-flight deliveries already handed to us are
			// drained by the range below emptying `deliveries`.
			_ = ch.Cancel(c.consumerTag, false)
			return ctx.Err()

		case d, ok := <-deliveries:
			if !ok {
				return errors.New("delivery channel closed by broker")
			}
			c.dispatch(ctx, d)
		}
	}
}
```

The per-delivery decision — the heart of the manual-ack contract:

```go
func (c *Consumer) dispatch(ctx context.Context, d amqp.Delivery) {
	ctx, span := c.tracer.Start(ctx, "amqp.process")
	defer span.End()
	span.SetAttributes(
		attribute.Int64("messaging.rabbitmq.delivery_tag", int64(d.DeliveryTag)),
		attribute.String("messaging.rabbitmq.routing_key", d.RoutingKey),
		attribute.String("messaging.destination.name", d.Exchange),
		attribute.Bool("messaging.message.redelivered", d.Redelivered),
	)

	// d.Redelivered==true means this copy was requeued after an earlier
	// unacked crash/nack — the AMQP analog of a log replay. Idempotency
	// (dedup on a stable message id) must absorb it, exactly as the
	// Redpanda consumer dedups on EventID.
	err := c.handle(ctx, d)
	switch {
	case err == nil:
		// Ack ONLY after the side effect is durable. multiple=false acks
		// just this delivery tag, not every lower tag on the channel.
		_ = d.Ack(false)

	case errors.Is(err, ErrTransient):
		// Transient (broker/db blip): requeue for an immediate retry.
		// requeue=true. Use ONLY when you expect the fault to clear —
		// otherwise this is an infinite hot-loop.
		_ = d.Nack(false, true)

	default:
		// Permanent / poison: requeue=false. Because the queue declares
		// x-dead-letter-exchange, this routes the message to the retry
		// topology instead of dropping it. Reject(false) is equivalent to
		// Nack(false, false) for a single message.
		_ = d.Reject(false)
	}
}

var ErrTransient = errors.New("transient failure; retry")
```

### Flag reference

| Method | Signature | `multiple` / `requeue` meaning |
|---|---|---|
| `d.Ack(multiple)` | ack | `multiple=true` acks this tag **and all lower unacked tags** on the channel — batch ack, use with care. |
| `d.Nack(multiple, requeue)` | negative ack | `requeue=true` back to queue; `requeue=false` drop-or-dead-letter. `multiple` batches as above. |
| `d.Reject(requeue)` | reject one | Same as `Nack(false, requeue)` — single message only, no batch. |

## 4. Reconnect with auto-requeue safety

On connection loss the broker requeues every unacked delivery. The consumer just
needs to reconnect and re-declare; unacked work is not lost. Watch
`conn.NotifyClose`:

```go
func (c *Consumer) Run(ctx context.Context) error {
	backoff := time.Second
	for {
		if err := ctx.Err(); err != nil {
			return err
		}
		conn, err := amqp.Dial(c.url)
		if err != nil {
			time.Sleep(backoff)
			continue
		}
		closed := conn.NotifyClose(make(chan *amqp.Error, 1))

		ch, err := c.openChannel(conn)
		if err == nil {
			if err = c.declare(ch); err == nil {
				runErr := make(chan error, 1)
				go func() { runErr <- c.consume(ctx, ch) }()
				select {
				case <-closed: // broker/network dropped — unacked auto-requeued
				case err = <-runErr:
					_ = ch.Close()
					_ = conn.Close()
					return err // ctx cancelled → clean exit
				}
			}
		}
		_ = conn.Close()
		time.Sleep(backoff)
	}
}
```

## 5. Graceful shutdown — draining unacked deliveries

The correct sequence on SIGTERM:

1. Cancel the context → the delivery loop calls `ch.Cancel(consumerTag, false)`, so the broker **stops pushing** new deliveries.
2. Let already-received handlers **finish and ack**. Bound this with a drain deadline.
3. Anything still unacked when the channel closes is **auto-requeued** by the broker — never lost, but the redelivered copy must be idempotently absorbed.

```go
func Main(parent context.Context, c *Consumer) error {
	ctx, stop := signal.NotifyContext(parent, syscall.SIGTERM, os.Interrupt)
	defer stop()

	err := c.Run(ctx)
	if errors.Is(err, context.Canceled) {
		return nil // clean shutdown
	}
	return err
}
```

## 6. Prefetch tuning worked example

A per-tenant DataAsset classification handler that takes ~2s per message,
unevenly (some assets are large):

- **Start `prefetch=1`.** Fair dispatch: a consumer chewing on a huge asset is not also handed 50 queued small ones while an idle sibling starves.
- Scale out by adding **more consumer processes on the same queue** (Competing Consumers), not by raising prefetch.
- Only raise prefetch (e.g. to 10) once you measure that handler latency is low and uniform and the round-trip ack latency, not handler time, is the throughput ceiling.
- **Ordering caveat:** the moment you have >1 competing consumer, cross-message order is gone. If DataAsset events for one tenant must be ordered, give each tenant its own queue (consistent-hash exchange on tenant id) and run a single consumer per queue — you trade pool-wide parallelism for per-tenant order.

## Anti-patterns

- `autoAck=true` "to go faster" — loses all in-flight work on any crash.
- Acking before the DB write commits — a crash between ack and commit loses the event with no offset to recover from.
- `Nack(_, true)` on a deterministic failure — infinite redelivery hot-loop.
- Sharing one `*amqp.Channel` across goroutines — data race; delivery tags collide.
- Treating `d.Redelivered` as an error — it is the normal at-least-once signal; dedup, do not reject.
