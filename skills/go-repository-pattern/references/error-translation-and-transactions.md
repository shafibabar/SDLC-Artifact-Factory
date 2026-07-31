# Error Translation and Transaction Boundaries — Worked Standard

Full worked material referenced from `SKILL.md`'s "Error-Translation Standard" and
"Transaction-Boundary Standard" sections. Self-contained — reads without the parent
body already in context. Covers: the complete pgx-error-to-domain-error mapping, why
the translation helper lives beside its repository rather than in a shared file, the
exact rule for where a `pgx.Tx` is opened and committed, and the `Querier`/`WithTx`
mechanism a repository uses to participate in a caller-supplied transaction.

---

## 1. The Complete pgx Error-Translation Table

Every error a repository method can receive from pgx falls into one of these cases.
Anything not in this table is an unrecognised infrastructure failure — wrap it with
`fmt.Errorf("...: %w", err)` and return it as-is; do not invent a domain sentinel for
an error class you have not actually seen and classified.

| pgx/pgconn condition | Detection | Domain translation | Why |
|---|---|---|---|
| No matching row | `errors.Is(err, pgx.ErrNoRows)` | `domain.ErrNotFound` (sentinel) | Parameter-free — existence check, no diagnostic payload (`go-domain-model`'s Invariant-Violation Error Standard) |
| Unique-constraint violation | `errors.As(err, &pgErr)` then `pgErr.Code == "23505"` | `&domain.ErrDuplicate{Field: ...}` (typed) | Carries which constraint fired — gets a named type, not a sentinel |
| Foreign-key violation | `pgErr.Code == "23503"` | `domain.ErrInvalidReference` (sentinel) | A referenced row does not exist; parameter-free is enough for the caller to react |
| Client-side context deadline | `errors.Is(err, context.DeadlineExceeded)` | `domain.ErrTimeout` (sentinel) | The caller's own deadline (request timeout, `errgroup` budget) elapsed before the query returned |
| Client-side context cancellation | `errors.Is(err, context.Canceled)` | `domain.ErrCanceled` (sentinel) | The caller walked away (client disconnect, sibling goroutine failed) — not a server-side fault |
| Server-side statement timeout | `pgErr.Code == "57014"` (`query_canceled`) | `domain.ErrTimeout` (sentinel — same as client deadline) | Postgres's own `statement_timeout` fired. A **different underlying mechanism** from `context.DeadlineExceeded` (no local ctx involved at all — the server aborted a still-live client request) but the **same caller-visible effect**, so it maps to the same sentinel. Treating these as two different domain errors makes the application layer handle a distinction it cannot act on differently. |
| Serialization failure (SERIALIZABLE isolation) | `pgErr.Code == "40001"` | `domain.ErrRetryable` (sentinel) | Not a business conflict like `ErrConcurrentModification` — it means Postgres detected a conflicting concurrent transaction and aborted this one; the correct response is an automatic retry of the whole use case, not surfacing it to a user. Only relevant if a repository method explicitly runs at `pgx.Serializable` (rare — see `go-project-structure`'s Quality Criteria before reaching for this over the version-column CAS this skill uses by default). |

```go
// internal/infrastructure/postgres/dataasset_repo.go — lives beside the repo that
// uses it. NOT internal/infrastructure/errors.go (go-project-structure's anti-pattern:
// a dedicated infra errors file implies infrastructure owns a failure vocabulary; it
// only ever translates into the domain's). If a second repository needs the same
// three-case switch, duplicate the ~12 lines rather than centralise them into a
// package the Dependency Rule then has to justify importing.
func translatePgError(err error, notFound error) error {
    switch {
    case err == nil:
        return nil
    case errors.Is(err, pgx.ErrNoRows):
        return notFound
    case errors.Is(err, context.DeadlineExceeded):
        return domain.ErrTimeout
    case errors.Is(err, context.Canceled):
        return domain.ErrCanceled
    }
    var pgErr *pgconn.PgError
    if errors.As(err, &pgErr) {
        switch pgErr.Code {
        case "23505":
            return &domain.ErrDuplicate{Field: constraintField(pgErr.ConstraintName)}
        case "23503":
            return domain.ErrInvalidReference
        case "57014":
            return domain.ErrTimeout
        case "40001":
            return domain.ErrRetryable
        }
    }
    return err // unrecognised — not swallowed, not guessed at
}

// constraintField maps a Postgres constraint name to the business field it protects.
// Keep this table next to the migration that creates the constraint (go-migration) —
// a constraint renamed in a migration with no matching update here silently degrades
// ErrDuplicate.Field to the constraint's raw SQL name.
func constraintField(constraint string) string {
    switch constraint {
    case "data_assets_source_id_tenant_id_key":
        return "source_id"
    default:
        return constraint
    }
}
```

Call sites stay one line: `return nil, translatePgError(err, domain.ErrNotFound)` for a
read, `return translatePgError(err, nil)` for a write with no not-found case (a `nil`
second argument is a programming error if it's ever actually reached — writes fail
the CAS predicate, they don't 404).

---

## 2. Where a Transaction Opens, and Why Never Inside a Repository

**The rule:** the *application layer's* command handler opens the `pgx.Tx`, and
commits or rolls it back — never a repository method. A repository method never calls
`pool.Begin(ctx)`.

This is not a style preference. A repository method knows only its own statements; it
cannot know whether it is the *only* write in the current use case or one of several
that must commit or roll back together. A `Save` that opens and commits its own
transaction internally is atomic *with itself* but not with anything else the use case
does in the same request — a second repository call, a second aggregate, a
publish-adjacent write. The atomicity boundary a transaction expresses is a **use-case**
boundary, and only the application layer (`go-service-layer`'s command handler) knows
where that boundary actually is. This generalises the pattern the previous version of
this skill already got half right (compare-and-swap update + outbox insert atomic
*with each other*) to the case that pattern didn't cover: a use case needing more than
one repository call to commit together.

### The `Querier` Interface and `WithTx`

Both `*pgxpool.Pool` and `pgx.Tx` implement the same three-method shape pgx repository
code actually calls. Name that shape explicitly and depend on it instead of the
concrete pool type:

```go
// internal/infrastructure/postgres/querier.go
type Querier interface {
    Exec(ctx context.Context, sql string, args ...any) (pgconn.CommandTag, error)
    Query(ctx context.Context, sql string, args ...any) (pgx.Rows, error)
    QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

type DataAssetRepo struct{ q Querier }

func NewDataAssetRepo(pool *pgxpool.Pool) *DataAssetRepo { return &DataAssetRepo{q: pool} }

// WithTx returns a repository value bound to the caller's transaction instead of the
// pool. It does not open, commit, or roll back anything — it only rebinds where
// subsequent calls send their statements. The returned value is cheap (one pointer
// field) and is discarded at the end of the use case.
func (r *DataAssetRepo) WithTx(tx pgx.Tx) *DataAssetRepo { return &DataAssetRepo{q: tx} }
```

`FindByID` is safe to call on either a pool-bound or tx-bound repo — a read has no
atomicity requirement of its own. **`Save` is a hard precondition on being tx-bound**:
its `UPDATE` and its outbox `INSERT` are two separate statements, and only a shared
`pgx.Tx` makes them commit or roll back together. Calling `Save` on a pool-bound repo
is a code-review defect, not a runtime-guarded one — see `SKILL.md`'s Quality Criteria
for the exact grep that catches it (every `Save` call site must be reached through a
`WithTx(tx)` value in the same function).

### The Application-Layer Worked Example

```go
// internal/application/commands/classify_data_asset.go
type ClassifyDataAssetHandler struct {
    pool   *pgxpool.Pool          // owns transaction lifecycle for this use case
    assets *postgres.DataAssetRepo // concrete type — this handler needs WithTx, which
                                    // is not on the narrow domain.DataAssetRepository
                                    // port. A deliberate, narrow exception to
                                    // consumer-defined-port-only wiring (go-project-
                                    // structure), scoped to the one field that needs
                                    // it — every other dependency on this handler
                                    // still takes the narrow port. Handlers with no
                                    // multi-call atomicity requirement keep using the
                                    // port unchanged, exactly as go-service-layer
                                    // already shows.
    policy domain.AccessPolicy
    clock  func() time.Time
}

func (h *ClassifyDataAssetHandler) Handle(ctx context.Context, cmd ClassifyDataAsset) (err error) {
    tx, err := h.pool.Begin(ctx)
    if err != nil {
        return fmt.Errorf("begin tx: %w", err)
    }
    // Same named-return-plus-deferred-rollback idiom as the old in-repository Save:
    // rollback is a no-op after a successful commit, so every return path is safe.
    defer func() {
        if rbErr := tx.Rollback(ctx); rbErr != nil && !errors.Is(rbErr, pgx.ErrTxClosed) {
            err = errors.Join(err, fmt.Errorf("rollback: %w", rbErr))
        }
    }()

    repo := h.assets.WithTx(tx) // caller-supplied transaction — repo never opened one

    asset, err := repo.FindByID(ctx, cmd.DataAssetID)
    if err != nil {
        return err
    }
    sub, err := domain.SubjectFromContext(ctx)
    if err != nil {
        return ErrUnauthenticated
    }
    res := domain.Resource{Type: "data-asset", ID: asset.ID(), TenantID: asset.TenantID()}
    if err := h.policy.Evaluate(ctx, sub, res, domain.ActionClassify); err != nil {
        return err
    }
    if err := asset.Classify(cmd.Sensitivity, cmd.ClassifiedBy, h.clock()); err != nil {
        return err
    }
    if err := repo.Save(ctx, asset); err != nil { // UPDATE + outbox INSERT, same tx
        return err
    }

    return tx.Commit(ctx)
}
```

`go-service-layer` owns the general command-handler shape (idempotency, ABAC ordering,
the CQRS write/read split); this skill owns only the transaction-specific fields
(`pool`, `assets`) and the `WithTx` call that makes `Save` safe to call at all.

### Repository Method Bodies Do Not Change Shape

`Save` still executes exactly the two statements the previous version of this skill
showed (compare-and-swap `UPDATE`, then the outbox `INSERT` per drained event) — only
`r.pool.Begin(ctx)` / `tx.Commit(ctx)` move out of the method body and into the
caller. Every statement inside `Save` now runs against `r.q` (whatever `Querier` this
repo value was constructed or `WithTx`-rebound with) instead of a locally-opened `tx`:

```go
func (r *DataAssetRepo) Save(ctx context.Context, a *domain.DataAsset) error {
    ct, err := r.q.Exec(ctx, `
        UPDATE data_assets
           SET sensitivity_level = $1, classified_by = $2, classified_at = $3,
               version = version + 1, updated_at = now()
         WHERE id = $4 AND tenant_id = $5 AND version = $6`,
        string(a.Sensitivity()), a.ClassifiedBy(), a.ClassifiedAt(),
        a.ID(), a.TenantID(), a.Version(),
    )
    if err != nil {
        return translatePgError(fmt.Errorf("updating data asset %s: %w", a.ID(), err), nil)
    }
    if ct.RowsAffected() == 0 {
        return fmt.Errorf("data asset %s: %w", a.ID(), domain.ErrConcurrentModification)
    }
    for _, e := range a.PullEvents() {
        payload, mErr := json.Marshal(e)
        if mErr != nil {
            return fmt.Errorf("marshalling %s: %w", e.EventType(), mErr)
        }
        if _, err = r.q.Exec(ctx, `
            INSERT INTO outbox (id, aggregate_id, tenant_id, event_type, payload, occurred_at)
            VALUES ($1,$2,$3,$4,$5, now())`,
            uuid.New(), a.ID(), a.TenantID(), e.EventType(), payload,
        ); err != nil {
            return translatePgError(fmt.Errorf("writing outbox %s: %w", e.EventType(), err), nil)
        }
    }
    return nil
}
```

No `Begin`, no `defer tx.Rollback`, no `Commit` — every path in `Save` now either
returns an error (the caller's `defer tx.Rollback(ctx)` unwinds everything) or returns
`nil` (the caller's `tx.Commit(ctx)` makes it durable). The method is shorter *and*
strictly more composable than the version that opened its own transaction.
