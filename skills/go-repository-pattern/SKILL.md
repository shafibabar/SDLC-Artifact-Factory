---
name: go-repository-pattern
description: >
  Teaches how to implement the Repository pattern over pgx to a checkable
  engineering standard: satisfying the consumer-defined domain port, mapping
  DB rows back through Reconstitute (never the failing New constructor),
  optimistic-concurrency writes (compare-and-swap on version), draining
  Domain Events into the Transactional Outbox in the same transaction as the
  state change, mandatory tenant scoping, and — the standards a prior pass
  only sketched — the complete pgx-error-to-domain-error translation table
  (pgx.ErrNoRows, pgconn.PgError.Code unique/foreign-key violations, client
  context deadline vs server statement_timeout), the transaction-boundary
  rule (opened/committed/rolled back at the application layer via pgx.Tx,
  never inside a repository method, and how a repository participates in a
  caller-supplied transaction via a Querier interface and WithTx),
  connection-pool usage (pgxpool.Pool as the default querier, Acquire only
  for an explicit connection-scoped session), and query-construction rules
  (parameterised $N placeholders always, no string-built SQL, pgx has no
  named-parameter syntax). Full pgx error table and transaction worked
  example in references/error-translation-and-transactions.md; query and
  pool depth in references/query-construction-and-connection-pooling.md.
  Implements the data-architect's schemas. Used by the backend-engineer
  during Implement.
version: 2.0.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, pgx, repository, postgres, outbox, optimistic-concurrency, tenant, transactions, error-translation]
related: [go-domain-model, go-error-handling, go-project-structure, go-migration, go-integration-test, go-service-layer, multi-tenancy-design]
---

# Go Repository Pattern

## Purpose

A repository is the only thing that knows how an Aggregate is persisted. It satisfies the small, consumer-defined port from `domain/ports.go`, hides pgx entirely from the application layer, and guarantees three non-negotiables: every write carries the Aggregate's Domain Events into the Transactional Outbox *in the same transaction*, every query is scoped to the tenant, and every pgx error crossing out of this package arrives as a domain type.

This repository is pgx-native throughout (`pgxpool.Pool`, `pgx.Batch`, `pgx.ErrNoRows`) — a deliberate, justified departure from the more portable-but-slower `database/sql`+`sqlx` mainstream default (Campbell, *Designing Backend Systems with Go*), made to use Postgres-specific features directly. Not an oversight to reconcile.

A repository is Robert Martin's **Humble Object** pattern applied to persistence: thin, hard-to-unit-test wrapper code, verified by integration tests against a real database (`go-integration-test`), not unit tests with a mocked driver. Logic worth unit-testing — invariants, state transitions — lives in the Aggregate (`go-domain-model`), fully testable with no database at all.

---

## Satisfying the Port

The interface lives with the consumer (`internal/domain/ports.go`); the implementation lives in `internal/infrastructure/postgres/` and does not redeclare it.

```go
type DataAssetRepo struct{ q Querier } // Querier: pool by default, tx via WithTx — see below

func NewDataAssetRepo(pool *pgxpool.Pool) *DataAssetRepo { return &DataAssetRepo{q: pool} }

// Compile-time assertion: a renamed/re-typed method fails to compile HERE, not at
// some unrelated call site (go-project-structure's Minimalist Interfaces).
var _ domain.DataAssetRepository = (*DataAssetRepo)(nil)
```

---

## Reconstitute, Never `New` — the Repository's Specific Obligation

`go-domain-model` defines the split: `New…` is an invariant-checked, event-emitting operation for creating a *new* Aggregate; `Reconstitute` rebuilds one from data that was already valid when it was stored, re-validates nothing, and emits nothing. **This skill's rule is the consumer side of that split, and it has exactly one form:** every row a repository reads back from Postgres is mapped through `domain.Reconstitute(...)` — never `domain.NewDataAsset(...)`. Calling `New…` from a repository read path would re-run invariant checks against data the database already accepted, and — far worse — re-emit the creation event for a row that was created yesterday, republishing a stale `DataAssetRegistered` into the outbox on every read. There is no method on a repository that is allowed to call a `New…` constructor; `New…` is exclusively an application-layer, command-side operation.

---

## Reads — Parameterised and Tenant-Scoped

Every query uses `$N` placeholders and filters by `tenant_id` from context (full rationale for both: `references/query-construction-and-connection-pooling.md`).

