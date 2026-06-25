---
name: go-concurrency-patterns
description: >
  Teaches idiomatic, leak-free Go concurrency — goroutine lifecycle discipline
  (every goroutine has a bounded lifetime and an explicit exit tied to a parent
  context), channels (buffered vs unbuffered), the sync primitives (Mutex,
  RWMutex, Once, Pool), errgroup for parallel pipeline stages with error
  propagation and cancellation, worker pools, and fan-out/fan-in. The standard
  this plugin holds for any code that spawns goroutines. Used by the
  backend-engineer during Implement.
version: 1.0.0
phase: implement
owner: backend-engineer
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
        it := it                          // capture loop var (pre-1.22 safety; explicit is clearer regardless)
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

Prefer **sharing by communicating** (channels) over **communicating by sharing** (mutexes) when designing data flow — but a `Mutex` around a small in-memory map is simpler and faster than a channel-guarded goroutine, so use judgement, not dogma.

---

## Worker Pool

A worker pool throttles concurrent work to a fixed number of workers draining a bounded job channel. Use it when you have a long stream of tasks and want steady, bounded resource use (the consumer's batch processing is one instance — see `go-event-consumer`).

```go
func runPool(ctx context.Context, workers int, jobs <-chan Job, handle func(context.Context, Job) error) error {
    g, gctx := errgroup.WithContext(ctx)
    for i := 0; i < workers; i++ {
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

Fan-out: distribute work across goroutines. Fan-in: merge their results into one channel. The merge goroutine closes the output only after all producers finish — coordinated with a `WaitGroup`.

```go
func fanIn[T any](ctx context.Context, sources ...<-chan T) <-chan T {
    out := make(chan T)
    var wg sync.WaitGroup
    wg.Add(len(sources))
    for _, src := range sources {
        go func(c <-chan T) {
            defer wg.Done()
            for v := range c {
                select {
                case out <- v:
                case <-ctx.Done():
                    return
                }
            }
        }(src)
    }
    go func() { wg.Wait(); close(out) }() // close exactly once, after all producers done
    return out
}
```

---

## Leak Prevention Checklist

- Every `go`/`g.Go` has an owner and a `ctx.Done()` (or closed-channel) exit.
- No send/receive without a `select { … case <-ctx.Done(): }` escape if it could block past its request.
- Channels are closed by the sender, exactly once.
- The race detector passes: `go test -race ./...` (mandatory — see `go-makefile`).
- Goroutine count is stable under load (verify with pprof goroutine profile — see `go-performance-optimization`).

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

---

## Output Format

Produces Go source plus race-tested concurrent code. Reusable plumbing lives in a small internal package:

```
internal/pkg/concurrency/pool.go      (generic worker pool)
internal/pkg/concurrency/fanin.go     (generic fan-in)
internal/pkg/concurrency/*_test.go    (table-driven + `go test -race`; written first)
```
