# Skill: quality/contract-test-spec

## Purpose
Produce a Contract Test Specification for one consumer–provider pair — the tests that verify a consumer's minimum required fields are still present and correctly typed in the provider's published schema. Consumer-driven: the consumer defines what it needs; the provider proves it delivers that minimum contract.

## Inputs
- `artifacts/implement/contracts/{consumer}-{provider}-contract.md`
- `artifacts/design/contracts/event-schemas.md`
- `artifacts/design/contracts/events/`
- `artifacts/quality/test-plan.md`
- **Arguments required:** consumer name, provider name (e.g. `entity-domain`, `file-domain`)

## Output
**File:** `artifacts/quality/contracts/{consumer}-{provider}.md`
**Registers in manifest:** yes

## Contract Test Rules (enforced)
- Contract tests run in the **consumer's** CI pipeline against the **provider's** schema in the shared kernel.
- Provider runs consumer contract tests in its own CI before merging any schema change.
- Build tag `//go:build contract` on all contract test files.
- Tests assert only the fields the consumer requires — not the full schema.
- A consumer that receives extra fields it doesn't care about must not fail (tolerance of additional fields).

## Artifact Template

```markdown
# Contract Test Specification: {consumer} ← {provider}

**Product:** {product_name}
**Phase:** Quality
**Artifact:** Contract Test Specification
**Consumer:** {consumer service name}
**Provider:** {provider service name}
**Event / API:** {event type or API endpoint}
**Schema source:** `{shared-kernel-repo}/schemas/{SchemaName}.v{N}.schema.json`
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Contract: entity-domain ← file-domain (FileProcessed.v1)

### Consumer Requirements

The Entity Domain consumes `FileProcessed` events from File Domain. The fields it requires:

| Field path | Required type | Required? | Consumer usage |
|-----------|-------------|----------|---------------|
| `event_id` | `string` (UUID) | Yes | Idempotency key |
| `tenant_id` | `string` (UUID) | Yes | Tenant scoping |
| `payload.file_id` | `string` (UUID) | Yes | Aggregate ID lookup |
| `payload.file_path` | `string` | Yes | Extraction context |
| `payload.mime_type` | `string` | Yes | Extraction strategy selection |
| `payload.content_hash` | `string` | Yes | Dedup check |
| `payload.file_size_bytes` | `integer` | Yes | Resource limit enforcement |
| `occurred_at` | `string` (RFC 3339) | Yes | Event ordering |

**Fields the consumer does NOT need** (and must not fail on if present):
- `payload.storage_location_id`
- `payload.scan_id`
- `metadata.*` (any additional metadata fields)

---

## Test Implementation

```go
//go:build contract

package contracts_test

import (
    "encoding/json"
    "os"
    "testing"

    "github.com/xeipuuv/gojsonschema"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
)

// schemaPath points to the shared kernel schema in this repo (pulled as a git submodule or copied in CI)
const fileProcessedSchemaPath = "../../contracts/schemas/FileProcessed.v1.schema.json"

