# Skill: design/policy-catalogue

## Purpose
Produce the Policy Catalogue — a complete inventory of all domain policies. A Policy is a reaction to a domain event: "When {event} then {command or side-effect}". Policies are the connective tissue of the event-driven system; they are what flows between bounded contexts.

## Inputs
- `artifacts/design/domain/events.md`
- `artifacts/design/domain/commands.md`
- Event Storming session output (lilac sticky notes from ES session)

## Output
**File:** `artifacts/design/domain/policies.md`
**Registers in manifest:** yes

## Policy Rules (enforced)
- A Policy always starts with "When {DomainEvent}" — the trigger must be one specific domain event.
- A Policy either issues one or more Commands, or produces a side effect (e.g. send notification, update read model).
- Policies must NOT read the state of another aggregate directly — they receive everything they need from the event payload.
- Policies that span bounded contexts are Integration Policies — these require ACL translation.
- Policies CANNOT loop: Policy A triggers Event X, which triggers Policy B, which must NOT trigger Event A's chain again. Document prevention where risk exists.

## Artifact Template

```markdown
# Policy Catalogue

**Product:** {product_name}
**Phase:** Design
**Artifact:** Policy Catalogue
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## Policy Naming Convention
- Named as a process: `InitiateScanWhenLocationActivated`
- Or as a rule: `NewFilesMustBeProcessedOnDiscovery`
- Always answerable with "When X, then Y"

---

## {Bounded Context: File Domain}

### P-FILE-01: InitiateScanWhenLocationActivated

| Attribute | Value |
|-----------|-------|
| **Trigger** | `StorageLocationActivated` (credentials validated successfully) |
| **Actor** | System (event-driven, no human in loop) |
| **Issues command** | `InitiateScan` → StorageLocation aggregate |
| **Data used from event** | `storage_location_id`, `scan_configuration` |
| **Integration policy?** | No — within File Domain |
| **Loop risk** | Low — InitiateScan → ScanInitiated does not trigger CredentialsValidated |
| **Failure handling** | If `InitiateScan` is rejected (scan already in progress), log and discard — idempotent |

---

### P-FILE-02: RetryCredentialValidationOnFailure

| Attribute | Value |
|-----------|-------|
| **Trigger** | `CredentialValidationFailed` |
| **Actor** | System (with back-off timer) |
| **Issues command** | `ValidateCredentials` → StorageLocation aggregate (retry with exponential back-off) |
| **Retry limit** | 3 attempts, then emit `LocationPermanentlyInvalid` |
| **Integration policy?** | No — within File Domain |
| **Loop risk** | Managed by retry limit |

---

## {Bounded Context: Cross-Context: File → Entity}

### P-XCTX-01: ProcessFileWhenDiscovered

| Attribute | Value |
|-----------|-------|
| **Trigger** | `FileDiscovered` (from File Domain) |
| **Actor** | System |
| **Issues command** | `ExtractEntities` → FileProcessingJob aggregate (Entity Domain) |
| **Integration policy?** | **Yes** — crosses from File Domain to Entity Domain |
| **ACL required?** | Yes — `FileDiscovered` payload must be translated to Entity Domain model; no File Domain types leak into Entity Domain |
| **Data translation** | `file_path` → `source_reference`, `storage_location_id` → `origin_location_id` |
| **Failure handling** | Dead letter queue → manual review queue after 3 delivery attempts |

---

## {Bounded Context: Cross-Context: Entity → Compliance}

### P-XCTX-02: EvaluateComplianceWhenEntityGraphUpdated

| Attribute | Value |
|-----------|-------|
| **Trigger** | `GoldenRecordUpdated` (from Entity Domain) |
| **Actor** | System |
| **Issues command** | `EvaluateComplianceRule` for each active compliance rule that references the updated entity type |
| **Integration policy?** | **Yes** — crosses from Entity Domain to Compliance Domain |
| **Fan-out risk** | One `GoldenRecordUpdated` may trigger N `EvaluateComplianceRule` commands (one per active rule). Document max fan-out. |
| **Failure handling** | Individual rule evaluation failures are isolated — one failed rule does not block others |

---

## {Bounded Context: Compliance Domain}

### P-COMP-01: AlertOnCriticalFinding

| Attribute | Value |
|-----------|-------|
| **Trigger** | `FindingCreated` where `severity = CRITICAL` |
| **Actor** | System |
| **Side effect** | Enqueue alert notification (→ Alert Domain) |
| **Integration policy?** | **Yes** — crosses from Compliance Domain to Alert Domain |
| **Filtering** | Only severity = CRITICAL; HIGH findings batched for digest |

---

## Policy Inventory Summary

| ID | Name | Trigger Event | Issues Command / Effect | Type |
|----|------|--------------|------------------------|------|
| P-FILE-01 | InitiateScanWhenLocationActivated | `StorageLocationActivated` | `InitiateScan` | Internal |
| P-FILE-02 | RetryCredentialValidationOnFailure | `CredentialValidationFailed` | `ValidateCredentials` (retry) | Internal |
| P-XCTX-01 | ProcessFileWhenDiscovered | `FileDiscovered` | `ExtractEntities` | **Integration** |
| P-XCTX-02 | EvaluateComplianceWhenEntityGraphUpdated | `GoldenRecordUpdated` | `EvaluateComplianceRule` | **Integration** |
| P-COMP-01 | AlertOnCriticalFinding | `FindingCreated` (CRITICAL) | Enqueue alert | **Integration** |
| ... | ... | ... | ... | ... |
```

## Quality Checks
- [ ] Every policy starts with a specific domain event trigger (not a vague condition)
- [ ] Integration policies crossing bounded contexts are identified and ACL requirement is noted
- [ ] Fan-out policies document expected max fan-out to prevent unbounded message explosions
- [ ] Loop risks are analysed for every policy chain longer than 2 hops
- [ ] Failure handling is specified for every integration policy
