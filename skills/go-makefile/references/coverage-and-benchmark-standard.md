# Coverage Threshold and Benchmark Standard

Self-contained reference for `go-makefile`'s `cover` and `bench` targets: the exact gate,
what is excluded from the count and why, how the enforcement script is wired, and the boundary between
a dev-time benchmark run and `go-performance-test`'s CI-gated regression detection.

---

## The Coverage Gate: 100%, Enforced Not Measured

The product's gate is **100% of lines and branches** (`test-pyramid`). `cover` enforces both
halves: statement blocks, then `gobco` branches. There is no threshold variable to lower. A
measured result above 90% and under 100% fails unless the user reviews the gap and waives that run
with recorded comments. A **no result** (tool failure or unmeasured file) blocks the build: change
the code so it can be measured, or list an exception for the user's approval.

**A measured-but-unenforced number gates nothing**, and neither does a printed one: `go tool cover`
rounds to one decimal, so a gap can read 100.0%. The check fails on any statement block with a zero
count.

### What Counts, and What's Excluded

- **Everything in the module is counted**, `cmd/**` composition roots included: with
  `-coverpkg=./...`, packages without tests appear in the profile at zero. Test them or list them
  as exclusions for the user's approval.
- **Excluded automatically: machine-generated code only** — moq mocks by file name (`_moq.go`) and
  files carrying the `// Code generated ... DO NOT EDIT.` marker before the package clause. Test
  doubles written by hand are counted.
- **Every other exclusion** is a line in `coverage-exceptions.txt` with its approval date and reason
  (both gates read it; excepted files are printed as not measured).

### The Checks

Copy `go-unit-test`'s `check-go-line-coverage.sh` and `check-go-branch-coverage.sh` to the service's
`scripts/`; do not write second versions. Both need Python 3; the branch check needs `gobco` v1.3.4
on `PATH` (`go install github.com/rillig/gobco@v1.3.4`), locally and in CI. `make cover` calls both;
each runs the tests itself:

```bash
./scripts/check-go-line-coverage.sh $(COVER_EXCEPTIONS) --out coverage.out .
./scripts/check-go-branch-coverage.sh $(COVER_EXCEPTIONS) .
```

**Exit codes:** `0` pass, `1` a gap, `2` no result. Both non-zero codes stop `make cover` and so
`make ci`. The branch check runs without `-race`: it measures only, and `gobco`'s counters are
unsynchronised. Race detection stays with the line check's run.

**Why the line check runs under `-race` and `-covermode=atomic`:** `-covermode=atomic` (rather
than `count` or `set`) is required because `-race` is on: atomic counters are safe to increment
concurrently, which `set`/`count` mode's plain counters are not once the race detector is
instrumenting concurrent access to the same counter. The branch check is the one un-raced run,
because `gobco`'s own counters are unsynchronised; it measures only and never replaces a raced run.

---

## The Benchmark Target: Dev-Time Signal, Not a CI Gate

`make bench` runs `go test -run=^$ -bench=. -benchmem ./...` — a **single, unreplicated pass**.
It never runs under `-race`: the race detector's instrumentation overhead (commonly cited in the
2-20x range) makes any timing or allocation number it produces meaningless as a performance
measurement, and race-safety is already verified separately by `test`/`cover`, both of which do
run under `-race` — `bench` doesn't need to re-prove it.

**What a single run is good for:** immediate, noisy, directionally-useful feedback while a
developer is actively optimizing a hot path — "did the allocation count I just changed go down."
This is `go-performance-optimization`'s use of the *same underlying mechanism*
(`testing.B`, `-benchmem`) for a different purpose than the paragraph below.

**What a single run is never used for:** gating a merge. Run-to-run variance on any shared or
even dedicated CI runner exceeds most real regressions — a "+8%" from one `bench` invocation
proves nothing statistically. `go-performance-test` owns the statistically valid version of this
same measurement: `go test -bench=. -benchmem -count=10 ./...` piped through `benchstat` against
a committed baseline, reading the `p=` significance value (not just the raw percentage), run as
its **own dedicated CI job** — deliberately *not* wired into `make ci`, because a `-count=10`
sweep across every tracked operation is too slow for the PR-loop fast-feedback budget `ci-pipeline`
holds every other `make ci` gate to. `go-makefile` emits the single-run `bench` target only;
`go-performance-test` owns the baseline file, the `benchstat` comparison, and the regression-gate
CI job. Do not re-implement `benchstat` comparison logic inside this Makefile — that ownership
boundary is deliberate, not an oversight to "complete."