func TestContract_FileProcessed_ConsumerRequirements(t *testing.T) {
    t.Parallel()

    schemaLoader := gojsonschema.NewReferenceLoader("file://" + fileProcessedSchemaPath)

    cases := []struct {
        name    string
        payload string
        wantOK  bool
    }{
        {
            name: "ValidMinimalPayload_ConsumerRequiredFieldsOnly",
            payload: `{
                "event_id": "550e8400-e29b-41d4-a716-446655440000",
                "tenant_id": "660e8400-e29b-41d4-a716-446655440001",
                "occurred_at": "2026-06-20T12:00:00Z",
                "payload": {
                    "file_id": "770e8400-e29b-41d4-a716-446655440002",
                    "file_path": "drive://hr-documents/contract.pdf",
                    "mime_type": "application/pdf",
                    "content_hash": "sha256:abc123",
                    "file_size_bytes": 204800
                }
            }`,
            wantOK: true,
        },
        {
            name: "ValidFullPayload_ExtraFieldsToleratedByConsumer",
            payload: `{
                "event_id": "550e8400-e29b-41d4-a716-446655440000",
                "tenant_id": "660e8400-e29b-41d4-a716-446655440001",
                "occurred_at": "2026-06-20T12:00:00Z",
                "payload": {
                    "file_id": "770e8400-e29b-41d4-a716-446655440002",
                    "file_path": "drive://hr-documents/contract.pdf",
                    "mime_type": "application/pdf",
                    "content_hash": "sha256:abc123",
                    "file_size_bytes": 204800,
                    "storage_location_id": "880e8400-e29b-41d4-a716-446655440003",
                    "scan_id": "990e8400-e29b-41d4-a716-446655440004"
                }
            }`,
            wantOK: true,
        },
        {
            name: "InvalidPayload_MissingFileID",
            payload: `{
                "event_id": "550e8400-e29b-41d4-a716-446655440000",
                "tenant_id": "660e8400-e29b-41d4-a716-446655440001",
                "occurred_at": "2026-06-20T12:00:00Z",
                "payload": {
                    "file_path": "drive://hr-documents/contract.pdf",
                    "mime_type": "application/pdf",
                    "content_hash": "sha256:abc123",
                    "file_size_bytes": 204800
                }
            }`,
            wantOK: false,
        },
        {
            name: "InvalidPayload_MissingTenantID",
            payload: `{
                "event_id": "550e8400-e29b-41d4-a716-446655440000",
                "occurred_at": "2026-06-20T12:00:00Z",
                "payload": {
                    "file_id": "770e8400-e29b-41d4-a716-446655440002",
                    "file_path": "drive://hr-documents/contract.pdf",
                    "mime_type": "application/pdf",
                    "content_hash": "sha256:abc123",
                    "file_size_bytes": 204800
                }
            }`,
            wantOK: false,
        },
    }

    for _, tc := range cases {
        tc := tc
        t.Run(tc.name, func(t *testing.T) {
            t.Parallel()

            documentLoader := gojsonschema.NewStringLoader(tc.payload)
            result, err := gojsonschema.Validate(schemaLoader, documentLoader)
            require.NoError(t, err)

            if tc.wantOK {
                assert.True(t, result.Valid(), "contract violations: %v", result.Errors())
            } else {
                assert.False(t, result.Valid(), "expected validation failure but payload was valid")
            }
        })
    }
}
```

---

## CI Integration

**Consumer repo CI** (entity-domain `ci.yml`):
```yaml
contract-tests:
  name: Contract Tests
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
      with:
        submodules: recursive   # pulls shared-kernel schemas
    - run: go test -tags=contract ./...
```

**Provider repo CI** (file-domain `ci.yml`):
```yaml
consumer-contract-validation:
  name: Consumer Contract Validation
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
      with:
        submodules: recursive
    - name: Run all consumer contract tests against our schema
      run: go test -tags=contract ./contracts/...
      # This runs the same tests from the consumer repo, copied or referenced here
      # A failure means the provider broke a consumer's contract
```

---

## Breaking Change Protocol

If a schema change breaks a consumer contract test:
1. Do NOT merge the schema change.
2. Bump the event version (e.g. `FileProcessed.v2`).
3. Publish both versions for a minimum 30-day migration window.
4. Notify all consumers (tracked in integration-design.md consumer registry).
5. Each consumer updates its contract test to target `.v2` before `.v1` is retired.
```

## Quality Checks
- [ ] `//go:build contract` build tag on all contract test files
- [ ] Consumer required fields are documented in a table before the code
- [ ] Tests cover: valid minimal payload, valid full payload (extra fields tolerated), each missing required field
- [ ] CI integration shows contract tests in BOTH consumer and provider CI
- [ ] Breaking change protocol is defined
- [ ] Schema path references the shared kernel (not a local copy)
