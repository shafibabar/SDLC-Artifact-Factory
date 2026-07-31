---
name: go-mongodb-repository
description: >
  Teaches the backend-engineer to implement a MongoDB repository in Go to a
  checkable standard: the official mongo-go-driver
  (go.mongodb.org/mongo-driver), a Collection-narrow port that hides the
  driver behind the domain (repository pattern), CRUD with bson struct-tag
  mapping and Reconstitute-on-decode, aggregation pipelines built as
  mongo.Pipeline / bson.D and decoded with cursor.All, multi-document
  transactions via StartSession and session.WithTransaction (when they earn
  their cost), index creation at startup with mongo.IndexModel and the ESR
  rule, per-operation read/write concern selection (w:"majority",
  read concern snapshot), mongo.ErrNoDocuments and duplicate-key
  WriteException translation into domain errors, and mandatory tenantId
  scoping on every filter and as the leading field of every compound index.
  The document-store analog of go-repository-pattern (which owns pgx and
  Postgres): same rigor, BSON and mongo-go-driver instead of SQL and pgx.
  Full repository (interface + mongo impl, CRUD, bson mapping, error table,
  compile-time assertion, per-tenant filter) in
  references/repository-implementation.md; aggregation-from-Go, transactions,
  index creation, and the test-fixture pattern in
  references/aggregation-transactions-indexes.md. Implements the
  data-architect's document schemas (document-data-modeling). Used by the
  backend-engineer during Implement for any service backed by MongoDB.
version: 1.0.0
phase: implement
owner: backend-engineer
created: 2026-07-31
tags: [implement, backend, mongodb, repository, go, aggregation, driver]
related: [go-repository-pattern, go-domain-model, document-data-modeling, go-migration]
tools: [Bash]
---

# Go MongoDB Repository

## Purpose

A MongoDB repository is the only thing that knows how a document-shaped Aggregate is persisted. It satisfies the small, consumer-defined port from `domain/ports.go`, hides the official `mongo-go-driver` entirely from the application layer, and guarantees three non-negotiables identical in spirit to the pgx repository (`go-repository-pattern`): every operation is scoped to the tenant, every driver error crossing out of the package arrives as a domain type, and the application layer — never a repository method — owns any multi-document transaction boundary.

This is the **document-store analog** of `go-repository-pattern`. Where that skill owns pgx / Postgres / SQL, this one owns `mongo-go-driver` / BSON / the aggregation pipeline. The repo default is still PostgreSQL (`document-data-modeling` gates *when* a service earns Mongo at all); this skill governs *how* to build the repository once that decision is made and justified.

A repository is Robert Martin's **Humble Object**: thin, hard-to-unit-test wrapper code verified by integration tests against a real MongoDB (Testcontainers), not unit tests with a mocked driver. Logic worth unit-testing — invariants, state transitions — lives in the Aggregate (`go-domain-model`), fully testable with no database.

---

## The Collection-Narrow Port — Never `*mongo.Client`

Depend on the smallest interface the repository actually calls, not the concrete `*mongo.Collection` and never `*mongo.Client`. This keeps the driver swappable and the repository testable, mirroring the pgx `Querier` port.

```go
// A narrow port satisfied structurally by *mongo.Collection.
type docCollection interface {
    InsertOne(ctx context.Context, doc any, opts ...*options.InsertOneOptions) (*mongo.InsertOneResult, error)
    FindOne(ctx context.Context, filter any, opts ...*options.FindOneOptions) *mongo.SingleResult
    Find(ctx context.Context, filter any, opts ...*options.FindOptions) (*mongo.Cursor, error)
    UpdateOne(ctx context.Context, filter, update any, opts ...*options.UpdateOptions) (*mongo.UpdateResult, error)
    DeleteOne(ctx context.Context, filter any, opts ...*options.DeleteOptions) (*mongo.DeleteResult, error)
    Aggregate(ctx context.Context, pipeline any, opts ...*options.AggregateOptions) (*mongo.Cursor, error)
}

type MongoDataAssetRepo struct{ col docCollection }

func NewMongoDataAssetRepo(db *mongo.Database) *MongoDataAssetRepo {
    return &MongoDataAssetRepo{col: db.Collection("data_assets")}
}

// Compile-time assertion: a renamed/re-typed method fails to compile HERE.
var _ domain.DataAssetRepository = (*MongoDataAssetRepo)(nil)
```

