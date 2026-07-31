# Aggregation, Multi-Document Transactions, and Index Creation — Full Worked Standard

The three mechanics the SKILL.md body points to: building an aggregation pipeline from Go and decoding it into a domain Read Model, opening a multi-document transaction only when it earns its cost, and creating indexes idempotently at startup. Plus the integration-test-fixture pattern for exercising all three against a real MongoDB. Everything uses the official `go.mongodb.org/mongo-driver/mongo` surface.

---

## 1. Aggregation Pipeline from Go

An aggregation pipeline is an ordered list of stages, each transforming the document stream. In Go it is a `mongo.Pipeline` — a `[]bson.D`, one `bson.D` per stage. Build it in the repository, run it with `col.Aggregate`, decode with `cursor.All`, and return a domain Read Model. Never leak a pipeline stage or a `bson.M` upward.

### Stage vocabulary (real MongoDB stages)

| Stage | Purpose |
|---|---|
| `$match` | Filter the stream — put it **first** and on an indexed field so the pipeline scans as few documents as possible. |
| `$group` | Aggregate — `$sum`, `$avg`, `$push`, `$addToSet`, grouped by `_id`. |
| `$lookup` | Left-outer join into another collection — the exception, not the norm. |
| `$project` / `$addFields` | Reshape — include/exclude fields, compute new ones. |
| `$sort` | Order the stream (backed by an index where possible). |
| `$unwind` | Flatten an array field into one document per element. |
| `$facet` | Run several sub-pipelines over the same input in one pass. |

### Worked example — sensitivity counts per source, tenant-scoped

```go
type SensitivityCount struct {
    SourceID    string `bson:"_id"`   // $group key surfaces as _id
    Sensitivity string `bson:"sensitivity"`
    Count       int64  `bson:"count"`
}

func (r *MongoDataAssetRepo) CountBySensitivity(ctx context.Context) ([]SensitivityCount, error) {
    pipeline := mongo.Pipeline{
        // $match FIRST, tenant-scoped, on an indexed field.
        bson.D{{Key: "$match", Value: bson.D{
            {Key: "tenantId", Value: tenantID(ctx).String()},
            {Key: "deletedAt", Value: bson.D{{Key: "$exists", Value: false}}},
        }}},
        // $group by source + sensitivity, counting.
        bson.D{{Key: "$group", Value: bson.D{
            {Key: "_id", Value: bson.D{
                {Key: "sourceId", Value: "$sourceId"},
                {Key: "sensitivity", Value: "$sensitivity"},
            }},
            {Key: "count", Value: bson.D{{Key: "$sum", Value: 1}}},
        }}},
        // $sort for a stable Read Model.
        bson.D{{Key: "$sort", Value: bson.D{{Key: "count", Value: -1}}}},
    }

    cur, err := r.col.Aggregate(ctx, pipeline)
    if err != nil {
        return nil, translateMongoError(err)
    }
    defer cur.Close(ctx)

    var out []SensitivityCount
    if err := cur.All(ctx, &out); err != nil {
        return nil, translateMongoError(err)
    }
    return out, nil // a domain Read Model — no bson type escapes
}
```

**Rules.** `$match` first, always on an indexed field; verify every pipeline with `explain()` in review and refuse a collection scan. Keep the pipeline entirely inside the repository. Return a typed Read Model (`[]SensitivityCount`), never a `[]bson.M`. A `$lookup`-heavy pipeline is the signal that the workload is join-shaped and might belong in Postgres (`document-data-modeling`).

---

## 2. Multi-Document Transactions

Single-document writes are already atomic, so most repositories never open a transaction. When two documents (or two collections) genuinely must commit together, use a session and `session.WithTransaction`, which runs the callback under snapshot isolation and **retries the whole callback automatically** on a transient error. The transaction boundary is the *application layer's* — a repository method never calls `StartSession`.

### Cost — why this is a targeted tool, not a default

- Added latency and lock contention versus a plain write.
- A **60-second default transaction runtime limit** (`transactionLifetimeLimitSeconds`) — long work inside a transaction aborts.
- Requires a replica set (transactions are not available on a standalone `mongod`).
- Needing one *frequently* means the Aggregate boundaries are drawn wrong — fix the documents first.

### Worked example — application-layer command handler

```go
// In internal/application — NOT in the repository. The handler owns the session.
func (h *ReclassifyHandler) Handle(ctx context.Context, cmd ReclassifyCommand) error {
    session, err := h.client.StartSession()
    if err != nil {
        return err
    }
    defer session.EndSession(ctx)

    // WithTransaction retries the callback on TransientTransactionError /
    // UnknownTransactionCommitResult labels until it commits or the ctx expires.
    _, err = session.WithTransaction(ctx, func(sc mongo.SessionContext) (any, error) {
        // Both repository calls receive the session-bound context so their
        // writes join the same transaction and commit atomically.
        if err := h.assets.SaveCtx(sc, cmd.Asset); err != nil {
            return nil, err
        }
        if err := h.audit.AppendCtx(sc, cmd.AuditEntry); err != nil {
            return nil, err // returning an error aborts and rolls back the transaction
        }
        return nil, nil
    }, options.Transaction().
        SetWriteConcern(writeconcern.Majority()). // durable commit
        SetReadConcern(readconcern.Snapshot()))   // snapshot isolation

    return translateMongoError(err)
}
```

