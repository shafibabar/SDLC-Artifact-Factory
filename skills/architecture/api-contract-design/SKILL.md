---
name: api-contract-design
description: >
  Teaches how to design API contracts using the API-First approach — defining
  the OpenAPI 3.1 specification before any implementation code is written.
  Covers resource naming, HTTP method selection, request/response schema design,
  error response standards, versioning strategy, authentication headers, and
  how the API contract connects to the Command Catalog and Read Model designs
  from domain modelling. The OpenAPI spec is the authoritative contract between
  the backend-engineer and frontend-engineer. Used by the enterprise-architect
  agent after the Command Catalog and Read Model designs are complete.
version: 1.0.0
phase: design
owner: enterprise-architect
tags: [design, architecture, api-first, openapi, contract-first, rest]
---

# API Contract Design

## Purpose

API-First design means the API contract is designed and agreed upon before any implementation code is written. The contract is the source of truth — not the code. The code implements the contract; the contract does not describe the code.

This approach:
- Enables frontend and backend development to proceed in parallel (against the contract, not each other)
- Creates a machine-readable contract that tools can validate, mock, and generate code from
- Forces explicit decisions about resource naming, versioning, and error handling before they become embedded in code
- Creates Consumer-Driven Contract test anchors

---

## OpenAPI 3.1 as the Standard

All API contracts in this plugin use OpenAPI 3.1. The spec is stored at `api/openapi.yaml` in each service's repository.

The OpenAPI spec must:
- Be the source of truth — server-side code is generated from it or validated against it
- Be versioned in git alongside the service code
- Pass schema validation in CI before any other pipeline step
- Use `$ref` to reference shared schemas rather than repeating definitions

---

## Resource Naming

Resources are named after domain concepts from the Ubiquitous Language — not after database tables or implementation concepts.

| Good resource name | Poor resource name |
|---|---|
| `/v1/data-assets` | `/v1/files` (not Ubiquitous Language) |
| `/v1/storage-sources` | `/v1/sources` (vague) |
| `/v1/compliance-gaps` | `/v1/gaps` (ambiguous) |
| `/v1/estate-scans` | `/v1/scans` (not domain language) |

Rules:
- Plural nouns for collections: `/data-assets`
- Singular noun for a specific resource: `/data-assets/{id}`
- Use kebab-case: `/compliance-gaps`, not `/complianceGaps` or `/compliance_gaps`
- Nest only one level deep: `/data-assets/{id}/classification` — not deeper
- Actions that are not CRUD: use a sub-resource noun — `/estate-scans` (not `/scan-estate`)

---

## HTTP Method → Command/Query Mapping

| HTTP Method | Semantics | Maps to |
|---|---|---|
| `POST` | Create a new resource or trigger an action | Command |
| `PUT` | Replace an existing resource entirely | Command |
| `PATCH` | Partially update an existing resource | Command |
| `DELETE` | Remove a resource | Command |
| `GET` | Read a resource or collection | Query → Read Model |

Every Command from the Command Catalog maps to a `POST`, `PUT`, `PATCH`, or `DELETE` endpoint. Every Read Model query maps to a `GET` endpoint.

---

## Standard Response Shapes

### Success responses

| Status | When |
|---|---|
| `200 OK` | Successful GET, PUT, PATCH |
| `201 Created` | Successful POST that creates a resource |
| `202 Accepted` | Command accepted for async processing (the result will come via event) |
| `204 No Content` | Successful DELETE, or action with no response body |

### Error responses

All error responses use a standard envelope:

```yaml
ErrorResponse:
  type: object
  required: [error]
  properties:
    error:
      type: object
      required: [code, message]
      properties:
        code:
          type: string
          description: Machine-readable error code in SCREAMING_SNAKE_CASE
          example: DATA_ASSET_NOT_FOUND
        message:
          type: string
          description: Human-readable description suitable for display
          example: "The data asset with ID abc123 was not found"
        details:
          type: array
          description: Field-level validation errors
          items:
            type: object
            properties:
              field: { type: string }
              message: { type: string }
```

| Status | When | Error code pattern |
|---|---|---|
| `400 Bad Request` | Request payload is malformed or fails structural validation | `INVALID_[FIELD]`, `MISSING_[FIELD]` |
| `401 Unauthorized` | JWT missing or expired | `AUTHENTICATION_REQUIRED` |
| `403 Forbidden` | JWT valid but insufficient permissions | `INSUFFICIENT_PERMISSIONS` |
| `404 Not Found` | Resource does not exist | `[RESOURCE]_NOT_FOUND` |
| `409 Conflict` | Business rule violation (Aggregate guard failed) | `[RULE_VIOLATED]` |
| `422 Unprocessable Entity` | Payload is structurally valid but semantically invalid | `[VALIDATION_ERROR]` |
| `429 Too Many Requests` | Rate limit exceeded | `RATE_LIMIT_EXCEEDED` |
| `500 Internal Server Error` | Unexpected server error — never include internal details | `INTERNAL_ERROR` |

