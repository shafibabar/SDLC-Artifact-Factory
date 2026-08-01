---
name: python-async-concurrency
description: >
  Teaches the backend-engineer Python async concurrency — asyncio.TaskGroup
  (3.11+, cancels sibling tasks on first failure, the errgroup analog) for
  I/O-bound fan-out, the GIL as a fundamental (not incidental) limit meaning
  true CPU parallelism needs ProcessPoolExecutor (full processes, pickling, no
  shared memory — categorically heavier than goroutines), asyncio.CancelledError
  as the context-cancellation analog (carries no value), and the
  I/O-bound-coroutines vs CPU-bound-processes decision. The widest Go→Python
  divergence; the Python analog of go-concurrency-patterns.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, python, asyncio, taskgroup, gil, processpool, cancellation, concurrency, coroutine, async]
produces: python-concurrency-package
domain: backend
status: stable
related: [go-concurrency-patterns, python-service-layer, python-event-consumer]
---

# Python Async Concurrency

## Purpose

This is the Python analog of `go-concurrency-patterns`, and the widest divergence in the
whole `python-*` roster. Go and Python reach concurrency through structurally different
machinery: Go multiplexes thousands of cheap goroutines across `GOMAXPROCS` real OS
threads and gets true multi-core parallelism for free; CPython runs **one** thread of
Python bytecode at a time under the Global Interpreter Lock and gets its concurrency, for
I/O-bound work, from a single-threaded cooperative event loop (`asyncio`). The one
decision this skill exists to get right — the decision a naive port of the Go skill gets
wrong — is **I/O-bound work goes to coroutines; CPU-bound work goes to processes.**
Concurrency here still bounds latency and raises throughput; it is never decoration, and a
correct fast-enough sequential version always beats a concurrent one that merely looks
sophisticated.

---

## The Central Axis: I/O-Bound Coroutines vs CPU-Bound Processes

Before writing any concurrent Python, classify the work. This one fork governs every other
choice below and has no Go equivalent — in Go a goroutine serves both cases identically.

| Work is… | Because | Use | Never use |
|---|---|---|---|
| **I/O-bound** — waiting on Postgres (`asyncpg`), Redpanda (`aiokafka`), S3, HTTP | The GIL is *released* during the wait, so many coroutines make real progress on one thread | `asyncio.TaskGroup` / `gather`, `asyncio.Semaphore`-bounded pools | `ProcessPoolExecutor` (pointless pickling/IPC cost for work that never needed a core) |
| **CPU-bound** — document parsing, hashing, entity extraction, large JSON transforms | The GIL serialises pure-Python bytecode; more coroutines or threads add **zero** throughput and silently degrade to fully serial | `concurrent.futures.ProcessPoolExecutor` (separate OS processes, real cores) | `asyncio.Semaphore` "worker pool" of coroutines — it looks concurrent and runs serial |

The load-bearing failure: an `asyncio.Semaphore(10)`-bounded pool of coroutines is *correct*
for I/O-bound per-message work and *silently wrong* for CPU-bound per-message work — under
real CPU load it executes one task at a time no matter the limit, because only one thread
ever holds the GIL. This is the single most common way `go-concurrency-patterns`' "bounded
worker pool" language is ported wrong. Full worked pools, timeouts, and the fan-in
generic: `references/asyncio-patterns.md`. Why the GIL forces this and what a process
costs: `references/gil-and-processpool.md`.

Per `data-pipeline-implementation`'s standing escalation discipline, genuinely heavy
CPU/ML work (OCR, classification) belongs in a **separately-scaled worker service**, not
inline in a request-serving or event-consuming process at all — the `ProcessPoolExecutor`
guidance here is for bounded CPU work that must run in-process, not a licence to do OCR in
a FastAPI handler.

---

## asyncio.TaskGroup — the errgroup Analog (default for I/O fan-out)

