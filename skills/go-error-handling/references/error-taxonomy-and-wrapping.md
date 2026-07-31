# Error Taxonomy, Wrapping, and Inspection — Full Standard

Full worked material for `SKILL.md`'s "The Error Taxonomy" and "Wrapping and
Unwrapping Standard" sections. Self-contained — reads without the parent body
already in context.

---

## 1. The Five-Way Taxonomy, With Exact Selection Criteria

Every error this plugin's generated Go code produces is one of five kinds. The
choice is mechanical, not a style preference — answer the two questions in order
and the row is determined:

**Q1: Does the caller need a specific value out of the failure (an ID, a field
name, two conflicting states)?** No → sentinel. Yes → typed.
**Q2: Which layer owns the fact this error reports?** That answers domain vs.
infrastructure vs. application.

| Kind | Carries data? | Declared | Selection criterion |
|---|---|---|---|
| **Sentinel** | No — the fact alone is the whole message | `var ErrX = errors.New("...")`, one `var(...)` block per package | The condition is parameter-free: "not found," "forbidden," "concurrent modification." Any invalid input produces the identical fact. |
| **Typed** | Yes — one or more fields the caller plausibly wants to read | `type XError struct{...}` implementing `error` | A caller could plausibly extract a specific value from the failure — see `go-domain-model`'s `references/aggregate-invariant-enforcement.md`, "One Error Type Per Invariant." |
| **Domain error** | Either of the above | Aggregate's own package (`internal/domain/errors.go`) | The failure is a business rule or invariant. Owned entirely by `go-domain-model` — this skill states the general sentinel/typed mechanics; that skill states the one-error-type-per-invariant rule for a specific Aggregate. |
| **Infrastructure error** | N/A — never declared as its own vocabulary | Translated inline, at the exact call site that produced it | Infrastructure (pgx, a broker client, a secrets provider) never owns a failure vocabulary of its own — it only ever translates into a domain sentinel or typed error at the boundary. Full pgx-to-domain mapping table: `go-repository-pattern`'s `references/error-translation-and-transactions.md`. |
| **Application error** | Rare — most conditions are already domain conditions | `internal/application/{commands,queries}/errors.go`, only when a genuine use-case-level condition exists with no single owning Aggregate | An idempotency-key conflict spanning a use case is the canonical example. A near-empty or absent `errors.go` at this layer is expected, not a gap — see `go-project-structure`'s `references/package-layout-standard.md`, "Where Package-Level Errors Live." |

This skill owns the general sentinel/typed mechanics and the wrapping/inspection
rules below; it does not restate any sibling skill's layer-specific content —
each row above cites the skill that owns it.

---

## 2. Sentinel Errors

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

Callers test with `errors.Is(err, domain.ErrNotFound)` — it walks the wrap chain
(see §4), so a deeply-wrapped sentinel is still detected regardless of how many
layers added context on top of it.

## 3. Typed Errors

```go
type ValidationError struct {
    Field   string
    Message string
}
func (e ValidationError) Error() string { return e.Field + ": " + e.Message }
```

Extraction:

```go
var ve ValidationError
if errors.As(err, &ve) {
    // use ve.Field, ve.Message
}
```

A typed error's fields are the entire reason it exists over a sentinel — see the
"Wrong/Right" contrast in `go-domain-model`'s `references/aggregate-invariant-
enforcement.md` for why a generic `map[string]any` bucket type is itself an
anti-pattern (it trades static field access for two type assertions and no
compiler help if a key is renamed).

---

## 4. The Wrapping Standard

Wrap with `fmt.Errorf("...: %w", err)` at every layer that adds genuine context —
crossing an abstraction boundary, naming the operation, attaching the key
identifier. Each wrap builds a chain that reads like a stack trace in words:

```
"commit: write outbox DataAssetClassified: connection reset by peer"
```

Rules, each a defect if violated:

1. **`%w` exactly once per wrap.** `%v` is reserved for the rare, deliberate case
   of *breaking* the chain — e.g. to avoid leaking an internal error type across a
   public boundary.
2. **Add context, don't restate.** `"querying data asset %s: %w"` names the
   operation and the key identifier. `"error: %w"` adds nothing.
3. **Wrap where you add something, not at every call site.** Over-wrapping
   produces `"error: error: error: connection reset"` — noise, not a stack trace.
4. **No PII or secrets in the wrapped text** — see `references/error-message-
   standards.md`.

### errors.Is vs. errors.As

| Function | Question it answers | Use for |
|---|---|---|
| `errors.Is(err, target)` | "Is this — anywhere in the chain — that specific error?" | Matching a sentinel |
| `errors.As(err, &target)` | "Is there an error of this type in the chain? Give it to me." | Extracting a typed error's fields |

Never compare with `==` (`err == domain.ErrNotFound`) — identity comparison
breaks the instant an error is wrapped, since the wrapped value is a distinct
`*fmt.wrapError`, not the sentinel itself. Always inspect with `errors.Is`/
`errors.As`.

### The Wrap-Chain-Depth Smell

A wrap chain longer than **three to four levels** is a signal, not a hard limit:
it usually means a layer boundary is leaking too much internal detail upward
rather than translating it. This repo's actual layering caps out at exactly four
possible wrap points for a single call — infrastructure (pgx → domain sentinel,
`go-repository-pattern`), domain (an Aggregate method's own invariant error),
application (the command handler naming the use case), and transport (the
handler naming the HTTP-level operation, `go-chi-handler`) — so a chain deeper
than that on a single call path means a layer is wrapping something it should
instead be translating into its own vocabulary (see §1's infrastructure-error
row) or that two layers are each adding near-identical context. Reasoned
heuristic, not a number handed down by an external source: ground every review
of a wrap chain in "does each link name a genuinely different operation," not
merely "count the colons."

### Aggregating Independent Errors

For combining independent operational failures (e.g. multiple cleanup errors,
none of which is "the" cause), use `errors.Join` — each joined error remains
independently inspectable via `errors.Is`/`errors.As`:

```go
err = errors.Join(err, fmt.Errorf("rollback: %w", rbErr))
```

This is distinct from wrapping: wrapping expresses "this failure, with added
context"; `errors.Join` expresses "these N failures, all of which happened."
`go-repository-pattern`'s deferred-rollback idiom in `references/error-
translation-and-transactions.md` is the canonical worked instance.

---

## 5. Aggregating Validation Errors

Structural validation returns **all** problems in one round trip, not the first —
a caller fixing a form should see every field error at once (see
`go-chi-handler`):

```go
func (r classifyRequest) validate() []ValidationError {
    var errs []ValidationError
    // append one per invalid field …
    return errs
}
```

This is a different aggregation shape from `errors.Join` above: a `[]ValidationError`
is collected *before* any error exists (structural checks accumulate, they don't
short-circuit), whereas `errors.Join` combines errors that already occurred
independently during execution (e.g. two cleanup calls that both failed).
