# Worker Pools, DLQ Routing, and Graceful Drain

The full standard for bounded per-message concurrency — the `asyncio.Semaphore` pool for I/O-bound work versus the `ProcessPoolExecutor` for CPU-bound work — plus DLQ routing after N retries and the shutdown drain. Self-contained; `SKILL.md` points here for the complete listings and the honest cost model.

---

## 1. I/O-bound: an `asyncio.Semaphore`-bounded pool

Most per-message work in this product is I/O-bound: writing to Postgres, fetching a document from S3 or Google Drive, calling another service. The GIL is **released** during those waits, so coroutines run concurrently and cheaply — the same "many concurrent things, one thread of Python execution" model goroutines give, minus the multi-core part (which I/O-bound work doesn't need). The only thing to add is a ceiling on in-flight work so a burst of messages cannot open ten thousand simultaneous connections and exhaust memory:

```python
# Illustration: bounded fan-out for I/O-bound work
import asyncio


class IOBoundPool:
    """Bounded fan-out for I/O-bound per-message work. A Semaphore caps how
    many messages are in flight at once; asyncio.TaskGroup gives errgroup-like
    'cancel siblings on first failure' semantics on Python 3.11+."""

    def __init__(self, concurrency: int):
        self._sem = asyncio.Semaphore(concurrency)

    async def run(self, handle, messages) -> None:
        async with asyncio.TaskGroup() as tg:      # 3.11+: like Go's errgroup
            for msg in messages:
                tg.create_task(self._guarded(handle, msg))

    async def _guarded(self, handle, msg) -> None:
        async with self._sem:                      # blocks past the ceiling
            await handle(msg)                       # pass _handle_or_dlq: failures end in the DLQ
```

`asyncio.TaskGroup` (Python 3.11+) is the closest analog to Go's `errgroup`: it awaits every child task and, on the first unhandled exception, cancels the siblings and raises an `ExceptionGroup`. Because a per-message failure is caught inside `handle` (the consumer's `_handle_or_dlq`) and routed to the DLQ (never re-raised), one bad message never cancels the group — only a genuinely fatal error (or shutdown `CancelledError`) tears it down, exactly the "per-record failure ≠ batch failure" discipline from `go-event-consumer`.

Two consequences: records of one partition now finish out of order, so use the pool only where per-key order does not matter, and commit offsets only after the whole `run` call returns.

Sizing the Semaphore is about downstream capacity — connection-pool size, the rate limit of the API being called — not CPU cores. A good default is the `asyncpg` pool's `max_size`, so the consumer never has more DB work in flight than the pool can serve.

---

## 2. CPU-bound: a `ProcessPoolExecutor` — and why the Semaphore pool is wrong here

Some events demand pure-Python CPU work per message: entity extraction, classification, parsing a document body. Here the Semaphore pool from §1 is **not just suboptimal, it is incorrect**. Under the GIL only one thread executes Python bytecode at a time, so a hundred coroutines all doing CPU-bound Python work run **fully serial** — the Semaphore adds concurrency accounting over zero actual parallelism. The throughput you think you bought does not exist.

True multi-core parallelism for pure-Python code requires separate OS processes. `concurrent.futures.ProcessPoolExecutor`, driven from the event loop via `loop.run_in_executor`, is the mechanism:

```python
# Illustration: the CPU-bound pool
import asyncio
from concurrent.futures import ProcessPoolExecutor


# The target callable MUST be a top-level, importable function defined at module
# scope. ProcessPoolExecutor pickles the callable and its arguments to ship them
# to the worker process; a lambda, a closure, or a locally-defined (nested)
# function is not picklable and cannot cross the process boundary. Through
# run_in_executor the pickling error surfaces when the future is awaited.
def extract_entities(raw_document: bytes) -> list[str]:
    # pure-Python CPU-bound work runs here, in its own interpreter process
    ...


class CPUBoundPool:
    """Long-lived, bounded pool of worker PROCESSES. Never per-message."""

    def __init__(self, max_workers: int):
        self._pool = ProcessPoolExecutor(max_workers=max_workers)

    async def run_one(self, raw_document: bytes) -> list[str]:
        loop = asyncio.get_running_loop()
        # run_in_executor keeps the event loop responsive while the worker
        # process chews on the CPU work off-thread (off-process, here).
        return await loop.run_in_executor(self._pool, extract_entities, raw_document)

    def close(self) -> None:
        self._pool.shutdown(wait=True)
```

### The honest cost model — heavier than a goroutine, heavier than a worker_thread

- **Full process, not a lightweight stack.** Each worker is a complete CPython interpreter with its own memory. Go's goroutines are runtime-scheduled stacks sharing one address space; even Node's `worker_threads` share a process and can use `SharedArrayBuffer`. A `ProcessPoolExecutor` worker has neither advantage.
- **Pickling on every boundary crossing.** The callable and every argument are pickled on submit and the result is pickled on return. A large `raw_document` is copied and serialised twice per task. This is pure overhead a goroutine never pays.
- **No shared memory by default.** Workers cannot see the parent's objects. Shared state means `multiprocessing.shared_memory` (only for buffer-like data) or re-passing it through pickling — not the casual shared-heap access Go and Node worker threads allow.
- **Size to per-process memory cost, not core count.** The naive "one worker per core" default ignores that each worker holds a full interpreter plus whatever the task loads (a model, a parser, large buffers). A 4-core box loading a 2 GB model per worker cannot run 4 workers in 8 GB. Size the pool to `min(cores, available_memory / per_worker_footprint)`.
- **Never spin up a pool per message.** Process startup plus pickling cost dwarfs the work for anything short. The pool is constructed once at service start and lives for the process lifetime.

