# The GIL and ProcessPoolExecutor — Why CPU Parallelism Needs Full Processes

Reference material for `python-async-concurrency`. Explains, honestly, why CPython's GIL
forces `ProcessPoolExecutor` for CPU-bound parallelism, what a process costs relative to a
goroutine, when that cost is worth paying, and how to size the pool. Targets Python 3.11+.

---

## 1. What the GIL actually is (and is not)

The Global Interpreter Lock is a mutex inside the **CPython** interpreter that guarantees
only **one thread executes Python bytecode at a time**, regardless of how many OS threads
the process has. It is:

- **Fundamental, not incidental.** It is a property of the CPython *implementation* — how
  reference counting and object memory management are kept thread-safe cheaply — not a
  tunable, not a config flag, not a bug to be optimised away in a point release. You cannot
  architect around it within a single CPython process running pure-Python code.
- **Released during I/O and inside many C extensions.** When a thread makes a blocking
  syscall (socket read, disk read, `time.sleep`), it *releases* the GIL so another thread
  can run Python while it waits. That is why threads (and, better, `asyncio` coroutines)
  give real concurrency for **I/O-bound** work. Well-written C extensions (NumPy's array
  math, most `cryptography` primitives, `orjson`) also release the GIL around their heavy
  compute, so they can achieve real parallelism across threads — but this is a
  library-specific property, never something pure-Python code can assume.
- **Fatal to pure-Python CPU parallelism.** Two threads running a pure-Python hashing loop
  do **not** run in parallel; they take turns holding the GIL and the total throughput is
  that of one core minus lock-handoff overhead. Adding threads makes CPU-bound pure-Python
  code slightly *slower*, never faster.

The free-threaded ("no-GIL") CPython build, opt-in since roughly 3.13, removes this for
pure-Python code — but it is experimental, carries a single-thread performance cost, and
much of the C-extension ecosystem is not yet compatible. It is **tracked, not adopted**:
the frugal, boring-is-correct 2026 default assumes the GIL is present.

---

## 2. Why this forces `ProcessPoolExecutor` for CPU work

If one interpreter can only run one thread of Python bytecode at a time, the only way to
use N cores for pure-Python CPU work is **N separate interpreters** — i.e. N separate OS
processes. That is exactly what `concurrent.futures.ProcessPoolExecutor` gives:

```python
from concurrent.futures import ProcessPoolExecutor
import asyncio, os

# Long-lived, module-level. Sized deliberately (see §5), not per-request.
_CPU_POOL = ProcessPoolExecutor(max_workers=4)


def extract_entities(doc: bytes) -> list[str]:
    """Pure-Python CPU-bound work: runs in a worker PROCESS, on a real core."""
    ...                                     # heavy regex / parsing / classification
    return entities


async def extract_entities_async(doc: bytes) -> list[str]:
    """Await CPU work from an async handler without blocking the event loop."""
    loop = asyncio.get_running_loop()
    return await loop.run_in_executor(_CPU_POOL, extract_entities, doc)
```

Each submitted call:

1. **pickles** the arguments (`doc`) in the parent,
2. ships the bytes over a pipe to a worker process,
3. unpickles them there, runs the function on a dedicated core,
4. pickles the return value, ships it back, unpickles it in the parent.

That pickling + IPC round-trip is the price of real parallelism, and it is the price a
goroutine never pays.

---

## 3. Goroutine vs coroutine vs process — the comparison table

The single most important table in this skill. It is why the I/O-vs-CPU classification in
the SKILL body is load-bearing rather than stylistic.

| Property | Go goroutine | Python `asyncio` coroutine | Python worker process (`ProcessPoolExecutor`) |
|---|---|---|---|
| Unit | runtime-scheduled green thread | a suspended `async def` frame on one event loop | a full OS process with its own CPython interpreter |
| Startup cost | ~KB stack, microseconds | negligible — just a heap object | **milliseconds**: fork/spawn + interpreter init + module imports |
| Memory each | ~2 KB initial stack, grows on demand | a few KB of frame/closure state | **tens of MB**: a whole interpreter + imported modules, copied per worker |
| True CPU parallelism | **Yes** — M:N across `GOMAXPROCS` OS threads | **No** — one thread of Python bytecode (GIL) | **Yes** — separate interpreters on separate cores |
| Shares memory with parent | yes (same address space) | yes (same address space) | **No** — separate address space; data crosses by pickling/IPC (or explicit `shared_memory`) |
| Passing data in/out | direct references / channels | direct references / `await` | **pickle → pipe → unpickle** on every call boundary |
| Scheduling | preemptive (Go runtime) | cooperative (`await` yields) | OS preemptive |
| Right for | everything (I/O and CPU alike) | **I/O-bound** work only | **CPU-bound** pure-Python work only |
| Cancellation | `context.Context` | `CancelledError` (valueless) | cooperative only — a running process task is **hard to cancel** mid-flight |

The three rows that decide everything: goroutines are cheap **and** parallel, so Go uses
one primitive for both cases. Python coroutines are cheap but **not** parallel, so they
cover only I/O. Python processes are parallel but **expensive** (tens of MB, ms startup,
pickling every boundary, no shared memory, awkward cancellation), so they are the CPU-only
escape hatch — reserved, long-lived, and bounded, never the default reach.

