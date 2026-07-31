# Aggregation and Indexing — Pipeline Stages, Index Taxonomy, the ESR Rule

Self-contained reference for the `document-data-modeling` skill. The aggregation pipeline
is MongoDB's analytical query language, and indexing is the difference between a working
query and a collection scan. Grounded in the stable, publicly documented MongoDB
aggregation-stage and index contract. Examples use the data-estate `DataAsset` and
`auditEvents` collections and always scope by `tenantId`.

---

## Part A — The Aggregation Pipeline

A pipeline is an ordered list of **stages**, each consuming the previous stage's document
stream and emitting a new one. Design so the first stage filters early on an indexed
field, then reshape.

### Stage catalog (the stages you actually use)

| Stage | Does | Design note |
|---|---|---|
| `$match` | Filters documents by predicate | **First**, on an indexed field (`tenantId` + more). An index can only serve `$match`/`$sort` when they lead the pipeline. |
| `$group` | Aggregates: `$sum`, `$avg`, `$min`/`$max`, `$push`, `$addToSet` | The count/rollup engine. `_id` is the group key. |
| `$project` | Includes/excludes/derives fields | Reshape into the Read Model; drop fields you don't return. |
| `$addFields` | Adds computed fields, keeps the rest | Like `$project` but non-destructive. |
| `$sort` | Orders the stream | Serve from an index (ESR) or it sorts in memory (100MB limit). |
| `$limit` / `$skip` | Paginate | `$limit` early shrinks downstream work. |
| `$unwind` | Flattens an array field into one doc per element | Precedes `$group` when aggregating over embedded arrays (e.g. `tags`). |
| `$lookup` | Left-outer join into another collection | The **exception**, not the norm. Heavy `$lookup` load = re-examine whether this belongs in Postgres. |
| `$facet` | Runs multiple sub-pipelines over the same input | One pass → several rollups (counts + top-N together). |
| `$count` | Emits a single count document | Terminal tally. |

### Worked query 1 — sensitivity breakdown per connector (this tenant)

"How many confidential assets does each connector hold for tenant `t_8f21`?"

```javascript
db.dataAssets.aggregate([
  { $match: { tenantId: "t_8f21", "classification.sensitivity": "confidential" } },
  { $group: { _id: "$connector", assets: { $sum: 1 } } },
  { $sort: { assets: -1 } }
])
```

`$match` leads on the compound index `{ tenantId: 1, "classification.sensitivity": 1 }`
(Equality, Equality) so no scan; `$group` rolls up per connector.

### Worked query 2 — tag frequency via `$unwind` (multikey array)

"Top classification tags across this tenant's estate."

```javascript
db.dataAssets.aggregate([
  { $match: { tenantId: "t_8f21" } },
  { $unwind: "$classification.tags" },
  { $group: { _id: "$classification.tags", n: { $sum: 1 } } },
  { $sort: { n: -1 } },
  { $limit: 10 }
])
```

### Worked query 3 — the same pipeline from Go (`mongo-go-driver`)

Build stages as `bson.D` and decode the cursor into a domain Read Model. The persistence
mechanics belong to `go-mongodb-repository`; shown here to make the pipeline shape
concrete.

```go
pipeline := mongo.Pipeline{
	{{"$match", bson.D{{"tenantId", tid}, {"classification.sensitivity", "confidential"}}}},
	{{"$group", bson.D{{"_id", "$connector"}, {"assets", bson.D{{"$sum", 1}}}}}},
	{{"$sort", bson.D{{"assets", -1}}}},
}
cur, err := coll.Aggregate(ctx, pipeline)
if err != nil { return nil, err }
var rows []ConnectorBreakdown // Read Model, not bson.M leaked upward
if err := cur.All(ctx, &rows); err != nil { return nil, err }
```

### `$lookup` — the deliberate exception