---

## Versioning Strategy

APIs are versioned with a major version prefix in the path: `/v1/`, `/v2/`.

| Change type | Required action |
|---|---|
| Adding a new optional field to a response | Additive change — no version bump required. Consumers must tolerate unknown fields. |
| Adding a new endpoint | Additive change — no version bump required. |
| Removing a field from a response | Breaking change — bump to `/v2/`. Run `/v1/` and `/v2/` in parallel during sunset period. |
| Changing a field type or name | Breaking change — bump to `/v2/`. |
| Removing an endpoint | Breaking change — bump to `/v2/`. |

Version sunset policy: `/v1/` is maintained for a minimum of 6 months after `/v2/` launches. Deprecation is announced via a `Deprecation` response header.

---

## Authentication

All endpoints (except health checks) require JWT Bearer authentication:

```yaml
securitySchemes:
  BearerAuth:
    type: http
    scheme: bearer
    bearerFormat: JWT

security:
  - BearerAuth: []
```

The JWT is validated by the API Gateway / middleware before the request reaches any handler. Handler code never validates JWTs — it reads claims from context.

Health check endpoints (`GET /healthz`, `GET /readyz`) are excluded from authentication.

---

## Idempotency Header

All `POST`, `PUT`, and `PATCH` requests must support an `Idempotency-Key` header. The server stores the result for 24 hours and returns the stored result if the same key is seen again.

```yaml
parameters:
  - name: Idempotency-Key
    in: header
    required: false
    schema:
      type: string
      format: uuid
    description: >
      Client-generated UUID v4. If provided, the server returns the stored
      result for any duplicate request with the same key within 24 hours.
```

---

## OpenAPI Spec Structure

```yaml
openapi: "3.1.0"

info:
  title: "[Service Name] API"
  version: "1.0.0"
  description: "[Service responsibility in one paragraph]"

servers:
  - url: "https://api.{tenantId}.example.com/v1"
    variables:
      tenantId:
        description: "Tenant identifier for physical multi-tenancy routing"
        default: "demo"

security:
  - BearerAuth: []

tags:
  - name: DataAssets
    description: "Operations on discovered data assets"

paths:
  /data-assets:
    get:
      summary: "List data assets"
      tags: [DataAssets]
      parameters: [...]
      responses:
        "200":
          description: "Paginated list of data assets"
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/DataAssetListResponse"

components:
  schemas:
    DataAssetListResponse:
      type: object
      properties:
        items:
          type: array
          items:
            $ref: "#/components/schemas/DataAssetListItem"
        pagination:
          $ref: "#/components/schemas/PaginationMeta"

  securitySchemes:
    BearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
```

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Ubiquitous Language resources | Resource names from domain Ubiquitous Language | Database table names or generic names |
| All Commands covered | Every Command in the Command Catalog has an endpoint | Commands with no API endpoint |
| All Read Models covered | Every Read Model has a GET endpoint | Read Models not accessible via API |
| Standard error envelope | All error responses use the standard ErrorResponse shape | Custom error shapes per endpoint |
| Versioned | Path includes `/v1/` prefix | Unversioned paths |
| Auth on all endpoints | BearerAuth applied globally; health checks excluded | Endpoints missing authentication |
| Idempotency header | Documented on all mutating endpoints | POST endpoints with no idempotency support |

---

## Output Format

The primary output is the `api/openapi.yaml` file in the service repository:
`artifacts/[product]/design/[service-name]/openapi.yaml`

Accompanied by a contract summary:
`artifacts/[product]/design/[service-name]/api-contract-summary.md`

```markdown
---
artifact: api-contract-summary
product: [product name]
service: [service name]
version: 1.0.0
phase: design
created: [date]
owner: enterprise-architect
openapi-spec: artifacts/[product]/design/[service-name]/openapi.yaml
---

# API Contract Summary: [Service Name]

## Endpoints

| Method | Path | Command / Read Model | Auth | Idempotency |
|---|---|---|---|---|

## Breaking Change Log
[Version history and breaking changes — starts empty]

## Consumer Registry
[List of known consumers of this API — required for Consumer-Driven Contract tests]
```
