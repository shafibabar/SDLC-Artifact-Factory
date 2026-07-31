---
name: domain-event-catalog
description: >
  Teaches the domain-modeler and backend-engineer how to author, structure,
  and maintain a Domain Event Catalog — the authoritative registry of every
  Domain Event emitted by a Bounded Context, covering event naming conventions,
  the canonical envelope format (what fields every event must carry), the
  Outbox pattern as the reliable emission mechanism, Change Data Capture as
  the Outbox trigger, event versioning strategy, retention policy by event
  class, and the catalog artifact template. Used during Design and Implement
  phases whenever a new Bounded Context or Domain Event is defined.
version: 2.0.0
phase: design
owner: domain-modeler
created: 2026-06-25
tags: ["design","domain-modeling","event-storming","domain-events","outbox","event-naming","cdc"]
related:
  - aggregate-design
  - bounded-context-mapping
  - go-event-publisher
  - cqrs-pattern
  - read-model-design
  - glossary-management
---

# Domain Event Catalog

## Purpose

A Domain Event is something that happened in the domain that is significant to the business — immutable, past-tense, and business-meaningful. Evans identified Domain Events as the escape hatch for Rule 3 (one Aggregate per transaction): an Aggregate emits an event inside its own transaction; everything else updates asynchronously via that event. The Domain Event Catalog is the authoritative, versioned record of every Domain Event in a Bounded Context. Any service integration not governed by this catalog is undocumented coupling.

---

## Event Naming

Events follow the pattern: `[Aggregate][PastTenseVerb]` in PascalCase.

| Good | Poor | Why the poor name fails |
|---|---|---|
| `DataAssetClassified` | `FileUpdated` | Too generic; no business meaning |
| `ComplianceGapDetected` | `GapFound` | No aggregate prefix; imprecise |
| `StorageSourceConnected` | `SourceAdded` | Vague; not Ubiquitous Language |
| `AuditRecordCreated` | `AuditLogged` | Technical verb; domain says "created" |

Rules:
- Past tense — the event records something that already happened
- Name must be meaningful to a domain expert, not just an engineer
- Never use a CRUD verb alone as the full name — `DataAssetRegistered`, not `DataAssetCreated`

---

## Event Categories

Identify the category before defining an event — it determines retention, routing, and versioning discipline.

| Category | Definition | Example | Published externally? |
|---|---|---|---|
| **Domain Event** | A business fact from inside one Bounded Context; notifies consumers across contexts | `DataAssetClassified` | Yes — via Outbox → Redpanda |
| **Integration Event** | A shaped, translated version of a Domain Event for a specific consumer's contract | `ComplianceIntegration.DataAssetClassified.v1` | Yes — shaped per consumer |
| **Notification Event** | A lightweight signal carrying only the Aggregate ID; consumer fetches state via Read Model | `DataAssetUpdated` (ID only) | Yes — coarse-grained fan-out |

Use Domain Events as the default. Use Integration Events when a consuming context needs a stable, separately-versioned schema. Use Notification Events only when consumers will always query the Read Model for details anyway.

> **Internal vs. integration events (Khononov):** An event-sourced Aggregate may maintain internal persistence events used only to reconstruct its own state — these are distinct from the Domain Events published for cross-context integration. Design both lists separately and translate internal events to coarser Domain Events before the Outbox. See `references/versioning-and-retention.md`.

---

## Canonical Envelope

Every Domain Event carries the same envelope regardless of type. Required fields:

| Field | Type | Role |
|---|---|---|
| `eventId` | UUID v4 | Unique event instance ID — consumers use this for idempotency |
| `eventType` | string | PascalCase event name: `DataAssetClassified` |
| `version` | string | Schema version: `1.0.0` |
| `occurredAt` | ISO 8601 | When the fact happened in the domain (not when published) |
| `aggregateId` | UUID | The emitting Aggregate's ID |
| `aggregateType` | string | The emitting Aggregate's type: `DataAsset` |
| `correlationId` | UUID | Traces the full event chain back to the originating Command |
| `causationId` | UUID | ID of the immediate event or Command that directly caused this event |
| `boundedContext` | string | The emitting Bounded Context: `classification-engine` |
| `tenantId` | UUID | Physical multi-tenancy — required in every event for this product |
| `payload` | object | Event-specific data — schema defined per event in the catalog |

For the Go struct definition, CloudEvents alignment, detailed field-by-field explanations, and a worked `DataAssetClassified` example with every field filled: see **`references/event-format.md`**.

---

## Outbox Pattern

Publishing a Domain Event from the request path (dual-write) is an anti-pattern: a crash between the database write and the broker publish loses events or creates phantoms. The Transactional Outbox pattern solves this without a distributed transaction:

