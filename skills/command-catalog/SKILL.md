---
name: command-catalog
description: >
  Teaches the domain-modeler and backend-engineer to define, name, and catalog
  every Command in a Bounded Context — the intent-expressing Write-side inputs
  that trigger state changes in Aggregates. Covers Command naming conventions
  (imperative verb + noun, e.g. ClassifyDataAsset), the Command envelope format
  (fields every command must carry), validation rules (structural vs. business
  rule), the Command-to-Aggregate mapping, command handler responsibilities
  (load aggregate, validate, execute, emit events), and the catalog artifact
  template. Used during Design and Implement whenever a new Aggregate operation
  is defined.
version: 2.0.0
phase: design
owner: domain-modeler
created: 2026-06-25
tags: ["design","domain-modeling","commands","cqrs","aggregates","validation","command-handler"]
related: ["aggregate-design","domain-event-catalog","cqrs-pattern","api-contract-design"]
---

# Command Catalog

## What Is a Command

A Command is an intent-expressing instruction to change state — the Write side of CQRS. Unlike a Domain Event (an immutable record of something that already occurred), a Command may be **rejected**. Commands target exactly one Aggregate and trigger exactly one write operation.

The Command Catalog is the authoritative record of all Commands in a Bounded Context. It defines each Command's name, payload, validation rules, the Aggregate it targets, and the Domain Event emitted on success.

---

## Command vs Domain Event

| | Command | Domain Event |
|---|---|---|
| **Tense** | Imperative present — "Classify this asset" | Past — "DataAssetClassified" |
| **Outcome** | May succeed or fail | Always happened — cannot fail |
| **Direction** | Sent to one target (an Aggregate) | Broadcast to any interested consumers |
| **Rejection** | Can be rejected if invariants fail | Cannot be rejected — it already occurred |
| **Cardinality** | One sender, one receiver | One emitter, many receivers |
| **Example** | `ClassifyDataAsset` | `DataAssetClassified` |

---

## Command Naming

Pattern: `[Verb][Aggregate]` — imperative, present tense, PascalCase.

Rules:
- Use domain verbs, not CRUD verbs — "Classify", not "Update"; "Connect", not "Add"; "Register", not "Create"
- The verb must be the Aggregate Root's action language from the Ubiquitous Language
- The name must be understandable to a domain expert without reading the implementation

| Good command name | Poor command name |
|---|---|
| `ClassifyDataAsset` | `UpdateFile` (CRUD verb; not domain language) |
| `ConnectStorageSource` | `AddSource` (vague; not domain language) |
| `TriggerEstateScan` | `StartScan` (informal) |
| `DetachStorageSource` | `RemoveSource` (vague; "detach" is domain language) |
| `GenerateComplianceReport` | `GetReport` (GET is a read; this is a write triggering generation) |

---

## Command Envelope

Every Command carries six standard fields. These fields are required regardless of the Command's specific payload.

| Field | Type | Purpose |
|---|---|---|
| `commandId` | `uuid.UUID` | Globally unique per invocation; serves as the idempotency key |
| `aggregateId` | `uuid.UUID` | Identity of the Aggregate instance this Command targets |
| `aggregateType` | `string` | Type name of the Aggregate (`DataAsset`, `StorageSource`) |
| `issuedBy` | `uuid.UUID` | Actor identity — the user or service issuing the Command |
| `issuedAt` | `time.Time` | When the Command was issued (UTC) |
| `payload` | struct | The Command-specific fields (sensitivity level, classification reason, etc.) |

Full field-level specification with Go struct layout, worked `ClassifyDataAssetCommand` example, idempotency implementation, and edge cases: `references/command-format.md`.

---

## Validation Hierarchy

Commands are validated in two layers. Both must be defined in the catalog entry.

**Layer 1 — Structural Validation (API handler, before the Aggregate)**
Checks that the payload is well-formed: required fields present, types correct, values in expected ranges. Never touches the database. Applied in the API layer before the Command reaches the Aggregate.

