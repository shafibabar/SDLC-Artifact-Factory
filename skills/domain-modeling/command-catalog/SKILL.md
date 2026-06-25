---
name: command-catalog
description: >
  Teaches how to define and catalogue Commands in a DDD Bounded Context —
  covering the command definition format, naming conventions, validation rules,
  the distinction between a Command and a Domain Event, idempotency design for
  Commands, and how Commands translate to Go handler signatures and API endpoints.
  The Command Catalog is the authoritative record of all write operations in a
  Bounded Context. Used by the domain-modeler agent after Event Storming and
  Aggregate design.
version: 1.0.0
phase: design
owner: domain-modeler
tags: [design, ddd, commands, cqrs, write-model, idempotency, go]
---

# Command Catalog

## Purpose

A Command is an instruction to the system — a request to change state. Commands are the write side of CQRS. They differ from Domain Events in one critical way: a Command may be rejected. A Domain Event is a fact that has already occurred and cannot be undone (only compensated).

The Command Catalog is the authoritative record of all Commands in a Bounded Context. It defines what each Command means, what data it carries, which Aggregate handles it, what invariants are checked, and what Domain Event is emitted on success.

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

Commands follow the pattern: `[Verb][Aggregate]` — imperative, present tense, PascalCase.

| Good command name | Poor command name |
|---|---|
| `ClassifyDataAsset` | `UpdateFile` (CRUD verb; not domain language) |
| `ConnectStorageSource` | `AddSource` (vague; not domain language) |
| `TriggerEstatesScan` | `StartScan` (informal) |
| `DetachStorageSource` | `RemoveSource` (vague; "detach" is domain language for this context) |
| `GenerateComplianceReport` | `GetReport` (GET is a read; this is a write that triggers generation) |

Rules:
- Use domain verbs, not CRUD verbs — "Classify", not "Update"; "Connect", not "Add"; "Register", not "Create"
- The verb must be the Aggregate Root's action language
- The name must be understandable to a domain expert

---

## Command Definition Format

```
Command:         [CommandName]
Bounded Context: [Which context this Command belongs to]
Aggregate:       [Which Aggregate handles this Command]
Actor:           [Who or what issues this Command — human role or Policy]

Description:     [What this Command does in business terms]

Validation:
  - [Field-level validation rule — applied before the Command reaches the Aggregate]
  - [...]

Guard (Aggregate-level):
  - [Invariant check inside the Aggregate — can reject the Command]

Idempotency:     [How this Command is made safe to retry — which field is the idempotency key]

On Success:      [Domain Event emitted]
On Failure:      [Error type returned — business error, not a system error]

Payload:
  [field name]: [type] [required/optional] — [description and constraints]
```

---

## Command Validation Layers

Commands are validated in two layers. Both must be defined:

### Layer 1: Structural Validation (before the Aggregate)

Checks that the Command payload is well-formed — required fields are present, types are correct, values are within expected ranges. This is the API handler's responsibility. These checks never touch the database.

```go
func (c ClassifyDataAsset) Validate() error {
    if c.DataAssetID == uuid.Nil {
        return validation.Error("dataAssetId", "required")
    }
    if !c.SensitivityLevel.IsValid() {
        return validation.Error("sensitivityLevel", "must be one of: Public, Internal, Confidential, Restricted")
    }
    return nil
}
```

### Layer 2: Business Rule Validation (inside the Aggregate)

Checks invariants that require domain state — enforced by the Aggregate Root. These checks may require reading from the database.

```go
func (a *DataAsset) Classify(cmd ClassifyDataAsset) error {
    if a.IsArchived() {
        return ErrCannotClassifyArchivedAsset
    }
    if a.storageSourceID != cmd.StorageSourceID {
        return ErrDataAssetStorageSourceMismatch
    }
    // ... apply change and emit event
}
```

The two layers are intentionally separate. Layer 1 rejects malformed Commands at the boundary. Layer 2 rejects valid but business-rule-violating Commands inside the domain model. Do not merge them.

---

## Command Idempotency

Commands issued over a network may be retried (network timeout, client retry). A Command handler that is not idempotent will apply the same change twice on retry, corrupting state or double-emitting events.

Every Command must have an idempotency key — a field in the payload that uniquely identifies this Command invocation. If the same Command is received twice with the same idempotency key, the second invocation must be a no-op that returns the same result as the first.

**Implementation pattern:**

```go
// idempotency table
CREATE TABLE command_log (
    idempotency_key UUID PRIMARY KEY,
    command_type    TEXT NOT NULL,
    result          JSONB,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

// handler checks idempotency before processing
func (h *ClassifyDataAssetHandler) Handle(ctx context.Context, cmd ClassifyDataAsset) error {
    existing, err := h.commandLog.Find(ctx, cmd.IdempotencyKey)
    if err == nil && existing != nil {
        return nil // already processed — return success without re-applying
    }
    // ... process command
    // ... record result in command_log
}
```

---

## Commands and API Endpoints

Each Command maps to exactly one API endpoint in the service's API contract. The endpoint is always a state-changing HTTP method (POST, PUT, PATCH, DELETE) — never GET.

| Command | HTTP method | Path pattern |
|---|---|---|
| `ClassifyDataAsset` | PATCH | `/v1/data-assets/{id}/classification` |
| `ConnectStorageSource` | POST | `/v1/storage-sources` |
| `TriggerEstateScan` | POST | `/v1/storage-sources/{id}/scans` |
| `DetachStorageSource` | DELETE | `/v1/storage-sources/{id}` |

The mapping is documented in the Command Catalog and used as the authoritative input to the API contract design (`api-contract-design` skill in the architecture domain).

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Domain verb naming | Command names use domain verbs, not CRUD | Commands named UpdateX, DeleteX, GetX |
| Two-layer validation | Both structural and business-rule validation defined | Only structural validation — no Aggregate-level guards |
| Idempotency key | Every Command names its idempotency key field | Commands with no idempotency strategy |
| One result event | Every Command's success path emits exactly one Domain Event | Commands with no resulting event, or multiple events on a single success path |
| Actor identified | Every Command names its Actor (human role or Policy) | Commands with no identified sender |
| API mapping | Every Command maps to an HTTP endpoint | Commands with no API mapping documentation |

---

## Output Format

```markdown
---
artifact: command-catalog
product: [product name]
bounded-context: [context name]
version: 1.0.0
phase: design
created: [date]
owner: domain-modeler
---

# Command Catalog: [Bounded Context Name]

## Command Summary

| Command | Aggregate | Actor | Success Event | API Endpoint |
|---|---|---|---|---|

---

## Command Definitions

### [CommandName]

| Field | Value |
|---|---|
| **Aggregate** | |
| **Actor** | |
| **Description** | |
| **Idempotency Key** | |
| **On Success** | |
| **On Failure** | |

**Payload:**
| Field | Type | Required | Constraints |
|---|---|---|---|

**Structural Validation:**
- [Validation rule]

**Aggregate Guards:**
- [Invariant that can reject this Command]

**API Mapping:**
`[HTTP METHOD] [path]`

```go
type [CommandName] struct { ... }
func (c [CommandName]) Validate() error { ... }
```

[Repeat for each Command]
```
