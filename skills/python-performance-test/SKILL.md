---
name: python-performance-test
description: >
  Teaches the backend-engineer to write Python performance tests —
  pytest-benchmark micro-benchmarks and throughput tests with regression
  thresholds in CI, measuring the right unit (a hot function, a
  serialization path), and the distinction from
  python-performance-optimization (this GUARDS against regression; that
  IMPROVES). The Python analog of go-performance-test.
version: 1.0.0
phase: quality
owner: backend-engineer
created: 2026-07-31
tags: [quality, python, performance, benchmark, pytest-benchmark, regression, baseline, ci-gate, throughput, async]
produces: performance-regression-gate
domain: testing
status: stable
related: [go-performance-test, python-performance-optimization, python-load-test]
tools: [Bash]
---

# Python Performance Test

## Purpose

Performance degrades one innocuous commit at a time — a needless `dict` copy here, a switch from `orjson` to `json` there — until the `ClassifyDataAsset` path is slow and no one knows which change did it. This skill closes that gap with two things no other skill provides: a **committed statistical baseline** produced by `pytest-benchmark`, and a **CI job that fails the build** when a change regresses a tracked micro-benchmark beyond a reasoned tolerance. Performance becomes a tested, gated property, not a thing noticed in production. Authored and run by the backend-engineer during Quality.

---

## Guards vs Improves — The Boundary With python-performance-optimization

These two skills share the `pytest-benchmark` machinery for opposite jobs. Getting this wrong duplicates work the other skill owns:

| | `python-performance-optimization` | `python-performance-test` (this skill) |
|---|---|---|
| Verb | **IMPROVES** — makes a profiled hot path faster | **GUARDS** — fails CI when any later change makes it slower |
| What runs | One hand-run before/after `pytest-benchmark` pair while actively optimizing; py-spy / scalene / tracemalloc profiles | A committed baseline JSON + a `--benchmark-compare-fail` gate on every subsequent PR |
| Owns | Profiler selection, GIL-vs-I/O diagnosis, allocation-churn reduction, the async-vs-process decision | The stored baseline file, the tolerance threshold, the merge-blocking CI job |

This skill does **not** restate profiling, GIL-vs-I/O diagnosis, or allocation-reduction technique — that is `python-performance-optimization`. This skill's territory is what happens to a benchmark **after** it exists: enrollment, a stored baseline, the percentage-threshold comparison, and the CI gate.

The other boundary is **shift-right**: `python-load-test` (Locust, black-box, against the deployed FastAPI service through Linkerd mTLS) proves the *real system* holds its p99 under sustained traffic. This skill's `pytest-benchmark` micro-test is an **in-process proxy** — it calls a handler or a pure function directly, never crosses a network boundary, and deliberately excludes I/O. The two are complementary, never substitutes.

---

## Measure the Right Unit

A benchmark is only worth gating if it measures a unit whose regression matters and whose timing is *deterministic*. Track:

- **A hot pure function** — a domain calculation (`DataAsset` sensitivity scoring, a classification rule sweep over a batch), evaluated once per request or once per row.
- **A serialization path** — Pydantic `model_dump()` / `orjson.dumps()` of a `DataAssetClassified` event envelope, on the hot outbox-write path.
- **A handler's in-process logic** — the command handler called directly against a fast fixture double for its `asyncpg` repository port, so the timed loop contains business logic only, never a real Postgres round-trip.

Do **not** benchmark I/O-bound work here — a real `asyncpg` query, an `aiokafka` produce to Redpanda, an S3 read. Their timing is dominated by the network and the broker, is non-deterministic run-to-run, and belongs in `python-load-test`. Full "what NOT to benchmark" rule with reasoning: `references/throughput-and-ci.md`.

---

## pytest-benchmark Micro-Benchmarks

`pytest-benchmark` supplies a `benchmark` fixture that calls your callable many times, discards warmup rounds, and reports `min / median / mean / stddev / ops`. A tracked benchmark lives in `tests/benchmarks/test_*_bench.py` and is enrolled by that path convention — no separate manifest. Use `benchmark.pedantic(...)` when you need explicit `rounds`, `iterations`, and `warmup_rounds` control for a very fast function.

One Python-specific wrinkle the Go analog never faces: the `benchmark` fixture calls a **synchronous** callable, but the hot paths here are `async def`. Wrap the coroutine in a sync runner rather than benchmarking `asyncio.run`'s overhead repeatedly. The fixture usage, the async-wrapping pattern, `pedantic` mode, the stats fields, and two worked benchmarks (an `orjson` serialization path and a `DataAsset` domain calc) are in `references/pytest-benchmark-setup.md`.

---

## The CI Regression Gate — Stored Baseline, Never Automatic

`pytest-benchmark` saves a run to JSON (`--benchmark-save` / `--benchmark-autosave`) under `.benchmarks/`; a later run compares against it and **fails the build** when a tracked stat regresses past a threshold. This repo's committed baseline is deliberate, regenerated only two ways: (1) inside the same PR that knowingly trades speed for a feature, visibly reviewed; (2) on a scheduled cadence tied to tagged releases. **The baseline is never regenerated automatically on every merge** — that would let a slow regression quietly become the new "normal," defeating the gate.

