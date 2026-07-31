# Document Modeling Patterns — Embed vs. Reference, Cardinality, Schema Versioning

Self-contained reference for the `document-data-modeling` skill. Worked patterns for
modeling MongoDB documents in the data-estate/compliance product (the `DataAsset`
domain), grounded in the stable MongoDB document model and BSON contract. All examples
carry `tenantId` because the product is per-tenant physically isolated and every filter
must still scope by tenant as defense-in-depth.

---

## 1. The Embed-vs-Reference Three-Test, Worked

For every parent-child relationship, run the three tests. The answer is a *modeling*
decision recorded in the data model artifact, not a code detail.

1. **Bounded?** Will the child set stay well under the 16MB BSON document cap?
2. **Read together?** Is the child read on the same read path as the parent, every time?
3. **Owned by one?** Does exactly one parent own the child's lifecycle (contained)?

Three yeses → **embed**. Any no → **reference**.

### Worked case A — DataAsset + classification tags (embed)

A `DataAsset` (a file discovered in Google Drive / S3) has a handful of classification
tags produced when it was last scanned. Bounded (a few tags), read together (the listing
shows them), owned by one asset. Three yeses → embed.

```json
{
  "_id": { "$oid": "66a1f2c0e13b8a0012ab34cd" },
  "schemaVersion": 3,
  "tenantId": "t_8f21",
  "connector": "google-drive",
  "path": "/Finance/Q3-forecast.xlsx",
  "mimeType": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  "classification": {
    "sensitivity": "confidential",
    "tags": ["pii", "financial"],
    "scannedAt": { "$date": "2026-07-30T11:04:00Z" }
  }
}
```

The corresponding Go domain document with `bson` struct tags (the persistence code lives
in `go-mongodb-repository`; shown here only to make the shape concrete):

```go
type DataAsset struct {
	ID             primitive.ObjectID `bson:"_id,omitempty"`
	SchemaVersion  int                `bson:"schemaVersion"`
	TenantID       string             `bson:"tenantId"`
	Connector      string             `bson:"connector"`
	Path           string             `bson:"path"`
	MimeType       string             `bson:"mimeType"`
	Classification Classification     `bson:"classification"` // embedded sub-document
}

type Classification struct {
	Sensitivity string    `bson:"sensitivity"`
	Tags        []string  `bson:"tags"` // multikey-indexable array
	ScannedAt   time.Time `bson:"scannedAt"`
}
```

### Worked case B — DataAsset + audit events (reference)

Every access to a `DataAsset` writes an audit event. Over a tenant's lifetime this is
unbounded (one-to-squillions). Fails test 1 (bounded) and test 2 (not read with the
asset). → **reference**, and — per the inversion rule below — put the key on the *child*.

```json
// collection: auditEvents  (key points UP at the asset)
{ "_id": {"$oid": "..."}, "schemaVersion": 1, "tenantId": "t_8f21",
  "assetId": {"$oid": "66a1f2c0e13b8a0012ab34cd"},
  "action": "download", "actor": "u_44", "at": {"$date": "2026-07-31T09:00:00Z"} }
```

---

## 2. Cardinality Rules of Thumb

| Relationship | Rule of thumb | Where the link lives |
|---|---|---|
| **One-to-few** | Embed the children as an array sub-document | In the parent |
| **One-to-many** | Reference by default; embed only a *bounded* subset (e.g. last 20) | Array of keys in parent, or key in child |
| **One-to-squillions** | **Always reference** | Key on the **child**, pointing up at the parent |

### The one-to-squillions inversion

When the child set is genuinely unbounded (audit events, scan-result rows, per-file
extractions), you cannot store an array of keys in the parent either — that array itself
grows unbounded and re-breaches 16MB. The rule: **put the parent key on the child** and
query the child collection filtered by that key + `tenantId`. This is the single most
common modeling mistake carried over from relational thinking.

> **Threshold:** treat any relationship expected to exceed roughly a **few hundred**
> children per parent, or with no natural upper bound, as one-to-squillions — reference
> with the key on the child, never embed and never array-of-keys in the parent.

### Bounded-subset embedding (the hybrid)

