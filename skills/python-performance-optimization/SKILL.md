---
name: python-performance-optimization
description: >
  Teaches the backend-engineer to optimize Python service performance —
  measure-first with py-spy (can sample a running production process with no
  code change), scalene (CPU+memory+GPU line profiler), and tracemalloc for
  allocation tracking; reasoning about GIL-bound vs I/O-bound hot paths;
  reducing object churn (no sync.Pool equivalent); and the async-vs-process
  decision for throughput. The Python analog of go-performance-optimization.
version: 1.0.0
phase: quality
owner: backend-engineer
created: 2026-07-31
tags: [quality, python, performance, profiling, py-spy, scalene, tracemalloc, gil, asyncio, processpool, asyncpg, allocation, async]
related: [go-performance-optimization, python-async-concurrency, python-service-layer]
tools: [Bash]
---

# Python Performance Optimization

## Purpose

Performance work in a Python service covers two dimensions, and this skill governs both: **execution time** (CPU spent, algorithmic complexity, latency) and **allocation/memory** (object churn, GC pressure, heap growth). A change that cuts allocations but leaves an `O(n²)` algorithm in place, or one that shaves microseconds off a coroutine nobody's profile flagged, both fail this standard.

The governing rule, ahead of every technique below: **measure first.** A profile identifies the hot path; the algorithm's complexity class decides whether that path needs a constant-factor trick at all; a repeated timing proves the change actually helped. Skipping any of the three is an unverified guess wearing optimization's clothes. Most code should stay simple and obvious — a small, *profiled* minority earns these techniques.

Python adds one diagnosis Go does not have to make: **is the hot path GIL-bound (pure-Python CPU work, serialized by the Global Interpreter Lock) or I/O-bound (waiting on Postgres, Redpanda, S3)?** The two demand opposite fixes, and choosing wrong makes things worse. That fork governs everything below.

---

## Boundary With Sibling Skills — Read Before Reaching for a Reference

This skill owns the **optimization workflow methodology**: which profiler answers which question, GIL-vs-I/O diagnosis, allocation-churn reduction, and the async-vs-process throughput decision *once a profile has justified it*. Two adjacent skills own non-overlapping pieces this skill cites, not restates:

- `python-async-concurrency` owns the *correctness* of `asyncio.TaskGroup`, `asyncio.Semaphore` bounding, `ProcessPoolExecutor` lifecycle, cancellation, and the GIL's structural consequences. This skill only decides *when a profile says to reach for a process pool for throughput* — it does not re-teach how to run one safely.
- `python-service-layer` owns the Unit-of-Work transaction shape and `asyncpg` pool ownership. This skill only tunes that pool's *size/timeout* against profile evidence.

---

## Measure-First: The Hard Gate

**No optimization change merges without a before/after measurement demonstrating the actual improvement, taken over multiple repetitions** (`timeit`, `pytest-benchmark`, or a `py-spy` sample comparison), never a single run — run-to-run variance in a GC'd, JIT-free interpreter routinely exceeds the delta being claimed. A PR justified by "this should be faster" or "this avoids an allocation," with no attached numbers, is rejected on that basis alone — the same standing an untested bug fix has in this repo.

Unlike Go, Python has no `benchstat`/`b.ReportAllocs()` built into the test tool; the equivalent evidence is a `pytest-benchmark` comparison table or a pair of `py-spy`/`scalene` reports attached to the PR. Full measurement conventions and the honest divergence from Go's benchmark model: `references/optimization-patterns.md`.

---

## Profiler Selection — Pick the One That Answers Your Question

Three profilers, three distinct questions. Reaching for the wrong one wastes the session:

- **py-spy** — *"where is time going in a process I cannot or must not restart?"* A sampling profiler that attaches to a **running** process by PID and reads its stack from outside, in a separate process. It needs **no code change, no import, no restart** — this is its genuine, un-Go-like strength: you can `py-spy dump` or `py-spy record` against a live production pod experiencing the slowdown *right now* and get a flame graph, then detach. Sampling means near-zero overhead and no observer effect on the hot loop. Start here for any latency mystery in a deployed service.
- **scalene** — *"which exact line burns CPU, and which allocates?"* A line-level profiler that separates **CPU time, memory, and GPU** per line, and — critically for Python — distinguishes time spent in *Python* code from time spent in *native* (C-extension) code. That split is how you confirm a GIL diagnosis: high native-time on a line means the GIL is likely released there; high Python-time means it is held. Run it in a dev/staging repro when you need line resolution, not just a flame graph.
- **tracemalloc** — *"what is allocating, and is it leaking?"* Standard-library allocation tracker: snapshot, run the workload, snapshot again, diff the top allocation sites. This is the Python analog of Go's heap profile — it answers "where do the objects come from" and "is memory growing across a soak test," which py-spy and scalene do not answer precisely.

`cProfile` remains available for deterministic per-call counts in a unit-scoped repro, but it imposes heavy overhead and must never be attached to production — that is py-spy's job. Full command-by-command usage, worked flame-graph reading, the prod-safe sampling advantage, and scalene's native-vs-Python split: `references/profiling-toolkit.md`.