`asyncio.TaskGroup` (Python 3.11+) is the default for parallel I/O-bound stages needing
error propagation and coordinated cancellation. It is the direct analog of Go's
`errgroup`: the instant any child task raises, the group **cancels every sibling** and,
at the `async with` exit, raises the collected failures. Reach for it before hand-rolling
`create_task` + a results list, exactly as the Go skill reaches for `errgroup` before
`WaitGroup` + a channel.

```python
async def load_asset_view(asset_id: AssetId, uow) -> AssetView:
    async with asyncio.TaskGroup() as tg:            # spawns are Owned by the group
        asset_t = tg.create_task(uow.assets.get(asset_id))
        gaps_t  = tg.create_task(uow.gaps.for_asset(asset_id))
    # reached only if BOTH succeeded; either failure cancels the other and raises here
    return AssetView(asset=asset_t.result(), gaps=gaps_t.result())
```

Two honest divergences from `errgroup`, both critical, both expanded in
`references/asyncio-patterns.md`:

- **It raises an `ExceptionGroup`, not a single error.** If two siblings fail concurrently,
  both are collected; you unwrap with `except* NotFoundError:` (PEP 654 `except*`), not a
  plain `except`. `errgroup` surfaces only the first error and drops the rest — `TaskGroup`
  keeps them all. A handler that writes `except NotFoundError` around a `TaskGroup` will
  miss the exception because it is *wrapped*.
- **`gather` is the older, weaker tool.** `asyncio.gather(*aws)` does **not** cancel
  siblings on first failure by default (`return_exceptions=False` still lets the others run
  to completion in the background) and leaks tasks on cancellation. Prefer `TaskGroup`;
  the `gather`-vs-`TaskGroup` decision table is in `references/asyncio-patterns.md`.

---

## Bounding Concurrency — Semaphore, not "spawn per item"

The Go rule "every goroutine is Bounded" carries over unchanged: never spawn one task per
element of an unbounded input. For I/O-bound fan-out over many items, cap in-flight work
with an `asyncio.Semaphore` acquired *inside* each task, still under a `TaskGroup` so the
tasks stay Owned and Joined:

```python
sem = asyncio.Semaphore(20)                          # measured bound, never "big enough"
async def bounded(item):
    async with sem:
        return await handle(item)                    # only 20 in flight at once
async with asyncio.TaskGroup() as tg:
    for item in batch:
        tg.create_task(bounded(item))
```

The limit is a measured bound tied to the downstream's real capacity (connection-pool
size, broker partition count), never a guess. Sizing derivation and the CPU-vs-I/O worker
count formula: `references/gil-and-processpool.md`.

---

## Cancellation: asyncio.CancelledError — the context.Context analog (but valueless)

`asyncio.CancelledError` is Python's cancellation-propagation primitive, the analog of a
cancelled `context.Context`. When a `TaskGroup` sibling fails, when `asyncio.timeout()`
fires, or when a task is `.cancel()`-ed, `CancelledError` is *raised inside* the awaiting
coroutine at its next `await` point. Discipline:

- **Never swallow it.** A bare `except Exception:` does **not** catch `CancelledError` in
  3.8+ (it inherits from `BaseException`, deliberately) — but `except BaseException:` or a
  bare `except:` does, and swallowing it breaks cancellation. If you must run cleanup on
  cancel, catch it, do the cleanup, and **re-raise**.
- **It carries no value.** Like Go's `context.Context` *cancellation signal* but unlike the
  whole `context.Context` object, it carries no tenant id, no trace span, no deadline
  payload — request-scoped values travel by `contextvars` (see `python-service-layer`),
  cancellation travels by `CancelledError`, and the two are separate mechanisms. This split
  is the honest gap versus Go's single `ctx` that carries both.
- **Timeouts are cancellation.** `async with asyncio.timeout(5):` cancels the body by
  raising `CancelledError` internally and re-surfacing it as `TimeoutError` at the boundary.
  Wrap the awaitable, not a `time.sleep`. Worked timeout/cancel/cleanup examples:
  `references/asyncio-patterns.md`.

---

