# Optimization Patterns — GIL-Aware Fixes, Async-vs-Process, Churn Reduction, Pool Tuning

Once a profile (see `profiling-toolkit.md`) has identified the hot path *and*
classified it GIL-bound or I/O-bound, this reference is the catalog of fixes.
Every pattern here assumes the measure-first gate: a before/after number over
repeated runs, or it does not merge.

---

## The Measurement Harness — What "Before/After Numbers" Means

Python has no `benchstat`/`b.ReportAllocs()` baked into its test runner the way
Go does. The equivalent evidence is one of:

**`timeit` for a pure-function micro-benchmark** (no I/O):

```python
import timeit

n = timeit.repeat(
    stmt="normalize_batch(rows)",
    setup="from app.service.ingest import normalize_batch; from app.perf.fixtures import rows",
    repeat=7, number=100,
)
print(f"best of 7: {min(n)/100*1e6:.1f} µs/call")
```

Report the **minimum** of `repeat`, not the mean — the minimum is the run least
disturbed by GC pauses and OS scheduling, i.e. the closest to the true cost.

**`pytest-benchmark` for a comparison table checked into the PR**:

```python
def test_normalize_perf(benchmark, rows):
    result = benchmark(normalize_batch, rows)
    assert len(result) == len(rows)
```

```
------------------------------------------------ benchmark ------------------------------------------------
Name (time in us)          Min       Max      Mean    StdDev    Median
-----------------------------------------------------------------------
normalize_batch (before)  841.2   1,209.4    902.7     51.3     889.0
normalize_batch (after)   402.8     577.1    431.6     22.9     428.4
-----------------------------------------------------------------------
```

### Honest divergence from Go's benchmark model

Go's `testing.B` auto-scales `b.N` to a stable duration and `b.ReportAllocs()`
reports allocation count as a first-class number in the same run. Python has no
equivalent auto-scaling or built-in alloc count in `pytest-benchmark` — allocation
evidence comes *separately*, from tracemalloc (`profiling-toolkit.md`). So a
Python optimization PR carries **two** artifacts where Go carries one: a timing
comparison (timeit/pytest-benchmark) and, when the change targets allocation, a
tracemalloc before/after. There is no single command that does both.

---

## GIL-Bound Fixes — When the CPU Is Genuinely in Your Python

Confirmed GIL-bound (scalene shows high *Python* time on your own lines). In
priority order — cheapest and most reversible first:

### 1. Reduce the per-item work (algorithm first)

The complexity-class check comes before every trick below. An `O(n²)` membership
test inside the hot loop dwarfs any constant-factor win:

```python
# Before: O(n) `in` on a list, inside an O(n) loop -> O(n²)
known = load_known_asset_keys()            # list[str]
new = [a for a in assets if a.key not in known]

# After: set membership is O(1) -> O(n) overall
known = set(load_known_asset_keys())       # set[str]
new = [a for a in assets if a.key not in known]
```

No profiler trick recovers a complexity-class gap; fix the algorithm, then
re-profile before reaching for anything else.

### 2. Push the hot loop into a GIL-releasing native library

Many C-extension libraries **release the GIL** during their compute-heavy calls,
which is why scalene attributes their time to "native" not "Python". If the hot
loop is numeric or bytewise, expressing it via such a library both speeds the
per-item work *and* lets it run in parallel across threads:

```python
# Before: pure-Python per-row hashing, GIL held the whole loop
digests = [hashlib.sha256(row).hexdigest() for row in rows]

# After: the same hashing, but each sha256() call releases the GIL internally,
# so a ThreadPoolExecutor genuinely parallelizes across cores here.
from concurrent.futures import ThreadPoolExecutor
with ThreadPoolExecutor(max_workers=4) as pool:
    digests = list(pool.map(lambda r: hashlib.sha256(r).hexdigest(), rows))
```

This is a **library-specific** exception, not a general escape hatch — it works
only because `hashlib` releases the GIL. Pure-Python loops in a `ThreadPoolExecutor`
do **not** parallelize; they serialize under the GIL and add thread overhead for
nothing. Verify with scalene that the target line is native-time before assuming
threads help.

### 3. Offload to a ProcessPoolExecutor — the true-parallelism fix

