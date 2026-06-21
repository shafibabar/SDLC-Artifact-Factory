# Skill: implement/contract-definition

## Purpose
Produce a Consumer-Driven Contract Definition — the formal specification of what one consumer expects from one provider (API or event). These contracts become automated contract tests that run in the consumer's CI pipeline and break if the provider violates them. This is the mechanism that prevents silent breaking changes in the event-driven pipeline.

## Inputs
- `artifacts/design/contracts/event-schemas.md`
- `artifacts/design/contracts/{service}-api.md`
- `artifacts/design/architecture/integration-design.md`
- **Arguments required:** consumer BC name, provider BC name (e.g. `entity-domain file-domain`)

## Output
**File:** `artifacts/implement/contracts/{consumer}-{provider}-contract.md`
**Registers in manifest:** yes

## Contract Rules (enforced)
- Contracts are defined by the CONSUMER — not the producer. The consumer specifies minimum requirements.
- Contracts are additive: the producer can add new fields; it cannot remove or rename fields in the contract without a new version.
- API contracts and event contracts are separate — one file per (consumer, provider, channel-type) combination.
- Contract tests run in the CONSUMER's CI pipeline. The provider's CI also runs a compatibility check.
- Contracts use the Pact or equivalent consumer-driven contract testing pattern.

## Artifact Template

```markdown
# Consumer-Driven Contract: {Consumer} ← {Provider}

**Product:** {product_name}
**Phase:** Implement
**Artifact:** Consumer-Driven Contract
**Consumer:** {Consumer BC Service}
**Provider:** {Provider BC Service}
**Contract type:** Event | API
**Date:** {date}
**Status:** Approved

---

## Contract Type: Event — `{EventName}`

**Consumer:** Entity Domain Service
**Provider:** File Domain Service
**Channel:** Redpanda topic `file-domain.file-processed`
**Schema version:** v1

---

## Minimum Required Fields

The consumer only requires the fields listed here. The provider may include additional fields — the consumer ignores unknown fields. The provider MUST NOT remove or rename any field listed here without incrementing the schema version.

```json
{
  "event_id":        "string (uuid format) — REQUIRED",
  "event_type":      "string — REQUIRED; must equal 'FileProcessed'",
  "schema_version":  "string — REQUIRED; must equal 'v1'",
  "occurred_at":     "string (ISO8601) — REQUIRED",
  "idempotency_key": "string — REQUIRED; non-empty",
  "tenant_id":       "string (uuid format) — REQUIRED",
  "payload": {
    "file_id":             "string (uuid format) — REQUIRED",
    "storage_location_id": "string (uuid format) — REQUIRED",
    "file_checksum":       "string — REQUIRED; non-empty",
    "extracted_text_ref":  "string — REQUIRED; non-empty",
    "file_metadata": {
      "mime_type":     "string — REQUIRED; non-empty",
      "size_bytes":    "integer — REQUIRED; >= 0",
      "last_modified": "string (ISO8601) — REQUIRED"
    }
  }
}
```

---

## Fields NOT in This Contract (explicitly excluded)

| Field | Why excluded |
|-------|-------------|
| `payload.processing_duration_ms` | Consumer does not use this field — excluding it allows provider to remove it without breaking consumer |

---

## Contract Test Implementation

**Location:** `{consumer-repo}/internal/testing/contracts/file_processed_contract_test.go`
**Run in:** Consumer CI pipeline on every PR

```go
//go:build contract

// This test verifies that the FileProcessed event schema produced by the File Domain Service
// satisfies the Entity Domain Service's minimum contract requirements.
// Run: go test -tags=contract ./internal/testing/contracts/...

package contracts_test

import (
    "encoding/json"
    "os"
    "testing"

    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
    "github.com/xeipuuv/gojsonschema"
)

