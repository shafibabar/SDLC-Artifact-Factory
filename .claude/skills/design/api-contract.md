# Skill: design/api-contract

## Purpose
Produce an API Contract for one service — the formal specification of the HTTP API exposed by a bounded context service. Contracts are the interface agreement between teams; they must be defined before implementation begins (contract-first development).

## Inputs
- `artifacts/design/domain/commands.md` (for write operations)
- `artifacts/design/domain/read-models/` (for read operations)
- `artifacts/design/bounded-contexts.md`
- `artifacts/ideate/requirements/nfrs.md` (for rate limits, SLAs)
- **Argument required:** service name (e.g. `file-domain-service`, `compliance-domain-service`)

## Output
**File:** `artifacts/design/contracts/{service-name}-api.md`
**Registers in manifest:** yes

## API Contract Rules (enforced)
- Contract-first: spec is written before code. Code conforms to the contract, not vice versa.
- API versioning is in the path from day one: `/api/v1/...`
- Every endpoint documents: HTTP method, path, auth requirement, request body, success response, and all possible error responses.
- Error responses use RFC 7807 Problem Details format.
- Every endpoint that modifies state is idempotent or documents why it cannot be.
- Cursor-based pagination is required for all collection endpoints (no offset pagination for large collections).
- Sensitive data fields are marked in request/response schemas.
- Rate limits are documented per endpoint or endpoint group.

## Artifact Template

```markdown
# API Contract: {Service Name}

**Product:** {product_name}
**Bounded Context:** {context name}
**Service:** {service name}
**Phase:** Design
**Artifact:** API Contract
**Version:** v1
**Date:** {date}
**Status:** Draft

---

## Base URL
```
/api/v1/{bc-slug}/
```

## Authentication
All endpoints require a valid JWT Bearer token issued by the Identity Domain Service.

```
Authorization: Bearer <jwt>
```

The JWT must contain claims: `tenant_id`, `user_id`, `roles[]`.

Requests without a valid JWT → `401 Unauthorized`
Requests with a JWT that lacks required permissions → `403 Forbidden`

---

## Common Error Responses (RFC 7807)

All errors return `Content-Type: application/problem+json`:

```json
{
  "type": "https://{product-domain}/problems/{error-code}",
  "title": "Human-readable error title",
  "status": 400,
  "detail": "Specific reason for this instance of the error",
  "instance": "/api/v1/file/storage-locations/abc123",
  "trace_id": "uuid"
}
```

---

## Endpoints

---

### POST /storage-locations
**Description:** Register a new storage location.
**Required role:** `admin`
**Idempotent:** No — duplicate registrations return 409

**Request body:**
```json
{
  "storage_path": "string (required)",
  "platform": "GOOGLE_DRIVE | AWS_S3 | SHAREPOINT | DROPBOX (required)",
  "credential_ref": "string (required) — secrets manager reference key",
  "scan_configuration": {
    "resource_cap_percent": "integer 1–100 (default: 20)",
    "file_type_include": ["string"],
    "file_type_exclude": ["string"],
    "schedule": "string (cron expression, optional)"
  }
}
```

**Sensitive fields:** `credential_ref` — logged as `[REDACTED]` in all audit and access logs.

**Success response — 201 Created:**
```json
{
  "storage_location_id": "uuid",
  "status": "PENDING",
  "created_at": "ISO8601"
}
```

**Error responses:**

| Status | Error code | Condition |
|--------|-----------|-----------|
| 400 | `INVALID_PLATFORM` | `platform` not in allowed enum |
| 400 | `INVALID_RESOURCE_CAP` | `resource_cap_percent` outside 1–100 |
| 400 | `INVALID_CREDENTIAL_REF` | Credential reference not found in secrets manager |
| 409 | `ALREADY_EXISTS` | Storage path already registered for this tenant |
| 422 | `WRITE_SCOPE_REJECTED` | Credential has write access; read-only required |

---

### GET /storage-locations
**Description:** List all storage locations for the authenticated tenant.
**Required role:** `admin` or `viewer`
**Pagination:** Cursor-based (`after` cursor param)

**Query parameters:**
| Param | Type | Description |
|-------|------|-------------|
| `status` | string | Filter by status: `PENDING`, `ACTIVE`, `SCANNING`, `SCAN_ERROR`, `DEREGISTERED` |
| `after` | string | Cursor for next page (from previous response `next_cursor`) |
| `limit` | integer | Page size, default 20, max 100 |

**Success response — 200 OK:**
```json
{
  "items": [
    {
      "storage_location_id": "uuid",
      "storage_path": "string",
      "platform": "string",
      "status": "string",
      "last_scan_at": "ISO8601 | null",
      "created_at": "ISO8601"
    }
  ],
  "next_cursor": "string | null",
  "total_count": "integer"
}
```

---

### GET /storage-locations/{id}
**Description:** Get a single storage location by ID.
**Required role:** `admin` or `viewer`

**Success response — 200 OK:**
```json
{
  "storage_location_id": "uuid",
  "storage_path": "string",
  "platform": "string",
  "status": "string",
  "credential_ref": "[REDACTED]",
  "scan_configuration": { "..." },
  "last_scan_at": "ISO8601 | null",
  "created_at": "ISO8601",
  "updated_at": "ISO8601"
}
```

**Error responses:**

| Status | Condition |
|--------|-----------|
| 404 | Location not found or not owned by authenticated tenant |

---

### DELETE /storage-locations/{id}
**Description:** Deregister a storage location.
**Required role:** `admin`
**Idempotent:** Yes — deleting an already-deregistered location returns 200

**Error responses:**

| Status | Error code | Condition |
|--------|-----------|-----------|
| 409 | `SCAN_IN_PROGRESS` | Cannot deregister while a scan is running |

**Success response — 200 OK:**
```json
{
  "storage_location_id": "uuid",
  "status": "DEREGISTERED",
  "deregistered_at": "ISO8601"
}
```

---

## Rate Limits

| Endpoint group | Limit | Window |
|---------------|-------|--------|
| POST endpoints (write) | 60 req | per minute per tenant |
| GET endpoints (read) | 300 req | per minute per tenant |
| DELETE endpoints | 30 req | per minute per tenant |

Rate limit exceeded → `429 Too Many Requests` with `Retry-After` header.

---

## API Versioning Strategy

- Current version: `v1` (in path)
- Breaking changes require a new version (`v2`)
- Breaking change definition: removing a field, renaming a field, changing a field type, changing an HTTP status code
- Non-breaking changes (adding optional fields, adding new endpoints) do not require a version bump
- Old versions are deprecated not removed; at least 6 months notice before retirement
```

## Quality Checks
- [ ] All endpoints have path, method, auth requirement, request schema, success response, and error responses
- [ ] Error responses use RFC 7807 Problem Details format
- [ ] Sensitive fields are identified and marked as `[REDACTED]` in logs
- [ ] Collection endpoints use cursor-based pagination
- [ ] Rate limits are documented
- [ ] All endpoints that take an ID validate tenant ownership (not just existence) — prevents tenant data leakage
- [ ] API versioning strategy is documented
