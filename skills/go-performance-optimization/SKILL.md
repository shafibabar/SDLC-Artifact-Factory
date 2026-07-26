---
name: go-performance-optimization
description: >
  This plugin's performance-engineering standard, covering both memory and
  execution-time optimization explicitly. Covers: the full pprof profiling
  workflow (CPU/heap/goroutine/block/mutex profiles, which question each
  answers, flame-graph reading, go tool trace for latency, runtime.ReadMemStats
  for soak-test stability — references/profiling-workflow.md); the memory
  optimization standard (the generalized Preallocate Slices and Maps rule
  drainOnce is one instance of, sync.Pool for high-churn allocations and its
  reset/no-retain-after-put correctness hazards, avoiding unnecessary interface
  boxing on hot paths, strings.Builder vs quadratic concatenation —
  references/memory-optimization-standard.md); the execution-time optimization
  standard (algorithmic-complexity-first discipline before any micro-
  optimization, a concrete three-question decision test for premature
  optimization, and the measure-first hard gate: no optimization PR merges
  without a benchmark proving the improvement —
  references/execution-time-optimization-standard.md); and the
  benchmark-writing standard (testing.B conventions, b.ReportAllocs() always
  on, comparing before/after via benchstat, and the precise non-duplicating
  boundary with go-makefile's single-run dev-time bench target and
  go-performance-test's CI-gated regression gate —
  references/benchmark-writing-standard.md). Used by the backend-engineer
  during Implement whenever code is being optimized for allocation count, GC
  pressure, or execution time.
version: 2.0.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, performance, allocation, escape-analysis, sync-pool, pprof, benchmark, algorithmic-complexity, execution-time]
related: [go-domain-model, go-event-publisher, go-concurrency-patterns, go-makefile, go-performance-test, go-error-handling]
---

# Go Performance Optimization

## Purpose

Performance work in Go covers two distinct dimensions, and this skill governs both explicitly: **memory** (allocation count, GC pressure, heap growth) and **execution time** (CPU spent, algorithmic complexity, latency). Neither substitutes for the other — a change that cuts allocations but leaves an `O(n²)` algorithm in place, or one that shaves nanoseconds off a function nobody's profile flagged, both fail this standard.

The governing rule, ahead of every technique below: **measure first.** A profile identifies the hot path; an algorithm's complexity class decides whether the hot path even needs a constant-factor trick; a benchmark proves whether the change actually helped. Skipping any of the three is an unverified guess wearing optimization's clothes. Most code should be simple and obvious; a small, profiled minority earns these techniques.

---

## Boundary With Sibling Skills — Read Before Reaching for a Reference

This skill owns the **optimization workflow methodology**: profiling, algorithmic-complexity reasoning, which allocation technique to apply and when, and proving a change helped. Three adjacent skills own non-overlapping pieces this skill cites, not restates: `go-concurrency-patterns` owns concurrency-*specific* memory costs (goroutine stack cost, worker-pool sizing, channel-buffer tradeoffs) and goroutine-dump stack-trace interpretation for a live incident; `go-makefile` owns the single-run, dev-time `bench` target (quick, noisy, directional only — never evidence for the gate below); `go-performance-test` owns the CI-gated, statistically-valid `benchstat`-vs-baseline regression gate on every subsequent change, where this skill's benchmarks prove one specific PR helped.

---

## Profiling Workflow

Pick CPU profile for "where is time going," heap/memory profile for "where do allocations come from," goroutine profile for "how many goroutines, and is the count stable." `net/http/pprof` is exposed only on a separate, internal-only admin port — never the public API port. Full command reference, the goroutine-profile boundary with `go-concurrency-patterns`' incident runbook, flame-graph reading rules, `go tool trace` for latency problems, and `runtime.ReadMemStats` for soak-test stability: `references/profiling-workflow.md`.

---

## Memory Optimization Standard

Apply only where a profile shows the path is genuinely hot:

