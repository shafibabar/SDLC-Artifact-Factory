# Example 3 — High availability: routing reads to replicas without breaking read-your-writes

Self-contained. The enterprise case: the platform runs PostgreSQL as one primary plus two streaming replicas per region, for availability and read scale. Replicas apply the primary's changes asynchronously, typically within milliseconds but occasionally seconds behind. Kleppmann (*Designing Data-Intensive Applications*, Ch. 5) names the anomalies this lag causes. The design must say which ones each read path prevents:

| Anomaly | What the user sees | Prevented by |
|---|---|---|
| **Read-your-writes** | They change a classification, and the next screen shows the old value | Reading their own recent writes from the primary |
| **Monotonic reads** | A refresh shows a newer value, then an older one (two different replicas) | Pinning a session to one replica |
| **Consistent prefix** | Effects appear before their causes | Not a risk here: single-leader replication preserves order per replica |

## Input

> Dashboards and list screens should read from replicas. After a user classifies an asset, the asset detail screen must show their change immediately.

## Output

### The routing rule, stated once

- **Command side** (`FindByID` → `Save` inside a transaction) **always uses the primary.** It's bound to the primary's `pgx.Tx` via `WithTx`, so this needs no new code. Replicas are read-only and would reject the writes anyway.
- **Query side** (read models, lists, dashboards) uses a replica by default.
- **Query side immediately after this user's own write** uses the primary, for a bounded window. This is Kleppmann's "read from the leader for N seconds after a user's write" technique.

### Query-side repository with two queriers

```go
type AssetQueries struct {
    primary Querier // *pgxpool.Pool to the primary
    replica Querier // *pgxpool.Pool to the regional replica set
    recent  RecentWrites
}

// RecentWrites remembers, per tenant+user, when they last wrote. Back it with
// the same Redis the platform already runs for sessions, keys expiring after
// the window; an in-process map only works for a single instance.
type RecentWrites interface {
    Record(ctx context.Context, tenantID, userID uuid.UUID)
    WroteWithin(ctx context.Context, tenantID, userID uuid.UUID, window time.Duration) bool
}

// userID, like tenantID, reads the authenticated subject the auth middleware
// put on the context.

// readYourWritesWindow must exceed the replica lag you alert on (p99 lag SLO).
const readYourWritesWindow = 5 * time.Second

func (q *AssetQueries) querierFor(ctx context.Context) Querier {
    if q.recent.WroteWithin(ctx, tenantID(ctx), userID(ctx), readYourWritesWindow) {
        return q.primary // read-your-writes
    }
    return q.replica
}

func (q *AssetQueries) AssetDetail(ctx context.Context, id uuid.UUID) (domain.DataAssetView, error) {
    var view domain.DataAssetView
    err := q.querierFor(ctx).QueryRow(ctx, `
        SELECT id, name, sensitivity_level, classified_by, classified_at, version
          FROM data_assets
         WHERE id = $1 AND tenant_id = $2 AND deleted_at IS NULL`,
        id, tenantID(ctx),
    ).Scan(&view.ID, &view.Name, &view.Sensitivity, &view.ClassifiedBy, &view.ClassifiedAt, &view.Version)
    if err != nil {
        return domain.DataAssetView{}, translatePgError(err, domain.ErrNotFound)
    }
    return view, nil
}
```

The command handler records the write **after** `tx.Commit` succeeds, never before. A write recorded before the commit could route reads to the primary for data that was then rolled back. That's harmless, but recording it before the commit hides real bugs in tests.

```go
if err = tx.Commit(ctx); err != nil {
    return err
}
h.recent.Record(ctx, tenantID(ctx), userID(ctx))
return nil
```

### A cheaper alternative where it fits

The command's response already carries the new `version` (`cqrs-pattern`'s read-your-writes default). If the client sends it back as `?minVersion=7`, the query side can read from the replica and fall back to the primary only when the replica's row is older than version 7. That's precise, but it needs every client to cooperate. The time window works without client changes.

### Monotonic reads for dashboards

Pin each session to one replica (hash the session ID onto the replica list) rather than load-balancing every query. Then a refresh can never go backwards because it hit a more-lagged replica.

## What to test

- With replication paused (in an integration test, by pointing `replica` at a snapshot), a write followed by `AssetDetail` within the window returns the new value from the primary.
- After the window, reads go to the replica.
- `Save` called through `AssetQueries` does not exist: the query side has no write methods.