```javascript
// Attach the most-recent audit action to each asset. Works, but if this is a hot,
// frequent read the join-shaped need is a signal the data may belong in Postgres.
db.dataAssets.aggregate([
  { $match: { tenantId: "t_8f21" } },
  { $lookup: { from: "auditEvents", localField: "_id",
               foreignField: "assetId", as: "events" } },
  { $project: { path: 1, lastEvent: { $max: "$events.at" } } }
])
```

---

## Part B — Index Taxonomy and the ESR Rule

The governing rule is **index-supports-the-query**: every hot query must be covered by an
index, verified with `explain()`. An uncovered query is a design defect. Refuse a
collection scan (`COLLSCAN` in `explain()`) in review.

### Index types and when each

| Type | Definition | Use when |
|---|---|---|
| Single-field | `{ tenantId: 1 }` | One equality/sort predicate |
| **Compound** | `{ tenantId: 1, sensitivity: 1, scannedAt: -1 }` | Multi-predicate query — order by **ESR** (below) |
| **Multikey** | Auto over an array field, `{ "classification.tags": 1 }` | Predicate over an array; indexes each element |
| **Text** | `{ path: "text" }` | Full-text search over string content |
| **TTL** | `{ expiresAt: 1 }, { expireAfterSeconds: 0 }` | Ephemeral docs — auto-expire scan results, cached extractions, audit windows |
| Partial | `partialFilterExpression` | Index only a subset (e.g. only `confidential` assets) |
| Unique | `{ tenantId: 1, path: 1 }, { unique: true }` | Enforce a natural key within a tenant |

### The ESR rule for compound index field order

Order the fields of a compound index: **Equality first, then Sort, then Range.**

- **E**quality — fields matched with `=` (e.g. `tenantId`, `sensitivity`). Lead with them.
- **S**ort — fields the query sorts on (e.g. `scannedAt: -1`). Next, so the index also
  serves the sort and avoids an in-memory sort.
- **R**ange — fields matched with `$gt`/`$lt`/`$in` (e.g. `scannedAt: {$gte: ...}`). Last.

Worked: the query
`find({tenantId, sensitivity:"confidential", scannedAt:{$gte:X}}).sort({scannedAt:-1})`
is served by `{ tenantId: 1, sensitivity: 1, scannedAt: -1 }` — two equality fields lead,
and `scannedAt` covers *both* the sort and the range at the tail. `tenantId` always leads
every compound index in this product (tenant scoping + shard-key alignment).

### TTL worked example — auto-expiring scan results

```javascript
// scanResults documents self-delete 30 days after createdAt — cleanup is the
// database's job, not a cron.
db.scanResults.createIndex({ createdAt: 1 }, { expireAfterSeconds: 2592000 })
```

The `expireAfterSeconds` is measured from the indexed BSON date field; a background thread
removes expired documents. This is the native fit for ephemeral scan output and audit
retention windows.

---

## Part C — Index Anti-Patterns

| Anti-pattern | Why it hurts | Fix |
|---|---|---|
| Compound index with Range before Sort | Index can't serve the sort → in-memory sort, 100MB ceiling | Reorder to ESR |
| `tenantId` not leading | Cross-tenant scan; misaligned with shard key | `tenantId` leads every compound index |
| One index per field, no compound | Query intersects indexes poorly | Build the compound index the query needs |
| Indexing an unbounded-growth array (multikey) with a second array field | MongoDB forbids compound multikey over two arrays | Only one array field per compound index |
| Index that no query uses | Pure write-amplification cost | Drop it; every index must earn its write cost |
| Trusting a query without `explain()` | `COLLSCAN` ships to prod unnoticed | Verify `explain()` shows `IXSCAN`, refuse `COLLSCAN` in review |

### Consistency dials worth noting at model time

MongoDB exposes per-operation **write concern** (`w:1`, `w:"majority"`, `j:true` for
journal durability) and **read concern** (`local`, `majority`, `snapshot`) — consistency
is a per-call spectrum, not a single global default like Postgres. Note the required
concern per read/write path in the data model artifact so the repository code
(`go-mongodb-repository`) sets it deliberately: `w:"majority"` for classification writes
that must survive failover, `local` reads acceptable for a non-authoritative listing.