The full port, constructor, and CRUD body: **`references/repository-implementation.md`**.

---

## BSON Mapping Discipline — `bson` Tags and Reconstitute-on-Decode

The persistence document is a package-private struct with `bson:"…"` tags, distinct from the domain Aggregate. Decode a stored document into that struct, then rebuild the Aggregate through `domain.Reconstitute(...)` — **never `domain.New…`**. Calling a `New…` constructor from a read path re-validates already-valid stored data and re-emits the creation Domain Event on every read (the identical rule `go-repository-pattern` states for pgx rows).

- Store the tenant discriminator as `bson:"tenantId"` and the schema discriminator as `bson:"schemaVersion"` (`document-data-modeling` owns the handle-on-read upgrade switch).
- Never leak `bson.M` / `bson.D` / `primitive.ObjectID` upward — callers receive `*domain.DataAsset`, never a driver or BSON type.
- Prefer `bson.D` (ordered) for filters and pipeline stages where field order matters (compound-index match, `$sort`); `bson.M` (unordered map) only for simple single-field equality where order is irrelevant.

Full document struct, tag table, and decode path: **`references/repository-implementation.md`**.

---

## Per-Tenant Scoping — `tenantId` in Every Filter

Every filter carries `tenantId` from context as the leading field, and `tenantId` is the leading field of every compound index (ESR rule — Equality first). This is application-layer defense-in-depth *behind* physical isolation (`multi-tenancy-design`), not the sole barrier — read it as the second independent layer, exactly as the pgx repository treats its `tenant_id = $N` clause.

```go
filter := bson.D{{Key: "tenantId", Value: tenantID(ctx)}, {Key: "_id", Value: id}}
```

A filter missing `tenantId` is a code-review defect. A missing tenant in context must panic at the boundary, never silently become a cross-tenant scan. Full rule and helper: **`references/repository-implementation.md`**.

---

## Error-Translation Standard

Every driver error a method can receive is classified once, in a small private `translateMongoError` helper beside the repository — never a shared `internal/infrastructure/errors.go`. The rule with no exception: **no `mongo`-package or `bson` type ever crosses out of `internal/infrastructure/mongodb/`.** A caller inspecting a `mongo.WriteException` itself is a defect — the translation already happened. `mongo.ErrNoDocuments` from a `FindOne` becomes `domain.ErrNotFound`; a duplicate-key write becomes `domain.ErrConflict`. The complete table (including the exact duplicate-key code) and helper: **`references/repository-implementation.md`**.

---

## When to Use a Multi-Document Transaction

Single-document writes are **always atomic** in MongoDB — that is the document model's whole point, and the reason a correctly-drawn Aggregate almost never needs a transaction. Reach for a multi-document transaction only as a targeted tool, and treat needing one *frequently* as a signal the documents are drawn wrong.

| Situation | Correct tool |
|---|---|
| One Aggregate, all its state in one document | Plain `UpdateOne` — atomic, no session |
| Optimistic concurrency on one document | `UpdateOne` with a `version` predicate in the filter (CAS) |
| Two documents / two collections that must commit together | `StartSession` + `session.WithTransaction`, `w:"majority"` |
| A cross-Aggregate workflow you reach for often | Re-examine the document boundaries first (`document-data-modeling`) |

A transaction adds latency, lock contention, and carries a 60-second default runtime limit; `WithTransaction` retries on transient errors automatically. Worked session example and cost discussion: **`references/aggregation-transactions-indexes.md`**.

---

## Aggregation, Indexes — Pointers

