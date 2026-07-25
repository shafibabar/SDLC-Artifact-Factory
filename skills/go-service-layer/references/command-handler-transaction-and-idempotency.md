# Command Handler Standard — Transaction Boundary and Idempotency, Fully Worked

Full worked material referenced from `SKILL.md`'s "Command Handler Standard" section.
Self-contained — reads without the parent body already in context. Covers: the exact
`Handle(ctx, cmd) (Result, error)` signature, why this layer — not the repository —
opens the `pgx.Tx`, the `command_log` idempotency table participating in that same
transaction (the application-layer counterpart to `go-event-consumer`'s
`processed_events` pattern on the consume side), and the complete handler body in
fixed step order.

---

## 1. Why This Layer Opens the Transaction

`go-repository-pattern`'s Transaction-Boundary Standard states the rule from the
repository's side: **a repository method never calls `pool.Begin(ctx)`** — a
repository knows only its own statements, not whether this call is one of several that
must commit together. That "several that must commit together" knowledge belongs to
whichever code actually defines the use case boundary — the command handler. This
skill is the other half of that same rule, stated from the caller's side: the command
handler is the one and only place a `pgx.Tx` is opened, committed, or rolled back for a
write use case.

A command handler that needs this — any handler whose `Handle` makes more than one
repository call, or couples a repository call to the idempotency-ledger write below —
holds the pool and a **concrete** repository type (not the narrow
`domain.DataAssetRepository` port) specifically so it can call `.WithTx(tx)`:

```go
// internal/application/commands/classify_data_asset.go
type ClassifyDataAssetHandler struct {
    pool   *pgxpool.Pool           // owns transaction lifecycle for this use case
    assets *postgres.DataAssetRepo // concrete type — needs WithTx, not on the narrow port
    policy domain.AccessPolicy
    clock  func() time.Time
}
```

This is `go-repository-pattern`'s own stated exception, held to here exactly: *"A
deliberate, narrow exception to consumer-defined-port-only wiring, scoped to the one
field that needs it — every other dependency on this handler still takes the narrow
port."* A command handler with no multi-call atomicity requirement (a single
repository call, no idempotency ledger write coupled to it) keeps using the narrow
port unchanged and is unaffected by anything in this file.

---

## 2. The `command_log` Idempotency Table

`command-catalog` (design phase) already owns the idempotency contract this table
implements — this skill does not redefine it, only implements it in Go/pgx:

```sql
-- 00027_create_command_log.sql
-- +goose Up
CREATE TABLE command_log (
    idempotency_key UUID PRIMARY KEY,
    command_type    TEXT NOT NULL,
    result          JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- +goose Down
DROP TABLE command_log;
```

