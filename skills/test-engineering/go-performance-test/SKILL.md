---
name: go-performance-test
description: >
  Teaches performance regression testing in Go — using benchmarks as a quality gate
  (establishing baselines, detecting regressions with benchstat in CI), distinct
  from the backend-engineer's optimization-time benchmarking. Covers writing stable
  benchmarks, allocation tracking, baseline management, statistically sound
  comparison, profiling a regression, and gating per-operation performance against
  agreed budgets. The shift-right guard that performance does not silently rot.
  Used by the test-strategist during Quality.
version: 1.1.0
phase: quality
owner: test-strategist
created: 2026-06-25
tags: [quality, go, performance, benchmark, benchstat, regression, baseline]
---

# Go Performance Test

## Purpose

Performance degrades one innocuous commit at a time — a needless allocation here, an N+1 query there — until the system is slow and no one knows which change did it. Performance regression testing prevents that: it establishes a **baseline** for the operations that matter, then fails CI when a change makes them measurably worse. Performance becomes a tested, gated property, not a thing you notice in production.

This is distinct from the backend-engineer's `go-performance-optimization` (which uses benchmarks to *make code faster* during development). Here, the same Go benchmarks are used to **gate against regression** — the test-strategist owns performance as a quality attribute with baselines and CI enforcement.

---

## Boundary with Backend Optimization

| | `go-performance-optimization` (backend-engineer) | `go-performance-test` (test-strategist) |
|---|---|---|
| Goal | Make a hot path faster | Stop performance from regressing |
| When | Dev-time, while optimising | CI, continuously, every change |
| Output | Optimised code + a one-off profile | Baselines + a regression gate |
| Question | "Can this be faster?" | "Did this get slower than agreed?" |

They share the benchmark *mechanism* (`testing.B`, `ReportAllocs`, pprof) but serve different owners and goals. No duplication: the engineer writes the benchmark to optimise; the strategist enrolls it into the baseline gate.

---

## Stable Benchmarks

A benchmark used for gating must be stable, or its noise will cause false regressions. The same discipline as a good test:

```go
func BenchmarkClassifyHandler(b *testing.B) {
    h, fixture := setupClassifyBench(b)   // setup OUTSIDE the timed loop
    b.ReportAllocs()
    b.ResetTimer()                        // exclude setup from the measurement
    for i := 0; i < b.N; i++ {
        if err := h.Handle(fixture.ctx, fixture.cmd); err != nil {
            b.Fatal(err)
        }
    }
}
```

Rules: setup outside the loop + `ResetTimer`; no allocation in the harness that isn't part of what you're measuring; deterministic fixtures (no random/network); benchmark a meaningful unit (a handler, a serialization, a query path), not a trivial getter.

---

## Baselines and benchstat

A single benchmark run is noise; performance is compared **statistically** across multiple runs with `benchstat`, which reports the delta and whether it's significant. Read the `p=` value, not just the percentage: a "+8%" with `p=0.451` is noise, a "+8%" with `p=0.000` is a regression. benchstat marks statistically indistinguishable results with `~` — a `~` is never a regression, whatever the raw delta says.

```bash
# Baseline (committed) vs the PR — multiple counts for statistical validity
go test -run=^$ -bench=. -benchmem -count=10 ./... > new.txt
benchstat baseline.txt new.txt
```

```
name              old time/op    new time/op    delta
ClassifyHandler   12.4µs ± 2%    18.1µs ± 3%    +46%  (p=0.000 n=10)   ← regression, gate fails
ClassifyHandler   320 B/op       512 B/op       +60%  (allocs up too)
```

The baseline is committed and updated deliberately (an intentional change that trades speed for a feature updates the baseline in the same PR, visibly reviewed) — never silently.

---

## The CI Gate

A performance gate runs the benchmarks against the baseline and **fails on a significant regression beyond a threshold** (e.g., >10% on a tracked operation). Because full benchmark runs are slower than unit tests, the gate runs on a dedicated job (and can be scoped to the critical operations), not inline with every fast test.

```
perf-gate:
  go test -run=^$ -bench=. -benchmem -count=10 ./internal/... > new.txt
  benchstat baseline.txt new.txt
  fail if any tracked benchmark regresses > threshold with significance (p < 0.05)
```

This catches the "innocuous" slow-down at the PR that introduced it — the cheapest possible moment.

---

## Tracked Operations and Budgets

Not everything is gated — only the operations whose performance matters to an SLO or a hot path:

| Operation | Why tracked | Budget signal |
|---|---|---|
| Command handler (classify) | On the write hot path | time/op + allocs/op baseline |
| Event serialization / envelope | Runs per event in the pipeline | allocs/op (GC pressure) |
| Read-model query | On the read hot path | time/op |
| Outbox drain batch | Throughput-critical | time/op per batch |

Allocations are tracked as first-class, not just time — they drive GC pressure and are often the leading indicator of a regression (the mechanical-sympathy link to the backend skill).

---

## Diagnosing a Regression

When the gate fails, the workflow mirrors the optimisation discipline:

1. **Confirm** it's real (re-run with higher `-count`; rule out a noisy runner).
2. **Profile** the regressed benchmark (`-cpuprofile`/`-memprofile`; `go tool pprof`) to find what changed.
3. **Fix** the regression, or — if the slowdown is an accepted trade-off — update the baseline with a reviewed justification.

Relate findings back to `go-performance-optimization` for the actual fix; this skill's job is to *catch and gate*, the backend's is to *optimise*.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Stable benchmarks | Setup outside the loop; deterministic; `ReportAllocs` | Noisy benchmarks causing false regressions |
| Statistical comparison | `benchstat` over multiple counts | Eyeballing single-run numbers |
| Committed baseline | Baseline tracked; updated deliberately + reviewed | No baseline; silent drift |
| Gated in CI | Regression beyond threshold fails the build | Performance measured but never gated |
| Right operations | Hot-path/SLO operations tracked | Gating trivial code; missing hot paths |
| Allocs tracked | allocs/op baselined alongside time | Only wall-time tracked |
| Clear boundary | Gating here; optimisation in the backend skill | Re-deriving optimisation guidance here |

---

## Anti-Patterns

- **Gating on a single run** — run-to-run variance on any machine exceeds most real regressions; only a benchstat comparison over `-count=10`-style samples is evidence.
- **Treating every delta as a regression** — a delta without significance (`~`, high `p`) is noise; gating on it teaches people to ignore the gate.
- **Benchmarking work the compiler can delete** — if the result is unused, the optimizer may remove the call and you benchmark an empty loop; keep the result (assign to a package-level sink) or check the error as the sample does.
- **Setup inside the timed loop** — fixture construction dominates the measurement; setup before `b.ResetTimer()`.
- **Silently updating the baseline** — a baseline change is a performance decision; it rides in the same PR as the change that caused it, visibly reviewed.
- **Gating on shared noisy runners without headroom** — a 2% threshold on a busy CI VM is a flake factory; widen the threshold or use a quiet dedicated job.
- **Tracking time but not allocations** — allocs/op regressions surface as GC pressure later; they are the leading indicator.

---

## Output Format

Produces the performance gate and its baselines:

```
internal/**/*_bench_test.go            (gating benchmarks for tracked operations)
testdata/perf/baseline.txt              (committed baseline)
.github/workflows/perf-gate.yml         (benchstat regression gate)
docs/quality/perf-budgets.md            (tracked operations + thresholds)
```
