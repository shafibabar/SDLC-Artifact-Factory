---
name: go-concurrency-patterns
description: >
  Teaches idiomatic, leak-free Go concurrency — goroutine lifecycle discipline
  (every goroutine has a bounded lifetime and an explicit exit tied to a parent
  context), channels (buffered vs unbuffered), the sync primitives (Mutex,
  RWMutex, Once, Pool, WaitGroup, atomic), errgroup for parallel pipeline
  stages with error propagation and cancellation, worker pools, fan-out/fan-in,
  and the deadlock/livelock/starvation vocabulary with the critical caveat that
  Go's runtime deadlock detector and the race detector both miss a partial
  deadlock or a livelock. The standard this plugin holds for any code that
  spawns goroutines. Used by the backend-engineer during Implement.
version: 2.0.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, concurrency, goroutine, channel, errgroup, worker-pool, context]
---

# Go Concurrency Patterns

## Purpose

Go makes concurrency easy to write and easy to get subtly wrong. This skill is the standard for any code that spawns a goroutine. The governing rule, from the blueprint: **every goroutine has a deterministic lifecycle, a bounded lifetime, and an explicit exit mechanism linked to a parent context.** A goroutine with no owner and no exit is a leak; a leak is a slow outage.

Concurrency is used to *bound latency and increase throughput*, never as decoration. If a sequential version is correct and fast enough, it wins.

---

## The Goroutine Lifecycle Rule

Before writing `go`, answer three questions. If any answer is unclear, do not spawn the goroutine.

1. **Who owns it?** Some parent supervises it (an `errgroup`, the consume loop, the relay). Orphans are forbidden.
2. **When does it exit?** It exits on a specific signal — `ctx.Done()`, a closed channel, or finishing its work. "When the program ends" is not an exit mechanism.
3. **How are its errors handled?** Errors propagate to the owner (via `errgroup` or a result channel), never silently swallowed or logged-and-forgotten.

```go
// WRONG: orphan with no exit and a swallowed error
go func() { _ = doForever() }()

// RIGHT: owned, context-bound, error-propagating
g.Go(func() error {
    return doUntil(ctx) // returns when ctx is cancelled or work completes
})
```

---

## errgroup — the Default for Parallel Work

`golang.org/x/sync/errgroup` is the default tool for running parallel stages with error propagation and coordinated cancellation. The group's derived context is cancelled when the first goroutine returns an error, so siblings stop promptly.

```go
func fanOutProcess(ctx context.Context, items []Item, concurrency int, work func(context.Context, Item) error) error {
    g, gctx := errgroup.WithContext(ctx)
    g.SetLimit(concurrency)              // bounded — never unbounded fan-out
    for _, it := range items {
        g.Go(func() error {
            return work(gctx, it)         // gctx cancellation stops all on first error
        })
    }
    return g.Wait()                       // single join + first error
}
```

Reach for `errgroup` before raw `sync.WaitGroup` + channels — it handles the error and cancellation plumbing that hand-rolled versions get wrong.

---

## Channels: Buffered vs Unbuffered

| Channel | Semantics | Use for |
|---|---|---|
| **Unbuffered** | Send blocks until a receiver is ready — a synchronisation point | Handoff/rendezvous; signalling; backpressure by design |
| **Buffered** | Send blocks only when full — decouples producer/consumer rates | Smoothing bursts; a worker pool's job queue with a known bound |

Rules:
- **The sender closes**, never the receiver, and only when no more sends will happen.
- **A closed channel** yields the zero value immediately — use the two-value receive `v, ok := <-ch` to detect closure.
- **`select` with `<-ctx.Done()`** on every blocking channel op that could outlive a request, so cancellation always wins.
- **Buffer size is a deliberate bound**, never an arbitrary "make it big." An unbounded or huge buffer hides backpressure problems.

```go
select {
case job := <-jobs:
    process(job)
case <-ctx.Done():
    return ctx.Err() // cancellation always has an escape hatch
}
```

---

## The sync Primitives

