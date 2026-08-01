---
name: api-contract-design
description: >
  Teaches how to design API contracts using the API-First approach — defining
  the OpenAPI 3.1 specification before any implementation code is written.
  Covers resource naming, HTTP method selection, request/response schema design,
  error response standards, versioning strategy, authentication headers, how
  the API contract connects to the Command Catalog and Read Model designs from
  domain modelling, and — grounded in JJ Geewax's *API Design Patterns* —
  custom methods for actions that don't fit clean CRUD, the long-running
  operation (Operation resource) pattern for async work, resource revisions
  (ETags) for optimistic concurrency, and field masks for partial updates. The
  OpenAPI spec is the authoritative contract between the backend-engineer and
  frontend-engineer. Includes scripts/scaffold-api-contract-design.sh and
  scripts/validate-api-contract-design.sh. Used by the enterprise-architect
  agent after the Command Catalog and Read Model designs are complete.
version: 2.2.0
phase: design
owner: enterprise-architect
created: 2026-06-25
tags: [design, architecture, api-first, openapi, contract-first, rest]
produces: openapi-specification
domain: architecture
status: stable
related: [skill-authoring-standards, command-catalog, read-model-design]
---

# API Contract Design

## Purpose

API-First design means the API contract is designed and agreed upon before any implementation code is written. The contract is the source of truth — not the code. The code implements the contract; the contract does not describe the code.

This approach:
- Enables frontend and backend development to proceed in parallel (against the contract, not each other)
- Creates a machine-readable contract that tools can validate, mock, and generate code from
- Forces explicit decisions about resource naming, versioning, and error handling before they become embedded in code
- Creates Consumer-Driven Contract test anchors

