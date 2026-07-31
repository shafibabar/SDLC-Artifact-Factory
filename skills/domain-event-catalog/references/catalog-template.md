# Domain Event Catalog — Artifact Template

Self-contained fill-in template for a complete Bounded Context's Domain Event Catalog.
Copy this file to the product's artifact directory, fill in every placeholder, and remove
this header block. One catalog file per Bounded Context.

A worked `DataAssetClassified` entry appears at the end of each section as a concrete example.

---

## Artifact Frontmatter

```markdown
---
name: domain-event-catalog
product: [product name — e.g., Data Estate Compliance Platform]
bounded-context: [context name — e.g., Classification Engine]
version: 1.0.0
phase: design
created: [YYYY-MM-DD]
owner: domain-modeler
---
```

**Worked example:**
```markdown
---
name: domain-event-catalog
product: Data Estate Compliance Platform
bounded-context: Classification Engine
version: 1.0.0
phase: design
created: 2026-07-01
owner: domain-modeler
---
```

---

## Part 1 — Event Summary Table

Provides a quick-reference index of all events. One row per event. Add rows as events are defined.

```markdown
# Domain Event Catalog: [Bounded Context Name]

## Event Summary

| Event Name | Aggregate | Version | Consumers | Category | Retention |
|---|---|---|---|---|---|
| [EventName] | [AggregateName] | [SemVer] | [Consumer 1, Consumer 2] | [Domain/Integration/Notification] | [e.g., 90d broker / indefinite audit] |
```

**Worked example:**
```markdown
# Domain Event Catalog: Classification Engine

## Event Summary

| Event Name | Aggregate | Version | Consumers | Category | Retention |
|---|---|---|---|---|---|
| DataAssetClassified | DataAsset | 1.0.0 | Compliance Intelligence, Graph Context | Domain Event | 90d broker / indefinite audit |
| StorageSourceConnected | StorageSource | 1.0.0 | Data Asset Management, Graph Context | Domain Event | 30d broker |
| ClassificationFailed | DataAsset | 1.0.0 | Data Asset Management (retry queue) | Domain Event | 30d broker |
```

---

## Part 2 — Event Definitions

One definition block per event. Every field must be filled. Do not leave placeholders in a
submitted catalog — if a value is genuinely unknown, document the open question in `open_questions`
in `sdlc-context.json`.

```markdown
## Event Definitions

---

### [EventName] v[SemVer]

| Field | Value |
|---|---|
| **Bounded Context** | [Which context emits this event] |
| **Aggregate** | [Which Aggregate Root emits this event] |
| **Trigger** | [The Command or condition that caused this event to be emitted] |
| **Consumers** | [Comma-separated list of Bounded Contexts or services that subscribe] |
| **Category** | [Domain Event / Integration Event / Notification Event] |
| **Retention** | [Broker retention duration] / [Long-term storage policy] |
| **Idempotency Key** | [Field name(s) consumers use to deduplicate — always eventId unless stated] |
| **Policy** | [If this event triggers a Command in a consuming context: "Whenever [Event], [Command]"] |

**Payload:**

| Field | Type | Required | Description and constraints |
|---|---|---|---|
| [fieldName] | [type] | [Yes/No] | [Description — include allowed values, null conditions] |

**Invariants:**
- [A rule that is always true about this event's payload — e.g., "sensitivityLevel is always a valid enum value"]

**Example (JSON envelope + payload):**
```json
{
  "eventId": "[UUID v4]",
  "eventType": "[EventName]",
  "version": "[SemVer]",
  "occurredAt": "[ISO 8601 UTC]",
  "aggregateId": "[UUID]",
  "aggregateType": "[AggregateName]",
  "correlationId": "[UUID]",
  "causationId": "[UUID — same as correlationId if direct result of a Command]",
  "boundedContext": "[kebab-case context name]",
  "tenantId": "[UUID]",
  "payload": {
    "[fieldName]": "[value]"
  }
}
```

[Repeat for each event]
```

---

## Part 2 — Worked Example: DataAssetClassified v1.0.0