**Layer 2 — Business Rule Validation (inside the Aggregate)**
Checks invariants that require domain state — enforced by the Aggregate Root. May require database access. These checks live on Aggregate methods, not in the handler.

The two layers are intentionally separate. Layer 1 rejects malformed Commands at the boundary. Layer 2 rejects valid-but-domain-violating Commands inside the model. Do not merge them.

Go patterns for each layer, validation error shapes, guard clause idioms, and rejection flows: `references/validation-patterns.md`.

---

## Command Handler Responsibility Chain

A Command handler has exactly five responsibilities, in order:

1. **Deserialize and structurally validate** the incoming request (Layer 1 validation)
2. **Load the Aggregate** from its Repository using `aggregateId`
3. **Pass the Command to the Aggregate** — the Aggregate applies business-rule validation and, if valid, mutates state and emits a Domain Event
4. **Persist the Aggregate** via its Repository (the same transaction writes the Domain Event to the outbox)
5. **Return** the outcome — success with the emitted event ID, or a structured business error

Handlers do not contain business rules. Rules live on the Aggregate Root.

---

## Command-to-Aggregate Mapping

One Command targets exactly one Aggregate type. One Aggregate type has one Repository. This is Vernon's core Aggregate design rule: a single use case should modify exactly one Aggregate instance within one transaction.

The Command Catalog documents this mapping for every Command in the Bounded Context. Mapping table format, how to identify the right Aggregate for a command, the "command storms" anti-pattern, and a worked DataAsset Bounded Context mapping table: `references/command-aggregate-mapping.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Domain verb naming | Command names use domain verbs, not CRUD | Commands named UpdateX, DeleteX, GetX |
| Two-layer validation | Both structural and business-rule validation defined | Only structural validation — no Aggregate-level guards |
| Idempotency key | Every Command carries `commandId` as its idempotency key | Commands with no idempotency strategy |
| One result event | Every Command's success path emits exactly one Domain Event | Commands with no resulting event, or multiple events on one success path |
| Actor identified | Every Command names its Actor (human role or Policy) | Commands with no identified sender |
| Single Aggregate target | Every Command targets exactly one Aggregate type | Commands targeting two or more Aggregates |

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **CRUD-shaped Commands** — `UpdateDataAsset` with a bag of optional fields | One Command hides many intents; guards cannot be stated because the intent is unknown | One Command per business intent: `ClassifyDataAsset`, `ArchiveDataAsset`, each with its own guards |
| **Command targeting two Aggregates** | Requires a cross-Aggregate transaction, violating one-Aggregate-per-transaction | Target one Aggregate; coordinate the second via the emitted Domain Event or a Saga |
| **Guards in the handler instead of the Aggregate** | Business rules escape the domain model; any other caller of the Aggregate skips them | Handlers do structural validation and orchestration only; guards live on the root |
| **Command that returns read data** | Blurs the CQRS split; write path grows read concerns | Return the identifier and status only; clients query the Read Model for state |
| **Fire-and-forget Command with no result path** | The sender cannot distinguish rejection from loss | Commands are point-to-point with synchronous accept/reject; only Domain Events are broadcast |
| **Naming the Domain Event after the Command** — `ClassifyDataAssetEvent` | The event is a fact, not an echo of the request | Past-tense fact naming: `DataAssetClassified` |

---

## References

- `references/command-format.md` — Full Command envelope specification, Go struct layout, worked ClassifyDataAsset example, idempotency implementation with edge cases
- `references/validation-patterns.md` — Structural and business-rule validation in Go, guard clause patterns, error shapes, rejection flows
- `references/command-aggregate-mapping.md` — Command-to-Aggregate mapping table format, Vernon's one-command rule, finding the right Aggregate, worked DataAsset BC mapping
- `references/catalog-template.md` — Complete catalog artifact template with fill-in fields and a worked entry for ClassifyDataAsset
