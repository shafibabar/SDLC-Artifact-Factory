# Reference: Dead-Letter-Exchange + TTL Retry Topology (aio-pika)

RabbitMQ has **no offset** to "leave and come back to," so delayed retry and
poison-message quarantine must be **built as topology**. This reference gives the
exchange/queue graph, the `x-death` max-retries mechanism, and the aio-pika
declaration + handler code. It realizes the repo's `Dead Letter Queue` glossary
term in the AMQP `x-dead-letter-exchange` (DLX) form. The topology and its
correctness are identical to `go-amqp-consumer`; only the client is Python.

## Why topology, not a flag

In Redpanda a failed message is retried by simply *not advancing the offset* — the
log retains it. RabbitMQ removes a message on ack; a rejected message is gone
unless the queue routes it somewhere. `x-dead-letter-exchange` is that "somewhere."
A queue **dead-letters** a message (re-publishes it to its DLX) on any of:

- `basic.reject` / `basic.nack` with `requeue=False` (`await message.reject(requeue=False)` / `await message.nack(requeue=False)`),
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
                    │ exchange: scan.events (topic)     │
                    └─────────┬─────────┘
                              │ bind key: scan.gdrive.completed
                    ┌─────────▼──────────────────────┐
                    │ queue: scan.gdrive.work          │
                    │  x-dead-letter-exchange:         │
                    │      scan.retry                  │
                    │  x-dead-letter-routing-key:      │
                    │      scan.gdrive                 │
                    └─────────┬──────────────────────┘
             reject(requeue=False) on failure
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
`x-death` header** — a list of tables, one per (queue, reason) the message has
died at. Each entry carries a **`count`** field: the number of times this message
was dead-lettered from that queue for that reason. **This is your retry counter —
you do not maintain your own.** In aio-pika the header is read from
`message.headers`.

An `x-death` entry looks like (decoded to Python types):

```python
# message.headers["x-death"] == [
#   {
#     "count":        3,                    # ← retries so far from this queue/reason
#     "reason":       "rejected",           # "rejected" | "expired" | "maxlen"
#     "queue":        "scan.gdrive.work",
#     "exchange":     "scan.retry",
#     "routing-keys": ["scan.gdrive"],
#     "time":         datetime(...),
#     "original-expiration": "30000",
#   },
# ]
```

The max-retries decision reads this `count`:

```python
MAX_RETRIES = 5


def death_count(message, queue: str) -> int:
    """How many times this delivery was dead-lettered from `queue` for the
    'rejected' reason, per RabbitMQ's x-death header. Returns 0 when the header
    is absent (first delivery)."""
    deaths = (message.headers or {}).get("x-death")
    if not isinstance(deaths, list):
        return 0
    for entry in deaths:
        if not isinstance(entry, dict):
            continue
        if entry.get("queue") == queue and entry.get("reason") == "rejected":
            count = entry.get("count", 0)
            try:
                return int(count)
            except (TypeError, ValueError):
                return 0
    return 0
```

## Poison-message parking in the handler

When retries are exhausted, stop feeding the retry loop and route the message to a
terminal **parked** queue that is monitored/alerted and never auto-consumed. Do it
by publishing to a parked exchange and then acking the poison delivery (so it
leaves the work queue), rather than rejecting it back into the retry cycle.

```python
import aio_pika


async def handle_with_retry_cap(channel, message) -> None:
    try:
        await business(message)          # durable side effect
    except Exception:
        pass
    else:
        await message.ack()
        return

    if death_count(message, "scan.gdrive.work") >= MAX_RETRIES:
        # Exhausted: park it. Publish to the terminal DLQ, THEN ack the original
        # so it leaves the work queue and does not re-enter retry. Carry the
        # headers forward so the x-death forensic trail survives for a
        # compliance operator to inspect.
        parked = await channel.get_exchange("scan.parked")
        await parked.publish(
            aio_pika.Message(
                body=message.body,
                headers=message.headers,          # x-death audit trail preserved
                delivery_mode=aio_pika.DeliveryMode.PERSISTENT,
                content_type=message.content_type,
            ),
            routing_key="scan.gdrive",
        )
        await message.ack()
        return

    # Not yet exhausted: reject WITHOUT requeue so the work queue's DLX
    # (scan.retry) dead-letters it into the TTL retry queue for a delayed
    # redelivery. requeue=False is essential — requeue=True bypasses the DLX
    # and hot-loops.
    await message.reject(requeue=False)
```

## Declaring the retry topology in aio-pika

Declare all of it at startup; declaration is idempotent.

```python
import aio_pika
from aio_pika import ExchangeType


async def declare_retry_topology(channel) -> None:
    # Exchanges
    events = await channel.declare_exchange("scan.events", ExchangeType.TOPIC, durable=True)
    retry = await channel.declare_exchange("scan.retry", ExchangeType.DIRECT, durable=True)
    parked = await channel.declare_exchange("scan.parked", ExchangeType.DIRECT, durable=True)

    # Work queue: dead-letters rejected messages to the retry exchange.
    work = await channel.declare_queue(
        "scan.gdrive.work", durable=True,
        arguments={
            "x-dead-letter-exchange": "scan.retry",
            "x-dead-letter-routing-key": "scan.gdrive",
        },
    )
    await work.bind(events, routing_key="scan.gdrive.completed")

    # Retry queue: no consumer. Holds for TTL, then dead-letters BACK to work.
    retry_q = await channel.declare_queue(
        "scan.gdrive.retry.30s", durable=True,
        arguments={
            "x-message-ttl": 30000,                      # 30s backoff
            "x-dead-letter-exchange": "scan.events",
            "x-dead-letter-routing-key": "scan.gdrive.completed",
        },
    )
    await retry_q.bind(retry, routing_key="scan.gdrive")

    # Terminal parked queue: monitored, alerted, manually drained.
    parked_q = await channel.declare_queue("scan.gdrive.parked", durable=True)
    await parked_q.bind(parked, routing_key="scan.gdrive")
```

## Design notes and pitfalls

- **`requeue=False` is what triggers dead-lettering.** `nack(requeue=True)` / `reject(requeue=True)` requeue in place and **never reach the DLX** — the single most common retry-topology bug.
- **Per-message TTL vs queue TTL.** Setting `expiration` on the published `Message` gives per-message backoff but a subtle catch: a message only expires when it reaches the *head* of the queue (TTL is checked at the head). A single TTL value per retry queue avoids head-of-line TTL surprises, so prefer distinct fixed-TTL queues per backoff tier over per-message expiration.
- **`x-death` count is per (queue, reason).** Read the entry for the *work* queue with reason `rejected`; the retry queue's own `expired` entries are a different counter.
- **Carry `message.headers` forward when parking** so the `x-death` audit trail (how many times, from where, why) survives into the DLQ for a compliance operator to inspect.
- **This substitutes for offset-hold, it is not equal to it.** A log lets an unrelated new consumer replay history; this topology only re-delivers *failed* messages to *this* pipeline. If a workload needs true replay, that is a `message-broker-selection` signal to use Redpanda, not to extend this topology.