---

## 4. When a process pool is worth it — and when it is not

`ProcessPoolExecutor` earns its overhead only when **compute time per task ≫ the pickling +
IPC + scheduling overhead of that task**. A rule of thumb:

- **Worth it:** each task does tens of milliseconds or more of pure-Python CPU work on
  arguments that pickle cheaply (small inputs, or inputs already as bytes). Example: hashing
  or parsing a batch of documents where each parse is 50–500 ms of CPU.
- **Not worth it — use a coroutine instead:** the task is I/O-bound (waiting on Postgres,
  Redpanda, S3, HTTP). Sending I/O work to a process pool pays full pickling + IPC cost for
  work that never needed a core; it is strictly slower than an `asyncio` coroutine and adds
  failure modes. This is the mirror-image mistake to the marquee anti-pattern.
- **Not worth it — restructure instead:** each task is tiny (sub-millisecond) but there are
  millions of them. The per-task pickle/IPC overhead dominates; **batch** many items into
  one larger task (`chunksize` on `executor.map`, or hand-batching) so each process call
  amortises the overhead over many items.
- **Not worth it — pickle cost dominates:** the argument or return value is huge (a
  multi-GB array). Pickling and copying it across the process boundary can cost more than
  the compute saved. Reach for `multiprocessing.shared_memory` (zero-copy for buffer-like
  data) or, better, escalate the work out of the request process entirely (next point).

Per `data-pipeline-implementation`'s standing escalation discipline, genuinely heavy or
sustained CPU/ML work (OCR, model inference, large-scale entity extraction) belongs in a
**separately-scaled worker service** — a broker-backed stage worker — not inline in a
request-serving or event-consuming process at all. The in-process `ProcessPoolExecutor` is
for *bounded, occasional* CPU work that must run locally, not a licence to run a document
pipeline inside a FastAPI handler.

---

## 5. Sizing the pools honestly

Two different pools, two different formulas. Neither is "one per core" taken on faith.

### CPU-bound process pool

Start from the core count, then **subtract for memory and for the parent's own load**:

```
max_workers  ≈  min( os.cpu_count(),  available_RAM_for_workers / per_worker_RSS )
```

- `os.cpu_count()` is the ceiling — more processes than cores just context-switch with no
  throughput gain (the same conclusion as Go capping CPU-bound work at `GOMAXPROCS`).
- **Per-process memory is the real constraint.** Each worker is a full interpreter plus
  every imported module — commonly tens to hundreds of MB. Eight workers each holding a
  200 MB model is 1.6 GB before any request arrives. Size to what RAM allows, which is
  frequently *fewer* than `cpu_count()`.
- Leave headroom for the parent event-loop process, which is still serving I/O.
- Measure the steady-state RSS of one warmed worker (`ps`, `tracemalloc`, or
  `resource.getrusage`) before setting the number; do not guess.

### I/O-bound coroutine / Semaphore bound

Coroutines are cheap, so the bound is **not** about core count — it is about the downstream
resource's real capacity:

```
Semaphore(limit)  where limit = the smallest of:
    - the asyncpg pool max_size          (don't queue 10k tasks behind 20 connections)
    - the broker partition count         (for a consumer — more gives no extra parallelism)
    - the remote API's rate/concurrency limit
```

This is the analog of the Go skill's `GOMAXPROCS × (1 + wait/service)` idea applied to the
*bounding resource* rather than the CPU: the coroutines themselves cost almost nothing, so
you size to whatever they are waiting on, and validate with a real saturation sweep rather
than trusting the arithmetic as exact.

---

## 6. Practical process-pool hygiene

- **Create it once, at composition root; keep it for the process lifetime.** The FastAPI
  `lifespan` (see `python-service-skeleton`) is the right place to construct and
  `.shutdown(wait=True)` it. A pool built per request pays fork + interpreter-import cost
  (milliseconds) that dwarfs the work.
- **Top-level, picklable target functions only.** `ProcessPoolExecutor` pickles the
  callable by reference; a lambda, a closure, or a nested function raises
  `PicklingError`. The worked `extract_entities` above is a module-level `def` for exactly
  this reason.
- **Cancellation is cooperative and weak.** Cancelling the `Future` returned by
  `run_in_executor` does **not** interrupt a task already running in a worker — the worker
  runs it to completion. Design CPU tasks to be short (or chunked) so a shutdown does not
  wait on a long uninterruptible unit. This is a genuine step down from Go, where a
  goroutine checks `ctx.Done()` cooperatively at loop boundaries.
- **A crashing worker is contained but disruptive.** If a worker process dies (OOM,
  segfault in a C extension), the pool raises `BrokenProcessPool` and every pending future
  fails; the pool must be recreated. Threads and coroutines cannot crash a peer this way.
  Keep per-worker memory bounded (§5) to avoid OOM kills.
- **`ThreadPoolExecutor` is the sibling for blocking *I/O*, not CPU.** When a library is
  blocking but I/O-bound (a synchronous DB driver, `requests`), a thread pool via
  `run_in_executor(None, ...)` is correct and far cheaper than a process pool — the GIL
  releases during the I/O wait, so threads make real progress. Reserve the process pool for
  work that actually burns a core.
