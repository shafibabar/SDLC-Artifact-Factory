# Domain Event Envelope — Full Specification

Self-contained reference for the canonical envelope every Domain Event must carry.
Read this when authoring a new event definition, implementing the publisher struct in Go,
or verifying CloudEvents header alignment.

---

## Field-by-Field Specification

| Field | Type | Required | Description |
|---|---|---|---|
| `eventId` | UUID v4 | Yes | Globally unique identifier for this event *instance*. Two events that represent the same business fact at different times have different `eventId` values. Consumers use `eventId` as the idempotency key — deduplicate on this value before processing. |
| `eventType` | string | Yes | PascalCase name of the event: `DataAssetClassified`. Never abbreviated. The full name is the stable identity of the event schema — consumers bind to this string. |
| `version` | string | Yes | SemVer schema version: `1.0.0`. Consumers must check this field when handling multiple versions of the same event type. See `versioning-and-retention.md` for the full version-evolution discipline. |
| `occurredAt` | ISO 8601 UTC | Yes | The instant the domain fact happened, from the Aggregate's perspective, **not** when the event reached the broker. For a classification triggered at 14:32:09 UTC, `occurredAt` is that moment regardless of network or relay latency. Always UTC; always include milliseconds. |
| `aggregateId` | UUID | Yes | The ID of the Aggregate Root that emitted this event. This is the Aggregate's own client-generated UUID (Vernon: prefer client-generated identity so the Aggregate is fully valid — ID included — before any persistence I/O). |
| `aggregateType` | string | Yes | The Aggregate Root's type name: `DataAsset`, `StorageSource`, `AuditRecord`. Enables consumers to route events without inspecting the payload and allows multi-aggregate outbox tables to be filtered correctly. |
| `correlationId` | UUID | Yes | Traces the entire causal chain back to the originating user Command. Every event in a saga or policy chain shares the same `correlationId`. Use this to reconstruct the full end-to-end flow in logs and traces. Set it from the inbound HTTP `X-Correlation-Id` header or from the Command that started the operation; propagate it unchanged through every downstream event. |
| `causationId` | UUID | Yes | The ID of the **immediate** predecessor that caused this specific event — either the Command ID (if this event is the direct result of a user command) or the `eventId` of the event that triggered a Policy which issued the Command that produced this event. Unlike `correlationId`, `causationId` changes at each step in a chain: `Command A → causationId=A, correlationId=A`; `Event B (caused by A) → causationId=A, correlationId=A`; `Event C (caused by B via Policy) → causationId=B's eventId, correlationId=A`. This allows consumers to reconstruct a precise cause-effect graph, not just a flat audit trail. |
| `boundedContext` | string | Yes | Kebab-case name of the emitting Bounded Context: `classification-engine`, `data-asset-management`, `compliance-intelligence`. Consumers use this to implement Anti-Corruption Layer translation when needed. |
| `tenantId` | UUID | Yes | The tenant that owns the data in this event. Mandatory for this product's physical multi-tenancy model — every consumer must verify `tenantId` matches its own operational context before processing. Never process an event whose `tenantId` does not match the consumer's authorised tenant set. |
| `payload` | object | Yes | Event-specific data. Schema is defined per event type in the catalog. The payload carries the business-meaningful fields of the fact itself — not a full state dump, not a bare ID. Shape the payload around what consumers need to react without making a synchronous call back to the emitting context. |

---

## Go Struct Definition

```go
// package events — lives in internal/domain/events/ of the emitting service.
// This envelope is embedded by every concrete Domain Event type.

package events

import (
    "time"

    "github.com/google/uuid"
)

// Envelope is the standard header carried by every Domain Event.
// Concrete event types embed this struct and add their own Payload.
type Envelope struct {
    EventID        uuid.UUID `json:"eventId"`
    EventType      string    `json:"eventType"`
    Version        string    `json:"version"`
    OccurredAt     time.Time `json:"occurredAt"`
    AggregateID    uuid.UUID `json:"aggregateId"`
    AggregateType  string    `json:"aggregateType"`
    CorrelationID  uuid.UUID `json:"correlationId"`
    CausationID    uuid.UUID `json:"causationId"`
    BoundedContext string    `json:"boundedContext"`
    TenantID       uuid.UUID `json:"tenantId"`
}

// DataAssetClassified is a concrete Domain Event.
// The Payload struct carries only the classification fact.
type DataAssetClassified struct {
    Envelope
    Payload DataAssetClassifiedPayload `json:"payload"`
}

// DataAssetClassifiedPayload carries the business-meaningful fields of the classification fact.
type DataAssetClassifiedPayload struct {
    DataAssetID      uuid.UUID `json:"dataAssetId"`
    StorageSourceID  uuid.UUID `json:"storageSourceId"`
    SensitivityLevel string    `json:"sensitivityLevel"` // Public | Internal | Confidential | Restricted
    PreviousLevel    *string   `json:"previousLevel"`    // null on first classification
    ClassifiedBy     string    `json:"classifiedBy"`     // "engine" or a user UUID
    Confidence       *float64  `json:"confidence"`       // 0.0–1.0; null for manual override
}

// NewDataAssetClassified constructs the event from Aggregate state.
// The Aggregate calls this inside its Classify method, before writing to the outbox.
func NewDataAssetClassified(
    correlationID, causationID, tenantID, aggregateID, storageSourceID uuid.UUID,
    sensitivity, previous *string,
    classifiedBy string,
    confidence *float64,
) DataAssetClassified {
    return DataAssetClassified{
        Envelope: Envelope{
            EventID:        uuid.New(),
            EventType:      "DataAssetClassified",
            Version:        "1.0.0",
            OccurredAt:     time.Now().UTC(),
            AggregateID:    aggregateID,
            AggregateType:  "DataAsset",
            CorrelationID:  correlationID,
            CausationID:    causationID,
            BoundedContext: "classification-engine",
            TenantID:       tenantID,
        },
        Payload: DataAssetClassifiedPayload{
            DataAssetID:      aggregateID,
            StorageSourceID:  storageSourceID,
            SensitivityLevel: *sensitivity,
            PreviousLevel:    previous,
            ClassifiedBy:     classifiedBy,
            Confidence:       confidence,
        },
    }
}
```

