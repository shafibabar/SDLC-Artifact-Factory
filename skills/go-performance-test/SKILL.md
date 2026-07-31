---
name: go-performance-test
description: >
  This plugin's CI-gated performance-regression-testing standard for Go — the
  third and final owner in a three-way benchmark boundary alongside
  go-performance-optimization (optimization workflow and profiling
  methodology) and go-makefile (the single-run, dev-time `bench` target).
  This skill owns the thing those two only cite: the stored `benchstat`
  baseline, the exact `-count=10` comparison workflow, a reasoned tolerance
  threshold, and the CI job that fails a build on a statistically significant
  regression — never a silent auto-accept. Covers table-driven benchmark
  enrollment matching the unit-test convention
  (references/benchmark-and-regression-gate-standard.md, alongside the full
  baseline/CI-gate mechanics) and concrete numeric performance budgets tied to
  this repo's data-estate-mapping domain — an in-process p99 handler-logic
  budget and a per-request allocation budget, both derived from
  slo-definition's 800ms ClassifyDataAsset latency SLO and multi-tenancy-
  design's physical-isolation model (references/performance-budgets.md).
  Used by the test-strategist during Quality.
version: 2.0.0
phase: quality
owner: test-strategist
created: 2026-06-25
tags: [quality, go, performance, benchmark, benchstat, regression, baseline, ci-gate, performance-budget]
related: [go-performance-optimization, go-makefile, go-load-test, slo-definition, multi-tenancy-design, test-pyramid]
---

# Go Performance Test

## Purpose

Performance degrades one innocuous commit at a time — a needless allocation here, an N+1 query there — until the system is slow and no one knows which change did it. This skill closes that gap with two things neither sibling skill provides: a **committed statistical baseline**, and a **CI job that fails the build** when a change regresses beyond a reasoned tolerance. Performance becomes a tested, gated property, not a thing noticed in production. Authored and run by the test-strategist during Quality.

---

## The Three-Way Boundary — Read This Before Reaching for Any Reference

Three skills share the identical `testing.B`/`benchstat` machinery for three deliberately non-overlapping jobs. Getting this wrong means duplicating work another skill already owns:

| | `go-performance-optimization` | `go-makefile` | `go-performance-test` (this skill) |
|---|---|---|---|
| What runs | One hand-run before/after pair while actively optimizing a hot path | `make bench` — a single, unreplicated `-bench=. -benchmem` pass, no `-race` | `-count=10` sweep piped through `benchstat` against a **committed baseline**, its own CI job |
| Proves | *This specific PR* helped | "Did the number I just changed go down" — directional only | A regression on **every subsequent change** is caught automatically, statistically |
| Owns | Profiling methodology, algorithmic-complexity reasoning, `testing.B` writing conventions | The single-run dev-time target only | The baseline file, the `-count=10` sweep, the tolerance threshold, the merge-blocking gate |

This skill does not restate `testing.B` conventions (`b.ReportAllocs()`, setup outside `b.ResetTimer()`, deterministic fixtures) — that is `go-performance-optimization`'s `references/benchmark-writing-standard.md`. It does not restate profiling — that is `go-performance-optimization`'s `references/profiling-workflow.md`. This skill's unique territory is what happens to a benchmark **after** it exists: enrollment into a tracked baseline, the statistical comparison, and the CI gate itself.

---

## Table-Driven Benchmark Enrollment

A benchmark becomes gated by where it lives, not by a separate manifest to maintain: any `func BenchmarkX(b *testing.B)` inside `internal/**/*_bench_test.go` is swept by `-bench=.` and enrolled automatically — the same filename-pattern-as-policy convention `go-makefile`'s coverage filter and `go-mutation-test`'s package targeting already use. Tracked operations use **named sub-benchmarks over a table**, the identical shape `go-unit-test`'s table-driven convention uses for correctness tests, so `benchstat` can compare each case by name independently rather than one undifferentiated average: full worked example, the enrollment rule in detail, the stored-baseline mechanism, the exact `benchstat` workflow, the tolerance threshold and its reasoning, and the CI job in full: `references/benchmark-and-regression-gate-standard.md`.

---

## The Stored Baseline — Deliberate, Never Automatic

`testdata/perf/baseline.txt` is committed and regenerated only two ways: (1) inside the same PR that deliberately trades speed for a feature, visibly reviewed; (2) on a scheduled cadence tied to tagged releases, to keep the baseline honest against gradual drift without becoming a rubber stamp. **The baseline is never regenerated automatically on every merge** — doing so would let a slow regression quietly become the new "normal," defeating the entire point of the gate. Full mechanics: `references/benchmark-and-regression-gate-standard.md`.

---

## benchstat, the Tolerance Threshold, and CI Failure

```bash
go test -run=^$ -bench=. -benchmem -count=10 ./internal/... > new.txt
benchstat testdata/perf/baseline.txt new.txt
```