- **Aggregation from Go** builds a `mongo.Pipeline` of `bson.D` stages — `$match` first on an indexed field, then `$group` / `$lookup` / `$project` / `$unwind` — and decodes with `cursor.All(ctx, &out)`, returning domain Read Models. Keep pipelines *inside* the repository; never leak stages upward. `$lookup` is the exception, not the norm — heavy join-shaped work is the signal to reconsider Postgres.
- **Indexes are created at startup** (idempotently) via `col.Indexes().CreateMany` with `mongo.IndexModel`, following the ESR rule and a TTL index for anything ephemeral. Mongo has no migration DDL (`go-migration` owns the Postgres story); index creation is code that runs on boot.

Both worked in full: **`references/aggregation-transactions-indexes.md`**.

---

## Repository Rules

- **No business logic.** Loads, saves, translates — decisions belong in the Aggregate / application layer.
- **Return domain types, not documents.** Callers receive `*domain.DataAsset`, never a `bson.M` or persistence struct.
- **Context everywhere.** Every method takes `ctx` first and passes it to every driver call.
- **One repository per Aggregate.** No generic `Repository[T]`; small focused ports.
- **Reconstitute on decode, `New…` never.** No exceptions.
- **A repository method never calls `StartSession`.** The session/transaction boundary is the application layer's, exactly as `pool.Begin` is in the pgx skill.

---

## Quality Criteria

| Criterion | Pass | Fail | How to verify |
|---|---|---|---|
| Narrow port, not client | Repo field is a `docCollection`-style interface | Repo holds `*mongo.Client` or `*mongo.Collection` directly | Read the struct definition |
| Compile-time assertion | `var _ domain.X = (*MongoXRepo)(nil)` present | Absent | `grep -n "var _ domain" internal/infrastructure/mongodb` |
| Reconstitute on decode | Every read path calls `domain.Reconstitute` | A read calls a `New…` constructor | `grep -n "domain.New" internal/infrastructure/mongodb` — no hits |
| Tenant scoping | Every filter carries `tenantId` from context | A filter missing `tenantId` | Read every `bson.D` filter |
| No driver type leaks | No `mongo.`/`bson.` type past `mongodb/` | A `mongo.WriteException` inspected in application layer | `grep -rn "mongo\.\|bson\." internal/application` — empty |
| Error translation complete | `ErrNoDocuments` and duplicate-key both handled | Raw driver error returned | Read `translateMongoError` |
| Session only in app layer | Zero `StartSession` inside a repository method | A repository opens its own session | `grep -rn "StartSession" internal/infrastructure/mongodb` — empty |
| Context propagation | `ctx` passed to every driver call | `context.Background()` in a request path | `grep -rn "context.Background()" internal/infrastructure/mongodb` — no hits |

---

## Anti-Patterns

- **Depending on `*mongo.Client` / `*mongo.Collection`** — unswappable, forces a live server for every unit test; depend on a narrow interface.
- **Calling `New…` from a decode path** — re-validates stored data and republishes a stale creation event on every read.
- **Leaking `bson.M` / `primitive.ObjectID` upward** — the application layer must never speak BSON.
- **`StartSession` inside a repository** — steals the transaction boundary the application layer owns; a use case needing two repo calls to commit together can't compose them back.
- **Reaching for a multi-document transaction as a default** — usually a mis-drawn Aggregate; single-document writes are already atomic.
- **A filter with `tenantId` "optimised away"** — it is in every filter, no exceptions, even under physical isolation.
- **`$lookup`-heavy pipelines as the norm** — join-shaped work is the signal you wanted Postgres.

---

## Output Format

Go source built exactly to the standards above, plus integration tests against a real MongoDB via Testcontainers (`go-integration-test` owns the harness; this skill states what must be testable — real filters, real duplicate-key conflicts, real pipeline output):

```
internal/infrastructure/mongodb/dataasset_repo.go       (port, CRUD, bson mapping, translateMongoError, tenant filter)
internal/infrastructure/mongodb/indexes.go              (startup index creation — ESR + TTL)
internal/infrastructure/mongodb/dataasset_repo_test.go  (integration test — go-integration-test)
```

Full standards: `references/repository-implementation.md` (port, CRUD, bson mapping, error table, compile-time assertion, per-tenant filter) and `references/aggregation-transactions-indexes.md` (aggregation from Go, multi-document transactions, index creation, test-fixture pattern).
