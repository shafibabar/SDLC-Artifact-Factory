# Publishing and Confirms — Full aio-pika Reference

Runnable reference for a RabbitMQ producer in Python using `aio-pika` (the
async AMQP 0-9-1 client built on `aiormq`, over `asyncio`). Covers robust
connection and channel setup, idempotent topology declaration, publisher
confirms, the `mandatory` flag and how `aio-pika` surfaces an unroutable
`basic.return`, persistent delivery, and retry on `nack`. All identifiers are
real client API; no invented flags.

> This repo standardizes on Redpanda (Kafka API). Use this only when
> `message-broker-selection` has explicitly justified a queue broker for a
> workload (e.g. per-tenant RPC-style task dispatch). It is not a default.

Install: `pip install aio-pika`. The examples target `aio-pika` 9.x.

---

## 1. Robust Connection and Channel

A `Connection` is one TCP socket; `Channel`s are lightweight logical sessions
multiplexed over it. `aio_pika.connect_robust` returns a connection that
**auto-reconnects** after a broker blip and re-opens its channels — the Go
`amqp091` client has no equivalent, so this is a real Python advantage. Open one
connection per process and a channel per concurrent unit of publishing work.

`aio-pika` opens channels with **publisher confirms enabled by default**
(`publisher_confirms=True`); we set it explicitly here to make the contract
visible in the code.

```python
import asyncio

import aio_pika
from aio_pika import DeliveryMode, ExchangeType, Message
from aio_pika.abc import AbstractRobustConnection, AbstractRobustExchange


class Publisher:
    def __init__(self) -> None:
        self._conn: AbstractRobustConnection | None = None
        self._channel: aio_pika.abc.AbstractRobustChannel | None = None
        self._exchange: AbstractRobustExchange | None = None

    async def connect(self, url: str) -> None:
        # e.g. "amqp://user:pass@rabbit:5672/"
        self._conn = await aio_pika.connect_robust(url)
        # publisher_confirms=True is the default; explicit for clarity.
        self._channel = await self._conn.channel(publisher_confirms=True)
```

---

## 2. Idempotent Topology Declaration

Declare the exchange, the queue, and the binding on every startup. All three are
idempotent — RabbitMQ no-ops a re-declare with identical arguments and errors
only on a *conflicting* re-declare, which is the behaviour you want (it catches
drift). Set `durable=True` on both the exchange and the queue — two of the three
legs of the durability triple.

```python
    async def declare_topology(
        self, exchange: str, queue: str, binding_key: str
    ) -> None:
        assert self._channel is not None
        # Durable topic exchange — survives a broker restart.
        self._exchange = await self._channel.declare_exchange(
            exchange,
            ExchangeType.TOPIC,  # DIRECT / FANOUT / HEADERS are the alternatives
            durable=True,
        )
        q = await self._channel.declare_queue(
            queue,
            durable=True,
            # arguments={"x-dead-letter-exchange": ...} — see python-amqp-consumer
        )
        await q.bind(self._exchange, routing_key=binding_key)
```

`declare_exchange`'s second argument is the exchange *type*. `aio-pika` exposes
`ExchangeType.DIRECT`, `ExchangeType.TOPIC`, `ExchangeType.FANOUT`, and
`ExchangeType.HEADERS` — pick per the selection table in `SKILL.md`.

---

## 3. Publishing with Mandatory + Persistent Delivery

`Exchange.publish` carries `mandatory` as a keyword argument. The `Message`'s
`delivery_mode` field is the third leg of the durability triple:
`DeliveryMode.PERSISTENT` (value `2`) writes the body to disk; the default
`DeliveryMode.NOT_PERSISTENT` (value `1`) keeps it in memory only and loses it on
restart even on a durable queue.

Because publisher confirms are on, `await exchange.publish(...)` does not return
until the broker `ack` arrives — the awaited call **is** the confirm wait. A
broker `nack` or an unroutable `mandatory` return raises rather than returns.