A regression fails the gate only when it clears **both** a stated tolerance (this repo's default: **12%**, reasoned to absorb shared-CI-runner noise without hiding a real regression — see the full reasoning in the reference below) **and** statistical significance (`p < 0.05`); a `~`-marked delta is noise, never a gate failure, whatever the raw percentage claims. On failure the build fails outright — the only two ways forward are a genuine fix, or an explicit, reviewed baseline-update commit; the gate never silently accepts a new, slower baseline on its own. Exact CI job YAML, the noise/threshold reasoning, and allocs-tracked-alongside-time detail: `references/benchmark-and-regression-gate-standard.md`.

---

## Performance Budgets for the Data-Estate-Mapping Product

Tracked benchmarks are judged against concrete numeric budgets, not left to "whatever the baseline happens to be": an in-process p99 handler-logic time budget and a per-request allocation budget, both derived from `slo-definition`'s 800ms ClassifyDataAsset command-API latency SLO and `multi-tenancy-design`'s physical-isolation model (no per-row tenant filtering cost on this stack — the isolation is paid once, at the infrastructure layer; the per-request cost this budget accounts for is tenant-context enrichment for audit traceability). Full budget table, the SLO-to-budget derivation, and the multi-tenancy grounding: `references/performance-budgets.md`.

---

## Diagnosing a Regression

1. **Confirm it's real** — re-run at higher `-count`; rule out a noisy runner before trusting one comparison.
2. **Profile it** — hand off to `go-performance-optimization`'s `references/profiling-workflow.md`; this skill catches and gates, it does not re-teach diagnosis.
3. **Fix it, or update the baseline** — a deliberate trade-off rides in the same PR, reviewed, per the Stored Baseline section above.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Boundary respected | No restated `testing.B`/profiling content; cites `go-performance-optimization` and `go-makefile` | Benchmark-writing or profiling guidance duplicated here |
| Table-driven enrollment | Tracked benchmarks use named sub-benchmarks in `internal/**/*_bench_test.go` | Ungrouped `BenchmarkX` per case, unnamed and uncomparable by `benchstat` |
| Baseline committed, deliberate | `testdata/perf/baseline.txt` tracked; regenerated only via reviewed PR or scheduled release cadence | No baseline; regenerated automatically on every merge |
| Statistical comparison | `-count=10` piped through `benchstat`; both threshold **and** `p<0.05` required to fail | Single-run comparison; percentage-only judgment ignoring significance |
| Threshold reasoned | 12% stated with CI-noise rationale; overridable via `sdlc-config-management` | Zero-tolerance gate (flaky) or unstated/arbitrary threshold |
| Dedicated CI job | Runs as its own job, separate from `make ci`, never blocking the fast PR loop | Wired into the fast unit-test loop, or not gated in CI at all |
| Gate blocks merge | Regression beyond threshold fails the build; only fix or reviewed baseline-update unblocks | Gate measured but advisory; build passes regardless |
| Allocs tracked | `allocs/op` baselined and gated alongside `time/op` | Only wall-time tracked |
| Budgets grounded | p99 handler and per-request allocation budgets traced to `slo-definition`/`multi-tenancy-design` | Arbitrary numeric targets with no domain derivation |
| Right operations tracked | Hot-path/SLO-relevant operations enrolled | Trivial code gated; real hot paths missing |

---

## Anti-Patterns

- **Duplicating `testing.B` or profiling content here** — that is `go-performance-optimization`'s domain; this skill cites, never restates.
- **Gating on a single run** — run-to-run variance exceeds most real regressions; only a `benchstat` comparison over `-count=10` is evidence.
- **Silently updating the baseline** — a baseline change is a performance decision; it rides in the same PR, visibly reviewed, or on the scheduled cadence — never a script's automatic response to a failed gate.
- **Zero-tolerance thresholds on shared CI runners** — a flake factory; the reasoned 12% absorbs noise without hiding real regressions.
- **Treating every delta as a regression** — a `~`-marked or high-`p` delta is noise, not evidence, whatever the raw percentage claims.
- **Wiring the gate into `make ci`** — a `-count=10` sweep is too slow for the fast PR-loop budget `ci-pipeline` holds every other gate to; it runs as its own dedicated job.
- **Arbitrary numeric budgets** — a p99 or allocation target invented with no derivation from `slo-definition`'s actual SLOs is unfalsifiable and gets silently loosened the first time it's inconvenient.

---

## Output Format

- **`internal/**/*_bench_test.go`** — table-driven, named tracked benchmarks (per the enrollment convention above), `b.ReportAllocs()` always on. Never a bare, unnamed `BenchmarkX` when the operation has more than one meaningful case.
- **`testdata/perf/baseline.txt`** — the committed statistical baseline, `benchstat`-formatted output of a `-count=10` run. Regenerated only via a reviewed PR or the scheduled release-tagged cadence — never by an automatic script on merge.
- **`.github/workflows/perf-gate.yml`** — the dedicated CI job: `-count=10` sweep, `benchstat` against the committed baseline, fails on threshold-and-significance, never wired into `make ci`. Exact YAML: `references/benchmark-and-regression-gate-standard.md`.
- **`docs/quality/perf-budgets.md`** — the tracked-operations table with each budget's numeric target and its SLO/domain derivation, reviewed on the same cadence `slo-definition`'s SLO document already undergoes.
