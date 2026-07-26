# Benchmark Enrollment, the Stored Baseline, and the CI Regression Gate

Full standard referenced from `SKILL.md`'s "Table-Driven Benchmark Enrollment," "The Stored
Baseline," and "benchstat, the Tolerance Threshold, and CI Failure" sections. Self-contained —
reads without the parent body already in context. This file does not teach `testing.B` mechanics
(`b.ReportAllocs()`, setup-before-`b.ResetTimer()`, deterministic fixtures, not letting the
compiler elide the measured work) — that is `go-performance-optimization`'s
`references/benchmark-writing-standard.md`, cited here, never restated. This file teaches what
happens to a benchmark **after** it is correctly written: how it becomes tracked, how the tracked
baseline is stored and regenerated, the exact statistical comparison, the tolerance threshold, and
the CI job's failure behavior.

---

## Table-Driven Benchmarks, Matching the Unit-Test Convention

A tracked operation with more than one meaningful case (different payload sizes, tenant-scoped
vs. cross-tenant lookups, cold vs. warm cache) uses named sub-benchmarks over a table — the same
shape `go-unit-test`'s table-driven convention already uses for correctness tests, applied to
performance so `benchstat` can compare each case by name rather than one undifferentiated average:

```go
func BenchmarkClassifyHandler(b *testing.B) {
    cases := []struct {
        name string
        cmd  ClassifyDataAssetCommand
    }{
        {name: "single_entity", cmd: fixtureSingleEntity()},
        {name: "batch_50_entities", cmd: fixtureBatch(50)},
    }
    for _, tc := range cases {
        b.Run(tc.name, func(b *testing.B) {
            h, fixture := setupClassifyBench(b, tc.cmd) // setup OUTSIDE the timed loop
            b.ReportAllocs()
            b.ResetTimer()
            for i := 0; i < b.N; i++ {
                if err := h.Handle(fixture.ctx, tc.cmd); err != nil {
                    b.Fatal(err)
                }
            }
        })
    }
}
```

`benchstat` reports `BenchmarkClassifyHandler/single_entity` and
`BenchmarkClassifyHandler/batch_50_entities` as independent rows — a regression in the batch case
alone is not averaged away by the single-entity case staying flat, which a single undifferentiated
`BenchmarkClassifyHandler` would silently do.

**Enrollment is by file location, not a manifest to maintain by hand.** Any `func BenchmarkX(b
*testing.B)` inside a file matching `internal/**/*_bench_test.go` is swept by the CI job's
`-bench=. ./internal/...` and is enrolled — the identical filename-pattern-as-policy convention
`go-makefile`'s `check-coverage.sh` uses for excluding generated code, and `go-mutation-test` uses
for package targeting. A benchmark written under `go-performance-optimization`'s standard while
optimizing a specific PR does not automatically become tracked — it must be moved into (or
duplicated as a table case within) an `internal/**/*_bench_test.go` file to be enrolled; that
enrollment decision belongs to this skill, not to the optimization workflow that produced the
benchmark, exactly as `go-performance-optimization`'s own `references/benchmark-writing-standard.md`
already states.

---

## The Stored Baseline: What, Where, and When It Changes

`testdata/perf/baseline.txt` is a committed `benchstat`-formatted file — the literal output of a
`-count=10` sweep, checked into the repository like any other test fixture. It is regenerated in
exactly two circumstances, never a third:

1. **Inside the same PR that deliberately trades speed for something else** — a new validation
   pass, an added audit hook, a correctness fix that costs a few percent. The PR's diff includes
   both the code change and the regenerated `baseline.txt`, so a reviewer sees the performance
   trade-off in the same review as the change that caused it. This is a visible, reviewed decision,
   not a side effect.
2. **On a scheduled cadence tied to tagged releases** — the same "periodic, not continuous"
   discipline `go-mutation-test` applies to its own scheduling problem, for the identical
   underlying reason: hardware, Go-toolchain, and dependency drift accumulate slowly and
   legitimately change absolute numbers over months even with no code regression, and a baseline
   that is never refreshed eventually starts failing the gate on drift that has nothing to do with
   the PR being tested. A refresh at each tagged release keeps the baseline honest against that
   drift without touching it more often than that.

**The baseline is never regenerated automatically by CI on every merge, and the gate script never
writes a new baseline on a failed run.** Automatic regeneration on merge would let a slow-but-not-
zero regression that lands on a Tuesday quietly become Wednesday's new "normal" — the exact failure
mode a regression gate exists to prevent. A failed gate always requires a human decision (fix the
code, or open a reviewed baseline-update PR under case 1 above); the script's only job on failure
is to fail, loudly, with the `benchstat` diff attached as CI output.

---

## The benchstat Comparison, in Full

```bash
# CI job — a fresh checkout, dedicated runner, no other workload competing for CPU
go test -run=^$ -bench=. -benchmem -count=10 ./internal/... > new.txt
benchstat testdata/perf/baseline.txt new.txt
```