```markdown
---

### DataAssetClassified v1.0.0

| Field | Value |
|---|---|
| **Bounded Context** | Classification Engine |
| **Aggregate** | DataAsset |
| **Trigger** | `ClassifyDataAsset` Command accepted by the DataAsset Aggregate |
| **Consumers** | Compliance Intelligence (gap analysis), Graph Context (node labelling) |
| **Category** | Domain Event |
| **Retention** | 90 days broker / indefinitely in audit store |
| **Idempotency Key** | `eventId` |
| **Policy** | Whenever `DataAssetClassified` with `sensitivityLevel = Restricted`, issue `EvaluateComplianceGap` in Compliance Intelligence context |

**Payload:**

| Field | Type | Required | Description and constraints |
|---|---|---|---|
| `dataAssetId` | UUID | Yes | The ID of the classified DataAsset — same as `aggregateId` |
| `storageSourceId` | UUID | Yes | The StorageSource where the asset lives — referenced by ID per Rule 3 |
| `sensitivityLevel` | string | Yes | One of: `Public`, `Internal`, `Confidential`, `Restricted` |
| `previousLevel` | string or null | Yes | The prior SensitivityLevel; `null` on first classification |
| `classifiedBy` | string | Yes | `"engine"` for automated classification; a UUID string for a manual override by a user |
| `confidence` | number or null | Yes | Classification engine confidence score 0.0–1.0; `null` when `classifiedBy` is a user UUID |

**Invariants:**
- `sensitivityLevel` is always one of the four valid SensitivityLevel enum values
- `previousLevel` ≠ `sensitivityLevel` — a reclassification that produces no change emits no event
- `confidence` is `null` if and only if `classifiedBy` is a user UUID (not `"engine"`)

**Example:**
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
```

---

## Part 3 — Outbox Table Definition

One `outbox_events` table per service. Document the DDL here for the Bounded Context's own table.
Use the full DDL from `references/outbox-and-cdc.md` as the starting point.

```markdown
## Outbox Table

```sql
-- [Bounded Context] outbox table.
CREATE TABLE outbox_events (
    id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    aggregate_type   TEXT        NOT NULL,
    aggregate_id     UUID        NOT NULL,
    event_type       TEXT        NOT NULL,
    event_version    TEXT        NOT NULL DEFAULT '1.0.0',
    tenant_id        UUID        NOT NULL,
    correlation_id   UUID        NOT NULL,
    causation_id     UUID        NOT NULL,
    payload          JSONB       NOT NULL,
    published        BOOLEAN     NOT NULL DEFAULT false,
    published_at     TIMESTAMPTZ,
    retry_count      INT         NOT NULL DEFAULT 0,
    last_error       TEXT,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_outbox_unpublished
    ON outbox_events (aggregate_id, created_at)
    WHERE NOT published;
```
```

---

## Part 4 — DLQ Topics

One row per source topic.

```markdown
## DLQ Topics

| Source Topic | DLQ Topic | Max Retry Before DLQ | Alert Threshold | Alert Channel |
|---|---|---|---|---|
| [events.AggregateName] | [events.AggregateName.dlq] | [e.g., 5 attempts] | [e.g., 1 event in DLQ] | [e.g., #ops-alerts Slack] |
```

**Worked example:**
```markdown
## DLQ Topics

| Source Topic | DLQ Topic | Max Retry Before DLQ | Alert Threshold | Alert Channel |
|---|---|---|---|---|
| `events.DataAsset` | `events.DataAsset.dlq` | 5 attempts (relay `retry_count >= 5`) | Any event in DLQ | `#data-platform-alerts` |
| `events.StorageSource` | `events.StorageSource.dlq` | 5 attempts | Any event in DLQ | `#data-platform-alerts` |
```

---

## Part 5 — Versioning Sunset Tracker

Add a row whenever an event version is deprecated. Remove when sunset is confirmed complete.

```markdown
## Versioning Sunset Tracker

| Event Name | Deprecated Version | Sunset Date | Migrating Consumers | Status |
|---|---|---|---|---|
| [EventName] | [e.g., 1.0.0] | [YYYY-MM-DD] | [List of contexts still on old version] | [Announced / In Progress / Complete] |
```

---

## Catalog Checklist

Before submitting this catalog for phase-gate review, confirm every item:

- [ ] Every event name follows `[Aggregate][PastTenseVerb]` in PascalCase
- [ ] Every event has a complete Definition block (all fields filled, no placeholders)
- [ ] Every payload field is typed and documented with constraints
- [ ] Every event names at least one known consumer (no orphan events)
- [ ] Every event has an idempotency key defined
- [ ] Every Domain Event has a retention policy and DLQ topic
- [ ] The `outbox_events` DDL is present for this Bounded Context's service
- [ ] The Event Summary table is up to date with all defined events
- [ ] Any deprecated event versions appear in the Sunset Tracker
