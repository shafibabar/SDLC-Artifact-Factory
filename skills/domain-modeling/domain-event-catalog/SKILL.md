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
version: 1.0.0
phase: design
owner: domain-modeler
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

---

## Dead Letter Queue

When a consumer cannot process an event after exhausting retries, the event is moved to the Dead Letter Queue (DLQ):

- DLQ is a separate Redpanda topic: `[original-topic].dlq`
- Every event in the DLQ must be monitored and alerted on
- Events in the DLQ must not be silently discarded — they represent processing failures that require investigation
- Reprocessing from the DLQ must be a safe, monitored operation

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Past-tense naming | All events use `[Aggregate][PastTenseVerb]` in PascalCase | Events in present tense, CRUD-only names, or informal names |
| Standard envelope | All events include the standard envelope fields | Events missing `eventId`, `correlationId`, `tenantId`, or `version` |
| Idempotency key defined | Every event names the field(s) consumers use to deduplicate | Events with no idempotency key — consumers cannot be idempotent |
| Consumer list | Every event lists its known consumers | Events with no consumer documentation — orphan events |
| Versioning strategy | Additive vs breaking change handling is defined | Events with no versioning strategy |
| Transactional Outbox | All event publication uses the Outbox pattern | Events published directly from the request path (dual-write anti-pattern) |
| DLQ defined | Every consumer topic has a corresponding DLQ topic | Events that are silently discarded on consumer failure |

---

## Output Format

```markdown
---
artifact: domain-event-catalog
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
