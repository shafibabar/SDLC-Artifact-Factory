---
name: go-repository-pattern
description: >
  Teaches how to implement the Repository pattern over pgx — satisfying the
  consumer-defined domain port, mapping rows to reconstituted Aggregates,
  optimistic-concurrency writes (compare-and-swap on version), draining domain
  events into the Transactional Outbox in the same transaction as the state
  change, mandatory tenant scoping, parameterised queries, and context
  propagation. Implements the data-architect's schemas. Used by the
  backend-engineer during Implement.
version: 1.0.0
phase: implement
owner: backend-engineer
tags: [implement, go, pgx, repository, postgres, outbox, optimistic-concurrency, tenant]
---

# Go Repository Pattern

## Purpose

A repository is the only thing that knows how an Aggregate is persisted. It satisfies the small, consumer-defined port from `domain/ports.go`, hides pgx entirely from the application layer, and guarantees two non-negotiables: every write carries the Aggregate's Domain Events into the Transactional Outbox *in the same transaction*, and every query is scoped to the tenant.

This skill implements the schemas from the data-architect's `data-model-design` and uses the outbox table from `domain-event-catalog`. It performs no business logic — it loads, saves, and translates.

---

## Satisfying the Port

The interface lives with the consumer (`internal/domain/ports.go`); the implementation lives in `internal/infrastructure/postgres/` and does not redeclare it.

```go
// internal/infrastructure/postgres/dataasset_repo.go
package postgres

type DataAssetRepo struct {
    pool *pgxpool.Pool
}

func NewDataAssetRepo(pool *pgxpool.Pool) *DataAssetRepo { return &DataAssetRepo{pool: pool} }
```

---

## Reads — Parameterised and Tenant-Scoped

Every query uses `$N` placeholders (never string concatenation — see security `security-implementation`) and every query filters by `tenant_id`. Tenant comes from the context, set by auth middleware.

```go
func (r *DataAssetRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.DataAsset, error) {
    const q = `
        SELECT id, tenant_id, source_id, sensitivity_level, version
          FROM data_assets
         WHERE id = $1 AND tenant_id = $2 AND deleted_at IS NULL`

    var (
        aid, tid, sid uuid.UUID
        level         string
        version       int64
    )
    err := r.pool.QueryRow(ctx, q, id, tenantID(ctx)).
        Scan(&aid, &tid, &sid, &level, &version)
    switch {
    case errors.Is(err, pgx.ErrNoRows):
        return nil, fmt.Errorf("data asset %s: %w", id, domain.ErrNotFound)
    case err != nil:
        return nil, fmt.Errorf("querying data asset %s: %w", id, err)
    }
    return domain.Reconstitute(aid, tid, sid, domain.SensitivityLevel(level), version), nil
}
```

`pgx.ErrNoRows` is translated to a domain sentinel (`domain.ErrNotFound`) so the application layer never sees a pgx type — the abstraction holds (see `go-error-handling`).

---

## Writes — Optimistic Concurrency + Outbox in One Transaction

The save is the critical correctness point. Three things happen atomically: the compare-and-swap update (enforcing one-writer-per-aggregate via `version`), the outbox insert for every pulled Domain Event, and commit. If any step fails, the whole thing rolls back — no state change without its events, no events without the state change.

