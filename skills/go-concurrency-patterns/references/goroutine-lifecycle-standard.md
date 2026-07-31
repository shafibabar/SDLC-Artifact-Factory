# Goroutine Lifecycle Standard: Owned, Bounded, Joined

Full standard referenced from `go-concurrency-patterns/SKILL.md`'s "The Goroutine
Lifecycle Standard" section. Self-contained — reads without the parent body already
in context.

Every goroutine spawned anywhere in this repo's generated code must satisfy three
properties before it is considered done. This is a literal checklist to run against
each `go`/`g.Go` call site, not general advice:

1. **Owned** — a specific parent supervises it in code: an `errgroup`, a worker-pool
   loop, a relay's `Run` method, a consumer's consume loop. An "orphan" — `go func(){
   … }()` with nothing supervising it — is forbidden regardless of how small or
   short-lived it looks.
2. **Bounded** — there is an explicit, numeric cap on how many instances of this
   goroutine shape can exist concurrently at once: `errgroup.SetLimit(n)`, a fixed
   worker count in a `for range workers` spawn loop, or a known-length fan-out (one
   goroutine per element of a slice whose length is fixed at call time, not an
   unbounded stream). Never an unbounded per-item spawn against an open-ended input.
3. **Joined** — a specific, blocking call waits for completion and surfaces the
   outcome: `g.Wait()` (returns the first error), `wg.Wait()` (for goroutines with no
   error to report). "The process just keeps running and we assume it finished" is
   never a join point.

Errors propagate to the owner — via `errgroup`'s aggregated error or a result
channel the joining code actually reads — never logged-and-swallowed at the spawn
site itself.

```go
// WRONG: orphan, no bound, no join, error swallowed
go func() { _ = doForever() }()

// RIGHT: owned by g, bounded by SetLimit, joined by g.Wait(), error propagates
g.SetLimit(concurrency)
g.Go(func() error {
    return doUntil(ctx) // returns when ctx is cancelled or work completes
})
```

---

## errgroup — the Default Owner

`golang.org/x/sync/errgroup` is the default supervisor for parallel work because it
gives all three properties by construction: the group *is* the owner, `SetLimit`
gives the bound, and `g.Wait()` is the join point that also surfaces the first error
and cancels the group's derived context so siblings stop promptly.

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

Reach for `errgroup` before a hand-rolled `sync.WaitGroup` + result channel — the
error and cancellation plumbing it replaces is exactly what hand-rolled versions get
wrong.

---

## Worker Pool

A worker pool throttles a long stream of tasks to a fixed number of workers draining
a bounded job channel — steady, bounded resource use for a workload with more items
than you want concurrent goroutines.

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

Each worker satisfies all three properties: owned by the group, bounded by the
`for range workers` spawn count, joined and error-propagating via `g.Wait()`.

---

## The Checklist Applied to Every errgroup Pattern Already in This Repo

| Pattern | Owned by | Bounded by | Joined by |
|---|---|---|---|
| `go-service-skeleton`'s composition root | The top-level `errgroup` that starts every long-running component | One goroutine per named component (HTTP server, relay, consumer) — a small, fixed, enumerable set | `g.Wait()` in `main`, blocking until every component has stopped |
| `go-event-publisher`'s relay | The composition root's `errgroup` | Exactly one goroutine — the relay has no fan-out of its own | The relay's `Run` returning when `ctx.Done()` fires, joined by the owning `g.Wait()` |
| `go-event-consumer`'s worker pool | An `errgroup` created inside the consumer's `Run` | A fixed worker count sized to the batch/partition concurrency | `g.Wait()` inside `Run`, after which offsets are safe to commit |
| `go-event-consumer`'s heartbeat ticker | The same `errgroup` as the worker pool — a sibling goroutine, not a stray one | Exactly one ticker goroutine per consumer instance | Exits on the same `ctx.Done()` the worker pool selects on; joined by the same `g.Wait()` |
| `go-service-layer`'s parallel query fan-out | An `errgroup` created inline in the query handler | Exactly two goroutines — one per independent data source, a known-length fan-out, not an open-ended stream | `g.Wait()` before the handler reads either result variable |
| Generic worker pool (this file) | The enclosing `errgroup` | `workers` — a caller-supplied, fixed integer | `g.Wait()` |
| Generic fan-in (`references/worked-example.md`) | The enclosing `fanIn` call, via a `sync.WaitGroup` | `len(sources)` — fixed at call time | `wg.Wait()` inside the goroutine that closes the merged output channel |

No pattern in this table has an orphan goroutine, an unbounded spawn, or a missing
join point — this is the standard every new goroutine spawn site should be checked
against before being considered complete.