### The frugal default: don't do CPU work in the consumer at all

For this product the standing escalation discipline is that document parsing / OCR / classification is a **separately-scaled service**, not inline consumer work. So the correct answer for most consumers is neither pool for CPU work — it is to publish a "needs classification" event and let the dedicated CPU service (which owns its own `ProcessPoolExecutor`, sized to its own hardware) consume it. Reach for the `ProcessPoolExecutor` inside a consumer only when the CPU work is small, bounded, and genuinely cheaper to do in place than to round-trip through another topic.

---

## 3. DLQ routing after N retries

Transient failures retry with exponential backoff and jitter; exhausted or undecodable records route to `<topic>.dlq`. The original message value is forwarded **byte-for-byte unchanged** — failure metadata lives only in headers, so an undecodable payload still preserves its exact bytes for offline inspection:

```python
# src/classification/entrypoints/dead_letter.py
import asyncio
import random
from collections.abc import Awaitable, Callable

import asyncpg
from aiokafka import AIOKafkaProducer, ConsumerRecord

TRANSIENT_ERRORS: tuple[type[BaseException], ...] = (
    ConnectionError,                        # includes refused and reset connections
    TimeoutError,
    asyncpg.PostgresConnectionError,
    asyncpg.TooManyConnectionsError,
    asyncpg.CannotConnectNowError,
    asyncpg.SerializationError,
    asyncpg.DeadlockDetectedError,
)


def is_transient(exc: BaseException) -> bool:
    return isinstance(exc, TRANSIENT_ERRORS)


def dlq_topic(source_topic: str) -> str:
    return f"{source_topic}.dlq"        # per-source DLQ, never one shared DLQ


class DLQProducer:
    def __init__(self, producer: AIOKafkaProducer) -> None:
        self._producer = producer

    async def route(self, msg: ConsumerRecord, reason: str, retry_count: int = 0) -> None:
        headers = [(k, v) for k, v in (msg.headers or ())
                   if k not in ("x-retry-count", "x-dlq-reason")]
        headers.append(("x-retry-count", str(retry_count).encode()))
        headers.append(("x-dlq-reason", reason.encode()))
        await self._producer.send_and_wait(
            dlq_topic(msg.topic),
            value=msg.value,            # UNCHANGED original bytes — never re-serialised
            key=msg.key,                # preserve partition affinity (tenant key)
            headers=headers,
        )


async def with_retry(fn: Callable[[], Awaitable[None]], *, max_attempts: int,
                     base_delay: float = 0.5) -> None:
    """Retry a transient failure with exponential backoff and jitter. A non-transient
    failure, or the last attempt's failure, is raised so the caller can DLQ it."""
    for attempt in range(1, max_attempts + 1):
        try:
            await fn()
            return
        except Exception as exc:
            if not is_transient(exc) or attempt >= max_attempts:
                raise
            delay = base_delay * (2 ** (attempt - 1))
            await asyncio.sleep(delay + random.uniform(0, delay))   # jitter
```

Wiring it into the handler: a transient error retries up to `max_attempts`; a non-transient error (a decode failure, a domain rule violation) skips retry and goes straight to the DLQ with `retry_count=0`. Either way the value pushed to `<topic>.dlq` is `msg.value`, never a re-encoded object — re-serialising would discard the one thing a malformed record can still offer.

- `x-retry-count` records the attempt reached at exhaustion, set once on the DLQ push.
- `<topic>.dlq` is per source topic, so DLQ depth is attributable to one pipeline stage — a single shared DLQ topic makes depth ambiguous across sources.
- The Kafka key is preserved so DLQ records keep the same tenant partition affinity as the originals.

---

## 4. Graceful drain on shutdown

On `SIGTERM` the pod gets a grace period before `SIGKILL`. The consumer must stop fetching, let in-flight work finish, commit final offsets, and leave the group — all inside a bounded deadline under that grace period, so a hang never blocks the pod's shutdown past `SIGKILL`:

```python
# src/classification/entrypoints/event_consumer.py  (continued)
async def serve(component: DataAssetConsumer, producer: AIOKafkaProducer) -> None:
    """Run until SIGTERM/SIGINT. `producer` is the one the component's DLQProducer uses."""
    stop = asyncio.Event()
    loop = asyncio.get_running_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, stop.set)

    await producer.start()
    run_task = asyncio.create_task(component.run())
    stop_task = asyncio.create_task(stop.wait())
    try:
        # A signal, or the loop dying on its own.
        await asyncio.wait({run_task, stop_task}, return_when=asyncio.FIRST_COMPLETED)
        component.request_stop()                         # finish the record in hand
        await asyncio.wait_for(run_task, timeout=20.0)   # cancels run_task on timeout
    finally:
        stop_task.cancel()
        await asyncio.wait_for(producer.stop(), timeout=5.0)
```

The imports it adds to that module are `signal` and `AIOKafkaProducer` (from `aiokafka`). If the deadline passes or the loop failed, the error propagates and the process exits non-zero, which is what the orchestrator should see.

`consumer.stop()` (called from the component's `_drain`, see `consumer-loop-and-idempotency.md` §7) performs the group-leave; with auto-commit off it flushes no offsets, so the loop's own per-record commits are the only ones. A commit that fails during drain just means redelivery on restart, and the `processed_events` dedup makes redelivery a no-op. A service that owns a `ProcessPoolExecutor` shuts it down after the loop has ended (`shutdown(wait=True)` blocks until running tasks finish).

The bounded waits (20s for the loop, 5s for the producer) must sum to **less** than the Kubernetes `terminationGracePeriodSeconds` (default 30s) — otherwise the drain is still running when `SIGKILL` arrives and the graceful path was pointless.
