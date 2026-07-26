# Benchmark-Writing Standard

Full standard referenced from `SKILL.md`'s "Benchmark-Writing Standard" section.
Self-contained — reads without the parent body already in context. Covers `testing.B`
conventions, why `b.ReportAllocs()` is always on, and how to compare a before/after pair
via `benchstat` — plus the precise, non-duplicating boundary with `go-makefile`'s
dev-time `bench` target and `go-performance-test`'s CI-gated regression comparison, both
of which use this identical machinery for different jobs.

---

## `testing.B` Conventions

```go
func BenchmarkClassifyEnvelopeMarshal(b *testing.B) {
    env := sampleEnvelope()      // setup OUTSIDE the timed loop
    b.ReportAllocs()             // always on — see below
    b.ResetTimer()               // excludes setup from the measurement
    for i := 0; i < b.N; i++ {
        _, _ = json.Marshal(env)
    }
}
```

- **Setup goes before `b.ResetTimer()`, always.** Fixture construction, sample data
  generation, or a database connection counted inside the timed loop dominates the
  measurement and makes the benchmark meaningless — this is the single most common
  benchmark-writing mistake.
- **`b.ResetTimer()` immediately after setup, `b.StopTimer()`/`b.StartTimer()`** around
  any per-iteration setup that genuinely can't be hoisted out of the loop (rare — prefer
  restructuring the benchmark so setup is fully outside it whenever possible).
- **Deterministic fixtures only** — no randomness, no network calls, no wall-clock
  dependence inside the timed loop. A non-deterministic benchmark produces noise that
  looks like a regression on one run and an improvement on the next, defeating the entire
  point of a before/after comparison.
- **Benchmark a meaningful unit of work** — a handler, a serialization path, a query, a
  batch-drain — not a trivial getter or a single arithmetic operation where the loop
  overhead itself dominates whatever you're trying to measure.
- **Don't let the compiler delete the work being measured.** If a benchmark's result is
  computed and never used, the optimizer may prove the call has no observable effect and
  elide it, silently benchmarking an empty loop. Assign the result to a package-level
  sink variable, or check its error (as the example above does), so the compiler can't
  remove it.

```
BenchmarkClassifyEnvelopeMarshal-8   1_250_000   954 ns/op   320 B/op   4 allocs/op
```

---

## `b.ReportAllocs()` Is Always On

Every performance-critical benchmark in this repo calls `b.ReportAllocs()` —
non-negotiable, not a case-by-case judgment call. Allocation count is frequently a
**better** optimization signal than raw wall-clock time, because allocations drive GC
pressure, and GC pressure is what turns a locally fast function into a system that's slow
under sustained concurrent load in ways a single-threaded benchmark's timing alone won't
show. A benchmark reporting only `ns/op` with no `allocs/op` is missing the leading
indicator, not just an optional metric.

---

## Comparing Before/After With `benchstat`

**A single benchmark run is noise, not evidence — never compare two individual runs by
eye.** Run-to-run variance (CPU frequency scaling, thermal throttling, scheduler noise,
background processes) routinely exceeds the size of a real, meaningful regression or
improvement. Always compare statistically, across multiple runs:

```bash
go test -run=^$ -bench=. -benchmem -count=10 ./... > old.txt   # before the change
# ...apply the optimization...
go test -run=^$ -bench=. -benchmem -count=10 ./... > new.txt   # after the change
benchstat old.txt new.txt
```

```
name              old time/op    new time/op    delta
ClassifyMarshal   954ns ± 3%     612ns ± 2%    -35.85%  (p=0.000 n=10)
ClassifyMarshal   320 B/op       128 B/op      -60.00%  (allocs down too)
```

**Read the `p=` value, not just the percentage.** A `~` marker in `benchstat`'s output
means the two samples are statistically indistinguishable — treat that as no change,
whatever the raw percentage claims, never as a win worth keeping the added complexity
for. This is the exact evidence `SKILL.md`'s and
`references/execution-time-optimization-standard.md`'s measure-first hard gate requires
before an optimization PR merges.

---

## Boundary With `go-makefile` and `go-performance-test`

Three skills use the identical `testing.B` / `benchstat` machinery for three distinct,
deliberately non-overlapping jobs — this file teaches the first one only, and cites
rather than restates the other two:

| | This skill (`go-performance-optimization`) | `go-makefile` | `go-performance-test` |
|---|---|---|---|
| What runs | The exact before/after pair above, written and run by hand while actively optimizing one hot path | `make bench` — a single, unreplicated `go test -bench=. -benchmem ./...` pass, no `-race` | `go test -bench=. -benchmem -count=10 ./...` piped through `benchstat` against a **committed baseline**, as its own dedicated CI job |
| Purpose | Prove *this specific change* helped, with evidence, before it merges | Immediate, noisy, directionally-useful "did the number I just changed go down" feedback during active work | Catch a regression on **every subsequent change**, automatically, statistically |
| Owns | The optimization workflow and the PR-level measure-first gate | The single-run dev-time target only — no statistical comparison logic | The baseline file, the `-count=10` sweep, the `p<0.05` merge-blocking threshold |

Do not re-implement `go-performance-test`'s baseline/threshold logic here, and do not
treat `go-makefile`'s single `bench` run as sufficient evidence for the measure-first
gate above — a single run is exactly the noise this file's `benchstat` section warns
against. The benchmark written under this standard may later become one of
`go-performance-test`'s permanently tracked operations; that enrollment decision belongs
to that skill, not this one.