| Primitive | Use when | Notes |
|---|---|---|
| `sync.Mutex` | Protect a small critical section of shared mutable state | Hold the lock briefly; never across I/O or a channel op |
| `sync.RWMutex` | Read-heavy shared state with rare writes | Only when reads genuinely dominate; otherwise `Mutex` is simpler/faster |
| `sync.Once` | One-time lazy init (a cache, a compiled regexp) | The idiomatic singleton-init |
| `sync.Pool` | Reuse short-lived, frequently-allocated objects on hot paths | See `go-performance-optimization`; profile-justified |
| `sync.WaitGroup` | Wait for a known set of goroutines with no error return | Prefer `errgroup` when errors matter |
| `sync/atomic` | Lock-free counters/flags on a single word under high contention | Cheaper than `Mutex` when the guarded state is one numeric/boolean field — not a substitute for `Mutex` on anything larger. Already used this way in `go-chaos-test`'s `faultyPublisher` (`failNext atomic.Bool`) |

Prefer **sharing by communicating** (channels) over **communicating by sharing** (mutexes) when designing data flow — but a `Mutex` around a small in-memory map is simpler and faster than a channel-guarded goroutine, so use judgement, not dogma. The sharper two-question heuristic: are you transferring *ownership* of data, or coordinating independent pieces of logic, or signalling an occurrence? → channel. Are you guarding a struct's own internal state, in a small critical section? → `Mutex`/`RWMutex`, or `sync/atomic` if that state is a single counter or flag.

---

## Worker Pool