- **Preallocate Slices and Maps** — any slice/map whose maximum size is knowable before the loop starts (`make([]T, 0, knownBound)`) — never a bare `var` grown by `append` alone. `go-event-publisher`'s `drainOnce` (bounded by `r.batch`, the same value already used as the query's `LIMIT`) is the canonical worked instance of this rule, not a separate one.
- **`sync.Pool`** for high-churn allocations on a profiled hot path — reset/zero on `Get` or before `Put`, and never retain a reference after `Put` (the next `Get` can hand the same object to another goroutine; that's a data race, not just a smell).
- **Avoid unnecessary interface boxing** — passing a concrete value through an `interface{}`/`any` parameter on a hot path (`fmt.Sprintf`, `log.Printf` in a tight loop) forces a heap allocation a concretely-typed parameter wouldn't need.
- **`strings.Builder`**, not `+=` concatenation, in any loop — concatenation is quadratic-cost; `Builder` is amortized linear, the same growth strategy `append` uses.

Full standard, the generalized-rule reasoning, and every worked example: `references/memory-optimization-standard.md`.

---

## Execution-Time Optimization Standard

**Check the algorithm's complexity class before reaching for any allocation trick.** An `O(n²)` fix beats any `O(n)` micro-optimization — no preallocation or pooling closes a complexity-class gap. The concrete decision test before optimizing anything: (1) has a profile identified this exact spot as consuming a meaningful share of the budget, (2) is there a stated SLO this code is failing, (3) would fixing the algorithm matter more than a constant-factor trick. A "no" on (1) or (2) means stop. Full test, the algorithmic worked example, and the deepened optimization workflow: `references/execution-time-optimization-standard.md`.

---

## Measure-First: The Hard Gate

**No optimization change merges without a benchmark demonstrating the actual improvement, compared old-vs-new via `benchstat` over multiple runs.** A PR justified by "this should be faster" or "this avoids an allocation," with no attached before/after numbers, is rejected on that basis alone — the same standing an untested bug fix has in this repo. This gate is applied by a reviewer reading the evidence on the specific PR making the change; it is distinct from, and does not substitute for, `go-performance-test`'s automated CI regression gate on every later change. Full workflow: `references/execution-time-optimization-standard.md`.

---

## Benchmark-Writing Standard

Every performance-critical function gets a `func BenchmarkX(b *testing.B)` with setup outside the timed loop, `b.ResetTimer()` immediately after, and **`b.ReportAllocs()` always on** — allocation count is often a better signal than wall time, since it drives GC pressure. Compare before/after with `benchstat old.txt new.txt` over `-count=10` runs; read the `p=` value, and treat a `~`-marked delta as no change, not a win. Full conventions and the precise, non-duplicating boundary with `go-makefile`'s single-run target and `go-performance-test`'s CI gate: `references/benchmark-writing-standard.md`.

---

## The unsafe Package

`unsafe` (e.g., zero-copy `[]byte`↔`string`) is **forbidden unless** a benchmark proves a material win on a genuinely hot path *and* the use is reviewed and commented with the profile that justifies it. The default answer is no — correctness and clarity outrank micro-optimisation.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Measure-first hard gate | Optimisation PR includes benchstat before/after evidence | "Should be faster" claim with no numbers |
| Right profile for the question | CPU for time, heap for allocations, goroutine for count/stability | Guessing which profile to pull, or skipping profiling |
| Algorithm checked before micro-optimization | Complexity class + the three-question decision test applied before any technique | `O(n²)` left in place while allocation tricks are applied around it |
| Preallocation applied | `make(..., 0, knownBound)` wherever the bound is in scope | Repeated `append` growth on a knowable-size loop |
| `sync.Pool` correctness | Reset on get/before put; never retained after put; profile-justified | Stale state leaking across reuses; retained references; cargo-cult pooling |
| Interface boxing avoided on hot paths | Concretely-typed hot-path signatures | `fmt`/`any`-boxing in a tight loop |
| `strings.Builder` used | Loop-built strings use `Builder`, `Grow` when estimable | `+=`/`fmt.Sprintf` concatenation in a loop |
| Benchmark hygiene | `ReportAllocs`, `ResetTimer` after setup, deterministic, result not elided | Setup timed; nondeterministic; result silently optimized away |
| `unsafe` gated | Benchmarked, reviewed, commented | `unsafe` for unproven micro-gains |

---

## Anti-Patterns

- **Optimising from intuition** — "maps are slow," "reflection is the problem" — without a profile. The hot path is almost never where instinct says it is.
- **Fixing allocations before fixing the algorithm** — applying every technique here to an `O(n²)` loop instead of replacing it with an `O(n)` one.
- **Trusting a single benchmark run, or merging with no before/after numbers** — run-to-run variance exceeds most real regressions; the measure-first gate exists to block exactly this.
- **`sync.Pool` as a cargo cult, or retaining a pooled object after `Put`** — the former adds complexity for nothing; the latter is a data race the next `Get` will trigger.
- **`pprof` on the public port** — exposes heap contents and a DoS lever; internal admin port only.
- **Trading clarity for unmeasured nanoseconds** — an unreadable "fast" version that benchmarks identical to the simple one is pure cost.
- **Optimising against the SLO you don't have** — without a target, "faster" has no finish line; set the budget before chasing it.

---

## Output Format

Produces Go benchmarks and profile-justified optimisations (the optimisation lives in the relevant package; the evidence lives beside it):

```
*_test.go                      (BenchmarkXxx with b.ReportAllocs(), per the benchmark-writing standard)
docs/perf/<path>-profile.md    (the profile + benchstat before/after evidence required by the measure-first gate)
```
