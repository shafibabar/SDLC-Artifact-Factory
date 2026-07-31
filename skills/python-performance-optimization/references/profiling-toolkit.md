# Profiling Toolkit — py-spy, scalene, tracemalloc

Command-by-command usage for the three profilers this skill mandates, with worked
examples against the DataAsset service (FastAPI + asyncpg + aiokafka). Read the
SKILL.md body first for *which* profiler to reach for; this reference is *how* to
run each and how to read its output.

All three are installed via `uv` as dev dependencies, never shipped in the
production image:

```bash
uv add --dev py-spy scalene
# tracemalloc is standard library — no install
```

---

## py-spy — Sampling a Live Process With No Code Change

py-spy is a sampling profiler written in Rust that attaches to a **running**
CPython process by PID and reads its call stack from *outside* the process, via
OS process-memory inspection. The interpreter being profiled does not import
anything, is not restarted, and runs a separate `py-spy` process — this is the
capability Go's `pprof` cannot match, because `pprof` requires the target to
import `net/http/pprof` and expose an endpoint. With py-spy you profile the pod
that is slow *right now*.

### The prod-safe sampling advantage

Because py-spy samples (default 100 Hz) rather than instrumenting every call, its
overhead on the target is negligible and there is **no observer effect** on the
hot loop — the numbers you read are the numbers production is actually
experiencing. `cProfile`, by contrast, hooks every function call and can inflate
wall time several-fold, distorting exactly the ratios you are trying to measure.
The rule this skill enforces: **cProfile never runs in production; py-spy is how
you profile production.**

### The three sub-commands

`py-spy dump` — a one-shot snapshot of every thread's current stack. Use it when
a pod is *hung* or pinned at 100% CPU and you want to see what it is stuck in,
right now, without recording:

```bash
# Inside the pod (or with SYS_PTRACE granted to a sidecar):
py-spy dump --pid 1
```

```
Thread 1 (idle): "MainThread"
    _run_once (asyncio/base_events.py:1906)
    run_forever (asyncio/base_events.py:603)
Thread 7 (active): "asyncio_0"
    _canonicalize_asset (app/domain/data_asset.py:88)   <-- pinned here
    normalize_batch (app/service/ingest.py:141)
    handle_scan_event (app/consumer/scan.py:57)
```

A stack pinned in a `.py` file of *your own* (not in `asyncio` or a socket read)
is the GIL-bound signal — see the diagnosis section of the SKILL body.

`py-spy record` — samples over a window and writes an interactive flame graph
(SVG) or speedscope profile:

```bash
py-spy record --pid 1 --duration 30 --format flamegraph --output /tmp/scan.svg
# or, launching the process under py-spy from the start:
py-spy record --output /tmp/scan.svg -- python -m app.consumer.scan
```

`py-spy top` — a live, `top`-like view of the functions consuming the most time,
refreshed continuously. Good for a quick "is it CPU or is it waiting" read
without producing an artifact.

### Reading the flame graph

A flame graph plots stacks as stacked bars: **width = share of samples (time)**,
**vertical = call depth**. Read it width-first, not top-down:

1. Find the **widest** boxes at any level — those consumed the most wall time.
   Depth is just call nesting; a deep-but-narrow tower is cheap.
2. A wide box whose children are all narrow is a **self-time hot spot** — the
   time is spent *in that function's own body*, the prime optimization target.
3. A wide box in `asyncpg`'s socket-read or `aiokafka`'s fetch frames means the
   time is **I/O wait**, not CPU — do not micro-optimize Python here; the fix is
   concurrency or pool tuning (see `optimization-patterns.md`).
4. A wide box in one of your own domain functions with narrow children is the
   **GIL-bound** case — the CPU is genuinely in your Python bytecode.

`--idle` includes idle threads (event loop parked on `select`); omit it to see
only threads doing work. For asyncio services, `--subprocesses` follows
`ProcessPoolExecutor` children so you can see whether the offloaded CPU work is
actually parallelizing across processes.

---

## scalene — Line-Level CPU, Memory, and the Python-vs-Native Split

scalene is a high-precision profiler that reports, **per source line**: CPU time,
peak memory, memory-growth rate, and copy volume — and it splits CPU time into
**Python time** versus **native (C-extension) time** versus **system time**. That
split is the single most useful thing scalene does for a Python service, because
it is how you *confirm* a GIL diagnosis rather than guess it.

