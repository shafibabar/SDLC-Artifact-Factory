# MongoDB Repository Implementation — Full Worked Standard

The complete Go repository the SKILL.md body summarizes: the Collection-narrow port, the bson-tagged persistence document, CRUD with tenant scoping, the error-translation table (with the exact duplicate-key code), the compile-time interface assertion, and the tenant/context helpers. Every snippet uses the official driver `go.mongodb.org/mongo-driver/mongo` and its sub-packages `mongo/options`, `bson`, `bson/primitive` — no invented API surface.

---

## 1. The Domain Port (lives with the consumer)

The interface is declared where it is *used*, in `internal/domain/ports.go`, in domain vocabulary — it names no driver type.

```go
package domain

import (
    "context"
    "github.com/google/uuid"
)

// DataAssetRepository is the persistence port for the DataAsset Aggregate.
// It speaks only domain types; nothing here mentions MongoDB or BSON.
type DataAssetRepository interface {
    FindByID(ctx context.Context, id uuid.UUID) (*DataAsset, error)
    Save(ctx context.Context, a *DataAsset) error
    ListBySensitivity(ctx context.Context, level SensitivityLevel) ([]*DataAsset, error)
}
```

---

## 2. The Collection-Narrow Port

The repository depends on `docCollection`, satisfied structurally by `*mongo.Collection`, so a fake can be substituted in a fast unit test and the concrete driver never appears in a method signature.

```go
package mongodb

import (
    "context"
    "go.mongodb.org/mongo-driver/mongo"
    "go.mongodb.org/mongo-driver/mongo/options"
)

// docCollection is the slice of *mongo.Collection this repository actually calls.
type docCollection interface {
    InsertOne(ctx context.Context, doc any, opts ...*options.InsertOneOptions) (*mongo.InsertOneResult, error)
    FindOne(ctx context.Context, filter any, opts ...*options.FindOneOptions) *mongo.SingleResult
    Find(ctx context.Context, filter any, opts ...*options.FindOptions) (*mongo.Cursor, error)
    UpdateOne(ctx context.Context, filter, update any, opts ...*options.UpdateOptions) (*mongo.UpdateResult, error)
    DeleteOne(ctx context.Context, filter any, opts ...*options.DeleteOptions) (*mongo.DeleteResult, error)
    Aggregate(ctx context.Context, pipeline any, opts ...*options.AggregateOptions) (*mongo.Cursor, error)
    Indexes() mongo.IndexView
}
```

---

## 3. The Persistence Document — `bson` Tags

The stored document is a package-private struct, deliberately separate from the domain Aggregate. Every field carries an explicit `bson` tag; nothing relies on the driver's default lower-casing.

```go
type dataAssetDoc struct {
    ID            primitive.ObjectID `bson:"_id,omitempty"`
    AssetID       string             `bson:"assetId"`       // domain uuid as canonical string
    TenantID      string             `bson:"tenantId"`      // leading field of every index and filter
    SourceID      string             `bson:"sourceId"`
    Sensitivity   string             `bson:"sensitivity"`
    Version       int64              `bson:"version"`       // optimistic-concurrency token
    SchemaVersion int                `bson:"schemaVersion"` // handle-on-read upgrade discriminator
    DeletedAt     *time.Time         `bson:"deletedAt,omitempty"`
}
```

| Tag choice | Why |
|---|---|
| `_id,omitempty` | Let MongoDB assign the `ObjectId` on insert; omit it so a zero value is not written. |
| `assetId` as `string` | The domain identity is a `uuid.UUID`; store its canonical string so queries are human-readable and index-friendly, keeping `_id` for Mongo's own use. |
| `tenantId` first | Leading equality field of every compound index (ESR rule) and every filter. |
| `schemaVersion` | The handle-on-read migration hook — `document-data-modeling` owns the upgrade switch. |
| `deletedAt,omitempty` | Soft-delete marker; absent on live documents so a partial index can exclude them. |

---

## 4. Constructor and Compile-Time Assertion