func TestFileProcessedContract_MinimumRequiredFields(t *testing.T) {
    // Load the contract schema (consumer-defined minimum)
    schemaLoader := gojsonschema.NewStringLoader(`{
        "type": "object",
        "required": ["event_id", "event_type", "schema_version", "occurred_at",
                     "idempotency_key", "tenant_id", "payload"],
        "properties": {
            "event_id":        { "type": "string", "format": "uuid" },
            "event_type":      { "type": "string", "const": "FileProcessed" },
            "schema_version":  { "type": "string", "const": "v1" },
            "occurred_at":     { "type": "string", "format": "date-time" },
            "idempotency_key": { "type": "string", "minLength": 1 },
            "tenant_id":       { "type": "string", "format": "uuid" },
            "payload": {
                "type": "object",
                "required": ["file_id", "storage_location_id", "file_checksum",
                             "extracted_text_ref", "file_metadata"],
                "properties": {
                    "file_id":             { "type": "string", "format": "uuid" },
                    "storage_location_id": { "type": "string", "format": "uuid" },
                    "file_checksum":       { "type": "string", "minLength": 1 },
                    "extracted_text_ref":  { "type": "string", "minLength": 1 },
                    "file_metadata": {
                        "type": "object",
                        "required": ["mime_type", "size_bytes", "last_modified"],
                        "properties": {
                            "mime_type":     { "type": "string", "minLength": 1 },
                            "size_bytes":    { "type": "integer", "minimum": 0 },
                            "last_modified": { "type": "string", "format": "date-time" }
                        }
                    }
                }
            }
        }
    }`)

    // Load a sample FileProcessed event from the shared contracts repo
    // (pinned at the version the provider publishes)
    eventJSON, err := os.ReadFile("../../contracts/FileProcessed.v1.example.json")
    require.NoError(t, err, "provider example event file must exist in contracts/")

    documentLoader := gojsonschema.NewBytesLoader(eventJSON)
    result, err := gojsonschema.Validate(schemaLoader, documentLoader)
    require.NoError(t, err)

    if !result.Valid() {
        for _, desc := range result.Errors() {
            t.Errorf("Contract violation: %s", desc)
        }
        t.Fail()
    }
}
```

---

## Provider Compatibility Check

The File Domain Service (provider) runs this check in its CI to ensure it does not break any consumer contracts:

**Location:** `{provider-repo}/.github/workflows/ci.yml`

```yaml
- name: Contract compatibility check
  run: |
    # Download all consumer contracts from the contracts repo
    # Validate that the provider's example events satisfy every consumer contract
    go test -tags=contract ./internal/testing/provider-contracts/...
```

---

## Contract Registry

All active contracts are listed here for traceability:

| Contract | Consumer | Provider | Channel type | Current version |
|----------|---------|---------|-------------|----------------|
| `entity-domain ← file-domain (FileProcessed)` | Entity Domain | File Domain | Event | v1 |
| `compliance-domain ← entity-domain (EntitiesExtracted)` | Compliance Domain | Entity Domain | Event | v1 |
| `graph-domain ← entity-domain (GoldenRecordCreated)` | Graph Domain | Entity Domain | Event | v1 |
| `audit-domain ← file-domain (all events)` | Audit Domain | File Domain | Event | v1 |
| `web-ui ← file-domain (HTTP API)` | Web UI / API Gateway | File Domain | REST API | v1 |

---

## Breaking Change Process

When a provider must make a breaking change:

1. Increment schema version: `FileProcessed.v2.schema.json`
2. Update contracts repo with `v2` schema
3. Notify all consumer teams (consumer contact list in contracts/OWNERS.md)
4. Provider publishes BOTH `v1` and `v2` events for migration window (default 30 days)
5. Each consumer updates their contract test to `v2` and migrates their handler
6. After all consumers confirm migration, provider stops publishing `v1`
7. Update this contract document to reflect `v2`
```

## Quality Checks
- [ ] Contract is defined by the consumer, not the producer
- [ ] Minimum required fields are explicitly listed (not "all fields")
- [ ] Fields NOT in the contract are explicitly excluded with rationale
- [ ] Contract test uses real JSON Schema validation (not hand-rolled assertions)
- [ ] Provider compatibility check is in the provider's CI
- [ ] Breaking change process is documented
- [ ] Contract registry table is populated for all integration pairs