---

## CloudEvents Alignment

This repo's envelope is not a formal CloudEvents implementation, but maps cleanly to the CloudEvents 1.0 specification for interoperability with Knative, Dapr, or any CloudEvents-compatible broker:

| Envelope field | CloudEvents attribute | Notes |
|---|---|---|
| `eventId` | `id` | 1:1 — both are globally unique per event instance |
| `eventType` | `type` | CloudEvents recommends reverse-DNS prefix; use `com.caizin.classification-engine.DataAssetClassified` for external publication |
| `version` | `dataschema` (URI) | Point to the schema registry URI for the version: `https://schemas.caizin.com/events/DataAssetClassified/1.0.0` |
| `occurredAt` | `time` | 1:1 — both are RFC 3339 UTC timestamps |
| `aggregateId` | `subject` | The subject of the event; 1:1 for single-Aggregate events |
| `boundedContext` | `source` | CloudEvents uses a URI: `https://caizin.com/classification-engine` |
| `correlationId` | Extension attribute `correlationid` | Not in the core spec; set as a CloudEvents extension attribute |
| `causationId` | Extension attribute `causationid` | Not in the core spec; set as a CloudEvents extension attribute |
| `tenantId` | Extension attribute `tenantid` | Not in the core spec; required for multi-tenant routing |

When publishing to Redpanda with a CloudEvents-aware consumer, set the `ce-specversion: 1.0` header and map envelope fields to their CloudEvents counterparts above.

---

## Worked Example — DataAssetClassified

A fully filled event showing every envelope field and payload field:

```json
{
  "eventId": "8f14e45f-ceea-467f-a0e6-b2d9b3b0a1c2",
  "eventType": "DataAssetClassified",
  "version": "1.0.0",
  "occurredAt": "2026-07-01T14:32:09.412Z",
  "aggregateId": "3c9909af-9d2a-4c9c-8b1a-6e2f1a7d4e88",
  "aggregateType": "DataAsset",
  "correlationId": "a1b2c3d4-0000-4000-8000-000000000001",
  "causationId": "a1b2c3d4-0000-4000-8000-000000000001",
  "boundedContext": "classification-engine",
  "tenantId": "b7e23ec2-9d0a-4f5b-9c3d-2f8e6a1b4c7d",
  "payload": {
    "dataAssetId": "3c9909af-9d2a-4c9c-8b1a-6e2f1a7d4e88",
    "storageSourceId": "5d2c1f0e-7a8b-4c3d-9e0f-1a2b3c4d5e6f",
    "sensitivityLevel": "Restricted",
    "previousLevel": "Internal",
    "classifiedBy": "engine",
    "confidence": 0.94
  }
}
```

**Reading this example:**
- `correlationId` equals `causationId` here — the event is the direct result of a user Command; no intermediate Policy chain occurred.
- In a Policy chain (e.g., `DataAssetClassified` → Policy: `EvaluateComplianceGap` → `ComplianceGapDetected`), the downstream `ComplianceGapDetected` event would have `causationId = "8f14e45f-ceea-..."` (the `eventId` of `DataAssetClassified`) and `correlationId = "a1b2c3d4-..."` (the original Command's ID, unchanged).
- `previousLevel = "Internal"` is non-null — this is a re-classification, not a first classification.

---

## Per-Event Definition Block

Every event in the catalog must carry this structured definition in addition to the envelope schema:

```
Event:           DataAssetClassified
Bounded Context: Classification Engine
Aggregate:       DataAsset
Version:         1.0.0

Description:     A DataAsset has been assigned a SensitivityLevel, either by the
                 classification engine or by a human override.

Trigger:         ClassifyDataAsset Command accepted by the DataAsset Aggregate
Consumers:       Compliance Intelligence (gap analysis), Graph Context (node labelling)
Retention:       90 days on the broker; indefinitely in the audit store
Idempotency Key: eventId

Payload:
  dataAssetId:      UUID           — the classified asset
  storageSourceId:  UUID           — where the asset lives (reference by ID per Vernon Rule 3)
  sensitivityLevel: string         — one of: Public, Internal, Confidential, Restricted
  previousLevel:    string|null    — null on first classification
  classifiedBy:     string         — "engine" or a user UUID for manual override
  confidence:       number|null    — engine confidence 0.0–1.0; null for manual override

Invariants:
  - sensitivityLevel is always a valid SensitivityLevel value from the enum
  - previousLevel ≠ sensitivityLevel (a no-op reclassification emits no event)
  - confidence is null if and only if classifiedBy is a user UUID (not "engine")

Policy (if any): Whenever DataAssetClassified with sensitivityLevel = Restricted,
                 EvaluateComplianceGap (Compliance Intelligence context)
```

See `catalog-template.md` for the complete fill-in artifact template for an entire Bounded Context's catalog.