```
name                                    old time/op    new time/op    delta
ClassifyHandler/single_entity-8         12.4µs ± 2%    18.1µs ± 3%    +46.0%  (p=0.000 n=10)
ClassifyHandler/single_entity-8         320 B/op       512 B/op       +60.0%  (allocs up too)
ClassifyHandler/batch_50_entities-8     540µs ± 3%     551µs ± 2%      ~      (p=0.312 n=10)
```

Row one is a real, gated regression: the delta clears the tolerance threshold below **and** is
statistically significant. Row three's `~` marker means the two samples are statistically
indistinguishable — treat it as no change regardless of the raw percentage a careless read might
quote; it never fails the gate. **Both `time/op` and `allocs/op` are compared and gated** —
allocations are frequently the leading indicator of a regression, showing up as GC pressure under
sustained load before wall-time alone would flag it, the same reasoning
`go-performance-optimization`'s benchmark-writing standard states for why `b.ReportAllocs()` is
always on.

**CI-runner noise is a real constraint, not a hypothetical one.** Shared or even dedicated CI
runners exhibit CPU frequency scaling, thermal variance, and scheduler noise that a developer's own
machine mostly doesn't — this is exactly why the gate runs on a fixed, dedicated job (see the YAML
below) rather than inline with every other fast check, and why the threshold below is set wide
enough to absorb that noise without becoming toothless.

---

## The Tolerance Threshold: 12%

A gate must fail on a real regression and must not cry wolf on runner noise — the tolerance
threshold is the knob that trades off between those two failure modes, and it must be reasoned, not
guessed. This standard uses **12%**, reasoned as follows:

- **A 0% threshold is unusable.** Run-to-run variance on any shared or even dedicated CI runner
  routinely produces single-digit-percent swings with no code change at all; a 0%-tolerance gate
  fails PRs at random, and a gate that fails at random gets ignored or bypassed, which is worse
  than no gate.
- **A threshold below ~10% risks the same flakiness at lower severity** — still enough runner noise
  bleeds through on a busy day to produce an occasional false failure, eroding trust in the gate.
- **A threshold above ~15% starts hiding regressions that matter.** A repeated string of "just
  under 15%" regressions across several merges compounds into a genuinely slow system before any
  single PR ever trips the gate — the exact slow-boil failure mode this skill exists to prevent.
- **12% sits inside that 10–15% band**, deliberately closer to the noise-tolerant end because this
  repo's CI runners are shared (not dedicated bare-metal), and a threshold this repo can actually
  live with day to day protects the gate's credibility more than chasing a tighter number that
  generates false failures nobody trusts.

A delta fails the gate only when **both** conditions hold: the delta exceeds 12%, **and**
`benchstat` reports significance (`p < 0.05`, not `~`-marked). Either condition alone is
insufficient — a huge but insignificant delta is noise, and a small-but-significant delta under 12%
is deliberately tolerated as within the gate's stated noise budget. `sdlc-config-management`
documents a `perf_regression_threshold_pct` override key for a bounded context that needs it
tightened — a compliance-critical hot path where even an 8% regression matters more than the
noise-tolerance trade-off above — following the identical override pattern `go-mutation-test`'s
`mutation_test_cadence` and `go-makefile`'s `COVER_MIN` already establish.

---

## The CI Job, in Full

```yaml
# .github/workflows/perf-gate.yml — a dedicated job, deliberately NOT part of make ci.
name: perf-gate
on:
  pull_request:
    paths: ["internal/**"]

jobs:
  benchstat-regression:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with: { go-version-file: go.mod }
      - run: go install golang.org/x/perf/cmd/benchstat@latest
      - name: run tracked benchmarks (count=10)
        run: go test -run=^$ -bench=. -benchmem -count=10 ./internal/... > new.txt
      - name: compare against committed baseline
        run: |
          benchstat testdata/perf/baseline.txt new.txt | tee comparison.txt
          # fails (exit non-zero) on any row exceeding the 12% threshold with p<0.05 —
          # a small wrapper script parses benchstat's own delta/p columns; benchstat itself
          # is a comparison tool, not a gate, so the pass/fail decision is this script's job.
          scripts/check-perf-regression.sh comparison.txt 12
      - uses: actions/upload-artifact@v4
        if: always()
        with: { name: perf-comparison, path: comparison.txt }
```

**Deliberately absent from `make ci` and from the fast PR-loop unit/lint/vuln checks** — a
`-count=10` sweep across every tracked operation is too slow for the inner-loop speed budget
`ci-pipeline` holds every other `make ci` gate to, the identical reasoning
`go-makefile`'s `references/coverage-and-benchmark-standard.md` already states from the Makefile
side. On failure, the job's exit status blocks the PR from merging (a required status check); the
`comparison.txt` artifact is attached so a reviewer sees the exact `benchstat` diff without
re-running anything locally. Two, and only two, ways to unblock: fix the regression and push a new
commit, or open the reviewed baseline-update commit described above — the workflow itself has no
path that silently accepts a new baseline.