For pure-Python CPU work that cannot be pushed into a native library,
`ProcessPoolExecutor` is Python's only real multi-core primitive: separate OS
processes, each its own interpreter and GIL, so pure-Python bytecode runs
genuinely in parallel.

```python
from concurrent.futures import ProcessPoolExecutor
import asyncio, os

# Create ONCE at startup (FastAPI lifespan), never per-request.
_cpu_pool = ProcessPoolExecutor(max_workers=2)   # sized by memory, see below

async def canonicalize_many(rows: list[bytes]) -> list[dict]:
    loop = asyncio.get_running_loop()
    # run_in_executor keeps the event loop free while workers churn.
    return await loop.run_in_executor(_cpu_pool, _canonicalize_batch, rows)
```

**The ProcessPool cost model — why this is heavier than a goroutine:**

- **Pickling on every task boundary.** `rows` is pickled, sent over a pipe,
  unpickled in the worker; the result is pickled back. For large inputs this IPC
  cost can *exceed* the compute saved — measure the crossover. Objects that do
  not pickle (open connections, lambdas, local closures) cannot cross at all.
- **Full per-process memory.** Each worker is a complete interpreter with its own
  imported modules and heap — hundreds of MB is common. **Size the pool by
  available memory, never by `os.cpu_count()`** — a naive "one per core" pool
  OOMs a container long before it saturates CPU.
- **Startup latency.** Spawning a process is milliseconds, not microseconds;
  process-per-request is a documented anti-pattern. Always a long-lived bounded
  pool created at startup.

Because of all three costs, this repo's standing rule (`data-pipeline-implementation`)
is that **sustained** CPU/ML work — document parsing, OCR, entity extraction —
escalates out to a **separately-scaled worker service** behind a task queue
(`arq`/`taskiq`/Celery), not an inline `ProcessPoolExecutor` in the
request-serving process. The inline pool is only for bounded, occasional CPU
bursts a profile has proven.

---

## Async-vs-Process — The Throughput Decision Table

The single most consequential Python performance decision. Get the classification
(from `profiling-toolkit.md`) right first, then:

| Hot path is… | GIL during work | Right primitive | Wrong choice and why |
|---|---|---|---|
| Awaiting Postgres/Redpanda/S3 (I/O-bound) | Released | `asyncio.gather`/`TaskGroup` — cheap coroutine fan-out | `ProcessPoolExecutor` — pickling + process overhead for work that was never CPU-bound |
| Pure-Python CPU (JSON reshape, parse) | Held | `ProcessPoolExecutor` (or escalate to a worker service) | `asyncio` — coroutines serialize under the GIL and starve the loop, *raising* p99 for every other request |
| Numeric/bytewise via a native lib that releases the GIL | Released inside the call | `ThreadPoolExecutor` — real thread parallelism | `ProcessPoolExecutor` — unnecessary pickling when threads already parallelize |
| Mixed (I/O then a CPU burst per item) | Alternating | `asyncio` for the I/O + `run_in_executor` to a process pool for the CPU burst | Doing the CPU burst inline in the coroutine — blocks the loop for its whole duration |

The trap this table exists to prevent: throwing `asyncio` concurrency at
CPU-bound work. Coroutines are not threads; they share one thread of Python
execution. Ten CPU-bound coroutines under `asyncio.gather` run *fully serially*,
slower than a plain loop (scheduling overhead), while blocking every unrelated
request the loop was also serving.

---

## Churn Reduction — Reduction, Not Reuse (No sync.Pool)

Go reuses high-churn objects with `sync.Pool`. Python has no idiomatic
equivalent, and a hand-rolled pool is almost always a net loss (interpreter free
lists already recycle small objects; the pool's own bookkeeping and the
reset-correctness hazard cost more than they save). Reduce allocations instead.

### `__slots__` on hot, high-cardinality classes

A class without `__slots__` carries a per-instance `__dict__` (~100+ B of
overhead) and every attribute access goes through a dict lookup. For a class
instantiated per row in a large scan, `__slots__` removes the dict entirely:

```python
class DataAsset:
    __slots__ = ("asset_id", "tenant_id", "path", "kind", "version")

    def __init__(self, asset_id, tenant_id, path, kind, version):
        self.asset_id = asset_id
        self.tenant_id = tenant_id
        self.path = path
        self.kind = kind
        self.version = version
```

