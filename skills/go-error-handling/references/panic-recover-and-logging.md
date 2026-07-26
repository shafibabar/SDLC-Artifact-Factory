# Panic/Recover Discipline and the Error-Logging Standard

Full worked material for `SKILL.md`'s "Panic and Recover" and "Log Once at the
Boundary" sections. Self-contained — reads without the parent body already in
context.

---

## 1. When `panic` Is Correct — and When It Is Not

`panic` is reserved for **unrecoverable** states: a programming error, or a
failed critical initialisation that makes continuing meaningless. It is never
flow control for an ordinary, expected failure.

| Situation | Mechanism | Why |
|---|---|---|
| User sent bad input | Return an error (422/400) | Expected, recoverable — happens on every deployment, every day |
| Downstream DB is down | Return a wrapped error; retry/circuit-break | Expected failure mode of a distributed system, not a bug |
| Required config missing at startup | Acceptable to `panic`/fatal in `main` | The process cannot run in any meaningful state; there is no caller to hand an error to |
| Invariant that "can't happen" is violated (e.g. tenant missing after auth passed) | `panic` | It is a bug, by definition — the system reached a state its own logic claims is impossible. Caught at a boundary (below), not resumed. |

Donovan & Kernighan's framing (ch. 5.9) is the source of this boundary: `panic`
is for programmer errors and truly unrecoverable situations, never a substitute
for an `error` return, and `recover` is only sensibly used at a boundary — a
server's per-request handler — so one bad request doesn't take the whole process
down.

---

## 2. The Two-Place Recover Rule

`recover` lives in exactly two places in this repo's generated code — nowhere
else. Both exist for the identical reason: to convert an unrecoverable panic
into a contained, reported failure at the narrowest boundary that can absorb it
without losing the rest of the running process.

- **The HTTP `Recoverer` middleware** (one per chain — see `go-middleware`). It
  must be the **first** middleware registered, wrapping every other middleware
  and the handler itself, so a panic anywhere in the chain degrades exactly one
  request rather than crashing the process. The full placement rules, the exact
  `recover()` code, the reasoning for why `Recoverer` sits outermost despite the
  trade-off that costs (its own `r.Context()` never carries a request ID set by
  an inner middleware), and the canonical 500 response shape are `go-middleware`'s
  own — see its `references/recoverer-and-response-wrapping.md`. This skill states
  the boundary rule; it does not restate that skill's implementation.
- **The top of each spawned goroutine that could panic**, so a worker's panic
  doesn't take down the pool or the process it runs in (Go does not propagate a
  panic across a goroutine boundary — an unrecovered panic in any goroutine, even
  a background one, crashes the entire process, not just that goroutine).

```go
g.Go(func() (err error) {
    defer func() {
        if r := recover(); r != nil {
            err = fmt.Errorf("panic in worker: %v", r) // convert panic → error, propagate to owner
        }
    }()
    return work(gctx, job)
})
```

A `recover` anywhere other than these two places is a smell — it almost always
means a panic is being used as control flow, or that a failure is being silently
absorbed instead of propagated to the goroutine's owner (`go-concurrency-patterns`'
Owned/Bounded/Joined standard).

---

## 3. Log Once at the Boundary — "Log-and-Return Duplication"

**The anti-pattern, named precisely:** logging an error *and* returning it up the
call chain, so the same underlying failure gets logged independently by every
layer it passes through. One real incident then produces N near-identical,
differently-worded log lines — one per layer that both logged and returned —
making the actual incident harder to reconstruct, not easier, because a reader
has to deduplicate N log entries back into the one failure they all describe.

```go
// WRONG — log-and-return duplication. Each layer logs the same underlying
// failure on its way up, so one incident produces three log lines.
func (r *DataAssetRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.DataAsset, error) {
    row := r.q.QueryRow(ctx, `SELECT ... WHERE id = $1`, id)
    a, err := scanDataAsset(row)
    if err != nil {
        slog.ErrorContext(ctx, "failed to find data asset", "id", id, "error", err) // logged here...
        return nil, translatePgError(err, domain.ErrNotFound)                       // ...and returned here
    }
    return a, nil
}

func (h *ClassifyDataAssetHandler) Handle(ctx context.Context, cmd ClassifyDataAsset) error {
    asset, err := h.assets.FindByID(ctx, cmd.DataAssetID)
    if err != nil {
        slog.ErrorContext(ctx, "handle failed", "error", err) // logged AGAIN, same underlying failure
        return fmt.Errorf("classifying: %w", err)
    }
    // ...
}
```

```go
// RIGHT — every intermediate layer only wraps and returns; exactly one place
// (the boundary that owns the request — the HTTP handler, the event
// consumer's message handler, or main for a startup failure) logs.
func (r *DataAssetRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.DataAsset, error) {
    row := r.q.QueryRow(ctx, `SELECT ... WHERE id = $1`, id)
    a, err := scanDataAsset(row)
    if err != nil {
        return nil, fmt.Errorf("finding data asset %s: %w", id, translatePgError(err, domain.ErrNotFound))
    }
    return a, nil
}

func (h *ClassifyDataAssetHandler) Handle(ctx context.Context, cmd ClassifyDataAsset) error {
    asset, err := h.assets.FindByID(ctx, cmd.DataAssetID)
    if err != nil {
        return fmt.Errorf("classifying data asset %s: %w", cmd.DataAssetID, err) // wrap, don't log
    }
    // ...
}

// go-chi-handler's writeDomainError is the one place this error is finally
// logged, at the boundary that owns the request:
func writeDomainError(w http.ResponseWriter, r *http.Request, err error) {
    slog.ErrorContext(r.Context(), "request failed", "error", err) // the ONE log line
    // ...map err to a status code and write the response (go-chi-handler)
}
```

The rule generalises across every boundary type in this repo, not just HTTP:

| Boundary | The one place that logs |
|---|---|
| HTTP request | `go-chi-handler`'s `writeDomainError` / the `Recoverer` middleware for a panic |
| Consumed event | `go-event-consumer`'s message-handling loop, at the point it gives up (moves to DLQ) or acknowledges |
| Background/startup failure | `main`, immediately before `os.Exit`/`log.Fatal` |

Every layer *between* the origin and the boundary wraps and returns — it adds
context via `%w` (`references/error-taxonomy-and-wrapping.md`), it never calls
`slog`. This is the same "handle it exactly once" principle the taxonomy file's
wrapping rules already encode for *context*; here it applies to *reporting*.

### Why the Boundary, Specifically

Only the boundary has enough information to decide the error's actual severity
and audience (a 404 is not an incident; a panic is) and is the last point before
the failure either becomes a client-visible response or disappears from the
process entirely — logging anywhere else either duplicates that decision or
makes it prematurely, without the full wrapped context the boundary receives.
