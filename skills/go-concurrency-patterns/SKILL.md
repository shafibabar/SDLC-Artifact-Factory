---
name: go-concurrency-patterns
description: >
  This plugin's concurrency authority — every other Go skill that spawns a
  goroutine (go-service-skeleton's composition root, go-event-publisher's
  relay, go-event-consumer's worker pool and heartbeat, go-service-layer's
  parallel query fan-out) cross-references this skill for general
  goroutine-lifecycle discipline rather than restating it. Covers: the
  goroutine-lifecycle standard (owned/bounded/joined, not just "named" — full
  checklist in references/goroutine-lifecycle-standard.md); the full
  sync-primitives decision table (Mutex vs RWMutex vs channel vs WaitGroup vs
  Once vs atomic vs errgroup, each with a worked example grounded in this
  repo's actual usage — references/sync-primitives-decision-table.md); the
  context-propagation standard (ctx as first parameter always, what must never
  store one, cancellation-checking in long loops —
  references/context-propagation-standard.md); the memory/performance standard
  for concurrent code (goroutine stack cost, worker-pool sizing formulas,
  channel-buffer-sizing tradeoffs — references/memory-performance-standard.md);
  the deadlock/livelock/starvation incident-response runbook (pprof
  goroutine-dump interpretation —
  references/deadlock-livelock-starvation-runbook.md); and the race-testing
  standard for writing a test that reliably exercises a race rather than
  hoping `-race` catches one incidentally (references/testing-race-conditions.md).
  Used by the backend-engineer during Implement.
version: 3.0.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, concurrency, goroutine, channel, errgroup, worker-pool, context, atomic, deadlock]
related: [go-service-skeleton, go-event-publisher, go-event-consumer, go-service-layer, go-chaos-test, go-performance-optimization, go-makefile, go-load-test, health-check-design, go-middleware, go-error-handling]
---

# Go Concurrency Patterns

## Purpose

Go makes concurrency easy to write and easy to get subtly wrong. This skill is the standard every Go skill that spawns a goroutine defers to for general lifecycle discipline — the specific goroutine each of those skills owns (the relay, the consume loop, the parallel query fan-out) is theirs to describe; how a goroutine, any goroutine, must be owned, bounded, joined, cancelled, and race-free is decided here, once. Concurrency bounds latency and increases throughput — never decoration. A correct, fast-enough sequential version always wins over a concurrent one that merely looks more sophisticated.

---

## The Goroutine Lifecycle Standard: Owned, Bounded, Joined

Before writing `go` or `g.Go`, every spawn site must answer three questions in the affirmative — this is a literal checklist, not a guideline, and it applies to every goroutine spawned anywhere in this repo's generated code:

