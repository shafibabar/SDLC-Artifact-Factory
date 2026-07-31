# Coverage Threshold and Benchmark Standard

Self-contained reference for `go-makefile`'s `cover` and `bench` targets: the exact threshold,
what is excluded from the count and why, the enforcement script in full, and the boundary between
a dev-time benchmark run and `go-performance-test`'s CI-gated regression detection.

---

## The Coverage Threshold: 80%, Enforced Not Measured

**80%** is the factory-wide default (`COVER_MIN` in the Makefile), consistent with the number
already established independently by `test-pyramid` ("Gate: ≥80% on changed packages") and
`ci-pipeline` ("Coverage below the enforced threshold (≥80%)") — `go-makefile` is the mechanism
that actually enforces the number both of those skills already name, not a fourth, different
source of truth. A product may override it per `sdlc-config-management`'s pattern (e.g. `85` for
a bounded context handling PII classification) by setting `COVER_MIN` in the product's own
Makefile include or CI variables — the mechanism stays identical, only the number moves.

**A measured-but-unenforced number gates nothing.** `go tool cover -func` printing a percentage
to a log that nobody is required to look at is equivalent to no coverage policy at all. The
`cover` target's `check-coverage.sh` call is what turns the number into a build failure — the
distinction `test-pyramid` calls "coverage is a signal, not a target": measuring it makes it
visible, *enforcing* it makes it a gate.

### What Counts, and What's Excluded

- **`cmd/**` composition roots are absent from the profile by construction, not by a filter.**
  `go-project-structure` is explicit that `cmd/server/main.go` only wires dependencies and starts
  the process — "the moment it decides anything, that decision is untestable without booting the
  process" — so a composition root correctly carries no `_test.go` file at all. `go test`'s
  default (non-`-coverpkg`) coverage profile only contains statements from packages that were
  themselves under test; a package with zero test files contributes zero lines to
  `coverage.out`, counted in neither the numerator nor the denominator. Nothing needs to actively
  exclude `cmd/` — it was never going to be present. Do not add a synthetic `main_test.go` whose
  only purpose is to inflate a number; that produces exactly the "line coverage with weak
  assertions proves nothing" failure mode `test-pyramid` warns against.
- **Generated code and mocks ARE compiled into tested packages and DO need an explicit filter.**
  Unlike `cmd/`, `oapi-codegen` output and `mockgen`/`moq` doubles frequently live inside a
  package that has real tests (a handler package importing its own generated server interface,
  for instance) — so their lines land in the same `coverage.out` as hand-written logic unless
  filtered out. The filter matches on filename convention, not a separate exclude-list to
  maintain by hand: any file ending `_gen.go`, `.pb.go`, or `_mock.go` is dropped from the
  profile before the percentage is computed. This is the one place this standard trades a small
  amount of precision (a filename-pattern match, not a semantic "is this generated" check) for
  zero maintenance burden — the same trade-off `go-project-structure`'s `arch` fitness function
  makes with its own pattern-based deny-list, made explicit rather than silently assumed.

### `check-coverage.sh` in Full

```bash
#!/usr/bin/env bash
# scripts/check-coverage.sh — enforce the coverage threshold on a filtered profile.
# Usage: check-coverage.sh coverage.out 80
# Invoked by `make cover`, part of `make ci`.
set -euo pipefail

profile="$1"
threshold="$2"

filtered="$(mktemp)"
trap 'rm -f "$filtered"' EXIT

# Keep the `mode: atomic` header line, then drop generated/mock files from the count.
head -1 "$profile" > "$filtered"
tail -n +2 "$profile" | grep -Ev '_gen\.go:|\.pb\.go:|_mock\.go:' >> "$filtered" || true

pct="$(go tool cover -func="$filtered" | tail -1 | awk '{print $NF}' | tr -d '%')"
echo "Coverage (generated/mock files excluded): ${pct}%  (threshold: ${threshold}%)"

awk -v p="$pct" -v t="$threshold" 'BEGIN { exit !(p+0 >= t+0) }' || {
  echo "FAIL: coverage ${pct}% is below the ${threshold}% threshold"
  exit 1
}
```

**Exit codes:** `0` on pass, `1` on a filtered percentage below `threshold` — the same
success/failure exit-code contract every `scripts/*.sh` in this plugin follows, so `make cover`'s
failure propagates through `make ci` without any special-case handling in either Makefile target.

**Why measured under `-race` and `-covermode=atomic`, never a separate un-raced run:** a second,
faster coverage run without `-race` would be a second test execution path — the exact thing the
race-detector-always-on standard (`SKILL.md`) forbids. `-covermode=atomic` (rather than `count` or
`set`) is required specifically because `-race` is on: atomic counters are safe to increment
concurrently, which `set`/`count` mode's plain counters are not once the race detector is
instrumenting concurrent access to the same coverage counter.

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
