# Hook: contract-compliance-checker

## Trigger
Fires when:
- A new event schema artifact is created (`artifacts/design/contracts/events/`)
- A new API contract artifact is created (`artifacts/design/contracts/`)
- A contract test spec is created (`artifacts/quality/contracts/`)
- The user runs `/sdlc-review` in the Implement or Quality phase

## Purpose
Verify that published contracts (event schemas, API contracts) are consistent with the integration design, that all consumer relationships are documented, and that breaking change procedures are followed when schemas evolve. Prevent silent contract drift between what is designed and what is tested.

## Execution

### Step 1: Load the integration design

```
Read: artifacts/design/architecture/integration-design.md
Extract:
  - Consumer group registry (which consumer subscribes to which topic)
  - Event schema version table
  - API contract list
  - Error policy per consumer (DLQ, retry, etc.)
```

### Step 2: Load all event schema artifacts

```
Read: artifacts/design/contracts/event-schemas.md (master index)
Read: artifacts/design/contracts/events/*.schema.json (all schemas)
For each schema: extract event_type, event_version, schema_version, required fields
```

### Step 3: Load all contract test specs

```
Read: artifacts/quality/contracts/*.md
For each contract test: extract consumer, provider, required fields tested
```

### Step 4: Run contract compliance checks

#### Check A: Every event in integration-design has a schema
```
For each event type in integration-design topic registry:
  Verify artifacts/design/contracts/events/{EventName}.v{N}.schema.json exists
  
If missing:
  FLAG: CONTRACT_GAP — event {EventName} has no schema defined
```

#### Check B: Every consumer in integration-design has a contract test
```
For each (consumer, event_type) pair in consumer group registry:
  Verify artifacts/quality/contracts/{consumer}-{provider}.md exists AND covers {event_type}
  
If missing:
  FLAG: CONTRACT_GAP — consumer {consumer} subscribes to {event_type} but has no contract test
```

#### Check C: Contract test covers required fields
```
For each contract test spec:
  Verify that the consumer's required fields list includes:
    - event_id (always required — idempotency key)
    - tenant_id (always required — isolation key)
    - occurred_at (always required — ordering)
    - payload.{minimum fields for this consumer's use case}
  
If event_id or tenant_id is missing from consumer's required fields:
  FLAG: CONTRACT_DEFECT — consumer {consumer} must require event_id and tenant_id
```

#### Check D: Schema versioning compliance
```
For each schema:
  Verify schema_version follows SemVer (major.minor.patch)
  Verify event_version is an integer (v1, v2, etc.)
  Verify additionalProperties: false is set on all schemas

For each schema change (detected by comparing with previous version):
  If the change is additive (new optional field): no version bump required — PASS
  If the change removes a field or changes a type: major version bump required
    Check: does the new schema file exist as EventName.v{N+1}.schema.json?
    If not: FLAG: BREAKING_CHANGE_UNVERSIONED
```

#### Check E: Backwards compatibility window
```
For each schema where v{N} and v{N+1} both exist:
  Both schemas must be present in the events/ directory simultaneously
  (Both versions published during 30-day migration window)
  FLAG if: v{N} schema is deleted but v{N+1} is less than 30 days old
```

### Step 5: Output

```
Contract Compliance Check
────────────────────────────────────────────────────────────────

Events checked: {N}
Consumer–provider pairs checked: {N}
Schemas with additionalProperties: false: {N}/{N}

CONTRACT GAPS (must fix):
  • consumer compliance-domain has no contract test for FileProcessed.v1
    Consumers without contract tests are invisible to producer CI — breaking changes go undetected.
    Fix: Run /sdlc-artifact quality/contract-test-spec compliance-domain file-domain

CONTRACT DEFECTS (must fix):
  • entity-domain contract test does not require tenant_id
    Fix: Add tenant_id to the required fields list in artifacts/quality/contracts/entity-domain-file-domain.md

BREAKING CHANGE VIOLATIONS (must fix):
  • FileProcessed.v1.schema.json: field 'file_path' changed from string to object
    This is a breaking change. Requires FileProcessed.v2.schema.json and 30-day parallel publishing.
    Fix: Run /sdlc-artifact design/event-schema FileProcessed 2 to create the v2 schema

────────────────────────────────────────────────────────────────
All passing: {N} contracts, {N} consumers, {N} schemas verified clean.
```

### Step 6: Record in manifest

```json
{
  "last_contract_compliance_check": "{ISO 8601}",
  "contract_gaps": {N},
  "contract_defects": {N},
  "breaking_change_violations": {N}
}
```