```go
func (r *DataAssetRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.DataAsset, error) {
    const q = `SELECT id, tenant_id, source_id, sensitivity_level, version
                 FROM data_assets WHERE id = $1 AND tenant_id = $2 AND deleted_at IS NULL`
    var (aid, tid, sid uuid.UUID; level string; version int64)
    err := r.q.QueryRow(ctx, q, id, tenantID(ctx)).Scan(&aid, &tid, &sid, &level, &version)
    if err != nil {
        return nil, translatePgError(err, domain.ErrNotFound)
    }
    return domain.Reconstitute(aid, tid, sid, domain.SensitivityLevel(level), version), nil
}
```

---

## Error-Translation Standard

Every pgx/pgconn error a repository method can receive is classified once, in a small private `translatePgError` helper living in the same file as the repository that calls it — never a shared `internal/infrastructure/errors.go` (`go-project-structure`'s anti-pattern: a dedicated infra errors file implies infrastructure owns a failure vocabulary; it only ever translates into the domain's). The complete table — `pgx.ErrNoRows`, `pgconn.PgError.Code` for unique (`23505`) and foreign-key (`23503`) violations, client `context.DeadlineExceeded`/`context.Canceled` vs. server-side `statement_timeout` (`57014`), and `40001` serialization failures — plus the full translation function: **`references/error-translation-and-transactions.md`**.

The rule with no exception: **no pgx or pgconn type ever crosses out of `internal/infrastructure/postgres/`.** A caller that needs to inspect `pgErr.Code` itself is a defect — the translation already happened.

---

## Transaction-Boundary Standard

**A repository method never calls `pool.Begin(ctx)`.** The transaction is opened, committed, and rolled back by the *application layer's* command handler — the only place that actually knows whether this repository call is one of several that must commit together. A repository participates in a caller-supplied transaction through two small pieces:

```go
type Querier interface { // satisfied structurally by *pgxpool.Pool and pgx.Tx
    Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
    Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
    QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

// WithTx rebinds this repository's statements onto the caller's transaction. It
// opens, commits, and rolls back nothing itself.
func (r *DataAssetRepo) WithTx(tx pgx.Tx) *DataAssetRepo { return &DataAssetRepo{q: tx} }
```

`FindByID` is safe pool-bound or tx-bound. **`Save` is a hard precondition on being tx-bound** — its `UPDATE` and outbox `INSERT` are two statements that only a shared `pgx.Tx` commits atomically; calling `Save` on a pool-bound repo is a code-review defect (see Quality Criteria). The application-layer `Handle` method that opens the `tx`, calls `assets.WithTx(tx)`, and `Commit`s at the end — using the identical named-return-plus-deferred-rollback idiom this skill used internally before — is fully worked in **`references/error-translation-and-transactions.md`**.

---

## Connection-Pool Usage Standard

`*pgxpool.Pool`'s `Exec`/`Query`/`QueryRow` acquire and release a connection automatically, per call — this is the default and correct choice for every method in this skill, transactional or not (`pool.Begin` already acquires and holds a connection for the transaction's lifetime; no explicit `Acquire` needed). `Acquire` is the narrow exception for an explicit *connection-scoped session* outside a transaction — advisory locks, `LISTEN`/`NOTIFY` — where connection identity itself, not row/table consistency, is what's being coordinated. An `Acquire`d connection must be `Release()`d on every path; an un-released one is a pool leak with no reclaim timeout. Full worked example and the "Acquire vs. WithTx" decision: **`references/query-construction-and-connection-pooling.md`**.

---

## Query-Construction Standard

Parameterised `$N` placeholders always; never `fmt.Sprintf` (or any string-building) into a SQL string — this is pgx's extended query protocol sending SQL text and values as two separate messages, the mechanical reason a value can never be re-parsed as SQL. pgx has **no named-parameter syntax** (`:name`/`@Name` are `sqlx`/`sqlc` features this driver doesn't have) — the convention for four-or-more parameters is one clause per line with an inline `// $N` comment naming the Go value bound there. Multi-statement reads use `pgx.Batch`, never a loop of string-concatenated `UNION ALL`. Full rule, worked bad/good pair, and `pgx.Identifier` for the one legitimate dynamic-identifier case: **`references/query-construction-and-connection-pooling.md`**.

---

## Tenant Context Helper

```go
func tenantID(ctx context.Context) uuid.UUID {
    id, ok := ctx.Value(ctxKeyTenant).(uuid.UUID)
    if !ok {
        panic("tenant id missing from context — auth middleware did not run") // caught at boundary
    }
    return id
}
```

A missing tenant must never silently become a cross-tenant query — the application-layer backstop behind physical isolation (`multi-tenancy-design`).

---

## Repository Rules

- **No business logic.** Loads, saves, translates — decisions belong in the Aggregate/application layer.
- **Return domain types, not rows.** Callers receive `*domain.DataAsset`, never a pgx row or DB struct.
- **Context everywhere.** Every method takes `ctx` first, passes it to every pgx call.
- **One repository per Aggregate.** No generic `Repository[T]`; small focused ports (`go-project-structure`).
- **Reconstitute on read, `New…` never.** See the standard above — no exceptions.

