# Command Catalog Artifact Template

Self-contained reference with the complete fill-in artifact template and a worked
entry for `ClassifyDataAsset` from the DataAsset Management Bounded Context.
Copy the template into the product's design artifacts directory and fill in one
entry per Command. Read alongside `SKILL.md`.

---

## Complete Catalog Artifact Template

```markdown
---
name: command-catalog
product: [product name]
bounded-context: [context name]
version: 1.0.0
phase: design
created: [YYYY-MM-DD]
owner: domain-modeler
---

# Command Catalog: [Bounded Context Name]

## Command Summary

| Command | Aggregate Type | Actor | Success Event | API Endpoint |
|---|---|---|---|---|
| [CommandName] | [AggregateType] | [Actor] | [EventName] | `[HTTP METHOD] [path]` |

---

## Command Definitions

### [CommandName]

**Overview**

| Field | Value |
|---|---|
| **Bounded Context** | [Which context this Command belongs to] |
| **Aggregate Type** | [Which Aggregate Root handles this Command] |
| **Aggregate Method** | `([AggregateReceiver] *[AggregateType]) [MethodName](cmd [CommandName]) error` |
| **Actor** | [Human role or automated policy that issues this Command] |
| **Description** | [What this Command does in business terms — one or two sentences from the Ubiquitous Language] |
| **Idempotency Key** | `commandId` — client-generated UUID per invocation |
| **On Success** | `[EventName]` Domain Event emitted |
| **On Failure** | `[ErrName]` (business) or `ValidationError{...}` (structural) |

---

**Command Envelope**

| Field | Go type | Required | Source |
|---|---|---|---|
| `CommandID` | `uuid.UUID` | Yes | Client-generated per invocation |
| `AggregateID` | `uuid.UUID` | Yes | URL path parameter |
| `AggregateType` | `string` | Yes | Hard-coded in handler: `"[AggregateType]"` |
| `IssuedBy` | `uuid.UUID` | Yes | Authenticated session context (UserID) |
| `IssuedAt` | `time.Time` | Yes | API handler: `time.Now().UTC()` |
| `TenantID` | `uuid.UUID` | Yes | Authenticated session context (TenantID) |

---

**Domain Payload**

| Field | Go type | Required | Constraints |
|---|---|---|---|
| [fieldName] | [type] | [Yes/No] | [Constraint description] |

---

**Structural Validation (Layer 1 — API Handler)**

- [ ] `commandId` is a non-nil UUID
- [ ] `aggregateId` is a non-nil UUID
- [ ] `issuedBy` is a non-nil UUID
- [ ] `tenantId` is a non-nil UUID
- [ ] [Domain field]: [specific constraint]
- [ ] [Domain field]: [specific constraint]

---

**Business Rule Guards (Layer 2 — Aggregate)**

- [ ] [Invariant that can reject this Command — stated in Ubiquitous Language]
- [ ] [Additional invariant]

---

**Go Struct**

\`\`\`go
type [CommandName] struct {
    commands.BaseCommand

    // Domain payload
    [FieldName] [GoType] `json:"[jsonName]" validate:"[tags]"`
}
\`\`\`

---

**API Mapping**

\`\`\`
[HTTP METHOD] /v1/[resource-path]
\`\`\`

Response on success: `202 Accepted`
\`\`\`json
{"commandId": "<uuid>", "eventId": "<uuid>"}
\`\`\`

---

[Repeat the above block for each Command in the Bounded Context]
```

---

## Worked Entry: ClassifyDataAsset

This entry demonstrates a fully-completed Command Catalog entry for the
`ClassifyDataAsset` Command in the DataAsset Management Bounded Context.

---

### ClassifyDataAsset

**Overview**

| Field | Value |
|---|---|
| **Bounded Context** | DataAsset Management |
| **Aggregate Type** | `DataAsset` |
| **Aggregate Method** | `(a *DataAsset) Classify(cmd ClassifyDataAsset) error` |
| **Actor** | Compliance Analyst |
| **Description** | Assigns or updates the sensitivity classification of a registered data asset. A DataAsset's sensitivity level determines which downstream compliance policies, access controls, and audit requirements apply to it. Classification is a privileged write operation recorded in the audit trail. |
| **Idempotency Key** | `commandId` — client-generated UUID per invocation |
| **On Success** | `DataAssetClassified` Domain Event emitted |
| **On Failure** | `ErrCannotClassifyArchivedAsset` · `ErrSensitivityLevelUnchanged` · `ErrStorageSourceInactive` · `ValidationError{...}` (structural) |

---

**Command Envelope**