---

## GIL-Bound vs I/O-Bound Diagnosis — The Python-Specific Fork

Before applying any fix, classify the hot path. The two failure modes look similar in a latency graph and demand opposite remedies:

- **I/O-bound** — the coroutine spends its time *awaiting* Postgres, Redpanda, or S3. The GIL is **released** during those waits, so `asyncio` concurrency scales well. The fix is almost never "more CPU" — it is **more concurrency** (`asyncio.gather`/`TaskGroup` fan-out), **pool tuning** (asyncpg pool size, statement caching), or **removing a serialization point** (an accidental `await` in a loop that should have been a batched query). Reaching for a process pool here is pure overhead.
- **GIL-bound** — the hot path is *pure-Python CPU work* (JSON reshaping at scale, hashing, in-Python parsing), and scalene shows the time as Python-time, not native-time. No amount of `asyncio` helps: coroutines share one thread of Python execution, so CPU-bound coroutines run **fully serially** and starve the event loop, adding latency to every other request. The only true-parallelism fix is a `ProcessPoolExecutor` (separate OS processes, each its own interpreter), and per this repo's `data-pipeline-implementation` discipline, sustained CPU/ML work should escalate out to a separately-scaled worker service entirely rather than run inline.

The diagnosis tool is scalene's Python-vs-native time split plus a py-spy flame graph: if the hot frames are your own `.py` functions and native-time is low, it is GIL-bound. Full decision procedure, the async-vs-process throughput tradeoff table, and the ProcessPool cost model (pickling on every task boundary, full per-process memory): `references/optimization-patterns.md`.

---

## Reducing Object Churn — There Is No sync.Pool

Go's answer to high-churn allocation is `sync.Pool`. **Python has no idiomatic equivalent**, and hand-rolling one is almost always a loss: the interpreter's own free lists and the cost of a pure-Python pool's bookkeeping usually erase the benefit, and a pool that hands out a not-fully-reset object is a correctness hazard with none of Go's compiler help. So allocation work in Python is *reduction*, not *reuse*:

- **`__slots__`** on hot, high-cardinality classes (a `DataAsset` created per row in a large scan) drops the per-instance `__dict__`, cutting both memory and attribute-access time.
- **Generators over materialized lists** in pipelines — stream rows, do not build a 100k-element list to iterate once.
- **Hoist invariant work out of loops** — compiled regexes, `.encode()` of constant strings, attribute lookups bound to locals.
- **Avoid needless intermediate objects** on hot paths — chained comprehensions that each materialize, per-iteration f-strings for logs that are usually discarded.

Full worked examples, `__slots__` measurement, asyncpg pool/statement-cache tuning, and the honest caveats (when `__slots__` backfires, when a generator hurts): `references/optimization-patterns.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Measure-first hard gate | PR carries before/after numbers over repeated runs | "Should be faster" with no numbers |
| Right profiler for the question | py-spy for live/prod, scalene for line CPU+mem, tracemalloc for allocations | cProfile bolted onto production; guessing |
| GIL-vs-I/O classified first | Hot path labeled I/O- or GIL-bound before any fix | `asyncio` thrown at CPU-bound work; process pool at I/O-bound work |
| Algorithm checked before micro-optimization | Complexity class examined before line tricks | `O(n²)` left in place while churn tricks applied around it |
| Churn reduced, not pooled | `__slots__`/generators/hoisting; no hand-rolled object pool | Cargo-cult `sync.Pool` port that leaks state |
| Process pool justified | `ProcessPoolExecutor` only where a profile proves GIL-bound CPU work | Naive process-per-request; pool sized by core count not memory |

---

## Anti-Patterns

- **Optimizing from intuition** — "dicts are slow," "asyncio will fix it" — without a profile. The hot path is almost never where instinct says.
- **Throwing `asyncio` at CPU-bound work** — CPU-bound coroutines run serially under the GIL and starve the loop; this makes latency *worse*, not better.
- **Porting `sync.Pool`** — a hand-rolled Python object pool usually costs more than it saves and reintroduces a reset-correctness hazard the compiler won't catch.
- **`cProfile` in production** — its overhead distorts the very numbers you need; py-spy samples a live process with none of that.
- **Trusting a single run** — interpreter variance exceeds most real deltas; repeat or the measurement is noise.
- **Sizing a `ProcessPoolExecutor` by core count** — each worker is a full interpreter with full memory overhead; size by memory, and prefer escalating sustained CPU work to a separate service.

---

## Output Format

Produces profile-justified optimizations and the evidence beside them (the change lives in its package; the evidence lives under `docs/perf/`):

```
docs/perf/<path>-profile.md    (py-spy/scalene/tracemalloc output + before/after timing the measure-first gate requires)
tests/perf/test_<name>.py      (pytest-benchmark comparison, where a repeatable micro-benchmark is warranted)
```
