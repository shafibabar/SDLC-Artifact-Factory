# Worked Experiment: Partial Deadlock Under Opposite-Order Lock Acquisition

Full worked experiment referenced from `SKILL.md`'s "The Patterns to Validate" table (the
Partial Deadlock / Livelock row) and named directly by
`go-concurrency-patterns/references/deadlock-livelock-starvation-runbook.md`'s Step 6 ("`go-
chaos-test`'s partial-deadlock experiment deliberately induces exactly this shape"). Self-
contained — reads without the parent body already in context.

**What this file owns, and what it deliberately does not:** this is the *prior* question —
deliberately inducing a partial deadlock in a controlled experiment, before any real incident,
to prove detection and recovery actually work. The runbook owns the *later* question — once a
deadlock is suspected in a running system, how to read a goroutine dump and confirm the exact
cycle. This file ends where the runbook begins; it does not restate Steps 1–6 of that runbook.

---

## Why This Category Needs a Chaos Experiment at All

Neither of this toolchain's two automatic concurrency checks catches a partial deadlock:
`go test -race` proves the absence of data races, a different problem; Go's runtime deadlock
detector only fires when *every* goroutine in the process is blocked simultaneously, and a
partial deadlock by definition leaves the rest of the process running. This experiment is the
only place in the toolchain that turns "we believe the worker pool's lock ordering is safe" into
a checked, repeatable proof — see `go-concurrency-patterns`' "Deadlock, Livelock, and Starvation"
section for the full taxonomy this experiment assumes.

---

## The Experiment

```go
// EXPERIMENT: worker pool detects (does not silently absorb) opposite-order lock contention
// STEADY STATE:  throughput ≥ 50 records/sec sustained; runtime.NumGoroutine() flat at
//                poolSize+baseline (60s pre-fault window)
// HYPOTHESIS:    if two worker goroutines acquire lockA/lockB in opposite order under sustained
//                contention, throughput on the affected path drops to zero while goroutine count
//                stays flat and elevated (not climbing — that would be a leak, a different bug)
//                and CPU goes idle, not pegged (pegged would be livelock, not deadlock) — and
//                this experiment's own assertions catch that signature automatically, without a
//                human reading a goroutine dump
// BLAST RADIUS:  this test binary's own worker pool, no shared infrastructure touched
// ROLLBACK:      n/a — runs against an isolated, ephemeral pool; a stuck test is bounded by
//                the test's own timeout, not a live system needing an abort
func TestWorkerPool_DetectsOppositeOrderLockDeadlock(t *testing.T) {
    pool := newChaosWorkerPool(t, chaosOppositeLockOrder) // build-tag-gated fault, see below
    requireSteadyThroughput(t, pool, 50 /* rec/sec */, 10*time.Second)

    baseline := runtime.NumGoroutine()
    pool.InjectContention(t) // forces two workers into lockA→lockB vs lockB→lockA

    // Detection signal, sampled — not inferred from a single snapshot (see the runbook's
    // Step 6 caveat on single-snapshot diagnosis):
    deadline := time.Now().Add(15 * time.Second)
    var stuck bool
    for time.Now().Before(deadline) {
        count := runtime.NumGoroutine()
        idle := cpuIdlePercent(t, pool)          // process-local CPU sample, not a cluster metric
        throughput := pool.Throughput()
        if count == baseline+poolSize && idle > 90 && throughput == 0 {
            stuck = true
            break
        }
        time.Sleep(500 * time.Millisecond)
    }
    require.True(t, stuck, "expected the injected opposite-order contention to produce a "+
        "flat-goroutine-count, idle-CPU, zero-throughput signature within 15s")

    // Artifact for a human only if this assertion above ever fails unexpectedly on real code
    // (not the intentionally-faulty chaos build): capture the goroutine dump for the runbook's
    // Step 3 stack-trace interpretation to use, rather than re-deriving it here.
    _ = pool.CaptureGoroutineDump(t, "testdata/chaos/deadlock-dump.txt")
}
```

**Fault-injection mechanism — a test-only build tag, never production code:** `InjectContention`
exists only in a file guarded by `//go:build chaos_deadlock`, compiled into this test binary
alone. It wraps the pool's two production locks (`lockA`, `lockB`) with a deliberately reversed
acquisition order in one goroutine's path only — goroutine A takes `lockA` then `lockB`;
goroutine B, under this build tag, is made to take `lockB` then `lockA` — while N goroutines
hammer both locks concurrently to force real contention rather than a race that might never
trigger. This mirrors the app-level fault-injection style `SKILL.md`'s `faultyPublisher`
decorator already uses: the fault lives in a test-only seam, deterministic, never touching the
shipped lock-ordering code.

---

## Livelock Variant — Same Harness, Different Fault

Swap `chaosOppositeLockOrder` for `chaosNaiveRetryNoJitter`: two goroutines each hold one lock
and retry-acquire the other on a fixed, synchronized interval with no jitter — each backs off,
retries at the same instant, collides again. The detection loop above is unchanged except the
pass condition inverts on the CPU axis: `idle < 10` instead of `idle > 90` (livelock keeps the
CPU busy; deadlock leaves it idle), matching the runbook's own signature table exactly.

---

## What Happens If This Is Hard to Diagnose

If the automated detection loop above ever fails to fire cleanly — the signature is ambiguous,
or a real (non-injected) incident produces a shape this experiment didn't anticipate — that is
exactly the boundary where this file stops and
`go-concurrency-patterns/references/deadlock-livelock-starvation-runbook.md` takes over: its
Steps 1–5 walk the goroutine-dump and CPU-profile interpretation this experiment's own assertions
are deliberately built to avoid needing, for the case where a human does have to read the dump
by hand. This experiment proves the fix holds under controlled conditions; the runbook diagnoses
an unplanned occurrence. Neither restates the other.