```go
type MongoDataAssetRepo struct{ col docCollection }

func NewMongoDataAssetRepo(db *mongo.Database) *MongoDataAssetRepo {
    return &MongoDataAssetRepo{col: db.Collection("data_assets")}
}

// The compile-time interface assertion: if a method is renamed or its
// signature drifts, compilation fails HERE — on this line — not at some
// distant call site. This is the document-store twin of the pgx repository's
// `var _ domain.DataAssetRepository = (*DataAssetRepo)(nil)`.
var _ domain.DataAssetRepository = (*MongoDataAssetRepo)(nil)
```

---

## 5. Read — `FindByID`, Tenant-Scoped, Reconstitute-on-Decode

```go
func (r *MongoDataAssetRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.DataAsset, error) {
    filter := bson.D{
        {Key: "tenantId", Value: tenantID(ctx).String()}, // tenant first — defense in depth
        {Key: "assetId", Value: id.String()},
        {Key: "deletedAt", Value: bson.D{{Key: "$exists", Value: false}}},
    }

    var doc dataAssetDoc
    if err := r.col.FindOne(ctx, filter).Decode(&doc); err != nil {
        return nil, translateMongoError(err) // ErrNoDocuments -> domain.ErrNotFound
    }

    // Rebuild through Reconstitute — NEVER domain.NewDataAsset. New… would
    // re-run invariant checks against data Mongo already accepted and re-emit
    // the creation Domain Event on every read.
    return domain.Reconstitute(
        uuid.MustParse(doc.AssetID),
        uuid.MustParse(doc.TenantID),
        uuid.MustParse(doc.SourceID),
        domain.SensitivityLevel(doc.Sensitivity),
        doc.Version,
    ), nil
}
```

---

## 6. Write — `Save` with Optimistic Concurrency (single-document, atomic)

A single-document `UpdateOne` is atomic in MongoDB — no session needed. Concurrency is enforced by placing the expected `version` in the *filter* (compare-and-swap): if another writer moved past it, zero documents match and the update is rejected.

```go
func (r *MongoDataAssetRepo) Save(ctx context.Context, a *domain.DataAsset) error {
    doc := toDoc(a) // domain -> dataAssetDoc

    filter := bson.D{
        {Key: "tenantId", Value: a.TenantID().String()},
        {Key: "assetId", Value: a.ID().String()},
        {Key: "version", Value: a.Version()}, // CAS: match the version we loaded
    }
    update := bson.D{{Key: "$set", Value: bson.D{
        {Key: "sensitivity", Value: string(a.Sensitivity())},
        {Key: "version", Value: a.Version() + 1},
        {Key: "schemaVersion", Value: currentSchemaVersion},
    }}}

    res, err := r.col.UpdateOne(ctx, filter, update, options.Update().SetUpsert(true))
    if err != nil {
        return translateMongoError(err)
    }
    if res.MatchedCount == 0 && res.UpsertedCount == 0 {
        return domain.ErrConcurrentModification // a concurrent writer won the CAS
    }
    return nil
}
```

`SetUpsert(true)` lets the first write of a brand-new Aggregate insert it; the CAS still protects every subsequent update. A unique index on `{tenantId, assetId}` makes a racing double-insert surface as a duplicate-key error rather than two documents.

---

## 7. Error-Translation Table and Helper

Every driver error is classified once, in this private helper beside the repository — never a shared `internal/infrastructure/errors.go`. No `mongo`-package or `bson` type crosses out of this package.

| Driver condition | Detected with | Domain error |
|---|---|---|
| No document matched a `FindOne` | `errors.Is(err, mongo.ErrNoDocuments)` | `domain.ErrNotFound` |
| Duplicate key on a unique index | `mongo.IsDuplicateKeyError(err)` — write error code **11000** (server message `E11000 duplicate key error`) | `domain.ErrConflict` |
| Client deadline elapsed | `errors.Is(err, context.DeadlineExceeded)` | `domain.ErrTimeout` |
| Client cancelled the call | `errors.Is(err, context.Canceled)` | `domain.ErrCanceled` |
| Transient transaction error | `mongo.IsTimeout(err)` / label `TransientTransactionError` | retried by `WithTransaction`, else `domain.ErrUnavailable` |
| Anything else | fallthrough | wrapped `domain.ErrInternal` |

