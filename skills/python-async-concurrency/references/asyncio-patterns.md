# asyncio Patterns — TaskGroup Fan-Out, gather vs TaskGroup, Bounded Pools, Timeouts, Cancellation

Reference material for `python-async-concurrency`. Every example targets Python 3.11+
(the version that introduced `asyncio.TaskGroup`, `asyncio.timeout`, and PEP 654
`ExceptionGroup`/`except*`), the sanctioned floor for this repo's Python services. All
code is runnable as-is against `asyncpg` / `aiokafka` clients.

---

## 1. TaskGroup fan-out / fan-in — the errgroup analog

`asyncio.TaskGroup` is the default for I/O-bound parallel stages. Structural contract,
one-to-one with Go's `errgroup`:

- Every `tg.create_task(...)` is **Owned** by the group (no orphan tasks).
- On the first child exception the group **cancels every other child** immediately.
- The `async with` block does not exit until every child has finished (**Joined**).
- At exit, if any child failed, the group raises an `ExceptionGroup` collecting *all*
  the failures that occurred (not just the first — this is the key divergence from
  `errgroup`, which surfaces only the first and discards the rest).

```python
import asyncio
from dataclasses import dataclass


@dataclass(frozen=True)
class AssetView:
    asset: "Asset"
    gaps: list["Gap"]
    lineage: list["LineageEdge"]


async def load_asset_view(asset_id: str, uow) -> AssetView:
    """Fan out three independent tenant-scoped reads in parallel; any failure
    cancels the siblings and surfaces at the async-with exit."""
    async with asyncio.TaskGroup() as tg:
        asset_t   = tg.create_task(uow.assets.get(asset_id))
        gaps_t    = tg.create_task(uow.gaps.for_asset(asset_id))
        lineage_t = tg.create_task(uow.lineage.for_asset(asset_id))
    # Reached only if ALL THREE succeeded. .result() never blocks here — the
    # tasks are already done — and never re-raises, because a failure would
    # have exited the block above via ExceptionGroup instead.
    return AssetView(
        asset=asset_t.result(),
        gaps=gaps_t.result(),
        lineage=lineage_t.result(),
    )
```

This is the Python port of `go-service-layer`'s parallel query fan-out. The Go version
uses ad-hoc confinement (each `errgroup` goroutine writes only its own destination
variable); the Python version confines identically — each task owns exactly one `Task`
object, and `.result()` is read only after the group has joined every task, so no two
coroutines ever touch the same variable concurrently. No lock is needed, for the same
reason no mutex is needed in the Go version.

### Unwrapping failures with `except*`

Because a `TaskGroup` raises an `ExceptionGroup`, a plain `except` around it silently
misses the real error — the error is *wrapped*. Use PEP 654 `except*`:

```python
try:
    view = await load_asset_view(asset_id, uow)
except* NotFoundError as eg:
    # eg.exceptions is a tuple of every NotFoundError the group collected
    for exc in eg.exceptions:
        log.warning("asset fan-out: not found", asset_id=exc.asset_id)
    raise                                  # re-raise the group; let the edge map it
except* PermissionError as eg:
    raise AuthorizationError() from eg
```

`except*` runs *every* matching clause (a single `ExceptionGroup` can match more than
one), unlike ordinary `except` which runs exactly one. If you only care that *something*
failed and want the first leaf, `eg.exceptions[0]` is it — but prefer handling the whole
group; dropping siblings is exactly the information `TaskGroup` exists to preserve over
`errgroup`.

---

## 2. `gather` vs `TaskGroup` — decision table

`asyncio.gather` predates `TaskGroup` and is weaker. Prefer `TaskGroup`; reach for
`gather` only in the narrow row below.

| Concern | `asyncio.gather(*aws)` | `asyncio.TaskGroup` |
|---|---|---|
| Sibling cancellation on first failure | **No** — by default the others keep running to completion in the background even after one raises | **Yes** — cancels every sibling immediately, like `errgroup` |
| What it raises | the **first** exception only (with `return_exceptions=False`); the rest are silently discarded/orphaned | an `ExceptionGroup` collecting **all** concurrent failures |
| `return_exceptions=True` mode | returns results and exceptions side-by-side as a list; nothing is cancelled, nothing is raised | not applicable — failures always propagate as a group |
| Task cleanup on outer cancellation | leaks: pending tasks are not awaited/cancelled for you | all children cancelled and awaited before exit |
| When to use | you genuinely want **all** awaitables to run to completion regardless of individual failure, and to inspect each outcome — e.g. best-effort fan-out to N notification sinks where one failing must not stop the others | **everything else** — any fan-out where a failure should stop the siblings |

```python
# Legitimate gather use: best-effort, failure-tolerant fan-out.
results = await asyncio.gather(
    notify_slack(evt), notify_email(evt), notify_webhook(evt),
    return_exceptions=True,                # a failed sink must NOT abort the others
)
for sink, outcome in zip(("slack", "email", "webhook"), results):
    if isinstance(outcome, Exception):
        log.warning("notify sink failed", sink=sink, error=str(outcome))
```

---

## 3. Semaphore-bounded pool — capping in-flight I/O

The Go "every goroutine is Bounded" rule ports unchanged: never spawn one task per element
of an unbounded input. Bound in-flight work with an `asyncio.Semaphore` acquired *inside*
each task, still under a `TaskGroup` so tasks stay Owned and Joined.

```python
async def import_all(asset_ids: list[str], uow, *, max_in_flight: int = 20) -> None:
    """Process a large batch with at most `max_in_flight` concurrent DB round-trips.
    The bound is the connection-pool size, not a guess."""
    sem = asyncio.Semaphore(max_in_flight)

    async def one(asset_id: str) -> None:
        async with sem:                    # blocks the 21st task until a slot frees
            await import_asset(asset_id, uow)

    async with asyncio.TaskGroup() as tg:
        for asset_id in asset_ids:
            tg.create_task(one(asset_id))
    # exits only after every import finished; any single failure cancels the rest
```

