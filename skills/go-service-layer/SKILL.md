---
name: go-service-layer
description: >
  Teaches how to implement the application layer — CQRS command and query
  handlers — to a checkable engineering standard: the exact
  Handle(ctx, cmd) (Result, error) signature, the transaction-boundary
  standard (this layer, never the repository, opens and commits the pgx.Tx —
  go-repository-pattern's Querier/WithTx contract — with the command_log
  idempotency insert sharing that same transaction, mirroring
  go-event-consumer's processed_events pattern), the query-handler standard
  (queries read a denormalised CQRS Read Model directly, bypassing the
  domain layer and repository entirely), the cache-aside standard for
  cache-eligible query handlers (shared cache-key construction, TTL policy
  with its staleness rationale, invalidate-on-write after commit, never a
  separate step), and the three-tier validation boundary dividing structural
  validation (go-chi-handler), this layer's own orchestration-level checks
  (does a Command-referenced id exist), and business-invariant validation
  (go-domain-model's Aggregate) — plus parallel query orchestration with
  errgroup and ad hoc goroutine confinement (Cox-Buday). Full worked
  examples in references/command-handler-transaction-and-idempotency.md,
  references/cache-aside.md, references/three-tier-validation-boundary.md,
  and references/parallel-query-orchestration.md. Implements the
  enterprise-architect's CQRS design and command-catalog's idempotency
  contract in Go. Used by the backend-engineer during Implement.
version: 3.0.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, cqrs, application-layer, command-handler, query-handler, transaction-boundary, idempotency, cache-aside, validation-boundary, errgroup, confinement]
produces: go-cqrs-handlers
domain: backend
status: stable
related: [go-repository-pattern, go-domain-model, go-chi-handler, go-error-handling, go-event-consumer, command-catalog, read-model-design, go-concurrency-patterns, multi-tenancy-design]
---

# Go Service Layer (Application Layer)

## Purpose

The application layer expresses use cases as Commands (writes) and Queries (reads) —
CQRS's Write Model / Read Model split, named precisely in the canonical glossary. A
handler orchestrates: load, authorise, call the domain, save. It contains **no
business rules itself** — those live in the Aggregate (`go-domain-model`). Campbell's
*Designing Backend Systems with Go* teaches one undifferentiated `services` layer for
both reads and writes; this repo deliberately diverges, the same shape of justified
departure `go-repository-pattern` documents for pgx over `database/sql` — the CQRS
split lets the read side be optimised (denormalised, cached, scaled independently)
without dragging invariant machinery into every list screen.

---

## Command Handler Standard

Every command handler exposes exactly one method: **`Handle(ctx context.Context, cmd Command) (Result, error)`.**
`Result` is the command's own DTO — `struct{}` for a command with no meaningful return
value, a small value type for one that does. No handler returns a bare `error`; the
uniform two-value return keeps every call site symmetrical.

**Transaction-boundary ownership: this layer — never the repository — opens the
`pgx.Tx`,** the caller's side of `go-repository-pattern`'s Transaction-Boundary
Standard (a repository method never calls `pool.Begin`). A handler with a multi-call
atomicity requirement holds `pool *pgxpool.Pool` and a **concrete** repository type
for `.WithTx(tx)` — a narrow, named exception to consumer-defined-port-only wiring,
scoped to that one field; every other dependency stays on the narrow port.

Fixed step order: **begin tx → idempotency insert-or-replay (`command_log`, same tx,
first statement) → load → authorise → domain call → save + record result → commit.**
Same shape as `go-event-consumer`'s `processed_events` placement: one transaction, so
a crash between the ledger write and the domain write is impossible by construction.

```go
ct, _ := tx.Exec(ctx, `INSERT INTO command_log (idempotency_key, command_type)
    VALUES ($1,$2) ON CONFLICT (idempotency_key) DO NOTHING`, cmd.IdempotencyKey, "ClassifyDataAsset")
if ct.RowsAffected() == 0 {
    return replayStoredResult(ctx, tx, cmd.IdempotencyKey) // duplicate delivery
}
repo := h.assets.WithTx(tx) // caller-supplied transaction — repo never opened one
```

Full handler body (idempotency, load, ABAC, domain call, save, result recording,
commit) and the `command_log` schema: `references/command-handler-transaction-and-idempotency.md`.

A command handler changes **exactly one Aggregate per transaction** (`aggregate-design`).
A use case that appears to need two changed atomically is a signal to reconsider the
boundary, or use eventual consistency via Domain Events / a Saga
(`event-driven-patterns`) — never a transaction spanning two Aggregates.

---

## Query Handler Standard

Queries never load Aggregates and never call a repository. CQRS's Read Model is a
distinct, often denormalised projection (`read-model-design`), read through a narrow
read-model port scoped to the tenant and permission:

```go
func (h *ListDataAssetsHandler) Handle(ctx context.Context, q ListDataAssets) (Page[DataAssetDTO], error) {
    sub, err := domain.SubjectFromContext(ctx)
    if err != nil { return Page[DataAssetDTO]{}, ErrUnauthenticated }
    if !sub.HasPermission("data-assets:read") { return Page[DataAssetDTO]{}, ErrForbidden }
    return h.view.List(ctx, sub.TenantID, q.Sensitivity, q.Page)
}
```

Bypassing the domain layer for reads is deliberate: an Aggregate enforces invariants
on a *mutation*; a read has none to enforce, and loading one to answer a list screen
drags invariant machinery and N+1 loads into a path that needs one `SELECT` against an
already-shaped view.

---

## Cache-Aside Standard

Opt-in, only for a query handler fronting a view `read-model-design` has already
flagged cache-eligible — never speculatively. Check cache → on miss, query the view →
populate with a bounded TTL. The cache key (`fmt.Sprintf("dataasset:%s:%s", tenantID,
id)`) is constructed by **one shared function**, called from both the query handler
that populates it and the command handler that invalidates it — two independently
formatted key strings silently drift and break invalidation with no symptom. The
command handler that wrote the change deletes that key itself, **after** `tx.Commit()`
succeeds, never before (a rolled-back write must not evict a valid entry) and never as
a separate deferred step (that gap is exactly the staleness window the TTL already
bounds). Full key-construction rule, TTL policy table, and the invalidate-on-write
worked example: `references/cache-aside.md`.

---

## Three-Tier Validation Boundary

`command-catalog`'s two design-level layers (structural, business-rule) leave a gap: a
check needing I/O (so it cannot be Tier 1) that is not an invariant of the *target*
Aggregate (so it does not belong inside that Aggregate's method). This layer owns that
middle tier.

| Tier | Owner | Checks | I/O | Example |
|---|---|---|---|---|
| 1 — Structural | `go-chi-handler` | Shape only, from request bytes alone | Never | Sensitivity string not one of four valid values |
| 2 — Orchestration | `go-service-layer` (here) | Does a referenced id/Aggregate exist — facts about *other* things the Command references | Narrow reads only, never writes | An `OwnerUserID` a Command names does not resolve to a real user |
| 3 — Business invariant | `go-domain-model` | Rules about the *target* Aggregate's own current state, using state already loaded | No — the Aggregate is pure | A sensitivity downgrade rejected by the Aggregate's own current field |

The distinguishing question is not "does this need the database" — Tiers 2 and 3 both
can — it is **whose state is being examined**: Tier 2 checks other referenced
entities; Tier 3 checks the one Aggregate this Command targets, already in memory.
Full worked orchestration-check example: `references/three-tier-validation-boundary.md`.

---

## Parallel Query Orchestration and Confinement

When a query gathers independent data from several sources, fan out with `errgroup` so
the slowest source bounds latency, not the sum — each goroutine writes only its own
destination variable, Cox-Buday's **ad hoc confinement**: data reachable by exactly one
goroutine by construction needs no mutex or channel, because the race synchronisation
would prevent cannot occur. `g.Wait()` is the join point. Full worked
`DashboardHandler` fan-out example: `references/parallel-query-orchestration.md`.
(General concurrency patterns beyond this one use: `go-concurrency-patterns`.)

---

## Rules

- **No business logic in handlers.** Decisions live in the Aggregate; handlers orchestrate.
- **This layer opens transactions, never the repository** — the `pgx.Tx` boundary lives in `Handle`, per `go-repository-pattern`'s Transaction-Boundary Standard. `pgx`/concrete-repository access is a narrow, named exception scoped to handlers with a multi-call atomicity requirement; every other dependency stays on the consumer-defined port. No HTTP types, ever.
- **Authorise before mutate.** Policy check precedes the domain call, always.
- **Idempotent commands, same transaction** — `command_log` insert-or-replay is the first statement, sharing the domain write's `tx`.
- **`ctx` first, propagated everywhere.**

---

## Quality Criteria

| Criterion | Pass | Fail | How to verify |
|---|---|---|---|
| Thin handlers, uniform signature | Orchestration only; every `Handle` returns `(Result, error)` | Business logic in the handler, or a bare-`error` return | Read the body against the fixed step order; `grep -n "func (h \*.*Handler) Handle" internal/application` |
| Transaction boundary, idempotency same-tx | `pool.Begin`/`tx.Commit` only inside `Handle`; repository never calls `.Begin`; `command_log` insert is the first statement in that same `tx` | A repository opens its own tx; insert-or-domain-write split across transactions | `grep -rn "\.Begin(ctx" internal/infrastructure/postgres` — empty; read `Handle` for one `tx.Begin`...`tx.Commit` spanning both |
| Write/read separation | Commands mutate Aggregates; queries read Read Model views | Queries loading Aggregates; commands reading views | Grep query handler files for `domain.Reconstitute`/`FindByID` — none |
| One Aggregate per tx | Each command touches one Aggregate | A transaction spanning multiple Aggregates | Read every `Save`/`WithTx` call site inside one `Handle` |
| Cache-key parity, invalidate post-commit | Populate/invalidate share one key function; `cache.Delete` runs after `tx.Commit()` succeeds | Two differently formatted key strings, or delete before/without a commit | Grep the key function's call sites; read statement order after `Commit` |
| Validation tier discipline | Tier 2 checks only referenced-entity existence; Tier 3 stays inside the Aggregate | A repository call inside the Aggregate, or a target-Aggregate re-check in the handler | Read handler I/O calls against the target Aggregate's own fields — none outside `FindByID`'s load |
| Authorise before mutate, framework-free | Policy precedes the domain call; only transaction-owning fields touch pgx, nothing touches `*http.Request` | Mutation before check; `*http.Request` in the application layer, or pgx in a no-atomicity handler | Read step order; read imports of every `internal/application/**` file |
| No shared mutable state in fan-out | Each `errgroup` goroutine writes one private destination variable | Two goroutines writing one slice/map | Read every `g.Go(func() error {...})` body for its write target |

---

## Anti-Patterns

- **The "service" that is really the domain** — invariant checks or state math written in the handler; the Aggregate can no longer guarantee them.
- **A repository opening its own transaction, or an idempotency insert in a separate tx from the domain write** — both reopen the dual-write race the Transaction-Boundary Standard exists to close.
- **Authorise-after-mutate** — a forbidden caller's in-memory mutation already happened before the check runs.
- **Queries through the write model** — loading Aggregates to answer a list screen.
- **Cache invalidation before commit, as a separate deferred step, or via a second independently formatted key string** — evicts a valid entry for a rolled-back write, reopens the staleness window the TTL already bounds, or silently stops matching.
- **A Tier 2 orchestration check that re-derives a Tier 3 Aggregate invariant**, or vice versa — drift between the two tiers means two places can disagree about the same rule.
- **Transactions spanning Aggregates, or shared mutable state across `errgroup` goroutines** — dissolves the consistency boundary; one Aggregate per tx, one destination variable per goroutine.

---

## Output Format

Go source built exactly to the standards above, plus tests written first (TDD):
handlers with no multi-call atomicity requirement get unit tests against mocked
ports; handlers holding `pool`/`WithTx` get integration tests against a real
PostgreSQL (`go-integration-test` owns the harness) — a mocked port cannot verify a
transaction boundary that is itself the thing under test.

```
internal/application/commands/classify_data_asset.go
internal/application/commands/classify_data_asset_test.go   (integration — owns pool/tx)
internal/application/queries/list_data_assets.go
internal/application/queries/list_data_assets_test.go       (unit — mocked read-model port)
```

Full standards: `references/command-handler-transaction-and-idempotency.md`,
`references/cache-aside.md`, `references/three-tier-validation-boundary.md`.