tracemalloc before/after over a 512k-row scan typically shows a 40–50% drop in
this class's total bytes, plus a small attribute-access speedup. **Caveats where
`__slots__` backfires:** it breaks multiple inheritance with other slotted
classes that define the same slot; it prevents adding attributes dynamically
(usually the point); and it is *not free to add later* if code elsewhere monkeys
attributes onto instances. Add it to genuinely hot, high-count classes a profile
flagged — not reflexively to every domain class.

### Generators over materialized lists

Do not build a giant list to iterate once:

```python
# Before: 100k dicts all resident at once -> memory spike + GC pressure
rows = [transform(r) for r in cursor.fetchall()]
for row in rows:
    await sink(row)

# After: one row resident at a time; constant memory
def transformed(cursor):
    for r in cursor:
        yield transform(r)

async for row in transformed(cursor):   # via an async generator in real async code
    await sink(row)
```

**Caveat where a generator hurts:** if you iterate the same sequence more than
once, a generator is exhausted after the first pass and re-running the pipeline
recomputes everything — materialize a list when it is genuinely reused, stream
when it is consumed once.

### Hoist invariant work out of loops

```python
# Before: recompiles the regex and re-encodes the constant every iteration
for a in assets:
    if re.match(r"^s3://", a.path):
        buf = a.path.encode("utf-8")

# After: compile/encode once; bind the method to a local
_S3 = re.compile(r"^s3://")
match = _S3.match
for a in assets:
    if match(a.path):
        buf = a.path.encode("utf-8")
```

Binding a hot method to a local (`match = _S3.match`) removes a global/attribute
lookup per iteration — a small but real win in a tight loop a profile flagged.

---

## asyncpg Connection-Pool and Statement-Cache Tuning

For an **I/O-bound** path, the highest-leverage tuning is usually the asyncpg
pool, not the Python code. Owned by `python-service-layer`; tuned here against
profile evidence.

```python
import asyncpg

pool = await asyncpg.create_pool(
    dsn=dsn,
    min_size=10,            # keep warm connections; avoid cold-connect latency under load
    max_size=20,            # cap: must stay under Postgres max_connections / replica count
    max_inactive_connection_lifetime=300.0,
    max_queries=50_000,     # recycle a connection after N queries (guards server-side bloat)
    statement_cache_size=1024,   # asyncpg prepares & caches statements per connection
)
```

- **`min_size`/`max_size`.** If a py-spy flame graph shows time parked in
  `pool.acquire`, the pool is exhausted — requests are queuing for a connection.
  Raise `max_size`, but never past what Postgres can serve
  (`max_connections` divided across every service replica and the physical
  per-tenant databases this product isolates). A pool larger than the DB can
  serve just moves the queue server-side and can tip Postgres over.
- **`statement_cache_size`.** asyncpg auto-prepares statements and caches them per
  connection; a cache too small for your query variety causes constant
  re-preparation. **Caveat:** the prepared-statement cache is incompatible with a
  server-side transaction-mode connection pooler (PgBouncer in `transaction`
  mode) — set `statement_cache_size=0` there, or the cached statement handle from
  one backend is reused against another and errors. Know your pooler mode before
  tuning this.
- **Batch, do not loop.** The most common I/O-bound self-inflicted wound is
  `await conn.fetchrow(...)` inside a Python loop (N round-trips). Replace with a
  single `conn.fetch` using `= ANY($1)` or `executemany`/`copy_records_to_table`
  for bulk writes — one round-trip. A flame graph wide on repeated `fetchrow`
  frames is this pattern; it is an algorithmic (round-trip-count) fix, not a
  micro-optimization.

---

## Caveats Summary

- **Free-threaded (no-GIL) CPython** (opt-in since ~3.13) would change the
  GIL-bound guidance materially — pure-Python threads would parallelize. It is
  not ecosystem-default or frugal-default in 2026; track it, do not build on it.
- **Native libraries releasing the GIL** (hashlib, NumPy, most crypto bindings)
  are a real but *library-specific* thread-parallelism exception — verify with
  scalene's native-time column, never assume.
- **Every pattern here is gated on a profile.** Applied without one, they are
  guesses that trade clarity for unmeasured microseconds — the top anti-pattern
  in the SKILL body.
