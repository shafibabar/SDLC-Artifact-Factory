# Consistency Patterns for Read Models

Self-contained reference for eventual consistency management in Read Model design. Usable without
the parent SKILL.md in context.

Grounded in: Kleppmann (Designing Data-Intensive Applications — replication lag anomalies and their
mitigations), Vernon (Implementing DDD — Domain Events for cross-Aggregate eventual consistency),
and this plugin's CQRS defaults.

---

## The Version Field Pattern

Every Read Model row carries two staleness signals propagated from the Aggregate that produced the events:

```sql
version     BIGINT  NOT NULL DEFAULT 0,   -- last Aggregate version applied to this row
updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
```

The `version` field is the Aggregate's own optimistic-concurrency counter, propagated verbatim into the
Read Model row by the Projector. It is not the Read Model's own row version — it is the Aggregate's.

Why this matters: after a Command completes, the Command handler returns the new Aggregate version in
the HTTP response. The client can then poll the Read Model until `row.version >= expectedVersion`.
This is the read-your-own-writes guarantee without ever reading from the Aggregate table directly.

### Version Field in the Aggregate Event

Every Domain Event carries the Aggregate version that was current when the event was emitted:

```go
// In the Aggregate, after state change:
type DataAssetClassified struct {
    DataAssetID      uuid.UUID
    TenantID         uuid.UUID
    SensitivityLevel SensitivityLevel
    ClassifiedBy     string
    OccurredAt       time.Time
    AggregateVersion int64  // the Aggregate's version *after* this event
}
```

### Version Field Propagation in the Projector

```go
func (p *DataAssetListProjector) handleClassified(ctx context.Context, e domain.DataAssetClassified) error {
    return p.store.UpdateSensitivity(ctx, UpdateSensitivityParams{
        DataAssetID:      e.DataAssetID,
        TenantID:         e.TenantID,
        SensitivityLevel: e.SensitivityLevel.String(),
        LastClassifiedAt: e.OccurredAt,
        Version:          e.AggregateVersion,  // propagated from event
        UpdatedAt:        e.OccurredAt,
    })
}
```

---

## Read-Your-Own-Writes Pattern

Kleppmann names "read-your-own-writes consistency" as a specific, precisely-named guarantee:
a user who just wrote something must be able to read their own write back, even if the replica
they are reading from has not caught up.

In a CQRS architecture, the equivalent problem is: a client issues a Command (e.g., classify a
DataAsset), the Command handler commits successfully, and the client immediately queries the Read
Model — but the Projector hasn't processed the event yet. The client sees stale data.

**The solution: version-header polling, not Write Model reads.**

### Step 1: Return the new Aggregate version from the Command handler

```go
// POST /data-assets/{id}/classify — handler response
type ClassifyResponse struct {
    DataAssetID      string `json:"dataAssetId"`
    SensitivityLevel string `json:"sensitivityLevel"`
    AppliedVersion   int64  `json:"appliedVersion"`  // new Aggregate version after classify
}
```

### Step 2: Expose the applied version in the Read Model GET response header

```go
// GET /data-assets/{id} — handler
func (h *Handler) GetDataAsset(w http.ResponseWriter, r *http.Request) {
    view, err := h.repo.FindByID(r.Context(), tenantID, assetID)
    // ...
    w.Header().Set("X-Applied-Version", strconv.FormatInt(view.Version, 10))
    json.NewEncoder(w).Encode(view)
}
```

### Step 3: Client polls until version is satisfied

The client (or BFF) polls `GET /data-assets/{id}` and inspects the `X-Applied-Version` header
until `appliedVersion >= expectedVersion`. Typical polling interval: 200ms, max 3 attempts.
If after 3 attempts the version has not caught up, the UI shows a "processing" indicator rather
than stale data presented as fresh.

**Do not fix read-your-own-writes by reading from the Aggregate table.** That silently
reintroduces the coupling CQRS was adopted to remove, and defeats the purpose of the Read Model.

---

## AsOf Timestamp for Aggregate Views (Dashboards)

Every summary / aggregate-level Read Model must carry an `as_of` timestamp and expose it in the
API response. A dashboard that cannot say how old it is will be trusted exactly until the first
incident — users cannot distinguish "zero compliance gaps" from "projector down for six hours."

```go
// In the Projector, every update stamps as_of:
type UpdateDashboardParams struct {
    TenantID  uuid.UUID
    AsOf      time.Time  // the OccurredAt of the most recently processed event
    // ... count fields ...
}

// In the API response:
type ComplianceDashboardResponse struct {
    TotalAssets       int                    `json:"totalAssets"`
    ClassifiedCount   int                    `json:"classifiedCount"`
    GapsByFramework   map[string]GapSummary  `json:"gapsByFramework"`
    AsOf              time.Time              `json:"asOf"`  // always exposed; never omitted
    LastScanAt        *time.Time             `json:"lastScanAt,omitempty"`
}
```

Alert when projection lag exceeds a threshold (e.g., `now() - as_of > 5 minutes`) so the
operations team knows the projector is behind before a user files a bug report about stale numbers.

