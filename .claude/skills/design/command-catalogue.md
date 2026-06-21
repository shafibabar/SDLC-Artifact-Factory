# Skill: design/command-catalogue

## Purpose
Produce the Command Catalogue — the complete list of all commands in the system, paired with the aggregates that handle them. Commands express user intent. They are validated and either accepted (producing domain events) or rejected (returning an error).

## Inputs
- `artifacts/design/domain/events.md`
- `artifacts/design/domain/aggregates/` (all existing aggregate definitions)
- `artifacts/ideate/requirements/functional.md`

## Output
**File:** `artifacts/design/domain/commands.md`
**Registers in manifest:** yes

## Command Rules (enforced)
- Names are imperative, PascalCase: `RegisterStorageLocation`, `InitiateScan`, `CreateFinding`
- Commands express intent — they may be rejected. Events cannot be rejected (they already happened).
- Every command targets exactly one aggregate.
- Commands carry the minimum data needed — no redundant data that can be retrieved from the aggregate's current state.
- Commands have an actor (who issues them): User, System, Timer, ExternalSystem.

## Artifact Template

```markdown
# Command Catalogue

**Product:** {product_name}
**Phase:** Design
**Artifact:** Command Catalogue
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## {Bounded Context: File Domain}

| Command | Actor | Target Aggregate | Events on Accept | Rejects when |
|---------|-------|-----------------|-----------------|--------------|
| `RegisterStorageLocation` | User (Admin) | StorageLocation | `StorageLocationRegistered` | Duplicate path, invalid platform |
| `ValidateCredentials` | System (scheduled) | StorageLocation | `CredentialsValidated` \| `CredentialValidationFailed` | Location not in Pending/ScanError state |
| `InitiateScan` | System (event-driven) | StorageLocation | `ScanInitiated` | Scan already in progress |
| `ReportScanComplete` | System (WorkerNode) | StorageLocation | `ScanCompleted` | Location not in Scanning state |
| `DeregisterStorageLocation` | User (Admin) | StorageLocation | `StorageLocationDeregistered` | Scan in progress |

### Command Detail: RegisterStorageLocation

**Actor:** User (Administrator role required)
**Target aggregate:** StorageLocation
**Idempotency:** Re-registering the same location is rejected with `ALREADY_EXISTS` error — not a duplicate.

**Input payload:**
```json
{
  "tenant_id": "uuid",
  "storage_path": "string",
  "platform": "GOOGLE_DRIVE | AWS_S3 | SHAREPOINT | DROPBOX",
  "credential_ref": "string (secrets manager reference)",
  "scan_configuration": {
    "resource_cap_percent": "integer 1–100",
    "file_type_include": ["string"],
    "file_type_exclude": ["string"]
  }
}
```

**Validation rules:**
1. `platform` must be one of the supported enum values
2. `credential_ref` must reference an existing secrets manager entry
3. `storage_path` must not already exist for this tenant
4. `resource_cap_percent` must be between 1 and 100

**On accept:** emits `StorageLocationRegistered`, writes to outbox table
**On reject:** returns structured error with code and message; no state change; no event

---

## {Bounded Context: Entity Domain}

| Command | Actor | Target Aggregate | Events on Accept | Rejects when |
|---------|-------|-----------------|-----------------|--------------|
| `ExtractEntities` | System (File Processing Service) | FileProcessingJob | `EntitiesExtracted` \| `ExtractionFailed` | Job already completed |
| `ResolveGoldenRecord` | System (Entity Extraction Service) | GoldenRecord | `GoldenRecordCreated` \| `GoldenRecordUpdated` | Conflicting deduplication signals (→ FlaggedForReview) |
| `FlagEntityForReview` | System | GoldenRecord | `EntityFlaggedForReview` | — |
| `ConfirmEntityResolution` | User (Admin) | GoldenRecord | `EntityResolutionConfirmed` | Reviewer not authorised |

---

## {Bounded Context: Compliance Domain}

| Command | Actor | Target Aggregate | Events on Accept | Rejects when |
|---------|-------|-----------------|-----------------|--------------|
| `EvaluateComplianceRule` | System (Graph Update Service event) | ComplianceRule | `FindingCreated` \| `RuleEvaluated` (no violation) | Rule not active |
| `AcknowledgeFinding` | User | Finding | `FindingAcknowledged` | Finding already resolved |
| `ResolveFinding` | User | Finding | `FindingResolved` | Finding already resolved |
| `CreateException` | User | Finding | `ExceptionCreated` | — |

---

## Command Inventory Summary

| Context | Command count | Commands |
|---------|--------------|---------|
| File Domain | {n} | RegisterStorageLocation, ... |
| Entity Domain | {n} | ExtractEntities, ... |
| Compliance Domain | {n} | EvaluateComplianceRule, ... |
| **Total** | {n} | |
```

## Quality Checks
- [ ] All command names are imperative PascalCase
- [ ] Every command has exactly one target aggregate
- [ ] Every command specifies its actor (not just "system" generically)
- [ ] Rejection conditions are defined for all commands
- [ ] Commands that must be idempotent are explicitly marked
- [ ] No undefined ubiquitous language terms