The repository methods accept the `mongo.SessionContext` as their ordinary `ctx` argument (it *is* a `context.Context`), so no repository code knows or cares whether it is running inside a transaction — exactly how the pgx repository's `WithTx` keeps its methods transaction-agnostic. `w:"majority"` + read concern `snapshot` is the standard transaction concern pairing.

---

## 3. Index Creation at Startup

MongoDB has no migration DDL — there is no `ALTER TABLE`, so index creation is Go code that runs idempotently on service boot (`go-migration` owns the Postgres migration story; this is the document-store equivalent). `Indexes().CreateMany` is idempotent: re-creating an index with the same key spec and name is a no-op.

### The ESR rule

Compound-index field order follows **Equality, Sort, Range**: equality-matched fields first, then the field you sort on, then range-matched fields. `tenantId` is always the leading equality field, both for query performance and as the physical expression of tenant scoping.

### Worked example — `indexes.go`

```go
func EnsureIndexes(ctx context.Context, col *mongo.Collection) error {
    models := []mongo.IndexModel{
        // Unique identity per tenant — makes a racing double-insert a duplicate-key error.
        {
            Keys:    bson.D{{Key: "tenantId", Value: 1}, {Key: "assetId", Value: 1}},
            Options: options.Index().SetName("uq_tenant_asset").SetUnique(true),
        },
        // ESR: Equality (tenantId, sensitivity) then Sort (assetId) for ListBySensitivity.
        {
            Keys: bson.D{
                {Key: "tenantId", Value: 1},
                {Key: "sensitivity", Value: 1},
                {Key: "assetId", Value: 1},
            },
            Options: options.Index().SetName("ix_tenant_sensitivity_asset"),
        },
        // Partial index excluding soft-deleted docs — keeps the live-set index small.
        {
            Keys: bson.D{{Key: "tenantId", Value: 1}, {Key: "sourceId", Value: 1}},
            Options: options.Index().
                SetName("ix_tenant_source_live").
                SetPartialFilterExpression(bson.D{{Key: "deletedAt", Value: bson.D{{Key: "$exists", Value: false}}}}),
        },
        // TTL index — MongoDB auto-expires ephemeral scan results after the window.
        {
            Keys:    bson.D{{Key: "expiresAt", Value: 1}},
            Options: options.Index().SetName("ttl_expires").SetExpireAfterSeconds(0),
        },
    }

    _, err := col.Indexes().CreateMany(ctx, models)
    return err
}
```

`SetExpireAfterSeconds(0)` with a per-document `expiresAt` date makes each document expire *at* the value in its own field — the native fit for ephemeral scan results, cached extractions, or an expiring audit window, so cleanup is the database's job, not a cron. Call `EnsureIndexes` once per collection at startup, after `Ping` succeeds and before the service accepts traffic.

---

## 4. Integration-Test Fixture Pattern

These mechanics are verified against a real MongoDB via Testcontainers, not a mocked driver (`go-integration-test` owns the harness; this is what a repository test drives). A single fixture spins up the container, ensures indexes, and hands back a tenant-scoped context.

```go
func newFixture(t *testing.T) (*MongoDataAssetRepo, context.Context) {
    t.Helper()
    ctx := context.Background()

    container, err := mongodb.Run(ctx, "mongo:7") // mongodb testcontainers module
    if err != nil {
        t.Fatalf("start mongo container: %v", err)
    }
    t.Cleanup(func() { _ = container.Terminate(ctx) })

    uri, _ := container.ConnectionString(ctx)
    client, err := mongo.Connect(ctx, options.Client().ApplyURI(uri))
    if err != nil {
        t.Fatalf("connect: %v", err)
    }
    t.Cleanup(func() { _ = client.Disconnect(ctx) })

    db := client.Database("test")
    if err := EnsureIndexes(ctx, db.Collection("data_assets")); err != nil {
        t.Fatalf("ensure indexes: %v", err)
    }

    tid := uuid.New()
    tctx := context.WithValue(ctx, ctxKeyTenant, tid) // satisfy tenantID(ctx)
    return NewMongoDataAssetRepo(db), tctx
}
```

What such tests must exercise (real behavior, not mocks): a `FindByID` miss returns `domain.ErrNotFound` (proving the `ErrNoDocuments` translation); a second insert of the same `{tenantId, assetId}` returns `domain.ErrConflict` (proving the duplicate-key translation against the real unique index); a stale-version `Save` returns `domain.ErrConcurrentModification` (proving the CAS); an aggregation returns the expected typed Read Model; and a filter for one tenant never returns another tenant's documents (proving tenant scoping). Transactions need a replica set — the single-node Testcontainer must be started as a one-node replica set for `WithTransaction` tests to run.
