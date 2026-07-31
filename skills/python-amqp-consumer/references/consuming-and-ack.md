# Reference: Consuming and Acknowledging (aio-pika)

Full worked RabbitMQ consumer in Python using `aio-pika` (which wraps `aiormq`),
over asyncio. This is the manual-ack analog of `python-event-consumer`'s aiokafka
consume loop. It assumes per-tenant **physical** isolation — one connection per
tenant vhost — consistent with the repo's isolation model. `aio-pika` speaks
AMQP 0-9-1; the correctness rules are identical to `go-amqp-consumer`, only the
client changes.

Install: `pip install aio-pika` (pulls in `aiormq`). For tracing,
`opentelemetry-api`.

## 1. Robust connection, channel, and QoS

`aio_pika.connect_robust()` returns a connection that **transparently
reconnects** — it re-establishes the socket, re-opens channels, and re-registers
consumers after a network drop, with no hand-written reconnect loop. This is the
main ergonomic divergence from Go's `amqp091-go`, where you watch `NotifyClose`
and rebuild everything yourself.

A `RobustConnection` is one TCP socket; a `RobustChannel` is a lightweight logical
session multiplexed over it. **One channel per consumer task** — delivery tags
(used by ack/nack) are scoped to the channel that delivered them, so concurrent
consumers must not share a channel.

```python
import asyncio
import aio_pika
from aio_pika.abc import AbstractIncomingMessage, AbstractRobustConnection
from opentelemetry import trace

tracer = trace.get_tracer("amqp-consumer")


class Consumer:
    def __init__(
        self,
        url: str,          # amqp://user:pass@host/<tenant-vhost> — per-tenant vhost
        queue_name: str,
        prefetch: int,
        handler,           # async callable: (msg) -> None, raises to signal failure
    ) -> None:
        self._url = url
        self._queue_name = queue_name
        self._prefetch = prefetch
        self._handle = handler
        self._conn: AbstractRobustConnection | None = None
        self._stop = asyncio.Event()

    async def _open(self) -> None:
        # connect_robust auto-reconnects; no manual NotifyClose loop needed.
        self._conn = await aio_pika.connect_robust(self._url)
        self._channel = await self._conn.channel()
        # prefetch_count caps unacked deliveries pushed to THIS channel.
        # For a Competing Consumers pool this is the fair-dispatch knob.
        await self._channel.set_qos(prefetch_count=self._prefetch)
```

## 2. Declaring the queue and binding (idempotent)

Declaration is idempotent — declaring an existing queue with matching arguments
is a no-op, so a consumer safely re-declares on every (re)connect. The
`x-dead-letter-exchange` argument wires poison/rejected messages to the retry
topology described in `dlx-retry-topology.md`.

```python
    async def _declare(self):
        exchange = await self._channel.declare_exchange(
            "scan.events", aio_pika.ExchangeType.TOPIC, durable=True,
        )
        queue = await self._channel.declare_queue(
            self._queue_name,
            durable=True,                       # survives broker restart
            arguments={
                "x-dead-letter-exchange": "scan.retry",      # reject → retry exchange
                "x-dead-letter-routing-key": "scan.gdrive",  # routing key on dead-letter
            },
        )
        await queue.bind(exchange, routing_key="scan.gdrive.completed")
        return queue
```

## 3. The delivery loop with correct ack/nack/reject

`queue.iterator()` yields `AbstractIncomingMessage` objects. With `no_ack=False`
(the default) each delivery is held unacknowledged until you resolve it. The loop
exits when `self._stop` is set (graceful shutdown) — the async context manager
cancels the underlying consumer so the broker stops pushing.

```python
    async def consume(self) -> None:
        await self._open()
        queue = await self._declare()

        # no_ack defaults to False — MANUAL ACK, the whole point.
        async with queue.iterator() as it:
            async for message in it:
                if self._stop.is_set():
                    break
                await self._dispatch(message)
```

The per-message decision — the heart of the manual-ack contract. Note the
**explicit** ack/nack rather than the `message.process()` context manager, so the
ack-after-durable-write ordering is visible in the code:

```python
    async def _dispatch(self, message: AbstractIncomingMessage) -> None:
        with tracer.start_as_current_span("amqp.process") as span:
            span.set_attribute("messaging.rabbitmq.delivery_tag", message.delivery_tag)
            span.set_attribute("messaging.rabbitmq.routing_key", message.routing_key or "")
            span.set_attribute("messaging.destination.name", message.exchange or "")
            # redelivered==True means this copy was requeued after an earlier
            # unacked crash/nack — the AMQP analog of a log replay. Idempotency
            # (dedup on a stable message id) must absorb it, exactly as the
            # aiokafka consumer dedups on event_id.
            span.set_attribute("messaging.message.redelivered", message.redelivered)

            try:
                await self._handle(message)          # durable side effect commits here
            except TransientError:
                # Transient (broker/db blip): requeue for an immediate retry.
                # Use ONLY when you expect the fault to clear — otherwise an
                # infinite hot-loop.
                await message.nack(requeue=True)
            except Exception:
                # Permanent / poison: requeue=False. Because the queue declares
                # x-dead-letter-exchange, this routes the message to the retry
                # topology instead of dropping it. reject(requeue=False) is
                # equivalent to nack(requeue=False) for a single message.
                span.record_exception(Exception)
                await message.reject(requeue=False)
            else:
                # Ack ONLY after the side effect is durable, never before.
                await message.ack()


class TransientError(Exception):
    """Raised by a handler for a fault expected to clear on retry."""
```