Sizing rule (see `gil-and-processpool.md` for the derivation): the bound tracks the real
downstream capacity — the `asyncpg` pool's `max_size`, the broker's partition count for a
consumer, the remote API's rate limit — never "big enough". A `Semaphore(10000)` in front
of a 20-connection pool just queues 9980 tasks inside `asyncpg` and hides backpressure.

### Bounded results collection — a generic fan-in helper

```python
from typing import Awaitable, Callable, TypeVar

T = TypeVar("T")
R = TypeVar("R")


async def map_bounded(
    items: list[T],
    fn: Callable[[T], Awaitable[R]],
    *,
    limit: int,
) -> list[R]:
    """Apply an async fn over items with bounded concurrency, preserving input
    order in the result. Any single failure cancels the rest (TaskGroup)."""
    sem = asyncio.Semaphore(limit)
    results: list[R | None] = [None] * len(items)   # index-confined: each task writes one slot

    async def run(i: int, item: T) -> None:
        async with sem:
            results[i] = await fn(item)

    async with asyncio.TaskGroup() as tg:
        for i, item in enumerate(items):
            tg.create_task(run(i, item))
    return [r for r in results]                      # type: ignore[return-value]  # all filled or we'd have raised
```

`results[i] = ...` is ad-hoc confinement: each task writes exactly one index, no two
tasks share a slot, and the list is read only after the group joins — the direct analog
of the Go fan-in example's per-goroutine destination variable, no lock required.

---

## 4. Timeouts — `asyncio.timeout` and `wait_for`

`asyncio.timeout()` (3.11+) is the preferred deadline mechanism. It cancels the body by
raising `CancelledError` inside it, then re-surfaces that at the boundary as
`TimeoutError`:

```python
async def get_with_deadline(asset_id: str, uow) -> "Asset":
    try:
        async with asyncio.timeout(5.0):            # wall-clock seconds
            return await uow.assets.get(asset_id)
    except TimeoutError:                             # note: TimeoutError, not asyncio.TimeoutError (aliased in 3.11+)
        raise UpstreamTimeout(asset_id, seconds=5.0)
```

`asyncio.timeout_at(loop.time() + 5)` sets an absolute deadline instead of a relative one —
useful when a single overall budget is shared across several sequential awaits. The older
`asyncio.wait_for(aw, timeout=5)` still works and wraps a single awaitable, but `timeout()`
composes better (it wraps an arbitrary block, not one coroutine) and is preferred for new
code.

---

## 5. Cancellation and cleanup — never swallow `CancelledError`

`asyncio.CancelledError` inherits from `BaseException` (not `Exception`) *specifically* so
that a routine `except Exception:` will not accidentally swallow a cancellation. Respect
that:

```python
async def consume_loop(consumer, uow) -> None:
    try:
        async for msg in consumer:
            await handle(msg, uow)
    except asyncio.CancelledError:
        # graceful drain on shutdown: commit what we have, THEN re-raise so the
        # caller's cancellation actually completes. Swallowing it would hang shutdown.
        await consumer.commit()
        raise
    finally:
        await consumer.stop()                       # runs on both success and cancel
```

Rules:

- A bare `except:` or `except BaseException:` catches `CancelledError`. If you use either
  (you rarely should), you **must** re-raise after cleanup, or cancellation/timeout/
  shutdown silently break.
- Cleanup that must survive cancellation goes in `finally`, or in an `except
  asyncio.CancelledError:` that re-raises.
- Work that must finish *after* the surrounding scope is cancelled (a final commit, a
  drain) is the analog of Go deriving a fresh `context.Background()`-rooted context for a
  graceful drain: run it with `asyncio.shield(...)` so the in-flight cleanup await is not
  itself cancelled, or run it in a `finally`/`except` that has already caught the cancel.

```python
async def save_then_notify(record, uow, notifier) -> None:
    await uow.save(record)                           # must not be interrupted mid-write
    # even if the caller cancels us now, let the notify finish rather than tearing down
    await asyncio.shield(notifier.publish(record.id))
```

`CancelledError` **carries no value** — no tenant id, no trace span, no payload. It is the
signal only. Request-scoped values ride `contextvars` (see `python-service-layer`); the
cancellation signal rides `CancelledError`; the two are independent, which is the honest
gap versus Go's single `ctx` that carries cancellation *and* values together.

---

## 6. Blocking calls — never in a coroutine, push to an executor

A synchronous blocking call (`time.sleep`, a `requests` HTTP call, a CPU-heavy pure-Python
loop, a blocking file read) inside a coroutine blocks the **entire event loop** — every
other coroutine on that loop stalls, not just the caller. This has no Go analog: a blocking
syscall in one goroutine parks only that goroutine. Offload blocking work:

```python
import asyncio
from concurrent.futures import ThreadPoolExecutor

# I/O-bound blocking library with no async version -> a thread is fine (GIL releases on I/O):
loop = asyncio.get_running_loop()
result = await loop.run_in_executor(None, blocking_http_lib.get, url)

# CPU-bound work -> a PROCESS executor, never a thread (the GIL would serialise threads):
_CPU_POOL = ProcessPoolExecutor(max_workers=4)       # long-lived, module-level
digest = await loop.run_in_executor(_CPU_POOL, hash_document, big_bytes)
```

The thread-vs-process choice here is the same central axis as the SKILL body: threads for
blocking **I/O** (the GIL releases during the wait), processes for blocking **CPU** (the
GIL would serialise threads to no benefit). The process path is expanded in
`gil-and-processpool.md`.