The reasoned default tolerance is **12%** on the **median** — the same figure `go-performance-test` uses, and for the same reason: it absorbs shared-CI-runner noise without hiding a real regression. The gate runs as its **own dedicated CI job**, never wired into the fast unit-test loop — a multi-round sweep is too slow for the PR-loop budget. Exact flags, the baseline-storage mechanics, the dedicated GitHub Actions job YAML, and the throughput/latency micro-test shape: `references/throughput-and-ci.md`.

---

## The Honest Python-vs-Go Divergence

`go-performance-test` gates on **two** signals: a 12% threshold **and** `benchstat`'s `p < 0.05` statistical-significance test, plus `allocs/op` from `b.ReportAllocs()`. Python has **neither built in**:

- **No significance test in the gate.** `pytest-benchmark`'s regression check is a raw percentage on a chosen stat (median), not a Mann-Whitney U test. To close that gap you either accept a slightly looser threshold to absorb the missing statistical guard, or adopt `asv` (airspeed velocity) for longer-horizon tracking. This repo takes the frugal path: median + a 12% threshold, run on a dedicated (quieter) job, no extra tool.
- **No allocation counter.** `pytest-benchmark` measures wall-time only — there is no `allocs/op` equivalent. Allocation regressions are caught separately, with `tracemalloc`, and that is `python-performance-optimization`'s territory, not a field in this gate.

Both divergences are stated plainly rather than papered over: the Python gate is honestly a wall-time-only, percentage-threshold gate. Full reasoning: `references/throughput-and-ci.md`.

---

## Diagnosing a Regression

1. **Confirm it's real** — re-run on the dedicated job at higher `rounds`; rule out a noisy runner before trusting one comparison.
2. **Profile it** — hand off to `python-performance-optimization` (py-spy on the running process, scalene for line resolution); this skill catches and gates, it does not re-teach diagnosis.
3. **Fix it, or update the baseline** — a deliberate trade-off rides in the same PR, reviewed, per the Stored Baseline section above.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Guards, not improves | Adds a baseline + CI gate; cites `python-performance-optimization` for technique | Re-teaches profiling or allocation reduction here |
| Right unit tracked | Hot pure function / serialization / in-process handler logic, deterministic | A real `asyncpg`/`aiokafka`/S3 call inside the timed loop |
| Async handled | Coroutine wrapped in a sync runner, not `asyncio.run` overhead measured | `async def` passed to the fixture untouched, or event-loop churn timed |
| Baseline committed, deliberate | `.benchmarks/` baseline tracked; regenerated only by reviewed PR or release cadence | Regenerated automatically on every merge |
| Threshold reasoned | 12% on median stated with CI-noise rationale; overridable via `sdlc-config-management` | Zero-tolerance (flaky) or unstated/arbitrary threshold |
| Dedicated CI job | Its own job, separate from the fast unit-test loop | Wired into the PR unit-test loop, or not gated at all |
| Gate blocks merge | Regression past threshold fails the build; only a fix or reviewed baseline-update unblocks | Measured but advisory; build passes regardless |
| Divergence honest | Wall-time-only + percentage-threshold stated; allocations deferred to `tracemalloc` | Claims `benchstat`-equivalent significance or `allocs/op` this stack lacks |

---

## Anti-Patterns

- **Benchmarking I/O here** — a real `asyncpg` query or `aiokafka` produce is non-deterministic and network-dominated; it belongs in `python-load-test`, never a micro-benchmark.
- **Passing a coroutine straight to `benchmark`** — the fixture calls sync callables; an un-wrapped `async def` either errors or times event-loop setup instead of the work.
- **Gating on a single run** — interpreter and GC variance exceeds most real regressions; only a saved-baseline comparison is evidence.
- **Silently updating the baseline** — a baseline change is a performance decision; it rides in the same PR, visibly reviewed, or on the scheduled cadence — never a script's automatic response to a failed gate.
- **Zero-tolerance thresholds on shared runners** — a flake factory; the reasoned 12% on median absorbs noise without hiding real regressions.
- **Claiming a significance test the gate does not have** — the compare-fail check is a percentage, not `p < 0.05`; state the divergence, do not pretend parity with `benchstat`.
- **Wiring the gate into the fast unit-test loop** — a multi-round sweep is too slow for the PR-loop budget; it runs as its own dedicated job.

---

## Output Format

- **`tests/benchmarks/test_*_bench.py`** — tracked micro-benchmarks using the `benchmark` fixture (or `benchmark.pedantic`), async paths wrapped in a sync runner, one meaningful case per benchmark function (per the enrollment convention above).
- **`.benchmarks/<machine>/baseline.json`** — the committed `pytest-benchmark` baseline. Regenerated only via a reviewed PR or the scheduled release cadence — never automatically on merge.
- **`.github/workflows/perf-gate.yml`** — the dedicated CI job: a multi-round sweep, a median-12% regression gate against the committed baseline, never wired into the fast unit-test loop. Exact YAML: `references/throughput-and-ci.md`.
- **`docs/quality/perf-budgets.md`** — the tracked-operations table with each benchmark's unit and why it is gated, reviewed on the same cadence `slo-definition`'s SLO document undergoes.
