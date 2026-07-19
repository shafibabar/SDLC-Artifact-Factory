---
name: domain-event-catalog
description: >
  Teaches how to define, catalogue, and govern Domain Events — including the
  event definition format, naming conventions, event schema design, versioning
  strategy, retention policy, and the Transactional Outbox pattern for reliable
  event publication. The domain-event-catalog is the authoritative record of all
  events in a Bounded Context and the primary contract between services in an
  event-driven architecture. Used by the domain-modeler agent after Event
  Storming, as a prerequisite to service design.
version: 1.1.0
phase: design
owner: domain-modeler
created: 2026-06-25
tags: [design, ddd, domain-events, event-catalog, event-driven, transactional-outbox]
---

# Domain Event Catalog

## Purpose

A Domain Event is something that happened in the domain that is significant to the business. It is a fact — immutable, past-tense, and business-meaningful. Domain Events are the communication medium of an event-driven architecture: they carry information across Bounded Context boundaries without direct coupling.

The Domain Event Catalog is the authoritative, versioned record of every Domain Event in a Bounded Context. It defines what each event means, what data it carries, who emits it, who consumes it, and how it must be handled. Any service integration that is not governed by this catalog is undocumented coupling.

---

## Domain Event Naming

Events follow the pattern: `[Aggregate][PastTenseVerb]`