| Field | Go type | Required | Source |
|---|---|---|---|
| `CommandID` | `uuid.UUID` | Yes | Client-generated per invocation: `uuid.New()` |
| `AggregateID` | `uuid.UUID` | Yes | URL path parameter: `/v1/data-assets/{id}/classification` |
| `AggregateType` | `string` | Yes | Hard-coded in handler: `"DataAsset"` |
| `IssuedBy` | `uuid.UUID` | Yes | Authenticated session context: JWT `sub` claim → `UserID` |
| `IssuedAt` | `time.Time` | Yes | API handler: `time.Now().UTC()` |
| `TenantID` | `uuid.UUID` | Yes | Authenticated session context: JWT `tenant_id` claim |

---

**Domain Payload**

| Field | Go type | Required | Constraints |
|---|---|---|---|
| `SensitivityLevel` | `domain.SensitivityLevel` | Yes | Must be one of: `Public`, `Internal`, `Confidential`, `Restricted`. Validated by `SensitivityLevel.IsValid()` in both Layer 1 (tag) and Layer 2 (Value Object guard). |
| `ClassificationNote` | `string` | No | Optional justification text. Max 500 characters. Written to the `DataAssetClassified` event payload for audit purposes. |

---

**Structural Validation (Layer 1 — API Handler)**

- [x] `commandId` is a non-nil UUID
- [x] `aggregateId` is a non-nil UUID
- [x] `issuedBy` is a non-nil UUID
- [x] `tenantId` is a non-nil UUID
- [x] `sensitivityLevel` is one of: `Public`, `Internal`, `Confidential`, `Restricted`
- [x] `classificationNote` is 500 characters or fewer (when provided)

---

**Business Rule Guards (Layer 2 — Aggregate)**

- [x] **Not archived**: `asset.IsArchived()` must be false. An archived asset is immutable.
- [x] **SensitivityLevel changed**: `asset.sensitivityLevel != cmd.SensitivityLevel`. Re-classifying at the same level is a no-op; the domain treats it as a conflict.
- [x] **StorageSource active (denormalized)**: `asset.storageSourceStatus == StorageSourceActive`. A Restricted classification against an inactive source would misrepresent the asset's true estate context. This check uses denormalized state kept eventually consistent via `StorageSourceStatusChanged` Domain Events.
- [x] **TenantID matches**: `asset.tenantID == cmd.TenantID`. Defence-in-depth check; the Repository also enforces this at query time.

---

**Go Struct**

```go
// package commands — internal/application/commands/classify_data_asset.go

type ClassifyDataAsset struct {
    commands.BaseCommand

    SensitivityLevel   domain.SensitivityLevel `json:"sensitivityLevel"   validate:"required,oneof=Public Internal Confidential Restricted"`
    ClassificationNote string                  `json:"classificationNote" validate:"max=500"`
}
```

---

**API Mapping**

```
PATCH /v1/data-assets/{id}/classification
```

Request body:
```json
{
  "sensitivityLevel": "Confidential",
  "classificationNote": "Contains PII fields identified during estate scan"
}
```

Response on success — `202 Accepted`:
```json
{
  "commandId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "eventId":   "b2c3d4e5-f6a7-8901-bcde-f01234567891"
}
```

Response on business-rule rejection — `422 Unprocessable Entity`:
```json
{
  "status": 422,
  "code":   "DOMAIN_RULE_VIOLATION",
  "message": "cannot classify an archived data asset"
}
```

Response on structural validation failure — `400 Bad Request`:
```json
{
  "status": 400,
  "code":   "VALIDATION_ERROR",
  "errors": [
    {"field": "sensitivityLevel", "message": "must be one of: Public, Internal, Confidential, Restricted"}
  ]
}
```

---

## Traceability Chain for ClassifyDataAsset

The catalog entry above is the single source of truth for this write operation.
Every downstream artifact traces back to it:

```
User story: "As a Compliance Analyst I want to classify a data asset's sensitivity"
    → Command Catalog: ClassifyDataAsset
        → Aggregate design: DataAsset.Classify() method + guards
        → Domain Event Catalog: DataAssetClassified (emitted on success)
        → API Contract: PATCH /v1/data-assets/{id}/classification
        → Feature File: Scenario "Classify a data asset as Confidential"
        → Test: TestDataAsset_Classify_* unit tests (written before the method)
```

The `pre-phase-advance` hook verifies this chain before the Bounded Context advances
from Design to Implement — specifically: Command name in Catalog, Domain Event in
Event Catalog, API endpoint in API contract, Feature File scenario for the happy path.