**The contract is a product, not plumbing** (per Kin Lane's *The API-First Transformation*): it is the durable interface a future mobile client, partner integration, or internal automation will be built against, long after the UI that motivated it first has changed or been replaced. Its design quality is reviewed with the same seriousness as a pricing model or a positioning statement — not treated as an implementation formality that happens to come first.

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

For the rarer action that genuinely isn't a resource-field update — not a state transition a `PATCH` can express — a **custom method** (`POST /{resource}:verb`) is the disciplined fallback, not a return to free-floating verb endpoints. See `references/advanced-resource-patterns.md`.

---

## HTTP Method → Command/Query Mapping

| HTTP Method | Semantics | Maps to |
|---|---|---|
| `POST` | Create a new resource or trigger an action | Command |
| `PUT` | Replace an existing resource entirely | Command |
| `PATCH` | Partially update an existing resource | Command |
| `DELETE` | Remove a resource | Command |
| `GET` | Read a resource or collection | Query → Read Model |

Every Command from the Command Catalog maps to a `POST`, `PUT`, `PATCH`, or `DELETE` endpoint. Every Read Model query maps to a `GET` endpoint. An omitted field in a `PATCH` body means "leave unchanged" — for resources with many optional fields, an explicit field mask removes the ambiguity; see `references/advanced-resource-patterns.md`.

---

## Standard Response Shapes

**Success responses:**

| Status | When |
|---|---|
| `200 OK` | Successful GET, PUT, PATCH |
| `201 Created` | Successful POST that creates a resource |
| `202 Accepted` | Command accepted for async processing — the body returns the resource ID and a status URL pointing to a fully-specified `Operation` resource (`references/advanced-resource-patterns.md`); the domain outcome also arrives via a Domain Event |
| `204 No Content` | Successful DELETE, or action with no response body |

**Error responses** — all use the standard `ErrorResponse` envelope — a top-level `error` object carrying a machine-readable `code` (SCREAMING_SNAKE_CASE, e.g. `DATA_ASSET_NOT_FOUND`), a human-readable `message` suitable for display, and an optional `details` array of field-level validation errors (`{field, message}`). Full schema: `references/openapi-spec-structure-example.md`.

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

`409 Conflict` here is a business-rule violation, not a lost-update collision between two concurrent writers — for resources with real concurrent-writer risk, pair it with the resource-revisions (`ETag`/`If-Match`) mechanism in `references/advanced-resource-patterns.md`, which detects the latter.

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

All endpoints (except health checks) require JWT Bearer authentication — a global `security: [BearerAuth: []]` paired with a `BearerAuth` HTTP bearer scheme (`bearerFormat: JWT`) declared in `components/securitySchemes`. Full definition: `references/openapi-spec-structure-example.md`.

The JWT is validated by the API Gateway / middleware before the request reaches any handler. Handler code never validates JWTs — it reads claims from context.

Health check endpoints (`GET /healthz`, `GET /readyz`) are excluded from authentication.

---

## Idempotency Header

All `POST`, `PUT`, and `PATCH` requests must support an `Idempotency-Key` header — an optional client-generated UUID v4. The server stores the result for 24 hours and returns the stored result if the same key is seen again. Declared once as a reusable `components/parameters/IdempotencyKey` entry and `$ref`'d on every mutating endpoint rather than repeated inline; full definition in `references/openapi-spec-structure-example.md`.

---

## Pagination, Filtering, and Sorting

Collection endpoints share one convention — never invent a per-endpoint variant:

- **Cursor pagination is the default.** `?cursor=[opaque token]&limit=[n]` with `limit` capped (default 25, max 100). The response's `pagination` object carries `nextCursor` (null on the last page). Cursors are opaque to clients — encode the sort key position server-side, never a raw offset. Offset pagination (`?page=3`) is permitted only for small, stable admin collections: on large or frequently-written collections it skips or duplicates rows as data moves between pages.
- **Filters are named query parameters** using canonical field names: `?sensitivityLevel=Restricted&storageSourceId=...`. Multiple values repeat the parameter. Every filterable field is declared in the spec — undocumented filters do not exist.
- **Sorting:** `?sort=classifiedAt&order=desc`. Only fields the Read Model indexes are sortable; the spec enumerates them.
- **Stable ordering is a contract.** Every paginated response has a deterministic total order (sort field plus ID tiebreaker); otherwise cursors are meaningless.

Named-query-parameter filtering (rather than a single filter-expression-string parameter) is a deliberate choice: simpler to implement, simpler to validate against undocumented filters, and simpler for a non-programmer PM to review in a spec. Do not "fix" this to match a filter-expression-string convention absent a concrete need for compound/boolean filter logic — see `references/advanced-resource-patterns.md`'s Caveats-equivalent note for the full reasoning.

---

## OpenAPI Spec Structure

Top-level shape: `openapi` version, `info`, `servers` (with the `tenantId` path variable for physical multi-tenancy routing), global `security`, `tags`, `paths`, and `components` (`schemas` plus `securitySchemes`). Full worked example, including a complete `paths` entry and its referenced schemas: `references/openapi-spec-structure-example.md`.

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
| Pagination convention | All collection endpoints use the shared cursor pagination shape | Per-endpoint pagination variants, or uncapped `limit` |
| Async operations resolvable | Every `202 Accepted` status URL returns a fully-specified `Operation` resource | A "status URL" with no documented response shape |
| Custom methods disciplined | Any `resource:verb` endpoint is a genuine non-CRUD action, not a CRUD workaround | Custom methods used where a standard method or resource-field update would fit |
| Concurrency-sensitive resources revisioned | Resources with real concurrent-writer risk carry `etag`/`If-Match` | Silent lost updates on a resource multiple clients can write concurrently |

---

## API Contract Review Checklist

Before treating a contract as ready for the Design phase gate, run one deliberate review pass over the finished spec — `enterprise-architect` is the sole author of every contract this factory produces, so the consistency a governance board would enforce still applies, just as a self-imposed gate. The checklist inherits every row from the Quality Criteria table above and adds no new criteria; a contract that fails any row is not ready for the Design phase gate regardless of how much of the spec is otherwise written. Full checklist: `references/contract-review-checklist.md`.

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Code-first contract** — generating the OpenAPI spec from handler annotations after implementation | The contract describes whatever got built; breaking changes ship silently because nothing gates them | Spec is written first, reviewed, and CI-validated; code is generated from or validated against it |
| **CRUD-over-tables API** — `POST /v1/data-asset-rows`, one endpoint per database table | The schema leaks into the contract; every migration becomes a breaking API change | Resources mirror the Ubiquitous Language and the Command Catalog, not storage |
| **Verb endpoints** — `POST /v1/classifyDataAsset` | Verbs proliferate without structure; caching, permissions, and tooling conventions all assume nouns | Commands map onto resource state transitions: `PATCH /v1/data-assets/{id}/classification` |
| **The 200-with-error-body** — errors returned as `200 OK` with `{"success": false}` | Clients, gateways, retries, and monitoring all key on status codes; errors become invisible | Correct 4xx/5xx status plus the standard ErrorResponse envelope |
| **Tunnelling through GET** — `GET /v1/data-assets/{id}/reclassify` | GET must be safe and cacheable; proxies may prefetch or retry it, mutating state unpredictably | Mutations use POST/PUT/PATCH/DELETE, always |
| **Chatty resource design** — a detail view requiring N follow-up calls per item | Front ends compensate with request storms; latency and rate limits are hit immediately | Shape the Read Model (and its GET response) to serve the whole view in one call |
| **Internal errors in responses** — stack traces, SQL, or Go error strings in `message` | Leaks implementation detail and creates an unintended contract that clients parse | `500` returns `INTERNAL_ERROR` with a correlation ID; detail goes to logs and traces |
| **Sunset by surprise** — deleting `/v1/` when `/v2/` ships | Every consumer breaks at once; trust in the contract collapses | Parallel-run with `Deprecation` headers and the announced 6-month minimum sunset |

---

## Scripts

Per `skill-authoring-standards`, this skill owns two deterministic scripts — neither decides whether an API contract is *good*, only whether the contract summary document is structurally complete, leaving judgment (are the resources actually well-named, is a custom method genuinely warranted) to the enterprise-architect's own review.

| Script | Does | Run when |
|---|---|---|
| `scripts/scaffold-api-contract-design.sh <product> <service-name>` | Copies `assets/api-contract-summary-template.md`, fills in product/service/date metadata, writes a new contract summary doc | Starting API contract design for a service |
| `scripts/validate-api-contract-design.sh <path>` | Checks required frontmatter, presence of all three Output Format sections, and that the Endpoints table has at least one real data row beyond its header | Before treating the contract as ready for the Design phase gate |

---

## Output Format

The primary output is the `api/openapi.yaml` file in the service repository: `artifacts/[product]/design/[service-name]/openapi.yaml`, per `references/openapi-spec-structure-example.md`.

Accompanied by a contract summary — fill-in-and-go: `assets/api-contract-summary-template.md` (or generate it directly via `scripts/scaffold-api-contract-design.sh`). Annotated template explaining each field: `references/output-format-template.md`. Mechanical completeness check: `scripts/validate-api-contract-design.sh`.
