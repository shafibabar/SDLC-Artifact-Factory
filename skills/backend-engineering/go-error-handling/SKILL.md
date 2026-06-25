---
name: go-error-handling
description: >
  Teaches the plugin's Go error-handling standard — errors as values (never
  discarded), wrapping with %w to preserve the chain, sentinel and typed errors,
  inspection with errors.Is and errors.As, where errors are translated between
  layers, the validation-error aggregation pattern, and the strict boundary on
  panic/recover (panics only for unrecoverable states, recovered only at runtime
  boundaries). This is a cross-cutting standard every other backend skill follows.
  Used by the backend-engineer during Implement.
version: 1.0.0
phase: implement
owner: backend-engineer
tags: [implement, go, errors, error-wrapping, errors-is, errors-as, panic, recover]
---

# Go Error Handling

## Purpose

Errors are part of the contract of every function, not an afterthought. This skill is the cross-cutting standard that the domain, repository, application, and handler skills all follow. Done right, an error carries enough context to diagnose a production incident from a single log line, can be inspected programmatically to make decisions, and never silently disappears.

The blueprint's rule is absolute: **never discard an error.** `_ = doThing()` is a defect unless accompanied by a comment justifying exactly why the error is provably irrelevant.

---

## Errors Are Values

Go has no exceptions for ordinary failure. A function that can fail returns an `error` as its last value, and the caller handles it explicitly.

```go
asset, err := repo.FindByID(ctx, id)
if err != nil {
    return fmt.Errorf("classifying asset: %w", err) // handle: wrap and return
}
```

Handling means one of: return it (usually wrapped), recover from it (retry, fallback), or — rarely, with justification — deliberately ignore it. Logging an error and continuing as if it didn't happen is **not** handling it.

---

## Wrapping with %w

Wrap an error with `fmt.Errorf("...: %w", err)` to add context while preserving the original for inspection. Each layer adds *what it was doing*, building a chain that reads like a stack trace in words.

```go
// Each wrap adds context; the %w verb keeps the chain inspectable.
"commit: write outbox DataAssetClassified: connection reset by peer"
```

Rules:
- **Add context, don't restate.** `"querying data asset %s: %w"` — say what operation, include the key identifier.
- **`%w` exactly once per wrap.** Use `%v` if you deliberately want to *break* the chain (rare — e.g., to avoid leaking an internal error type across a public boundary).
- **Don't wrap at every call** — wrap where you add genuine context (crossing a layer, naming the operation). Over-wrapping produces noise.
- **No PII or secrets in error text** — errors get logged (see security `privacy-design`).

---

## Sentinel Errors and Typed Errors

Two ways to make an error programmatically actionable:

### Sentinel errors — for known, parameter-free conditions

```go
// internal/domain/errors.go
package domain

import "errors"

var (
    ErrNotFound                = errors.New("resource not found")
    ErrForbidden               = errors.New("forbidden")
    ErrConcurrentModification  = errors.New("concurrent modification")
    ErrInvalidSensitivity      = errors.New("invalid sensitivity level")
    ErrCannotDowngradeSilently = errors.New("sensitivity cannot be downgraded without explicit reclassification")
)
```

Callers test with `errors.Is(err, domain.ErrNotFound)` — it walks the wrap chain, so a deeply-wrapped sentinel is still detected.

### Typed errors — when the error carries data

```go
type ValidationError struct {
    Field   string
    Message string
}
func (e ValidationError) Error() string { return e.Field + ": " + e.Message }

// Inspect and extract with errors.As:
var ve ValidationError
if errors.As(err, &ve) {
    // use ve.Field, ve.Message
}
```

Use a sentinel when the condition is a fact; use a typed error when the caller needs structured detail from it.

---

## errors.Is vs errors.As

| Function | Question it answers | Use |
|---|---|---|
| `errors.Is(err, target)` | "Is this (anywhere in the chain) that specific error?" | Matching sentinels |
| `errors.As(err, &target)` | "Is there an error of this type in the chain? Give it to me." | Extracting typed errors |

Never compare with `==` (`err == domain.ErrNotFound`) — it fails the moment the error is wrapped. Always `errors.Is`.

---

## Translating Errors at Layer Boundaries

An error type should not leak across an abstraction boundary. The repository translates infrastructure errors (pgx) into domain sentinels so the application layer never imports pgx (see `go-repository-pattern`):

```go
case errors.Is(err, pgx.ErrNoRows):
    return nil, fmt.Errorf("data asset %s: %w", id, domain.ErrNotFound) // pgx → domain
```

The HTTP handler then translates domain errors into status codes in one place (see `go-chi-handler`). Each layer speaks its own error vocabulary; the boundaries translate.

---

## Aggregating Validation Errors

Structural validation returns **all** problems at once, not the first — a caller fixing a form should see every field error in one round trip (see `go-chi-handler`).

```go
func (r classifyRequest) validate() []ValidationError {
    var errs []ValidationError
    // append one per invalid field …
    return errs
}
```

For combining independent operational errors (e.g., multiple cleanup failures), use `errors.Join`:

```go
err = errors.Join(err, fmt.Errorf("rollback: %w", rbErr)) // both inspectable via errors.Is
```

---

## Panic and Recover — the Strict Boundary

`panic` is reserved for **unrecoverable** states: a programming error or a failed critical initialisation that makes continuing meaningless. It is **never** flow control for ordinary failure.

| Situation | Mechanism |
|---|---|
| User sent bad input | return an error (422/400) — not a panic |
| Downstream DB is down | return a wrapped error; retry/circuit-break | 
| Required config missing at startup | acceptable to `panic`/fatal in `main` — the process cannot run |
| Invariant that "can't happen" violated (e.g., tenant missing after auth) | `panic` — it's a bug; caught at the boundary |

`recover` lives only at **runtime boundaries**, so a panic degrades one request instead of crashing the process:

- The HTTP `Recoverer` middleware (one per chain — see `go-middleware`)
- The top of each spawned goroutine that could panic (so a worker panic doesn't take down the pool)

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

A `recover` anywhere other than a boundary is a smell — it usually means a panic is being used as control flow.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| No discarded errors | Every error handled, returned, or justified-ignored with a comment | `_ = f()` or ignored returns |
| Context preserved | `%w` wrapping with operation context | Bare `return err` everywhere, or `errors.New(err.Error())` |
| Inspection over `==` | `errors.Is`/`errors.As` | `err == Sentinel`; type assertions on errors |
| Boundary translation | Infra errors → domain sentinels → HTTP codes | pgx errors reaching the handler |
| Aggregated validation | All field errors returned together | First-error-only validation |
| Panic discipline | Panics only unrecoverable; recover only at boundaries | Panic as control flow; recover sprinkled around |
| No sensitive data in errors | Errors carry ids/operations, not PII/secrets | PII or secrets in error strings |

---

## Output Format

Produces Go source (a sentinel-error file per package plus disciplined error handling throughout) and tests asserting error identity:

```
internal/domain/errors.go                 (sentinels)
internal/application/commands/errors.go    (application sentinels)
*_test.go                                  (assert errors.Is / errors.As behaviour)
```