1. **Same transaction:** Update the Aggregate's table AND write the event to `outbox_events` — COMMIT. Either both succeed or both fail.
2. **Separate relay process:** Read unpublished rows, publish to Redpanda, mark as published.

Two relay approaches:
- **Polling:** A background goroutine queries `WHERE NOT published ORDER BY created_at` on a schedule. Simple; slight latency.
- **CDC (Change Data Capture):** Debezium captures WAL changes to `outbox_events` and forwards them to Redpanda. Near-real-time; requires Kafka Connect deployment.

Choose polling for simplicity; choose CDC when sub-second latency is required or polling load on the database is unacceptable.

For the full `outbox_events` DDL, Go polling publisher implementation, CDC/Debezium connector configuration, idempotency consumer pattern, and DLQ mechanics: see **`references/outbox-and-cdc.md`**.

---

## Versioning Strategy

Events are immutable facts. Once emitted, they cannot be changed. When the schema must evolve:

| Change type | Strategy | Consumer obligation |
|---|---|---|
| Additive (new optional field) | Minor bump: `1.0.0 → 1.1.0` | Forward-compatible: tolerate unknown fields |
| Breaking (rename, remove, type change) | Major bump: `1.0.0 → 2.0.0` | Run both versions in parallel; old version has documented sunset |
| Event rename | Emit under new name; keep old name through sunset period | Consumers opt into migration explicitly |

> **Event-sourced internal events:** The additive/breaking strategy applies to transient integration events. Permanently-stored internal events (event-sourced Aggregates) require **event upcasting** — a load-time transformation, never parallel emission — because stored events can never be deleted or reissued. See `references/versioning-and-retention.md`.

For migration playbooks, consumer-side tolerant-reader patterns, and upcasting implementation: see **`references/versioning-and-retention.md`**.

---

## Retention Policy

| Event category | Broker retention | Long-term storage |
|---|---|---|
| Domain Event (audit-required) | 90 days | Indefinitely in the audit store |
| Domain Event (non-audit) | 30 days | Not required |
| Integration Event | Match consumer SLA | Consumer decides |
| Notification Event | 7 days | Not required |

Default for this product: all `DataAsset*` events are audit-required — 90 days on Redpanda, indefinitely in the audit store.

---

## Anti-Patterns

| Anti-pattern | Correction |
|---|---|
| **Event as state dump** — full Aggregate state in payload | Carry only the business fact and the fields consumers need to react |
| **Anaemic event** — only an ID in payload | Include the business-meaningful fields of the fact itself |
| **CRUD event name** — `DataAssetUpdated` as the only event | One event per business fact: `DataAssetClassified`, `DataAssetArchived` |
| **Dual write** — request handler publishes directly to broker | All publication goes through the Transactional Outbox |
| **Command disguised as event** — `SendComplianceReport` emitted as event | Name the fact (`ComplianceGapDetected`); a Policy in the consumer issues the Command |
| **Mutating published schema in place** | Additive → minor bump; breaking → new major version run in parallel |
| **Consumer coupling to cross-Aggregate order** | Per-Aggregate order only; use `correlationId`/`causationId` for causal reconstruction |
| **Internal events published as external contracts** | Translate internal persistence events to coarser Domain Events before the Outbox |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Past-tense naming | `[Aggregate][PastTenseVerb]` in PascalCase | Present tense, CRUD-only, or informal names |
| Full envelope | All required envelope fields present | Missing `eventId`, `correlationId`, `tenantId`, or `version` |
| Idempotency key | Every event names the consumer-deduplication field | No idempotency key defined |
| Consumer list | Every event names known consumers | Orphan events with no consumers |
| Versioning strategy | Additive vs. breaking change handling stated | No versioning strategy |
| Outbox only | All publication uses Transactional Outbox | Direct broker publish from request path |
| DLQ defined | Every consumer topic has a DLQ topic | Events silently discarded on failure |

---

## References

- **`references/event-format.md`** — Full envelope specification: Go struct, CloudEvents alignment, field-by-field purpose, worked `DataAssetClassified` example with every field filled
- **`references/outbox-and-cdc.md`** — Outbox DDL, polling publisher (Go), CDC/Debezium configuration, idempotency consumer pattern, DLQ mechanics
- **`references/versioning-and-retention.md`** — Additive versioning worked example, breaking-change migration playbook, event upcasting for event-sourced Aggregates, retention table with rationale, archival mechanics
- **`references/catalog-template.md`** — Fill-in artifact template with worked `DataAssetClassified` entry showing every field