One table, shared across every command type in the service (`command_type`
distinguishes rows; the key space is the client-generated `Idempotency-Key`, which is
already global per user intent — `react-api-client`'s "stable across retries of one
user intent" rule — not per-command-type). This is the exact shape
`command-catalog`'s Command Idempotency section already specifies; this skill adds
only where in the transaction it runs.

**Placement, stated as a rule — identical in shape to `go-event-consumer`'s
`processed_events` placement (`references/idempotent-consumer-standard.md` in that
skill, §3):** the idempotency `INSERT` is the *first* statement inside the command
handler's transaction, sharing that transaction with every write the domain call
produces. A crash between the idempotency insert and the domain write is impossible by
construction — one transaction, one commit, one rollback. This closes the small window
the previous version of this standard left open (a `Seen`/`Record` pair as two
separate calls, backstopped only by the repository's optimistic-concurrency CAS) —
that backstop is no longer needed for the race it existed to catch, because there is no
longer a gap for two concurrent retries to both pass a check.

```go
ct, err := tx.Exec(ctx,
    `INSERT INTO command_log (idempotency_key, command_type) VALUES ($1,$2)
     ON CONFLICT (idempotency_key) DO NOTHING`, cmd.IdempotencyKey, "ClassifyDataAsset")
if err != nil {
    return Result{}, fmt.Errorf("idempotency insert: %w", err)
}
if ct.RowsAffected() == 0 {
    // Duplicate delivery — a row with this key already exists. Fetch and replay its
    // stored result rather than re-running the use case (command-catalog: "the
    // duplicate invocation must return the same response as the original").
    var raw []byte
    if err := tx.QueryRow(ctx,
        `SELECT result FROM command_log WHERE idempotency_key = $1`, cmd.IdempotencyKey,
    ).Scan(&raw); err != nil {
        return Result{}, fmt.Errorf("fetching stored result: %w", err)
    }
    var res Result
    if err := json.Unmarshal(raw, &res); err != nil {
        return Result{}, fmt.Errorf("unmarshalling stored result: %w", err)
    }
    return res, tx.Commit(ctx) // nothing new to do; commit the (otherwise empty) tx
}
```

`ON CONFLICT (idempotency_key)` names the target explicitly here (unlike
`go-event-consumer`'s bare `ON CONFLICT DO NOTHING`) because `command_log` may later
grow a second unique constraint the bare form would then apply to ambiguously; naming
the target now costs nothing and avoids a silent behavior change if that happens.

---

## 3. The Complete Handler Body, in Fixed Step Order

```go
func (h *ClassifyDataAssetHandler) Handle(ctx context.Context, cmd ClassifyDataAsset) (res Result, err error) {
    tx, err := h.pool.Begin(ctx)
    if err != nil {
        return Result{}, fmt.Errorf("begin tx: %w", err)
    }
    // Named-return-plus-deferred-rollback: rollback is a no-op after a successful
    // commit, so every return path below is safe — identical idiom to the
    // application-layer worked example in go-repository-pattern's
    // references/error-translation-and-transactions.md §2.
    defer func() {
        if rbErr := tx.Rollback(ctx); rbErr != nil && !errors.Is(rbErr, pgx.ErrTxClosed) {
            err = errors.Join(err, fmt.Errorf("rollback: %w", rbErr))
        }
    }()

    // 1. Idempotency: insert-or-replay, same tx, first statement. See §2 above.
    ct, err := tx.Exec(ctx, `INSERT INTO command_log (idempotency_key, command_type)
        VALUES ($1,$2) ON CONFLICT (idempotency_key) DO NOTHING`,
        cmd.IdempotencyKey, "ClassifyDataAsset")
    if err != nil {
        return Result{}, fmt.Errorf("idempotency insert: %w", err)
    }
    if ct.RowsAffected() == 0 {
        return replayStoredResult(ctx, tx, cmd.IdempotencyKey) // §2's duplicate path
    }

    repo := h.assets.WithTx(tx) // caller-supplied transaction — repo never opened one

    // 2. Load the Aggregate.
    asset, err := repo.FindByID(ctx, cmd.DataAssetID)
    if err != nil {
        return Result{}, err // already a domain-typed error from the repo
    }

    // 3. Authorise BEFORE mutating (ABAC — enforced here, in the application layer).
    sub, err := domain.SubjectFromContext(ctx)
    if err != nil {
        return Result{}, ErrUnauthenticated
    }
    resource := domain.Resource{Type: "data-asset", ID: asset.ID(), TenantID: asset.TenantID()}
    if err := h.policy.Evaluate(ctx, sub, resource, domain.ActionClassify); err != nil {
        return Result{}, err // ErrForbidden — do not reveal why (access-control-model)
    }

    // 4. Execute the domain rule — the business logic lives in the Aggregate, not here.
    if err := asset.Classify(cmd.Sensitivity, cmd.ClassifiedBy, h.clock()); err != nil {
        return Result{}, err
    }

    // 5. Persist — state + outbox events, same tx (go-repository-pattern's Save).
    if err := repo.Save(ctx, asset); err != nil {
        return Result{}, err
    }

    // 6. Record the result the duplicate path above will replay.
    res = Result{} // ClassifyDataAsset has no meaningful return value; still recorded
    payload, err := json.Marshal(res)
    if err != nil {
        return Result{}, fmt.Errorf("marshalling result: %w", err)
    }
    if _, err := tx.Exec(ctx, `UPDATE command_log SET result = $1 WHERE idempotency_key = $2`,
        payload, cmd.IdempotencyKey); err != nil {
        return Result{}, fmt.Errorf("recording result: %w", err)
    }

    return res, tx.Commit(ctx)
}
```

The six steps are always in this fixed order: **begin tx → idempotency
insert-or-replay → load → authorise → domain call → save + record result → commit.**
Authorisation precedes mutation; persistence and result-recording share the same
transaction as the mutation; commit is the last statement in the function body.

---

## 4. Testability: This Handler Shape Is Integration-Tested, Not Mock-Unit-Tested

A handler holding `pool` and a concrete repository for `WithTx` cannot be meaningfully
unit-tested with a mocked port — the thing under test *is* the transaction boundary
itself, and a mock has no transaction to be bound to or rolled back from. `Handle`
methods shaped this way are verified by `go-integration-test` against a real
PostgreSQL via Testcontainers (that skill's own worked example exercises exactly this
handler shape: `classifyHandler.Handle(ctx, classifyCmd)` against a live database).
A command handler with **no** multi-call atomicity requirement — a single repository
call through the narrow port, no idempotency ledger write coupled to it — has no
transaction boundary of its own to verify and stays unit-testable with a mocked port,
unchanged from before this standard existed.
