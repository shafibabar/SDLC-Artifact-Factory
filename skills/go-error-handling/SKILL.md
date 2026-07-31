---
name: go-error-handling
description: >
  This plugin's error-handling authority — nearly every other Go skill
  (go-project-structure, go-domain-model, go-repository-pattern,
  go-service-layer, go-chi-handler, go-middleware, go-concurrency-patterns)
  cross-references this skill for general error taxonomy, wrapping, message
  standards, and panic/recover discipline rather than restating it. Covers:
  the full error taxonomy (sentinel vs. typed vs. domain vs. infrastructure
  vs. application errors, with exact selection criteria —
  references/error-taxonomy-and-wrapping.md); the wrapping/unwrapping
  standard (fmt.Errorf with %w, errors.Is/errors.As usage rules, and the
  wrap-chain-depth smell threshold — same reference); the nil-concrete-
  value-in-a-non-nil-error-interface footgun, independently compiled and
  verified against Go 1.23.4 (references/worked-example.md); the error
  MESSAGE standard (actionable, includes relevant IDs, never leaks secrets,
  a consistent lowercase/no-trailing-punctuation convention, a worked
  good-vs-bad table — references/error-message-standards.md); the strict
  two-place panic/recover boundary and the log-once-at-the-boundary
  anti-pattern, named "log-and-return duplication"
  (references/panic-recover-and-logging.md); and the error-path testing
  standard — coverage expectations, asserting wrapped errors correctly with
  errors.Is/errors.As (references/testing-error-paths.md). Used by the
  backend-engineer during Implement.
version: 3.0.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, errors, error-wrapping, errors-is, errors-as, panic, recover, error-messages, error-taxonomy, logging, testing]
related: [go-domain-model, go-repository-pattern, go-project-structure, go-service-layer, go-middleware, go-chi-handler, go-unit-test, go-concurrency-patterns]
---

# Go Error Handling

## Purpose

Errors are part of every function's contract, not an afterthought. This is the cross-cutting standard the domain, repository, application, and handler skills defer to for general taxonomy, wrapping, message quality, and panic/recover discipline — each sibling skill owns only its own layer-specific application of these rules. Done right, an error carries enough context to diagnose an incident from a single log line, is inspectable programmatically, and never silently disappears.

The rule is absolute: **never discard an error.** `_ = doThing()` is a defect unless a comment justifies exactly why the error is provably irrelevant. Handling means one of: return it (usually wrapped), recover from it, or — rarely, with justification — deliberately ignore it. Logging an error and continuing as if nothing happened is **not** handling it.

---

## The Error Taxonomy

Every error is one of five kinds, chosen mechanically, not by style preference:

| Kind | Use when | Declared |
|---|---|---|
| **Sentinel** | Condition is parameter-free — a fact, not data (`ErrNotFound`) | `var ErrX = errors.New(...)` |
| **Typed** | Caller plausibly needs a specific value out of the failure | `type XError struct{...}` |
| **Domain** | A business rule or invariant | Aggregate's own package (`go-domain-model`) |
| **Infrastructure** | Never its own vocabulary — always translated at the boundary | Inline, at the call site (`go-repository-pattern`) |
| **Application** | Rare — a use-case condition owned by no single Aggregate | `internal/application/*/errors.go`, only when genuinely needed |

Full criteria, code, and the sentinel-vs-typed decision worked out for a real Aggregate's full error roster: `references/error-taxonomy-and-wrapping.md`.

---

## Wrapping and Unwrapping

Wrap with `fmt.Errorf("...: %w", err)` at every layer that adds genuine context — never restate, never wrap with no context added, `%w` exactly once per wrap. Inspect with `errors.Is(err, target)` for a sentinel and `errors.As(err, &target)` to extract a typed error's fields — never `==`, which breaks the instant an error is wrapped.

A wrap chain deeper than **three to four levels** is a smell: it usually means a layer is leaking internal detail upward instead of translating it into its own vocabulary. Combine independent operational failures with `errors.Join`, not another layer of `%w`. Full rules, the exact `errors.Is`/`errors.As` decision table, and the depth-smell reasoning: `references/error-taxonomy-and-wrapping.md`.

---

## The Nil-Interface Footgun

A **typed nil is not the same as a nil `error`.** An `error` value is a two-word interface — a type word and a value word — and `err != nil` is true whenever the type word is set, even when the value word is nil. A function that declares a nil-valued, concrete-typed error variable (`var verr *ValidationError`) and returns it directly through an `error`-typed result always produces a non-nil interface, even when nothing went wrong.

**Never do this.** Return the bare `nil` literal for the no-error path, either directly or via an explicit conditional when converting a helper's typed-pointer result. Full wrong/right example, independently compiled and verified against Go 1.23.4: `references/worked-example.md`.

---

## Error Message Standards

Every message is actionable, includes the relevant ID, never leaks a secret or PII, and follows one casing convention: lower-case start, no trailing punctuation — so wrapped fragments compose cleanly at any depth (`"classifying: loading data asset 7f3e: not found"`, never a capitalized or punctuated fragment mid-chain). Good: `"loading data asset %s: %w"`. Bad: `"Error loading data asset."` (capitalized, punctuated, no ID) or anything containing a raw connection string, token, or full PII. Full good-vs-bad table and the reasoning for each rule: `references/error-message-standards.md`.