---

## Projector Rules

Projectors must satisfy five invariants. All five must hold before a Projector is considered correct:

### 1. Idempotent

Replaying the same event twice must produce the same Read Model state. Use `INSERT ... ON CONFLICT DO UPDATE`
(upsert), not bare `INSERT`. A Projector that appends on every event call will produce duplicates on replay.

```sql
-- CORRECT: idempotent upsert keyed on aggregate ID + tenant ID
INSERT INTO data_asset_list_view (id, tenant_id, file_path, ..., version, updated_at)
VALUES ($1, $2, $3, ..., $4, $5)
ON CONFLICT (id, tenant_id)
DO UPDATE SET
    file_path  = EXCLUDED.file_path,
    version    = EXCLUDED.version,
    updated_at = EXCLUDED.updated_at
WHERE data_asset_list_view.version < EXCLUDED.version;
-- The WHERE clause prevents rolling back a newer state on a re-delivered old event.
```

### 2. Never issues Commands

Projectors only read events and write Read Model rows. They never publish Domain Events, never call
Command handlers, and never write to Aggregate tables. Reactions to Domain Events (business responses
to something that happened) are Policies in the write side — not Projector side effects.

### 3. Handles all subscribed events; silently ignores others

A Projector subscribes to a specific set of event types. Events of unrecognized types (future schema
additions, other Aggregates' events on the same topic) are silently ignored — not errors. This
is the Tolerant Reader pattern at the Projector boundary.

### 4. Replayable from position 0

The Read Model can be fully rebuilt from the event stream by replaying from the first event. This
means the Projector must handle the earliest-possible events (e.g., `DataAssetRegistered` in
addition to `DataAssetClassified`) and must not depend on state that is not derivable from events.

### 5. Position tracking — committed with the Read Model write

The Projector tracks the last processed event offset (the Redpanda topic partition offset).
This offset is committed in the same database transaction as the Read Model write — not
separately. This guarantees that a crash between writing the Read Model row and committing the
offset causes the event to be reprocessed (idempotency covers the duplicate), rather than silently
skipped (which would cause permanent inconsistency).

```go
func (p *DataAssetListProjector) processEvent(ctx context.Context, tx pgx.Tx, event ConsumerRecord) error {
    if err := p.applyEvent(ctx, tx, event); err != nil {
        return err
    }
    // Commit offset in the SAME transaction as the Read Model write:
    return p.offsetStore.CommitOffset(ctx, tx, event.Topic, event.Partition, event.Offset)
}
```

---

## Rebuild With Shadow Table

When a Read Model needs to be rebuilt (corrupted projection, new projection logic, schema migration),
do not truncate and replay against the live table — the live table must keep serving queries throughout
the rebuild.

**Procedure:**

1. Create `data_asset_list_view_rebuild` with the same schema as `data_asset_list_view`.
2. Run the Projector against the rebuild table from event offset 0 (or from the snapshot if available).
3. Monitor rebuild progress by comparing the rebuild table's row count and max `updated_at` against
   the live table.
4. Once the rebuild table has caught up to within a few seconds of the live table:
5. In a single transaction:
   ```sql
   ALTER TABLE data_asset_list_view RENAME TO data_asset_list_view_old;
   ALTER TABLE data_asset_list_view_rebuild RENAME TO data_asset_list_view;
   ```
6. Point the Projector's consumer at the new table and continue processing live events.
7. Drop `data_asset_list_view_old` after confirming the swap succeeded.

This pattern ensures zero query downtime during a full replay. The live Read Model continues serving
reads from the old table until the swap; the swap itself is atomic. This is the standard shadow table
pattern — project into a shadow, then swap names in one transaction.

---

## Kleppmann's Eventual Consistency Anomalies — Mitigations

Kleppmann (Designing Data-Intensive Applications, Ch. 5) names three precisely-named replication-lag
anomalies that apply equally to CQRS projection lag:

| Anomaly | Scenario in CQRS | Mitigation |
|---|---|---|
| **Read-your-writes** | A client classifies a DataAsset and immediately queries the list — the projection hasn't caught up, so the old sensitivity level is returned | Return `appliedVersion` from the Command; client polls until `X-Applied-Version >= expectedVersion` |
| **Monotonic reads** | A user refreshes a dashboard twice in quick succession, hits two different read replicas — the second response shows an older `AsOf` than the first | Pin a session to one replica for dashboard reads (sticky routing); or expose `AsOf` so the user can see the freshness explicitly |
| **Consistent prefix reads** | A list shows `DataAssetClassified` results without showing the `DataAssetRegistered` event that created the asset — an in-flight ordering issue | Projectors process events in partition-ordered sequence; within a partition, a `DataAssetClassified` event for an asset cannot arrive before `DataAssetRegistered` (same Aggregate, same partition key) |

The partition-key discipline (partitioning events by `aggregateId` or `tenantId + aggregateId`) is
what makes consistent-prefix reads a non-issue within a single Aggregate's event stream. The other
two anomalies are addressed by version-header polling and `AsOf` exposure respectively.