1. **Owned** — a specific parent supervises it in code (an `errgroup`, a worker-pool loop, a relay's `Run`). Orphans (`go func(){ … }()` with no supervisor) are forbidden.
2. **Bounded** — there is an explicit, numeric cap on how many instances of it can exist concurrently (`SetLimit`, a fixed worker count, or a known-length fan-out), never an unbounded per-item spawn.
3. **Joined** — a specific call blocks until it finishes and surfaces its outcome (`g.Wait()`, `wg.Wait()`), so "the process just keeps running" is never the only exit path and an error never vanishes silently.

Errors propagate to the owner (`errgroup`'s aggregated error, or a result channel) — never logged-and-swallowed at the spawn site. This checklist applied against every errgroup pattern already in this repo (composition root, relay, worker pool, heartbeat ticker, parallel fan-out): `references/goroutine-lifecycle-standard.md`.

---

## errgroup — the Default for Parallel Work

`golang.org/x/sync/errgroup` is the default tool for parallel stages needing error propagation and coordinated cancellation: the group's derived context cancels the instant any goroutine returns an error, so siblings stop promptly, and `g.Wait()` is the one join point that both waits and surfaces the first error. Reach for it before hand-rolling `sync.WaitGroup` + a result channel — the plumbing it replaces is exactly the plumbing hand-rolled versions get wrong. Worked `fanOutProcess`/worker-pool examples: `references/goroutine-lifecycle-standard.md`.

---

## Channels: Buffered vs Unbuffered

| Channel | Semantics | Use for |
|---|---|---|
| **Unbuffered** | Send blocks until a receiver is ready — a synchronisation point | Handoff/rendezvous; signalling; backpressure by design |
| **Buffered** | Send blocks only once full — decouples producer/consumer pace | Smoothing bursts; a worker pool's job queue with a known, deliberate bound |

Rules: the **sender closes**, never the receiver, and only once, when no further sends will happen; a closed channel yields its zero value immediately, so detect closure with the two-value receive (`v, ok := <-ch`); every blocking channel op that could outlive a request selects on `<-ctx.Done()` so cancellation always wins; a buffer size is a measured, deliberate bound, never "make it big" — see the Memory & Performance standard below for exactly what that bound costs and trades off.

---

## The sync Primitives — Full Decision Table

| Primitive | Use when | Never use it for | Worked example |
|---|---|---|---|
| `chan` | Handing off *ownership* of data between goroutines, or signalling an occurrence | Guarding a struct's own internal state in place | Worker pool job channel (this file); fan-in, `references/worked-example.md` |
| `sync.Mutex` | Protecting a small critical section of shared mutable state | Held across I/O or a channel op | `go-middleware`'s `limiterStore` map — `references/sync-primitives-decision-table.md` |
| `sync.RWMutex` | Read-heavy state, rare writes, and the critical section is genuinely read-dominated | Write-heavy or roughly-even read/write state (plain `Mutex` is simpler and often faster) | `health-check-design`'s `Readiness.ready` flag — `references/sync-primitives-decision-table.md` |
| `sync.WaitGroup` | Waiting on a known set of goroutines with no result/error to collect | Anything where an error must propagate (use `errgroup` instead) | Fan-in's merge goroutine — `references/worked-example.md` |
| `sync.Once` | Exactly-once lazy initialisation (a cache, a compiled regexp, a singleton config load) | Repeated or conditional init (`Once` fires exactly once, ever) | `references/sync-primitives-decision-table.md` |
| `sync/atomic` | A single-word lock-free counter or flag under high contention | Any state larger than one field — not a `Mutex` substitute at that size | `go-event-consumer`'s `lastLoopPulse`/`lastTickerPulse` heartbeat; `go-chaos-test`'s `failNext atomic.Bool` |
| `errgroup` | Parallel stages needing coordinated cancellation and first-error propagation | A single goroutine with nothing to coordinate | `go-service-layer`'s parallel query fan-out (ad hoc confinement, no mutex needed) |

The sharper heuristic behind the table (Cox-Buday): are you transferring *ownership* of data, coordinating independent logic, or signalling an occurrence? → channel. Are you guarding a struct's own internal state in a small critical section? → `Mutex`/`RWMutex`, or `atomic` if that state is one field. Full table with every worked example expanded: `references/sync-primitives-decision-table.md`.

---

## Confinement — the Third Alternative to Channel or Mutex

Structuring code so a piece of data is, by construction, reachable by exactly one goroutine eliminates the need for a channel or mutex entirely — there is no race to synchronise against because the concurrent touch cannot happen. **Ad hoc confinement** (a convention, e.g. each `errgroup` goroutine in a fan-out writes only its own destination variable) is distinct from **lexical confinement** (enforced by scope). `go-service-layer`'s parallel query fan-out is ad hoc confinement in production use — no mutex, because `assets` and `gaps` are never touched by more than one goroutine, and `g.Wait()` orders every write before the parent reads either.

---

## Worker Pool and Fan-Out / Fan-In

A worker pool throttles a long stream of tasks to a fixed number of workers draining a bounded job channel — steady, bounded resource use (`go-event-consumer`'s batch processing is one instance). Fan-out distributes work across goroutines; fan-in merges results into one channel via a dedicated merge goroutine that closes the output only after every producer finishes, coordinated with a `WaitGroup`. Full worker-pool and generic `fanIn[T any]` listings, each checked against the Owned/Bounded/Joined standard: `references/goroutine-lifecycle-standard.md` and `references/worked-example.md`.

---

## Context Propagation Standard

`ctx context.Context` is **always the first parameter**, never a struct field — storing it hides the cancellation scope from the call signature and invites a stale or wrong-scoped context being reused later. Any loop that could run longer than one tick selects on `ctx.Done()` every iteration, not just at entry. A goroutine that must finish a bounded amount of work *after* its parent is cancelled (a final commit, a graceful drain) derives a **fresh**, separately-timed-out context from `context.Background()` — reusing the already-cancelled parent makes that final call fail instantly. Full standard, the exact "never store" list, and the drain worked example: `references/context-propagation-standard.md`.

---

## Memory and Performance for Concurrent Code

A goroutine's stack starts at ~2KB and grows on demand — cheap relative to an OS thread, but not free: an unbounded goroutine-per-request or goroutine-per-item pattern under high concurrency is a real memory risk, and every goroutine that captures a heap-escaping variable keeps that memory live for as long as the goroutine itself is. Worker-pool sizing is workload-shaped, not a guess: CPU-bound work is capped at `runtime.GOMAXPROCS(0)` (more just adds context-switch overhead with no throughput gain); I/O-bound work waiting on network calls sizes higher, starting from `GOMAXPROCS × (1 + wait/service)` and validated with a real saturation sweep (`go-load-test`), never trusted as an exact number. Channel buffers trade a bounded memory allocation and a delayed backpressure signal for decoupled producer/consumer pacing. Full standard with the sizing derivation: `references/memory-performance-standard.md`.

---

## Deadlock, Livelock, and Starvation

Three distinct failure modes, each different from a goroutine leak (unbounded, no exit) and a data race (unsynchronized concurrent access): **deadlock** — goroutines each wait on a resource the other holds; **livelock** — goroutines actively run and yield to each other with no real progress; **starvation** — a goroutine that could proceed is perpetually denied its needed resource. **The critical caveat: Go's runtime deadlock detector only catches a *full* deadlock — every goroutine blocked at once.** A partial deadlock (one corner stuck, the rest of the process fine) and a livelock (actively scheduled, not blocked) are both silent to it, and silent to `go test -race` too, which proves only the absence of data races. Neither is found by a crash — both are found only by behavioral/load testing and a `pprof` goroutine dump. Full step-by-step incident-response runbook, what to check first, and how to read a goroutine-dump stack trace: `references/deadlock-livelock-starvation-runbook.md`. Confirmed with a hypothesis-driven chaos experiment, not inferred from one snapshot: `go-chaos-test`'s partial-deadlock/livelock row.

---

## Testing: Race Detector Mandatory, and How to Actually Trigger a Race

`-race` is on for every test run, everywhere, no exceptions — enforced repo-wide by `go-makefile`, not re-decided per package. But a race the scheduler never happens to interleave during a run is invisible to `-race` regardless — passing once is not proof of absence. A test that reliably exercises a race forces the interleaving with an explicit barrier (both goroutines signal "ready," then both are released at once onto the racy line) rather than hoping incidental timing produces it; run repeatedly (`-race -count=100`) since scheduler nondeterminism still means one clean run proves nothing. Full pattern and worked example: `references/testing-race-conditions.md`.

---

## Leak Prevention Checklist

- Every `go`/`g.Go` satisfies Owned, Bounded, and Joined (above) — no exceptions for "small" or "temporary" goroutines.
- No blocking send/receive without a `select { … case <-ctx.Done(): }` escape if it could outlive a request.
- Channels are closed by the sender, exactly once.
- `go test -race ./...` passes, repeatedly, not just once (`go-makefile`).
- Goroutine count is stable under sustained load — verified with pprof's goroutine profile (`go-performance-optimization`), not assumed.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Owned | Every goroutine has a supervisor in code (`errgroup`/pool/loop) | Orphan `go func(){}()` |
| Bounded | Concurrency capped (`SetLimit`/fixed workers/known fan-out length) | Unbounded goroutine-per-item |
| Joined | A specific call blocks on completion and surfaces errors | "Process just keeps running," errors dropped |
| Cancellation honoured | Every blocking op `select`s on `ctx.Done()` | Blocking send/recv with no escape |
| Context discipline | `ctx` is always param 1, never a struct field; drain uses a fresh bounded context | `ctx` stored on a struct; drain reuses the cancelled parent |
| Sync primitive fits the table | Channel for handoff, Mutex/RWMutex for internal state, atomic for one field | Mutex around large/nested state; channel where confinement would do |
| Channel discipline | Sender closes once; buffer size is a measured, stated bound | Receiver closes; an arbitrary huge buffer |
| Memory-aware fan-out | Worker count derived from CPU-bound vs I/O-bound formula, validated by load test | "Big enough" worker count picked by feel |
| Race-free, repeatedly | `go test -race -count=N` clean, not just a single green run | One clean `-race` run trusted as proof |
| Deadlock/livelock awareness | Diagnosed via the runbook + a chaos experiment, not inferred from a hunch | Assuming `-race` or the runtime detector would have caught a stuck/spinning goroutine |

---

## Anti-Patterns

- **Orphan goroutines** — no owner, no exit signal, no error path. The canonical slow leak.
- **Goroutine-per-item fan-out** — one goroutine per element of an unbounded input. Always cap with `SetLimit` or a fixed worker count.
- **`ctx` stored on a struct field** — hides the cancellation scope from every call signature that reads it later; reused stale or wrong-scoped.
- **Holding a mutex across I/O or a channel op** — serialises the system on the slowest call and invites deadlock. Lock, touch memory, unlock.
- **`time.Sleep` as synchronisation** — sleeping "long enough" races by construction. Synchronise on a channel, `WaitGroup`, or context.
- **Closing a channel from the receiver, or from more than one goroutine** — panics on the next send.
- **Huge "safety" buffers** — `make(chan T, 100000)` hides backpressure until memory runs out; a buffer is a measured bound, not a pressure valve.
- **Trusting one clean `-race` run, or the runtime deadlock detector, to prove a stuck goroutine can't happen** — neither claim holds; see the Testing and Deadlock/Livelock standards above.
- **`tt := tt` loop-variable copies** — dead weight on Go 1.22+, where loop variables are per-iteration; a sign of an unported pre-1.22 habit.

---

## Output Format

This skill governs how goroutines are written wherever they appear in generated code — it does not own a single artifact file the way a domain model or a repository does. Reusable plumbing (a pool, a fan-in) lives in a small internal package; every file in it, and every goroutine spawned anywhere else in the codebase, must satisfy the Owned/Bounded/Joined checklist and pass `go test -race` before it is considered done:

```
internal/pkg/concurrency/pool.go      (generic worker pool)
internal/pkg/concurrency/fanin.go     (generic fan-in)
internal/pkg/concurrency/*_test.go    (table-driven, race-forcing barrier tests; written first)
```