| Good event name | Poor event name |
|---|---|
| `DataAssetClassified` | `FileUpdated` (too generic; not business-meaningful) |
| `ComplianceGapDetected` | `GapFound` (imprecise; which gap? in what context?) |
| `StorageSourceConnected` | `SourceAdded` (vague; doesn't name the concept) |
| `ScanCompleted` | `ScanDone` (informal; doesn't use Ubiquitous Language) |
| `AuditRecordCreated` | `AuditLogged` (verb "logged" is technical; "created" is domain) |

Rules:
- Use PascalCase
- Use past tense — the event records something that has already happened
- The name must be meaningful to a domain expert, not just an engineer
- Never use CRUD verbs directly ("Created", "Updated", "Deleted") as the entire name — they describe technical operations, not business events. Use them only as the verb component after a meaningful noun: `DataAssetRegistered`, not `FileCreated`

---

## Domain Event Definition Format

Every event in the catalog must have a complete definition:

```
Event:           [EventName]
Bounded Context: [Which context emits this event]
Aggregate:       [Which Aggregate emits this event]
Version:         [SemVer — 1.0.0]

Description:     [What happened in business terms — one or two sentences]

Trigger:         [What Command or condition caused this event to be emitted]
Consumers:       [Which Bounded Contexts or services consume this event]
Retention:       [How long this event must be retained in the message broker]
Idempotency Key: [Which field(s) uniquely identify this event so consumers can deduplicate]

Payload:
  [field name]: [type] — [description and constraints]
  [field name]: [type] — [description and constraints]

Invariants:
  - [Rule that is always true about this event's payload]

Policy (if any): [If this event automatically triggers a Command: "Whenever [Event], [Command]"]

Example:
{
  "eventId": "uuid",
  "eventType": "[EventName]",
  "version": "1.0.0",
  "occurredAt": "ISO8601 timestamp",
  "aggregateId": "uuid",
  "payload": { ... }
}
```

---

## Standard Event Envelope

All Domain Events share a common envelope — fields that appear in every event regardless of type:

| Field | Type | Description |
|---|---|---|
| `eventId` | UUID v4 | Unique identifier for this event instance — used for idempotency |
| `eventType` | string | The event name: `DataAssetClassified` |
| `version` | string | Schema version: `1.0.0` |
| `occurredAt` | ISO 8601 | When the event occurred in the domain (not when it was published) |
| `aggregateId` | UUID | The ID of the Aggregate that emitted the event |
| `aggregateType` | string | The Aggregate name: `DataAsset` |
| `correlationId` | UUID | Traces the chain of events back to the original Command |
| `causationId` | UUID | The ID of the event or Command that directly caused this event |
| `boundedContext` | string | The Bounded Context that emitted this event |
| `tenantId` | UUID | For multi-tenant systems — which tenant this event belongs to |
| `payload` | object | Event-specific data — defined per event |

The `tenantId` is mandatory in all events for the first product due to physical multi-tenancy requirements.

---

## Event Versioning

Events are immutable facts. Once emitted, they cannot be changed. When the schema must evolve:

| Change type | Strategy |
|---|---|
| **Additive change** (new optional field) | Bump minor version: `1.0.0` → `1.1.0`. Existing consumers must tolerate unknown fields (forward compatibility). |
| **Breaking change** (rename, remove, or change type of a field) | Bump major version: `1.0.0` → `2.0.0`. Run both versions in parallel during migration. Never delete `v1` until all consumers have migrated. |
| **Rename an event** | Emit under the new name; keep emitting under the old name for a defined sunset period. Document the sunset date. |

**Consumer responsibilities:**
- Consumers must be forward-compatible: they must handle fields they don't know about (ignore them, do not reject)
- Consumers must be backward-compatible for minor version bumps
- Consumers must explicitly opt into major version migration

---

## Transactional Outbox Pattern

Publishing a Domain Event and updating the database in the same transaction would require a distributed transaction — which is fragile and expensive. The Transactional Outbox pattern solves this without a distributed transaction:

```
┌──────────────────────────────────────────────────────────┐
│ Application Transaction (single DB transaction)           │
│                                                          │
│  1. Update Aggregate state in aggregate table            │
│  2. Write Domain Event to outbox table (same DB)         │
│                                                          │
│  COMMIT — either both succeed or both fail               │
└──────────────────────────────────────────────────────────┘
          │
          │ (separate process — not in the transaction)
          ▼
┌──────────────────────────────────────────────────────────┐
│ Outbox Relay (polling or CDC)                            │
│                                                          │
│  3. Read unpublished rows from outbox table              │
│  4. Publish to Redpanda                                  │
│  5. Mark row as published (or delete)                    │
└──────────────────────────────────────────────────────────┘
```

**Outbox table schema (Go/PostgreSQL):**
```sql
CREATE TABLE outbox_events (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type  TEXT NOT NULL,
    aggregate_id UUID NOT NULL,
    payload     JSONB NOT NULL,
    published   BOOLEAN NOT NULL DEFAULT false,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX ON outbox_events (published, created_at) WHERE NOT published;
```

**Rules:**
- The outbox table is always in the same database as the Aggregate table
- The outbox relay runs as a separate process — it is not part of the request path
- If the relay fails, events remain in the outbox until the relay recovers (at-least-once delivery)
- Consumers must be idempotent — they may receive the same event more than once
- The relay publishes with `aggregate_id` as the Redpanda partition key and reads rows in `created_at` order — this preserves per-Aggregate event ordering, which consumers may rely on; cross-Aggregate ordering is never guaranteed and consumers must not depend on it

---

## Dead Letter Queue

When a consumer cannot process an event after exhausting retries, the event is moved to the Dead Letter Queue (DLQ):

- DLQ is a separate Redpanda topic: `[original-topic].dlq`
- Every event in the DLQ must be monitored and alerted on
- Events in the DLQ must not be silently discarded — they represent processing failures that require investigation
- Reprocessing from the DLQ must be a safe, monitored operation
- **Ordering caveat:** parking an event in the DLQ lets later events for the same Aggregate be processed first. A consumer whose logic depends on per-Aggregate ordering must either halt that partition until the poison event is resolved, or be designed to reconcile out-of-order redelivery when the DLQ event is replayed. Choose per consumer and record the choice in the catalog.

---

## Worked Example

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
  storageSourceId:  UUID           — where the asset lives (reference by ID)
  sensitivityLevel: string         — one of: Public, Internal, Confidential, Restricted
  previousLevel:    string|null    — null on first classification
  classifiedBy:     string         — "engine" or a user ID for manual override
  confidence:       number|null    — engine confidence 0.0–1.0; null for manual override

Invariants:
  - sensitivityLevel is always a valid SensitivityLevel value
  - previousLevel ≠ sensitivityLevel (a no-op reclassification emits no event)
  - confidence is null if and only if classifiedBy is a user ID

Policy:          Whenever DataAssetClassified with sensitivityLevel = Restricted,
                 EvaluateComplianceGap (Compliance Intelligence context)
```

```json
{
  "eventId": "8f14e45f-ceea-467f-a0e6-b2d9b3b0a1c2",
  "eventType": "DataAssetClassified",
  "version": "1.0.0",
  "occurredAt": "2026-07-01T14:32:09Z",
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

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Past-tense naming | All events use `[Aggregate][PastTenseVerb]` in PascalCase | Events in present tense, CRUD-only names, or informal names |
| Standard envelope | All events include the standard envelope fields | Events missing `eventId`, `correlationId`, `tenantId`, or `version` |
| Idempotency key defined | Every event names the field(s) consumers use to deduplicate | Events with no idempotency key — consumers cannot be idempotent |
| Consumer list | Every event lists its known consumers | Events with no consumer documentation — orphan events |
| Versioning strategy | Additive vs breaking change handling is defined | Events with no versioning strategy |
| Transactional Outbox | All event publication uses the Transactional Outbox | Events published directly from the request path (dual-write anti-pattern) |
| DLQ defined | Every consumer topic has a corresponding DLQ topic | Events that are silently discarded on consumer failure |

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Event as state dump** — the payload carries the Aggregate's entire current state | Consumers couple to the full write model; every internal field change is a schema change | Carry the fact and the fields consumers need to react; consumers query a Read Model for anything more |
| **Anaemic event** — payload is only an ID, forcing every consumer to call back | Turns event-driven integration into hidden synchronous coupling; the emitter's availability gates every consumer | Include the business-meaningful fields of the fact itself (what changed, from what, by whom) |
| **CRUD event names** — `DataAssetUpdated` as the only event | The business meaning is erased; consumers must diff payloads to guess what happened | One event per business fact: `DataAssetClassified`, `DataAssetArchived`, each with precise triggers |
| **Mutating a published schema in place** — editing v1 instead of versioning | Deployed consumers break without warning; the immutable-fact contract is violated | Additive change → minor bump with tolerant readers; breaking change → new major version run in parallel |
| **Dual write** — request handler writes the database and publishes to the broker directly | A crash between the two writes loses events or publishes phantom ones | All publication goes through the Transactional Outbox |
| **Commands disguised as events** — `SendComplianceReport` published as an "event" | An instruction broadcast to many consumers has no single accountable handler and cannot be rejected | Name the fact (`ComplianceGapDetected`) and let a Policy in the consuming context issue the Command |
| **Consumer coupling to cross-Aggregate order** | Only per-Aggregate order is guaranteed by the partition key; cross-partition order is an accident of timing | Design consumers around per-Aggregate ordering plus `correlationId`/`causationId` for causal reconstruction |

---

## Output Format

```markdown
---
name: domain-event-catalog
product: [product name]
bounded-context: [context name]
version: 1.0.0
phase: design
created: [date]
owner: domain-modeler
---

# Domain Event Catalog: [Bounded Context Name]

## Event Summary

| Event Name | Aggregate | Version | Consumers | Retention |
|---|---|---|---|---|

---

## Event Definitions

### [EventName] v1.0.0

| Field | Value |
|---|---|
| **Bounded Context** | |
| **Aggregate** | |
| **Trigger** | |
| **Consumers** | |
| **Retention** | |
| **Idempotency Key** | |
| **Policy** | |

**Payload:**
| Field | Type | Required | Description |
|---|---|---|---|

**Invariants:**
- [Rule always true about this event]

**Example:**
```json
{ ... }
```

[Repeat for each event]

---

## Outbox Table Definition
[SQL CREATE TABLE statement for this context's outbox_events table]

## DLQ Topics
| Source Topic | DLQ Topic | Alert Threshold |
|---|---|---|
```