## The GIL, Stated Honestly

The GIL is not an incidental wart to be tuned away — it is a defining property of CPython:
only one thread executes Python bytecode at a time, no matter how many OS threads exist. So
Python's threading gives concurrency for I/O-bound work (the GIL releases during I/O waits)
but **no CPU parallelism for pure-Python code at all**. The only true-parallelism escape
hatch is `ProcessPoolExecutor` — full separate OS processes, each with its own interpreter,
no shared memory by default, pickling every task's input and output across the process
boundary. That is categorically heavier than a goroutine (a ~KB runtime-scheduled stack) —
so process pools are long-lived and bounded well below core count once per-process memory
is counted, never spun up per request. The full why, the pickling cost, when a process pool
earns its overhead, and the goroutine-vs-coroutine-vs-process comparison table live in
`references/gil-and-processpool.md`. (The experimental free-threaded / no-GIL CPython build
is tracked but **not** adopted — it is not the frugal, boring-is-correct 2026 default.)

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Work classified first | I/O-bound → coroutines; CPU-bound → `ProcessPoolExecutor` | Semaphore-bounded coroutine pool used for CPU-bound per-item work |
| Owned / Bounded / Joined | Spawns under a `TaskGroup`; in-flight count capped by `Semaphore`/pool | Bare `create_task` with no group; one task per unbounded item |
| TaskGroup over gather | `TaskGroup` for fan-out needing sibling cancellation | `gather` where a failed sibling must stop the others but doesn't |
| ExceptionGroup handled | `except*` unwraps `TaskGroup` failures | plain `except` around a `TaskGroup` misses the wrapped error |
| Cancellation respected | `CancelledError` never swallowed; re-raised after cleanup | bare `except:` / `except BaseException:` eats the cancel |
| Values vs cancellation split | tenant/trace via `contextvars`; cancel via `CancelledError` | expecting `CancelledError` to carry request values |
| Process pool sized honestly | long-lived, bounded below core count for per-process memory | pool-per-request; naive "one worker per core" |

---

## Anti-Patterns

- **`asyncio.Semaphore` coroutine pool for CPU-bound work** — the marquee mistake. Looks
  concurrent, runs fully serial under the GIL. CPU work needs processes.
- **`ProcessPoolExecutor` for I/O-bound work** — pays pickling and IPC cost for work that
  a coroutine handles for free; strictly worse.
- **`gather` where sibling cancellation was needed** — one task fails, the rest keep
  burning resources in the background. Use `TaskGroup`.
- **plain `except` around a `TaskGroup`** — the real error is wrapped in an
  `ExceptionGroup`; catch with `except*`.
- **Swallowing `CancelledError`** — a bare `except:` breaks timeouts and shutdown; catch,
  clean up, re-raise.
- **`time.sleep()` / blocking calls in a coroutine** — blocks the *entire* event loop, not
  one task; use `await asyncio.sleep()`, and push blocking library calls to
  `run_in_executor`.
- **Fire-and-forget `asyncio.create_task(...)` with no reference** — the task can be
  garbage-collected mid-flight and its exception vanishes; keep it Owned by a `TaskGroup`.
- **Process pool spun up per request** — process startup + interpreter import dwarfs the
  work; the pool is long-lived and bounded.

---

## Output Format

Like `go-concurrency-patterns`, this skill governs how concurrency is written wherever it
appears in generated Python — it owns no single artifact file. Reusable plumbing (a bounded
fan-out helper, a shared process-pool provider) lives in a small internal module; every
`create_task`/pool spawn anywhere must satisfy Owned/Bounded/Joined and pass its
`pytest-asyncio` test before it is done:

```
app/pkg/concurrency/fanout.py        (TaskGroup + Semaphore bounded fan-out helper)
app/pkg/concurrency/cpu_pool.py      (long-lived ProcessPoolExecutor provider)
app/pkg/concurrency/test_*.py        (pytest-asyncio; cancellation + ExceptionGroup cases; written first)
```