```go
func (r *DataAssetRepo) Save(ctx context.Context, a *domain.DataAsset) (err error) {
    tx, err := r.pool.Begin(ctx)
    if err != nil {
        return fmt.Errorf("begin tx: %w", err)
    }
    // Rollback is a no-op after a successful Commit; this guarantees no leaked tx on any path.
    defer func() {
        if rbErr := tx.Rollback(ctx); rbErr != nil && !errors.Is(rbErr, pgx.ErrTxClosed) {
            err = errors.Join(err, fmt.Errorf("rollback: %w", rbErr))
        }
    }()

    // Compare-and-swap on version: 0 rows ⇒ concurrent modification.
    ct, err := tx.Exec(ctx, `
        UPDATE data_assets
           SET sensitivity_level = $1, classified_by = $2, classified_at = $3,
               version = version + 1, updated_at = now()
         WHERE id = $4 AND tenant_id = $5 AND version = $6`,
        string(a.Sensitivity()), a.ClassifiedBy(), a.ClassifiedAt(),
        a.ID(), a.TenantID(), a.Version(),
    )
    if err != nil {
        return fmt.Errorf("updating data asset %s: %w", a.ID(), err)
    }
    if ct.RowsAffected() == 0 {
        return fmt.Errorf("data asset %s: %w", a.ID(), domain.ErrConcurrentModification)
    }

    // Drain Domain Events into the outbox — same transaction.
    for _, e := range a.PullEvents() {
        payload, mErr := json.Marshal(e)
        if mErr != nil {
            return fmt.Errorf("marshalling %s: %w", e.EventType(), mErr)
        }
        if _, err = tx.Exec(ctx, `
            INSERT INTO outbox (id, aggregate_id, tenant_id, event_type, payload, occurred_at)
            VALUES ($1,$2,$3,$4,$5, now())`,
            uuid.New(), a.ID(), a.TenantID(), e.EventType(), payload,
        ); err != nil {
            return fmt.Errorf("writing outbox %s: %w", e.EventType(), err)
        }
    }

    if err = tx.Commit(ctx); err != nil {
        return fmt.Errorf("commit: %w", err)
    }
    return nil
}
```

**Why the named return `(err error)` + deferred rollback:** it guarantees the transaction is always closed on every return path, including panics, and surfaces a rollback failure without masking the original error. This is the blueprint's "never discard errors" applied to the most dangerous resource in the service.

---

## Tenant Context Helper

```go
// tenantID extracts the caller's tenant from context. A missing tenant is a programming
// error (auth middleware must run first) — fail loud rather than query across tenants.
func tenantID(ctx context.Context) uuid.UUID {
    id, ok := ctx.Value(ctxKeyTenant).(uuid.UUID)
    if !ok {
        panic("tenant id missing from context — auth middleware did not run") // caught at boundary
    }
    return id
}
```

A missing tenant must never silently become a cross-tenant query. This is the application-layer backstop behind physical isolation (see `multi-tenancy-design`).

---

## Repository Rules

- **No business logic.** A repository loads, saves, and translates. Decisions belong in the Aggregate/application layer.
- **Return domain types, not rows.** Callers receive `*domain.DataAsset`, never a pgx row or a DB struct.
- **Context everywhere.** Every method takes `ctx` first and passes it to every pgx call — this carries cancellation, deadlines, and the trace span.
- **One repository per Aggregate.** No generic `Repository[T]`; small focused ports (see `go-project-structure`).
- **Batch with `pgx.Batch`** for multi-statement reads — never build dynamic SQL.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Atomic state + events | Update and outbox inserts in one transaction | Publish-after-commit; events outside the tx |
| Optimistic concurrency | CAS on `version`; 0 rows → `ErrConcurrentModification` | Last-write-wins with no version check |
| Tenant scoping | Every query filters `tenant_id` from context | A query missing the tenant filter |
| Parameterised SQL | Only `$N` placeholders | Any string-concatenated SQL |
| Error translation | pgx errors wrapped/translated to domain sentinels | pgx types leaking to the application layer |
| Tx always closed | Deferred rollback safe after commit; no leaked tx | A path that can leave a transaction open |
| Context propagation | `ctx` passed to every pgx call | Background context or dropped ctx |

---

## Output Format

Produces Go source plus integration tests (run against a real PostgreSQL via testcontainers — see test-engineering):

```
internal/infrastructure/postgres/dataasset_repo.go
internal/infrastructure/postgres/dataasset_repo_test.go   (integration test)
```