---

## Quality Criteria

| Criterion | Pass | Fail | How to verify |
|---|---|---|---|
| Atomic state + events | `UPDATE` and outbox `INSERT`s share one `Querier` bound by the caller | Two separate `Exec` calls with no shared `pgx.Tx` between them | Read `Save`; confirm every write inside it uses `r.q`, no local `Begin` |
| No `BeginTx` in a repository | Zero occurrences of `.Begin(` inside `internal/infrastructure/postgres/*.go` | A repository method opens its own transaction | `grep -rn "\.Begin(ctx" internal/infrastructure/postgres` — empty |
| `Save` only called tx-bound | Every `Save` call site is preceded by `.WithTx(tx)` in the same function | A `Save` call on a pool-bound repo value | Read every `Save(` call site's enclosing function for a `WithTx` upstream |
| Reconstitute on read | Every read path calls `domain.Reconstitute`, never `domain.New…` | A repository read calls a `New…` constructor | `grep -n "domain.New" internal/infrastructure/postgres` — no hits |
| Optimistic concurrency | CAS on `version`; 0 rows → `ErrConcurrentModification` | Last-write-wins with no version predicate | Read the `UPDATE`'s `WHERE` clause for `version = $N` |
| Tenant scoping | Every query filters `tenant_id` from context | A query missing the tenant filter | Read every `WHERE` clause for `tenant_id = $N` |
| Parameterised SQL | Only `$N` placeholders, values passed as args | Any string-concatenated/`Sprintf`-built SQL | `grep -rn "Sprintf\|fmt\.Sprint" internal/infrastructure/postgres` — no hits feeding a query string |
| Error translation complete | Every pgx/pgconn error type this skill's table names is handled in `translatePgError` | A pgx/pgconn type (`pgx.ErrNoRows`, `*pgconn.PgError`) referenced outside `postgres/` | `grep -rn "pgx\.\|pgconn\." internal/application internal/handlers` — empty |
| No dedicated infra errors file | `translatePgError` lives beside its repository | A shared `internal/infrastructure/errors.go` | `find internal/infrastructure -name errors.go` — empty |
| Connection-pool discipline | `Acquire` only for advisory-lock/`LISTEN` sessions, always `defer conn.Release()` | `Acquire` used for ordinary reads/writes, or a path with no `Release` | Read every `Acquire(` call site's justification and its `defer` |
| Tx always closed | Deferred rollback in the *application-layer* `Handle`, safe after commit | A path that can leave a transaction open | Read `Handle`'s `defer` against every `return` |
| Context propagation | `ctx` passed to every pgx call | Background context or dropped ctx | `grep -rn "context\.Background()" internal/infrastructure/postgres` — no hits inside a request path |

---

## Anti-Patterns

- **`BeginTx` inside a repository method** — reintroduces exactly the composability problem the Transaction-Boundary Standard closes; a use case needing two repository calls to commit together can't get it back without a rewrite.
- **Calling `New…` from a read path** — re-validates already-valid stored data and republishes a stale creation event into the outbox on every read.
- **Publish-after-commit** — publishing outside the transaction reintroduces the dual-write problem the Transactional Outbox closes.
- **Last-write-wins saves** — an `UPDATE` with no `version` predicate silently overwrites a concurrent write.
- **Tenant filter "optimised away"** — `tenant_id` is in every `WHERE` clause, no exceptions, even under physical isolation.
- **A pgx/pgconn type leaking past `postgres/`** — the whole point of `translatePgError` is that nothing downstream ever needs `errors.As(err, &pgconn.PgError{})`.
- **Dynamic SQL assembly** — `fmt.Sprintf` with column/filter fragments, even "safe" ones, normalises the habit that ends in injection.
- **`Acquire` used as a substitute for `WithTx`** — gets same-connection guarantees without atomicity; almost never what was actually wanted.

---

## Output Format

Go source built exactly to the standards above, plus integration tests run against a real PostgreSQL via Testcontainers — this skill states what a repository method must be testable against (real SQL, real CAS conflicts, real constraint violations); `go-integration-test` owns how the test harness itself works:

```
internal/infrastructure/postgres/dataasset_repo.go       (Querier, WithTx, translatePgError, reads/writes)
internal/infrastructure/postgres/dataasset_repo_test.go  (integration test — go-integration-test)
```

Full standards: `references/error-translation-and-transactions.md` (error table, transaction worked example) and `references/query-construction-and-connection-pooling.md` (query construction, `pgx.Batch`, connection-pool `Acquire`).
