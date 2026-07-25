# Context Propagation Standard

Full standard referenced from `go-concurrency-patterns/SKILL.md`'s "Context
Propagation Standard" section. Self-contained — reads without the parent body
already in context. Grounded in Cox-Buday's *Concurrency in Go* (the
`context.Context`-as-cancellation-tree chapter) and Donovan & Kernighan's *The Go
Programming Language*; cross-checked against every layer of this repo's Go skills
(`go-chi-handler`, `go-service-layer`, `go-repository-pattern`, `go-event-consumer`,
`go-event-publisher`), all of which already follow this discipline uniformly.

---

## Rule 1: `ctx context.Context` Is Always the First Parameter

Every function that can block, call downstream, or be cancelled takes `ctx` as its
first parameter, named `ctx`, never buried later in the signature or bundled into a
struct or a request/options type. This is Go's single most well-known idiom, and
its violation is the single most well-known way to violate it: a `ctx` that isn't
the first parameter is easy for a future edit to silently drop or reorder past.

```go
// RIGHT
func (r *DataAssetRepo) FindByID(ctx context.Context, id uuid.UUID) (*DataAsset, error)

// WRONG — ctx buried, easy to drop on the next edit
func (r *DataAssetRepo) FindByID(id uuid.UUID, ctx context.Context) (*DataAsset, error)
```

---

## Rule 2: What NEVER Stores a Context

A `context.Context` is never a struct field, never a package-level variable, and
never a field on a message/event type carried through a channel for later use. All
three hide the cancellation scope from the call signature — the whole reason
`context.Context` is threaded explicitly through every call, rather than looked up
from ambient state:

- **Never a struct field.** `type Consumer struct { ctx context.Context }` is
  forbidden — checked and confirmed absent across every struct in this repo's Go
  skills (`OutboxRelay`, `Consumer`, every handler and repository). Each method
  takes `ctx` as its own first parameter instead, scoped to that single call.
- **Never a package-level variable.** A shared, mutable "current context" invites
  one call's cancellation or deadline leaking into an unrelated call that happens
  to run concurrently.
- **Never a field on a value sent over a channel for later use.** A context
  captured at send time and acted on later, after its original deadline or
  cancellation scope has become stale, silently uses the wrong scope — if a
  goroutine needs a context to act on a channel value, it should already have its
  own (typically the group's `gctx` from `errgroup.WithContext`), not one riding
  along inside the payload.

The one narrow, deliberate exception to "always derive downward, never store": a
component that must finish a bounded amount of work *after* its parent has already
been cancelled (see Rule 4) derives a **fresh** context from `context.Background()`
rather than reusing the cancelled parent — that fresh context is still not stored
anywhere; it lives only for the duration of the one bounded call that needs it.

---

## Rule 3: Cancellation-Checking Discipline in Long Loops

Any loop that could run longer than a single tick — a consume loop, a worker
pool's job loop, a retry-with-backoff loop, a batch-processing loop — selects on
`ctx.Done()` on every iteration, not only once at entry. Checking cancellation only
before the loop starts means a cancelled context is not honoured until the current
iteration (which could itself be slow, or unbounded) happens to finish on its own.

```go
for {
    select {
    case <-ctx.Done():
        return ctx.Err() // checked every iteration, not just once before the loop
    case job, ok := <-jobs:
        if !ok {
            return nil
        }
        if err := handle(ctx, job); err != nil {
            return err
        }
    }
}
```

This is the same shape as the Worker Pool example in
`references/goroutine-lifecycle-standard.md` — the `select` on `gctx.Done()` inside
the `for` is what makes cancellation actually stop the loop promptly, rather than
merely being checked once and then ignored for however long the loop keeps running.

---

## Rule 4: A Fresh, Bounded Context for Post-Cancellation Work

Some cleanup must happen *after* the parent context is already cancelled — a
consumer's final offset commit on shutdown, a relay's last transaction rollback.
Reusing the parent context for that final call fails instantly, since the parent is
already `Done()`. The correct pattern derives a new, separately-timed-out context:

```go
dctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
defer cancel()
c.client.CommitUncommittedOffsets(dctx) // errors here just mean re-delivery on restart
c.client.Close()
```

`go-event-consumer`'s graceful drain is the real, in-repo instance of this exact
pattern — the parent `ctx` is already cancelled by the time `drain` runs, so it
derives `dctx` from `context.Background()` with its own bound, rather than
attempting (and instantly failing) to reuse the parent.

---

## Quick Self-Check

| Question | If the answer is wrong |
|---|---|
| Is `ctx` parameter 1, named `ctx`, on every function that can block or call downstream? | Reorder it — never bury it after other parameters |
| Does any struct anywhere have a `ctx context.Context` field? | Remove it; thread `ctx` through the method call instead |
| Does every loop that could run long check `ctx.Done()` every iteration? | Add the `select` inside the loop body, not only before it |
| Does post-cancellation cleanup reuse the already-cancelled parent context? | Derive a fresh, separately-bounded context from `context.Background()` instead |