```go
func translateMongoError(err error) error {
    switch {
    case err == nil:
        return nil
    case errors.Is(err, mongo.ErrNoDocuments):
        return domain.ErrNotFound
    case mongo.IsDuplicateKeyError(err):
        // Server duplicate-key write error, code 11000 ("E11000 duplicate key error").
        return domain.ErrConflict
    case errors.Is(err, context.DeadlineExceeded):
        return domain.ErrTimeout
    case errors.Is(err, context.Canceled):
        return domain.ErrCanceled
    default:
        // A *mongo.WriteException with an unrecognised code, or any driver error
        // we do not classify, becomes an opaque internal error — the raw driver
        // type never escapes this package.
        return fmt.Errorf("%w: %v", domain.ErrInternal, err)
    }
}
```

`mongo.IsDuplicateKeyError` inspects the underlying `*mongo.WriteException` / `*mongo.CommandError` for write-error code **11000**; do not string-match the `E11000` message text, which is not a stable contract — use the helper.

---

## 8. Tenant and Context Helpers

```go
type ctxKey int

const ctxKeyTenant ctxKey = iota

// tenantID pulls the authenticated tenant from context. A missing tenant is a
// programming error (auth middleware did not run) — it must panic at the
// boundary, never silently become a cross-tenant query.
func tenantID(ctx context.Context) uuid.UUID {
    id, ok := ctx.Value(ctxKeyTenant).(uuid.UUID)
    if !ok {
        panic("tenant id missing from context — auth middleware did not run")
    }
    return id
}
```

Every repository method takes `ctx` first and threads it into every driver call so a caller's deadline and cancellation propagate all the way to the wire. Set a per-operation timeout at the application layer with `context.WithTimeout`; the repository never invents its own `context.Background()`.

---

## 9. List — `Find` + `cursor.All`, Still Tenant-Scoped

```go
func (r *MongoDataAssetRepo) ListBySensitivity(ctx context.Context, level domain.SensitivityLevel) ([]*domain.DataAsset, error) {
    filter := bson.D{
        {Key: "tenantId", Value: tenantID(ctx).String()},
        {Key: "sensitivity", Value: string(level)},
        {Key: "deletedAt", Value: bson.D{{Key: "$exists", Value: false}}},
    }

    cur, err := r.col.Find(ctx, filter, options.Find().SetSort(bson.D{{Key: "assetId", Value: 1}}))
    if err != nil {
        return nil, translateMongoError(err)
    }
    defer cur.Close(ctx)

    var docs []dataAssetDoc
    if err := cur.All(ctx, &docs); err != nil { // decode the whole cursor at once
        return nil, translateMongoError(err)
    }

    out := make([]*domain.DataAsset, 0, len(docs))
    for _, d := range docs {
        out = append(out, reconstituteDoc(d)) // Reconstitute, never New…
    }
    return out, nil
}
```

`cursor.All` is correct for a bounded result set; for an unbounded stream iterate with `cur.Next(ctx)` and decode one document at a time to keep memory flat. Always `defer cur.Close(ctx)` — an unclosed cursor holds a server-side resource.

---

## 10. Client Construction (composition root, not the repository)

The repository receives a `*mongo.Database`; the client is built once at the composition root with read/write concern chosen deliberately, and pinged before use.

```go
func connect(ctx context.Context, uri string) (*mongo.Client, error) {
    opts := options.Client().
        ApplyURI(uri).
        SetWriteConcern(writeconcern.Majority()).       // durable acknowledgement
        SetReadConcern(readconcern.Majority()).          // read majority-committed data
        SetReadPreference(readpref.PrimaryPreferred())

    client, err := mongo.Connect(ctx, opts)
    if err != nil {
        return nil, err
    }
    if err := client.Ping(ctx, readpref.Primary()); err != nil {
        return nil, err
    }
    return client, nil
}
```

Read/write concern are per-operation dials: override on a specific call via `options.Update().SetWriteConcern(...)` when one operation needs a stronger or weaker guarantee than the client default. `w:"majority"` (`writeconcern.Majority()`) is the safe default for state-changing writes in this repo.
