# Parallel Query Orchestration and Confinement — Full Worked Example

Full worked material referenced from `SKILL.md`'s "Parallel Query Orchestration and
Confinement" section. Self-contained — reads without the parent body already in
context. Covers: why a dashboard-style query fans out with `errgroup` instead of
querying sequentially, and why the fan-out needs no mutex despite writing to shared
local variables from multiple goroutines.

---

## 1. The Problem: Sequential Fan-Out Sums Every Source's Latency

A dashboard query that needs data from two independent views — an asset-classification
summary and a coverage-gap summary — has no dependency between the two calls. Calling
them one after another makes the handler's total latency the *sum* of both, even
though nothing forces that ordering. The independent-sources case is exactly what
`errgroup.WithContext` fans out for: latency becomes the *slower* of the two, not the
sum.

## 2. The Worked Example

```go
func (h *DashboardHandler) Handle(ctx context.Context, q GetDashboard) (DashboardDTO, error) {
    sub, err := domain.SubjectFromContext(ctx)
    if err != nil {
        return DashboardDTO{}, ErrUnauthenticated
    }
    tid := sub.TenantID

    g, gctx := errgroup.WithContext(ctx)
    var assets AssetSummary
    var gaps GapSummary
    g.Go(func() error {
        var err error
        assets, err = h.assetView.Summary(gctx, tid)
        return err
    })
    g.Go(func() error {
        var err error
        gaps, err = h.gapView.Summary(gctx, tid)
        return err
    })
    if err := g.Wait(); err != nil {
        return DashboardDTO{}, fmt.Errorf("loading dashboard: %w", err)
    }
    return DashboardDTO{Assets: assets, Gaps: gaps}, nil
}
```

`errgroup.WithContext` derives `gctx` from `ctx` and cancels it the instant either
goroutine returns a non-nil error — the surviving goroutine's in-flight query gets
cancelled too, rather than running to completion for a result nothing will use.
`g.Wait()` blocks until both goroutines finish (successfully or not) and returns the
first non-nil error, if any; it is the one and only join point — no goroutine started
by `g.Go` outlives the `Handle` call that started it.

## 3. Why No Mutex Is Needed

`assets` and `gaps` are each written by exactly one goroutine and read by the calling
goroutine only after `g.Wait()` returns — which happens-after both writes complete,
by `errgroup`'s own internal synchronisation (a `sync.WaitGroup` under the hood). This
is Cox-Buday's **ad hoc confinement**: a piece of data is, by construction and
convention rather than by a language-enforced boundary, reachable by exactly one
goroutine at a time. There is nothing to synchronise with a `sync.Mutex` because the
race such synchronisation would prevent — two goroutines touching the same variable
concurrently — cannot occur here: `assets` is never touched by the `gaps` goroutine or
vice versa, and the parent goroutine never reads either variable until after the join
point has already ordered every write before it.

**The rule this generalizes to:** confinement is "ad hoc" (as opposed to lexical
confinement — a variable declared inside the goroutine's own closure with no outside
reference at all) specifically because nothing in the type system stops a future edit
from having both goroutines write the same variable by mistake. The discipline is a
convention a reviewer must check, not a guarantee the compiler enforces — which is
exactly what the Quality Criteria row "No shared mutable state in fan-out" in
`SKILL.md` exists to catch: read every `g.Go(func() error {...})` body and confirm each
one writes only its own destination variable.

## 4. When *Not* to Reach for This Pattern

Fan-out only pays for itself when the sources are genuinely independent and each call
has meaningful latency (a network round-trip, not an in-process map lookup). Two
`SELECT`s against the same connection pool racing each other still contend for pool
connections — real parallelism up to the pool's `MaxConns`, not free beyond it. A
query handler with one data source has nothing to fan out; forcing an `errgroup` around
a single `g.Go` call adds goroutine-scheduling overhead for no latency benefit.