A worker pool throttles concurrent work to a fixed number of workers draining a bounded job channel. Use it when you have a long stream of tasks and want steady, bounded resource use (the consumer's batch processing is one instance — see `go-event-consumer`).

```go
func runPool(ctx context.Context, workers int, jobs <-chan Job, handle func(context.Context, Job) error) error {
    g, gctx := errgroup.WithContext(ctx)
    for range workers {
        g.Go(func() error {
            for {
                select {
                case <-gctx.Done():
                    return gctx.Err()
                case job, ok := <-jobs:
                    if !ok {
                        return nil // jobs channel closed by the producer ⇒ clean exit
                    }
                    if err := handle(gctx, job); err != nil {
                        return err // cancels the group; other workers drain and exit
                    }
                }
            }
        })
    }
    return g.Wait()
}
```

Each worker has all three lifecycle properties: owned by the group, exits on closed channel or cancelled context, propagates its error.

---

## Fan-Out / Fan-In

Fan-out: distribute work across goroutines. Fan-in: merge their results into one channel. The merge goroutine closes the output only after all producers finish — coordinated with a `WaitGroup`. Full generic `fanIn[T any]` implementation: `references/worked-example.md`.

---

## Leak Prevention Checklist

- Every `go`/`g.Go` has an owner and a `ctx.Done()` (or closed-channel) exit.
- No send/receive without a `select { … case <-ctx.Done(): }` escape if it could block past its request.
- Channels are closed by the sender, exactly once.
- The race detector passes: `go test -race ./...` (mandatory — see `go-makefile`).
- Goroutine count is stable under load (verify with pprof goroutine profile — see `go-performance-optimization`).

---

## Deadlock, Livelock, and Starvation

Three distinct failure modes — each different from a goroutine leak (an unbounded goroutine with no exit) and from a data race (concurrent access to unsynchronized memory):

- **Deadlock** — two or more goroutines each wait on a resource the other holds; neither can proceed. A **partial deadlock** (some goroutines stuck, others still running fine) is the common shape in a real service; a **full deadlock** (every goroutine in the process blocked simultaneously) is rarer but is the one case the runtime notices.
- **Livelock** — goroutines are actively running and scheduled, repeatedly reacting to each other (backing off, retrying, yielding), but making no real progress — CPU stays busy, throughput stays near zero.
- **Starvation** — a goroutine that *could* proceed is perpetually denied the resource it needs (an unfair lock, a greedy sibling that never backs off), while the rest of the system keeps running normally.

> **The critical caveat — read this before trusting any tool to catch these: Go's runtime deadlock detector (`fatal error: all goroutines are asleep - deadlock!`) only catches *full* deadlock, the case where every single goroutine in the program is simultaneously blocked at once.** It does **not** catch a partial deadlock — the process stays up, one corner of the system just silently stops making progress — and it does **not** catch a livelock, because a livelocked goroutine is actively scheduled and running, not blocked, so the detector has nothing to trigger on. Both failure shapes are also invisible to `go test -race`: the race detector proves the absence of *data races* (concurrent, unsynchronized memory access) — a completely different problem from a goroutine that is simply stuck or spinning uselessly. **No automated tool in this toolchain catches a partial deadlock or a livelock.**

Because neither the deadlock detector nor the race detector catches these, partial deadlock and livelock are found only by **behavioral and load testing**: watch goroutine count and CPU utilization under sustained load (`runtime.ReadMemStats`, pprof's goroutine profile — see `go-performance-optimization`), and run hypothesis-driven chaos experiments that deliberately induce lock contention (see `go-chaos-test`). The signatures differ — a flat goroutine count with zero throughput and *idle* CPU is partial deadlock; a flat goroutine count with zero throughput and *pegged* CPU is livelock — but neither one crashes the process or fails a `-race` run.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Bounded lifetime | Every goroutine exits on ctx/closed channel/completion | A goroutine with no exit path |
| Owned | Supervised by errgroup/pool/loop | Orphan `go func(){}()` |
| Bounded fan-out | Concurrency capped (`SetLimit`/fixed workers) | Unbounded goroutine-per-item |
| Cancellation honoured | Blocking ops `select` on `ctx.Done()` | Blocking send/recv with no escape |
| Channel discipline | Sender closes once; buffers are deliberate bounds | Receiver closes; arbitrary huge buffers |
| Race-free | `go test -race` clean | Data races on shared state |
| Errors propagate | Via errgroup/result channel | Swallowed or logged-and-dropped |
| Deadlock/livelock awareness | Behavioral/load testing checks goroutine count + CPU under contention (see `go-chaos-test`) | Assuming `-race` or the runtime deadlock detector would have caught a stuck or spinning goroutine |

---

## Anti-Patterns

- **Orphan goroutines** — `go func(){ … }()` with no owner, no exit signal, no error path. The canonical slow leak.
- **Goroutine-per-item fan-out** — spawning one goroutine per element of an unbounded input (one per event, one per file). Always cap with `g.SetLimit` or a fixed worker count.
- **`tt := tt` / `it := it` loop-variable copies** — dead weight on Go 1.22+, where loop variables are per-iteration. Their presence signals an unported pre-1.22 habit.
- **Holding a mutex across I/O or a channel operation** — serialises the whole system on the slowest call and invites deadlock. Lock, touch memory, unlock.
- **`time.Sleep` as synchronisation** — sleeping "long enough" in production code or tests races by construction. Synchronise on a channel, a `WaitGroup`, or a context.
- **Closing a channel from the receiver** (or from multiple goroutines) — panics on the next send. The sender closes, exactly once.
- **Huge "safety" buffers** — `make(chan T, 100000)` hides backpressure until memory runs out. A buffer is a measured bound, not a pressure-relief valve.
- **Trusting `-race` or the deadlock detector to catch a stuck goroutine** — neither does. `go test -race` proves the absence of data races only; the runtime deadlock detector fires only when *every* goroutine in the process is blocked at once. A partial deadlock or a livelock is silent to both and is found only by behavioral/load testing — see "Deadlock, Livelock, and Starvation" above.

---

## Output Format

Produces Go source plus race-tested concurrent code. Reusable plumbing lives in a small internal package:

```
internal/pkg/concurrency/pool.go      (generic worker pool)
internal/pkg/concurrency/fanin.go     (generic fan-in)
internal/pkg/concurrency/*_test.go    (table-driven + `go test -race`; written first)
```