```bash
# CLI-driven repro (a script that reproduces the hot path deterministically):
scalene --cpu --memory app/perf/repro_normalize.py

# HTML report for attaching to a PR:
scalene --html --outfile /tmp/normalize.html app/perf/repro_normalize.py

# Reduce noise to only the lines that matter:
scalene --reduced-profile app/perf/repro_normalize.py
```

### Reading the native-vs-Python column

```
       Memory  │ Time   Python │ native │ system │ Line
       ─────── │ ────── ────── │ ────── │ ────── │ ─────────────────────────────
         2 MB  │  71%    68%   │   2%   │   1%   │  out = {canon(k): v for k, v …}
        14 MB  │  22%     3%   │  19%   │   0%   │  digest = hashlib.sha256(buf)…
         0 MB  │   4%     0%   │   0%   │   4%   │  await conn.fetch(SQL, tenant)
```

- Line 1: **68% Python time** — the dict-comprehension is pure-Python CPU work
  holding the GIL. This is a **GIL-bound** hot spot; `asyncio` will not help it,
  and reducing per-key work or moving it to a `ProcessPoolExecutor` is the fix.
- Line 2: mostly **native time** — `hashlib` releases the GIL inside its C
  implementation, so this line already parallelizes across threads; it is *not*
  the GIL bottleneck even though it is 22% of wall time.
- Line 3: **system time** on an `await` — this is I/O wait; the GIL is released,
  and no Python optimization applies. Concurrency or pool tuning is the lever.

The memory column and its growth-rate sibling are scalene's tracemalloc-adjacent
view — a line with a high memory number *and* a persistent growth rate across the
run is an allocation hot spot or a leak; drill in with tracemalloc for the exact
allocating call sites.

### async note

scalene profiles asyncio code, but attributes time to whichever coroutine the
event loop is running. For a service, drive it with a deterministic repro script
that exercises one hot path, not the full server, so the numbers are readable.

---

## tracemalloc — Allocation Tracking and Leak Detection

tracemalloc is in the standard library and answers the question py-spy and
scalene do not answer precisely: **exactly which call sites allocate, and is
memory growing over time.** It is the Python analog of Go's heap profile. It
works by snapshot-diffing: start tracing, snapshot, run the workload, snapshot
again, and compare.

### Top allocation sites

```python
import tracemalloc

tracemalloc.start(25)  # keep 25 frames of traceback per allocation

# ... exercise the hot path once ...
snapshot = tracemalloc.take_snapshot()
for stat in snapshot.statistics("lineno")[:10]:
    print(stat)
```

```
app/domain/data_asset.py:88: size=41.2 MiB, count=512011, average=84 B
app/service/ingest.py:141:   size=12.8 MiB, count=160003, average=84 B
```

512k `DataAsset`-adjacent objects at 84 B each is the churn signal — the fix is
`__slots__` and generator streaming (see `optimization-patterns.md`), not a pool.

### Soak-test leak detection — the diff

The high-value use is comparing two snapshots taken *far apart* under sustained
load, which surfaces objects that accumulate rather than being collected:

```python
tracemalloc.start(25)
baseline = tracemalloc.take_snapshot()

for _ in range(100_000):
    handle_scan_event(sample_event())   # the workload under test

current = tracemalloc.take_snapshot()
for stat in current.compare_to(baseline, "lineno")[:10]:
    print(stat)   # positive size_diff = net growth = candidate leak
```

```
app/consumer/scan.py:57: size=88.4 MiB (+88.4 MiB), count=100000 (+100000)
```

A `count` that scales 1:1 with iterations and never drops is a retained
reference — a cache without eviction, an unbounded list, a closure capturing
per-event state. This is the tool that catches the slow OOM a flame graph never
shows.

### Cost and caveat

tracemalloc roughly doubles memory and adds meaningful CPU overhead while
tracing, so it is a dev/staging or short-window tool, not a permanently-on
production setting. Its `start(nframe)` depth trades traceback detail for
overhead — 25 frames is generous; drop to a handful for a lighter touch.

---

## Which One, One More Time

| Question | Tool | Why |
|---|---|---|
| Where is time going in a live prod process I can't restart? | **py-spy** | Attaches by PID, no code change, no observer effect |
| Which exact line burns CPU, and is it Python or native? | **scalene** | Line-level, splits Python/native/system time |
| What is allocating, and is memory leaking over a soak? | **tracemalloc** | Snapshot-diff of allocation sites |
| Deterministic per-call counts in a unit repro? | cProfile | Heavy overhead — dev only, never production |
