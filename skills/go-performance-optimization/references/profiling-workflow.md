# The pprof Profiling Workflow

Full standard referenced from `SKILL.md`'s "Profiling Workflow" section. Self-contained —
reads without the parent body already in context. Covers every profile type `pprof`
exposes, which question each one answers, how to read a flame graph, `go tool trace` for
latency problems pprof's sampling misses, and `runtime.ReadMemStats` for soak-test
stability. This is the mechanics every other skill's profiling citation resolves to —
`go-concurrency-patterns`' deadlock/livelock/starvation runbook and
`go-service-skeleton`'s shutdown-leak check both point here for the commands themselves,
while owning their own *interpretation* depth once a profile is in hand.

---

## Which Profile Answers Which Question

Pick the profile from the question you're actually asking — not by habit:

| Question | Profile | Enable |
|---|---|---|
| "Where is CPU time actually going?" | CPU | `go test -cpuprofile cpu.out -bench .` |
| "Where are allocations coming from? Why is GC pressure high?" | Heap/memory | `go test -memprofile mem.out -bench .` |
| "How many goroutines exist, and where are they blocked?" | Goroutine | `curl http://internal-host:PORT/debug/pprof/goroutine?debug=2` |
| "Where is lock contention costing time?" | Mutex | `runtime.SetMutexProfileFraction(n)` |
| "Where are goroutines blocked on channels/sync, not just how many?" | Block | `runtime.SetBlockProfileRate(n)` |
| "I have a latency problem, not a throughput problem" | `go tool trace` (below) — pprof's sampling misses scheduling/GC-pause/syscall latency entirely | `go test -trace=trace.out -bench=Pipeline ./...` |

```bash
go test -bench=Classify -cpuprofile=cpu.out -memprofile=mem.out ./...
go tool pprof -http=:0 cpu.out              # flame graph in browser
go tool pprof -top -alloc_objects mem.out   # top allocators by object count
```

**In production, `net/http/pprof` is exposed on a separate, internal-only admin port —
never the public API port.** The endpoints expose heap contents and are a cheap DoS
lever; every worked example in this repo's skills that samples a live profile
(`go-concurrency-patterns`' deadlock runbook, `go-service-skeleton`'s leak check) assumes
this same internal-only port.

---

## The Goroutine Profile: This Skill's Depth vs. the Incident-Response Runbook

This skill teaches *when to pull a goroutine profile and what its raw shape means* —
"is the count bounded and stable under load," "is it climbing," "is CPU idle or pegged
alongside it." That is the optimization-workflow and capacity-planning question:
confirming a worker pool or fan-out is sized correctly, or that a suspected leak is real
before chasing it.

**Interpreting an individual stuck goroutine's stack trace during a live incident** —
reading `semacquire` vs `chan receive` vs `IO wait` labels, finding a lock-ordering
cycle across two dumps, differentiating a partial deadlock from starvation — is owned in
full by `go-concurrency-patterns`' `references/deadlock-livelock-starvation-runbook.md`.
Don't restate that table here; reach for the profile using the commands above, then hand
off to that runbook the moment the question becomes "why is this specific goroutine
stuck" rather than "how many goroutines, and is the count healthy."

---

## Reading a Flame Graph

`go tool pprof -http=:0 cpu.out` renders a flame graph from CPU-profile samples. Three
rules for reading it correctly — getting these backwards is the most common way to
misdiagnose a profile:

- **Width is proportion of samples (time), not call order or duration of a single call.**
  A wide box means the profiler caught many samples with that function on the stack —
  it is where time is actually going. A narrow box, however visually prominent its
  color, is not worth chasing.
- **Height is stack depth**, top-to-bottom (or bottom-up, depending on orientation) —
  it shows *who called whom*, not cost. A tall, narrow tower of wrapper functions with
  no wide box anywhere in it is not a hot path; it's just a deep call chain that happens
  to run rarely.
- **Look for wide plateaus, not tall towers.** The widest boxes at any level are the
  functions actually consuming the sampled time — start there, not at whichever function
  happens to be visually largest due to color or position.

`go tool pprof -top -alloc_objects mem.out` (or `-alloc_space` for bytes rather than
object count) gives the equivalent ranked list for a heap profile without needing to read
a graph at all — often the faster first check.

---

## `go tool trace` — Latency and Scheduling, Not Throughput

For a latency problem specifically (a slow p99 despite acceptable average throughput),
the execution tracer shows goroutine scheduling gaps, GC pause windows, network-blocking
time, and syscall delays — all invisible to CPU profiling's statistical sampling, which
only sees a goroutine while it's actually running, never while it's waiting to be
scheduled.

```bash
go test -trace=trace.out -bench=Pipeline ./...
go tool trace trace.out
```

Reach for this only once a CPU/heap profile has already ruled out "the code itself is
slow" — `go tool trace` answers "why did this goroutine sit idle for 40ms when it had
work to do," a different question than "which function burns the most CPU."

---

## `runtime.ReadMemStats` — Stability Under Sustained Load

A profile is a single snapshot; a soak/stress test needs a trend. Sample
`runtime.ReadMemStats` periodically during sustained load and watch three fields:
`HeapAlloc` (live heap size right now), `Mallocs - Frees` (live object count — the
cleanest leak signal, since it's immune to GC timing noise that `HeapAlloc` alone isn't),
and `NumGC` (collection frequency — a rising rate at flat load means growing allocation
pressure). A steady-state live-object count under sustained load means no leak; monotonic
growth over the soak window means one — this is the same steady-state check
`go-service-skeleton`'s shutdown-and-health standard and `go-concurrency-patterns`' Leak
Prevention Checklist both point back to this file for.

---

## This Skill's Boundary With the Bench-Target and CI-Gate Skills

Every command on this page is a **dev-time diagnostic** run by hand while actively
optimizing a specific hot path. Two adjacent skills use the same underlying tooling for
different jobs — see `SKILL.md`'s Boundaries section and
`references/benchmark-writing-standard.md` for the precise split with `go-makefile`'s
single-run `bench` target and `go-performance-test`'s CI-gated `benchstat` regression
gate. This file does not duplicate either.