---

## Panic and Recover — the Two-Place Boundary

`panic` is reserved for unrecoverable states — a programming error, or a failed critical initialisation that makes continuing meaningless. It is never flow control for an ordinary failure (bad input, a downstream outage): those return errors. `recover` lives in exactly two places in this repo's generated code:

- The HTTP `Recoverer` middleware (one per chain — see `go-middleware`)
- The top of each spawned goroutine that could panic (so a worker panic doesn't take down the pool)

A `recover` anywhere else is a smell — almost always a panic used as control flow, or a failure silently absorbed instead of propagated to its owner. Full placement rules, the worker-goroutine conversion pattern, and why `Recoverer` specifically must be the outermost middleware: `references/panic-recover-and-logging.md` (the `Recoverer`'s own implementation is `go-middleware`'s).

---

## Log Once at the Boundary

**Named anti-pattern: log-and-return duplication** — logging an error *and* returning it up the call chain, so every layer that does both logs the same underlying failure independently. One incident then produces N near-identical log lines instead of one. The rule: every intermediate layer wraps and returns; exactly one place — the boundary that owns the request (the HTTP handler, the event consumer's message loop, or `main` for a startup failure) — calls `slog`. Full wrong/right example across all three boundary types: `references/panic-recover-and-logging.md`.

---

## Testing Error Paths

Every function with a non-nil `error` return gets at least one test case that actually drives it down an error-returning path — one case per distinct failure mode, in the table-driven shape `go-unit-test` establishes as this repo's default. Assert with `errors.Is`/`errors.As` matching the taxonomy the function under test uses, extracting and checking a typed error's fields, not just that extraction succeeded. A bare `if err == nil { t.Fatal(...) }` with no further assertion passes for **any** error and proves nothing about which one occurred; neither does asserting on the message string, which breaks the moment a message is reworded. Full standard and the worked pattern: `references/testing-error-paths.md`; the fully worked domain-model instance already exists in `go-domain-model`'s `references/aggregate-invariant-enforcement.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| No discarded errors | Every error handled, returned, or justified-ignored with a comment | `_ = f()` or ignored returns |
| Taxonomy and boundary translation fit | Sentinel for parameter-free facts, typed when a caller needs data, infra translated (not invented) into domain vocabulary | A typed error with no fields; pgx errors reaching the handler |
| Context preserved, chain bounded | `%w` wrapping with genuine context, ≤3-4 levels deep | Bare `return err`; `errors.New(err.Error())`; deeper chains |
| Inspection over `==` | `errors.Is`/`errors.As` | `err == Sentinel`; type assertions on errors |
| Message quality | Actionable, ID included, lower-case, no trailing punctuation, no secrets/PII | Vague, inconsistently punctuated, or leaking a DSN/token/PII |
| Panic discipline | Panics only unrecoverable; `recover` only at the two named boundaries | Panic as control flow; `recover` sprinkled elsewhere |
| No typed-nil footgun | No-error paths return the bare `nil` literal | A nil-valued, concrete-typed error variable returned through an `error`-typed result |
| Log once | Exactly one `slog` call per failure, at the owning boundary | Log-and-return duplication at two or more layers |
| Error-path tested | One test case per distinct failure mode, asserted via `errors.Is`/`errors.As` | Happy-path-only tests; bare `err == nil` checks; string-matching on `err.Error()` |

---

## Anti-Patterns

- **Log-and-return duplication** — logging an error and also returning it, so every layer that does both produces its own log line for the same failure. Log once, at the boundary.
- **The typed-nil footgun** — `var verr *ValidationError; return verr` returns a non-nil `error` interface even when `verr` was never assigned.
- **`err == ErrNotFound`** — identity comparison breaks on the first wrap; `errors.Is` walks the chain.
- **`errors.New(err.Error())`** — flattening an error into a new string severs the chain, defeating `errors.Is`/`errors.As` downstream.
- **Wrapping with no added context, or wrapping too deep** — `"error: %w"` at every call site, or a chain past 3-4 levels.
- **`recover` outside the two named boundaries, or panic used as control flow** — panicking on bad input and recovering mid-stack to resume; both mask a bug as normal operation.
- **Leaking infrastructure error types across a boundary** — a handler switching on `pgx.ErrNoRows` couples transport to the driver; translate at the repository.
- **Testing only that `err != nil`, or string-matching `err.Error()`** — proves a function failed, never that it failed for the intended reason; the latter also breaks on any reworded message.

---

## Output Format

Produces Go source (a sentinel-error file per package plus disciplined error handling throughout) and tests asserting error identity:

```
internal/domain/errors.go                 (sentinels + typed domain errors)
internal/application/commands/errors.go    (application sentinels — rare)
internal/handlers/http/errors.go           (transport-layer structural error type)
*_test.go                                  (table-driven, error-path coverage per §"Testing Error Paths")
```
