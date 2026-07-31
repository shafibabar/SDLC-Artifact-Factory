# Event Versioning and Retention — Full Reference

Self-contained reference for integration event versioning (additive and breaking changes),
migration playbooks, event upcasting for event-sourced Aggregates, retention policy rationale,
and archival to the audit store. Read this when a Domain Event schema must evolve, when
planning a consumer migration, or when configuring Redpanda retention.

---

## Two Distinct Versioning Disciplines

Domain Event versioning splits into two fundamentally different problems:

| Concern | Integration event versioning | Event-sourced internal event versioning |
|---|---|---|
| What it governs | Transient events on a Redpanda topic with a retention window | Permanently-stored events in an append-only event store |
| Can old versions stop being emitted? | Yes — once all consumers have migrated | **Never** — the stream is the system of record |
| Migration mechanism | Parallel emission of v1 and v2; consumers opt into v2 | Event upcasting: load-time transformation; stored bytes unchanged |
| Schema breaking change approach | Emit under a new event type or new `version` field; sunset old version | Write an upcaster function; never rewrite stored events |

Apply the correct discipline based on the event's role. Most events in this repo are integration
events and use the additive/breaking strategy below. An Aggregate that adopts Event Sourcing
(see `cqrs-pattern` and `skills/aggregate-design/SKILL.md`) must use upcasting for its internal
event stream.

---

## Integration Event Versioning

### Additive Change (Minor Bump)

An additive change adds a new **optional** field. Existing consumers that do not know about the
field must tolerate it (forward compatibility — ignore unknown fields).

**Before (1.0.0):**
```json
{
  "payload": {
    "dataAssetId": "...",
    "sensitivityLevel": "Restricted",
    "classifiedBy": "engine"
  }
}
```

**After (1.1.0) — new optional `confidence` field added:**
```json
{
  "payload": {
    "dataAssetId": "...",
    "sensitivityLevel": "Restricted",
    "classifiedBy": "engine",
    "confidence": 0.94
  }
}
```

**Consumer obligation for additive changes:**
- Use a deserialisation library configured to ignore unknown fields (`json.Unmarshal` in Go ignores
  unknown JSON keys by default — no change needed).
- Do NOT assert that `confidence` is absent; treat absence as `null`/zero.
- Do NOT upgrade the consumer to require `confidence` until all producers have confirmed v1.1.0 is
  deployed — unknown how long v1.0.0 events remain in the broker.

**Go tolerant reader pattern:**
```go
type DataAssetClassifiedPayload struct {
    DataAssetID      uuid.UUID `json:"dataAssetId"`
    SensitivityLevel string    `json:"sensitivityLevel"`
    ClassifiedBy     string    `json:"classifiedBy"`
    // Optional fields from v1.1.0 — pointer so absence == nil, not zero-value.
    Confidence *float64 `json:"confidence,omitempty"`
}
```

### Breaking Change (Major Bump)

A breaking change renames, removes, or changes the type of an existing field. It produces a new
event version that is incompatible with consumers of the old version.

**Strategy:**
1. Emit both versions from the producer simultaneously: old version (1.0.0) and new version (2.0.0).
2. Announce the sunset date for v1.0.0 to all consumers.
3. Consumers migrate to 2.0.0 before the sunset date.
4. On the sunset date, stop emitting v1.0.0.

**Implementation options:**

Option A — `version` field in the envelope (recommended):
```go
// Producer emits both until sunset.
func (s *ClassificationService) Classify(...) {
    evtV1 := buildV1Event(...)   // version: "1.0.0"
    evtV2 := buildV2Event(...)   // version: "2.0.0"
    _ = s.outbox.WriteAll(ctx, tx, evtV1, evtV2)
}
```

Consumer dispatches on `version`:
```go
switch envelope.Version {
case "1.0.0":
    return h.handleV1(payload)
case "2.0.0":
    return h.handleV2(payload)
default:
    return fmt.Errorf("unrecognised version: %s", envelope.Version)
}
```

Option B — separate event type names:
```
DataAssetClassified        (1.0.0 — old consumers)
DataAssetClassifiedV2      (2.0.0 — new consumers)
```

Use Option B when the semantic meaning of the event has changed substantially, not just the
schema shape. Option A is simpler for pure schema evolution.

### Event Rename

When a Domain Event is renamed (e.g., `DataAssetTagged` → `DataAssetClassified`):

1. Start emitting both names simultaneously.
2. Document the sunset date for the old name.
3. Update the Domain Event Catalog to show both names with a "deprecated as of [date]" note.
4. Consumers subscribe to the new name; migrate before sunset.
5. On sunset, stop emitting the old name.

Never rename an event without a parallel emission period. A consumer that only subscribes to
the old name will silently stop receiving events after the rename with no error.

---

## Event Upcasting (Event-Sourced Aggregates Only)

When an event-sourced Aggregate's stored internal event stream must evolve, the additive/breaking
strategy above does not apply — stored events can never be deleted, reissued, or run in parallel
with v2. The stream is the permanent system of record.

Instead, use **event upcasting**: a versioned, load-time transformation function that converts
an old-shape stored event into the shape the current code expects. The stored bytes are never
rewritten; only the in-memory representation during replay is upgraded.

**When upcasting is needed:**
- A field was renamed in the stored event schema.
- A field was removed and must be synthesised from existing data for backwards compatibility.
- A new required field was added that must be populated from context during replay.

**Go upcaster pattern:**