### Ack / nack / reject reference

| Method | Meaning |
|---|---|
| `await message.ack()` | Positive ack; message removed. Optional `multiple=True` acks this tag **and all lower unacked tags** on the channel — batch ack, use with care. |
| `await message.nack(requeue=bool, multiple=bool)` | Negative ack. `requeue=True` back to queue; `requeue=False` drop-or-dead-letter. `multiple` batches as above. |
| `await message.reject(requeue=bool)` | Reject one message; equivalent to `nack(requeue=requeue, multiple=False)`. No batch form. |

### The `message.process()` context manager and its trap

`aio-pika` also offers `async with message.process(requeue=..., reject_on_redelivered=...):`
which **auto-acks on clean exit** and **auto-nacks on exception**. It is concise
but hides *when* the ack fires — at block exit. It is only correct if the durable
write finished inside the block:

```python
    async def _dispatch_ctx(self, message: AbstractIncomingMessage) -> None:
        # requeue=False so a raised exception dead-letters via the DLX rather than
        # requeuing in place (which would bypass the retry topology and hot-loop).
        async with message.process(requeue=False):
            await self._handle(message)   # MUST fully commit here; ack fires on exit
```

Prefer the explicit form in `_dispatch` for the manual-ack contract this skill
teaches — the Go `amqp091-go` client has no `process()` equivalent, so the
explicit form also keeps the two languages line-comparable.

## 4. Reconnect with auto-requeue safety

On connection loss the broker requeues every unacked delivery. With
`connect_robust`, `aio-pika` reconnects, re-declares (idempotent), and re-registers
the consumer automatically — unacked work is not lost and no manual loop is
needed. Contrast Go, where the reconnect loop and re-declare are hand-written.
The redelivered copies arrive with `message.redelivered == True`; idempotency
absorbs them.

## 5. Graceful shutdown — draining unacked deliveries

Drive cancellation with an `asyncio.Event` set from a signal handler. The correct
sequence on SIGTERM:

1. Set `self._stop` → the `async for` breaks and the `queue.iterator()` context manager cancels the consumer, so the broker **stops pushing** new deliveries.
2. Let already-received handlers **finish and ack**. Bound this with a drain deadline via `asyncio.wait_for`.
3. Anything still unacked when the channel closes is **auto-requeued** by the broker — never lost, but the redelivered copy must be idempotently absorbed.

```python
async def main(url: str) -> None:
    consumer = Consumer(url, "scan.gdrive.work", prefetch=1, handler=handle_asset)

    loop = asyncio.get_running_loop()
    import signal
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, consumer._stop.set)

    try:
        await consumer.consume()
    finally:
        # iterator context already cancelled the consumer; close the socket.
        if consumer._conn is not None:
            await consumer._conn.close()


if __name__ == "__main__":
    asyncio.run(main("amqp://guest:guest@localhost/tenant-42"))
```

## 6. Prefetch tuning worked example

A per-tenant DataAsset classification handler that takes ~2s per message,
unevenly (some assets are large):

- **Start `prefetch_count=1`.** Fair dispatch: a consumer chewing on a huge asset is not also handed 50 queued small ones while an idle sibling starves.
- Scale out by adding **more consumer processes on the same queue** (Competing Consumers), not by raising prefetch. Because the handler is CPU-bound classification, prefer separate processes over asyncio tasks in one process (the GIL serializes CPU work) — matching `python-event-consumer`'s ProcessPool reasoning.
- Only raise prefetch (e.g. to 10) once you measure that handler latency is low and uniform and the round-trip ack latency, not handler time, is the throughput ceiling.
- **Ordering caveat:** the moment you have >1 competing consumer, cross-message order is gone. If DataAsset events for one tenant must be ordered, give each tenant its own queue (consistent-hash exchange on tenant id) and run a single consumer per queue — you trade pool-wide parallelism for per-tenant order. With per-tenant physical isolation this is natural: one vhost, one work queue, one consumer per tenant.

## Anti-patterns

- `no_ack=True` "to go faster" — loses all in-flight work on any crash.
- Acking before the DB write commits — a crash between ack and commit loses the event with no offset to recover from.
- `nack(requeue=True)` on a deterministic failure — infinite redelivery hot-loop.
- Sharing one channel across concurrent consumer tasks — delivery tags collide.
- Using `message.process()` with the durable write *outside* the block — the auto-ack fires before the effect is durable.
- Treating `message.redelivered` as an error — it is the normal at-least-once signal; dedup, do not reject.