```python
    async def publish(
        self, routing_key: str, body: bytes, message_id: str
    ) -> None:
        assert self._exchange is not None
        message = Message(
            body=body,
            content_type="application/json",
            delivery_mode=DeliveryMode.PERSISTENT,  # = 2; durability-triple leg
            message_id=message_id,  # real code: outbox row id (idempotency key)
        )
        # mandatory=True -> broker returns the message if it routes to zero
        # queues; under confirms aio-pika raises DeliveryError for that return.
        await self._exchange.publish(
            message,
            routing_key=routing_key,
            mandatory=True,
        )
```

---

## 4. How aio-pika Surfaces an Unroutable Return

This is the single most important divergence from Go. In Go's `amqp091`, a
`mandatory` message that routes to zero queues arrives on a **separate**
`NotifyReturn` channel *and* the confirm `ack` still fires — you correlate the
two by `MessageId` yourself. In `aio-pika`, `aiormq` correlates the
`basic.return` to the in-flight delivery **internally** and raises
`aio_pika.exceptions.DeliveryError` out of the awaited `publish`. There is no
side channel and no correlation code to write.

```python
from aio_pika.exceptions import DeliveryError


async def publish_or_alarm(
    pub: Publisher, routing_key: str, body: bytes, message_id: str
) -> None:
    try:
        await pub.publish(routing_key, body, message_id)
    except DeliveryError as exc:
        # Confirmed-but-unroutable: a routing key matched no binding.
        # exc.message carries the returned aio_pika message; exc.frame the
        # basic.return/basic.nack frame. Treat as a HARD config error:
        # surface an OTel span event / counter. Never a silent drop.
        raise RuntimeError(
            f"unroutable message_id={message_id} routing_key={routing_key!r} "
            f"matched no binding"
        ) from exc
```

`DeliveryError` covers both a broker `nack` and a `mandatory` return — inspect
`exc.frame` if you must distinguish them, but for a producer that matters both
outcomes mean "not delivered where intended" and both must block marking the
message published.

---

## 5. Retry on Nack

A `nack` (internal broker error, not a routing miss) is rare. Retry the **same**
message with bounded backoff; the message's `message_id` is stable, so a consumer
deduplicates a double-delivery from a retry that actually succeeded broker-side.
A `mandatory` return is **not** retried blindly — the fix is topology, not a
resend — so this loop re-raises those.

```python
async def publish_with_retry(
    pub: Publisher, routing_key: str, body: bytes, message_id: str
) -> None:
    max_attempts = 5
    backoff = 0.1
    for attempt in range(1, max_attempts + 1):
        try:
            await pub.publish(routing_key, body, message_id)
            return
        except DeliveryError as exc:
            # An unroutable return is a topology bug — do not spin on it.
            if getattr(exc, "message", None) is not None:
                raise
            if attempt == max_attempts:
                raise
            await asyncio.sleep(backoff)
            backoff *= 2
```

Retrying on `nack` gives at-least-once **from the broker's acceptance point**.
Combined with an idempotent consumer keyed on `message_id`, the end-to-end
guarantee is at-least-once with dedup — the same contract `python-event-publisher`
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
is `scan.#` routes to **zero** queues → with `mandatory=True` it raises
`DeliveryError`; without `mandatory` it is silently lost. This is exactly why the
mandatory flag is non-optional for any message that matters.

---

## 7. Batched Throughput

The per-message `await` in §3 is the correctness baseline. For throughput, launch
many publishes and await them together — `asyncio.gather` is the Python analog of
Go's buffered-confirm-channel + drain goroutine:

```python
async def publish_batch(pub: Publisher, rows: list[tuple[str, bytes, str]]) -> None:
    await asyncio.gather(
        *(pub.publish(rk, body, mid) for rk, body, mid in rows)
    )
```

Each coroutine still waits for its own confirm; `gather` raises if **any** publish
raises (a nack or an unroutable return), so a failing batch is visible as one
exception. Bound concurrency with a `Semaphore` if the batch is large.

---

## 8. Clean Shutdown

```python
    async def close(self) -> None:
        if self._conn is not None:
            # Closing the robust connection closes its channels and waits for
            # outstanding confirms to settle.
            await self._conn.close()
```

Never close the connection while publishes are still in flight — `await` every
outstanding `publish` (or the `gather`) first, or you may report a publish as
failed that the broker actually accepted. The robust connection's auto-reconnect
does **not** replay in-flight publishes; that guarantee comes from the Outbox
(`references/outbox-over-amqp.md`), not the client.