```go
// internal/domain/events/upcaster.go
package events

import (
    "encoding/json"
    "fmt"
)

// StoredEvent is what the event store row looks like on disk.
type StoredEvent struct {
    EventType string          `json:"eventType"`
    Version   string          `json:"version"`
    Data      json.RawMessage `json:"data"`
}

// Upcast converts a stored event from any historical version to the current version.
// The stored bytes are never modified — this function operates on the in-memory decoded form.
func Upcast(stored StoredEvent) (StoredEvent, error) {
    switch stored.EventType {
    case "DataAssetClassified":
        return upcaseDataAssetClassified(stored)
    default:
        return stored, nil // No upcaster registered — treat as current version.
    }
}

func upcaseDataAssetClassified(stored StoredEvent) (StoredEvent, error) {
    switch stored.Version {
    case "1.0.0":
        // v1.0.0 did not have `storageSourceId` in the payload — synthesise a zero UUID.
        var data map[string]interface{}
        if err := json.Unmarshal(stored.Data, &data); err != nil {
            return stored, fmt.Errorf("upcast v1.0.0: unmarshal: %w", err)
        }
        if _, ok := data["storageSourceId"]; !ok {
            data["storageSourceId"] = "00000000-0000-0000-0000-000000000000"
        }
        updated, _ := json.Marshal(data)
        return StoredEvent{
            EventType: stored.EventType,
            Version:   "1.1.0",
            Data:      updated,
        }, nil
    case "1.1.0":
        return stored, nil // Already current.
    default:
        return stored, fmt.Errorf("unknown version %q for %s", stored.Version, stored.EventType)
    }
}
```

**Upcaster registration:** call `Upcast` in the Aggregate's `Reconstitute` path, before any
`Apply`/`When` method sees the event. Never call it in the `NewAggregate` construction path —
upcasting is only for replaying stored history, not for new events being appended.

**Snapshot cadence:** Once an event-sourced Aggregate's stream grows long enough that replay
time is noticeable (typically 1,000+ events per instance), periodically persist a snapshot of the
Aggregate's current derived state alongside the event stream. The snapshot is never authoritative
— it is a disposable load-time acceleration. Rebuild: if no snapshot exists, replay from the
beginning of the stream. If a snapshot exists, replay only events appended after the snapshot
was taken (identified by the snapshot's `stream_version` field).

---

## Retention Policy — Rationale and Configuration

### Decision Table

| Event category | Redpanda topic retention | Long-term storage | Rationale |
|---|---|---|---|
| Domain Event — audit-required | 90 days | Indefinitely (audit store) | SOC 2, regulatory audit trails require multi-year retention; 90 days on broker covers consumer replay needs |
| Domain Event — non-audit | 30 days | Not required | Sufficient for consumer restart replay; no regulatory obligation |
| Integration Event | Match consumer SLA | Consumer decides | Consumer owns retention requirements for its own contractual obligations |
| Notification Event | 7 days | Not required | Consumers fetch state from Read Model; the notification itself has no long-term value |

**Classification for this product:** All `DataAsset*` events are audit-required. The product is
a data compliance platform — every classification, gap detection, and remediation event is
a potential audit evidence item. Default to 90-day broker / indefinite audit store for all
`DataAsset*`, `ComplianceGap*`, `StorageSource*`, and `AuditRecord*` events.

### Redpanda Topic Configuration

```bash
# Create a topic with 90-day retention (milliseconds).
rpk topic create events.DataAsset \
  --partitions 12 \
  --replicas 3 \
  --topic-config retention.ms=7776000000 \
  --topic-config retention.bytes=-1 \
  --topic-config min.insync.replicas=2
```

**Partition count guidance:**
- 12 partitions as a starting point for `events.DataAsset` (allows up to 12 consumer instances).
- Use `aggregate_id` as the partition key (already done by the relay) — this guarantees
  per-Aggregate ordering across the broker's lifetime.
- Do not reduce partition count after creation — Redpanda requires a new topic for that.

### Archival to the Audit Store

Events classified as audit-required must be written to a long-term audit store (separate from
the Redpanda topic) before or immediately after broker publication.

**Recommended pattern:** A dedicated `audit-archiver` consumer subscribes to all audit-required
event topics and writes rows to a `audit_events` PostgreSQL table (or an S3-compatible object
store for very high volume) with indefinite retention.

```sql
-- In the audit store database (separate schema, read-only for most services)
CREATE TABLE audit_events (
    id              UUID        PRIMARY KEY,             -- Same as eventId
    event_type      TEXT        NOT NULL,
    event_version   TEXT        NOT NULL,
    tenant_id       UUID        NOT NULL,
    aggregate_id    UUID        NOT NULL,
    aggregate_type  TEXT        NOT NULL,
    correlation_id  UUID        NOT NULL,
    occurred_at     TIMESTAMPTZ NOT NULL,
    recorded_at     TIMESTAMPTZ NOT NULL DEFAULT now(),  -- When the archiver wrote this row
    payload         JSONB       NOT NULL
);

CREATE INDEX idx_audit_tenant_type
    ON audit_events (tenant_id, event_type, occurred_at DESC);

CREATE INDEX idx_audit_aggregate
    ON audit_events (aggregate_id, occurred_at ASC);
```

**Archiver idempotency:** The archiver uses `INSERT ... ON CONFLICT (id) DO NOTHING` — if the
same event is received more than once (at-least-once delivery), the duplicate is silently ignored
and the original row is preserved.

---

## Sunset Documentation Template

When retiring an event version, add this block to the Domain Event Catalog entry:

```
Sunset notice:
  Version:        1.0.0
  Sunset date:    2026-10-01
  Migration:      Subscribe to version 2.0.0 — see migration guide below
  Action required: Update consumer to handle the `storageSourceId` field in the payload
  Contact:        domain-modeler@caizin.com for questions
```

Sunset dates must be communicated to consuming team leads at least 30 days in advance and
tracked as items in the Domain Event Catalog. Never let a sunset date pass without verifying
all known consumers have migrated.