For one-to-many where the *recent* children are read with the parent but the full history
is not, embed a capped subset (the last N) in the parent for read locality *and* keep the
full set in a referenced child collection. MongoDB's `$push` with `$slice` maintains the
cap on write.

---

## 3. Denormalization as an Owned Tradeoff

There are no joins on the write path, so duplicating data is a deliberate design act, not
an accident. Copying `tenantName` into each `DataAsset` makes a tenant listing one query
instead of a per-row lookup.

| You gain | You owe |
|---|---|
| Read locality (one query, no `$lookup`) | A consistency obligation: update **every** copy when the source changes, or explicitly accept staleness |
| Fewer round trips | Write-time fan-out to all duplicating documents |

Record, in the data model artifact, for each denormalized field: the source of truth, the
documents that hold copies, and who performs the fan-out update (application, background
job, or "staleness accepted with TTL"). An unnamed denormalization is an anti-pattern.

---

## 4. Schema Versioning in a Schemaless Store

MongoDB enforces no structure by default, so the schema is an application concern and it
*will* drift unless versioned. There is no `ALTER TABLE`.

### The versioned-document + handle-on-read pattern

1. Every document carries `schemaVersion` from creation.
2. The load path is a small upgrade switch — read an old version, return the current
   shape *in memory*. No migration window, no downtime.
3. A background migrator can lazily rewrite documents at rest during idle time.

```go
// handle-on-read: upgrade older documents to the current shape as they load.
func upgrade(a *DataAsset) *DataAsset {
	if a.SchemaVersion < 2 {
		// v1 stored a single string "tag"; v2 uses a []string "tags".
		if a.Classification.Tags == nil && a.legacyTag != "" {
			a.Classification.Tags = []string{a.legacyTag}
		}
		a.SchemaVersion = 2
	}
	if a.SchemaVersion < 3 {
		// v3 added sensitivity, defaulting legacy docs to "unclassified".
		if a.Classification.Sensitivity == "" {
			a.Classification.Sensitivity = "unclassified"
		}
		a.SchemaVersion = 3
	}
	return a
}
```

### Locking the contract once stable — `$jsonSchema` validator

Once a collection's shape settles, attach a server-side validator so malformed writes are
rejected at the database, not just in code:

```javascript
db.runCommand({
  collMod: "dataAssets",
  validator: { $jsonSchema: {
    bsonType: "object",
    required: ["schemaVersion", "tenantId", "connector", "path"],
    properties: {
      schemaVersion: { bsonType: "int", minimum: 3 },
      tenantId:      { bsonType: "string" },
      classification: { bsonType: "object", properties: {
        sensitivity: { enum: ["public","internal","confidential","restricted","unclassified"] },
        tags:        { bsonType: "array", items: { bsonType: "string" } }
      }}
    }
  }},
  validationLevel: "moderate"
})
```

---

## 5. The Bucketing Pattern (time-series / high-frequency children)

When children arrive at high frequency (e.g. per-minute scan-progress samples for a
DataAsset), storing one document per sample floods the collection and one embedded array
grows unbounded. The **bucket pattern** stores a fixed window of samples per document —
one bucket document per asset per hour — bounding both document size and document count.

```json
{ "_id": {"$oid": "..."}, "schemaVersion": 1, "tenantId": "t_8f21",
  "assetId": {"$oid": "66a1f2c0e13b8a0012ab34cd"},
  "hour": {"$date": "2026-07-31T09:00:00Z"}, "count": 3,
  "samples": [ {"t": 12, "pct": 40}, {"t": 30, "pct": 55}, {"t": 51, "pct": 80} ] }
```

Writes append to the current hour's bucket with `$push`; a `count` guards the cap. This
keeps each document bounded (predictable size) and the collection small (buckets, not
samples), which is exactly the read/index profile MongoDB rewards.

## 6. The Outlier Pattern

Most `DataAsset`s have a few classification tags, but a rare few (a giant shared drive
root) have thousands. Do not size every document for the outlier. Embed the common case;
for the rare document that would breach the cap, set an `hasOverflow: true` flag and move
the excess to a referenced overflow collection. The application checks the flag and reads
the overflow only for the outliers — the 99% common path stays a single-document read.
