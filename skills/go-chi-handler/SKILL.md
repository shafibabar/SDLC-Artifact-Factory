---
name: go-chi-handler
description: >
  Teaches how to implement HTTP handlers with net/http + chi as the transport
  edge — route registration mirroring the OpenAPI contract, the exact
  json.Decoder configuration for request decoding (DisallowUnknownFields,
  http.MaxBytesReader size limiting, Content-Type enforcement), the complete
  decode-error-to-HTTP-status mapping table for every encoding/json failure
  mode, the response-encoding standard (Content-Type header ordering relative
  to WriteHeader, the success envelope), the precise structural-vs-domain
  validation boundary, the canonical ErrorResponse envelope and error-message
  content standards (no leaked internals, consistent code/message/fields/
  traceId), mapping domain errors to HTTP status via a single error writer,
  and keeping handlers thin (decode → validate → call → encode) as an
  instance of Clean Architecture's Humble Object pattern. Implements the
  enterprise-architect's api-contract-design. Full worked handler code is in
  references/worked-handler-examples.md; the complete decode/encode/error
  standard is in references/request-response-standard.md. Used by the
  backend-engineer during Implement.
version: 2.1.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, chi, net-http, handler, dto, validation, error-mapping, json]
produces: go-http-handler
domain: backend
status: stable
related: [go-error-handling, go-middleware, go-domain-model, go-service-layer, go-project-structure, go-service-skeleton, health-check-design, api-contract-design]
---

# Go chi Handler

## Purpose

The HTTP handler is the transport edge. Its only job is to translate between HTTP and the application layer: decode the request, validate its structure, call the relevant command/query handler, and encode the result (or map the error). It contains no business logic and no persistence — it is a thin, boring, predictable adapter. Boring transport code is correct transport code.

**This is Robert C. Martin's Humble Object pattern, applied at the HTTP boundary.** The handler is the humble object: thin, and deliberately not unit-tested in isolation for business behaviour — it is verified only via `httptest` integration-style tests that exercise it as a real HTTP request/response round trip. The business decisions it delegates to are fully unit-tested one layer in, in `go-service-layer`'s command/query handlers and `go-domain-model`'s Aggregates. This skill owns the handler function body itself — the general error-wrapping/taxonomy standard is `go-error-handling`'s, and the middleware chain around the handler (auth, rate limiting, CORS, panic recovery) is `go-middleware`'s.

---

## Route Registration Conventions

Routes mirror the OpenAPI contract path-for-path — a route present in one but not the other is contract drift, not a style choice. Resource paths are plural nouns (`/v1/data-assets`); HTTP methods map to intent (`GET` read, `POST` create, `PATCH` partial update, `DELETE` remove — `PUT` full-replace only where the contract genuinely models one); sub-actions are nested path segments (`/{id}/classification`), never verbs in the path. The router is built once, in `internal/handlers/http/router.go`, and handed the already-constructed application handlers — it never constructs a repository, a pool, or anything infrastructure-owned (that belongs to `go-service-skeleton`'s composition root). Health/readiness routes are mounted on a separate, unauthenticated router entirely (`health-check-design`), never nested under a `/v1` group that passes through `mw.Authenticate`. Full worked router: `references/worked-handler-examples.md`.

Mutation routes read an optional `Idempotency-Key` request header and pass it through unexamined to the command — the handler's only job is to forward it; the idempotency store that dedupes on it is `go-service-layer`'s concern, not this skill's.

---

## Handler Shape: Decode → Validate → Call → Encode

Every handler follows the same four steps: decode the path/body against the standard below, run structural validation, call the application layer with `r.Context()`, then encode the result through the same standard. The `ClassifyDataAsset` mutation handler is the canonical worked example — decode → validate → call `a.classify.Handle` → `204 No Content`, mapping any error through the single `writeDomainError` point. Full code: `references/worked-handler-examples.md`.

---

## Request Decoding Standard

Every handler decodes through one shared `decodeJSON`, never `json.Unmarshal`/`json.NewDecoder` called ad hoc per handler:

```go
r.Body = http.MaxBytesReader(w, r.Body, maxRequestBodyBytes) // size cap — DoS protection
dec := json.NewDecoder(r.Body)
dec.DisallowUnknownFields()                                  // reject typos/stale fields, don't silently ignore
```

Three things happen before the domain ever sees the body: **Content-Type is checked** (reject non-`application/json` with 415 before parsing a byte), **the body is size-capped** via `MaxBytesReader` (never an unbounded read), and **unknown fields are rejected** rather than silently dropped. Every failure mode this can produce — malformed syntax, wrong field type, empty body, unknown field, oversized body, trailing data — is named and mapped to an exact HTTP status and error code in one table, not reinvented per handler. Full `decodeJSON` implementation and the complete mapping table: `references/request-response-standard.md`.

---

## Response Encoding Standard

Every 2xx response goes through one shared `writeJSON`, and the header-ordering rule is unconditional: **`w.Header().Set(...)` always happens before `w.WriteHeader(status)`, with no exceptions** — `WriteHeader` flushes the header block, so anything set afterward is silently discarded, not an error, not a warning on the wire. A success body uses the same envelope discipline as errors: a single top-level named key (`dataAssetsResponse{DataAssets: [...]}`), never a bare array or object, so a later field (pagination metadata, a `next` link) extends the response without breaking a client that reads the named key. Full `writeJSON`, the broken-ordering counter-example, and the query-handler worked example: `references/request-response-standard.md` and `references/worked-handler-examples.md`.

---

## Structural Validation at the Boundary

The handler validates **shape only** — types, formats, required fields, enum membership, ranges — answerable from the request bytes alone, and returns every violation in one pass. The instant answering a question requires the aggregate's current state, another aggregate, or the caller's permissions, it is domain validation and belongs to the Aggregate (`go-domain-model`), never duplicated in the handler by reaching into a repository "just to check." Full boundary table with the rule of thumb and cardinality contrast (all-at-once vs. one-business-rule-at-a-time): `references/request-response-standard.md`.

---

## Error Response Standard

Every error response — decode failure, validation failure, domain error, unmapped 500 — uses one `ErrorResponse` envelope: `code` (machine-matchable, `SCREAMING_SNAKE_CASE`), `message` (human-readable, safe to log or show), `fields` (populated only for structural validation, all failures at once), `traceId` (read from `r.Context()`, correlates to `go-middleware`'s `RequestID`/span). The message-content rule is absolute: **4xx messages may be specific — they describe the client's own request — 5xx messages are always the same opaque sentence; internals (SQL, stack traces, file paths, driver strings) go to the log with the trace id, never the body.** Domain errors map to status through exactly one `writeDomainError` switch — one category, one status, never scattered per handler. Full envelope shape, message-standard rules, and the category→status table: `references/request-response-standard.md`.

---

## Quality Criteria

| Criterion | Pass | Fail | How to verify |
|---|---|---|---|
| Thin handler | Decode/validate/call/encode only | Business logic, SQL, or event publishing inline | Read the handler body; anything past the four steps is a defect |
| Route/contract parity | Every router entry matches an OpenAPI path+method, and vice versa | A route with no contract entry, or a contract path never registered | Diff `router.go`'s routes against `api/openapi.yaml`'s paths |
| Content-Type enforced | Non-JSON bodies rejected 415 before parsing | Parser invoked on an unchecked body | `decodeJSON`'s Content-Type check runs first |
| Body size capped | `http.MaxBytesReader` on every decode path | Any handler reading `r.Body` unwrapped | `grep -rn "r.Body =" internal/handlers/http` — every hit wraps in `MaxBytesReader` |
| Unknown fields rejected | `dec.DisallowUnknownFields()` set | Decoder accepts stray/typo'd fields silently | Same decoder construction, one call site |
| Every decode-error path mapped | All rows of `request-response-standard.md`'s table produce a distinct code/status | A `default:`-only decode handler, or a bare 400 with no code | Table row × integration test — one `httptest` case per row |
| Header ordering held | `Header().Set` precedes every `WriteHeader` call | A header set after `WriteHeader` (silently dropped) | Read every response-writing function top to bottom for the two-line order |
| Structural/domain boundary held | `validate()` never calls a repository or checks aggregate state | A repository call inside request-DTO validation | Read `validate()`'s imports — no `domain.*Repository` reachable |
| Single error mapping | Domain errors mapped in one `writeDomainError`; decode errors in one `writeDecodeError` | Status codes scattered/inlined per handler | `grep -rn "WriteHeader(http.Status" internal/handlers/http` — only inside the two mapping functions and `writeJSON` |
| Envelope uniformity | Every error response is the one `ErrorResponse` shape | A bespoke shape for one error type | Read every `write*Error` call site's target type |
| No leaked internals | 5xx `message` is always the opaque sentence | SQL/stack trace/driver text in a response body | Grep response-writing code for `err.Error()` reaching a 5xx `message` field |
| `traceId` populated | Present on every error response when available | Empty/hardcoded `traceId` | Integration test asserts a non-empty `traceId` on an induced error |
| Context propagation | `r.Context()` passed inward | `context.Background()` in a handler | `grep -rn "context.Background()" internal/handlers/http` — no hits |

---

## Anti-Patterns

- **`uuid.MustParse` (or any `Must*`) on request-derived data** — a panic on untrusted input turns a bad request into a crash-inducing DoS vector. Parse with the error-returning form and map the failure to 400.
- **Ad hoc `json.Unmarshal`/`json.NewDecoder` per handler** — bypasses the shared size cap, `DisallowUnknownFields`, and the error-mapping table; every decode path must be `decodeJSON`.
- **Header set after `WriteHeader`** — silently discarded, not an error; the classic footgun that ships a response with the wrong (or missing) `Content-Type`.
- **Per-handler status logic** — `w.WriteHeader(409)` scattered through handlers instead of the single `writeDomainError`/`writeDecodeError` mapping points.
- **Business logic in `validate()`** — a structural-validation method that queries a repository or checks aggregate state has quietly become domain validation in the wrong layer, and now two places can disagree about the same rule.
- **Echoing internal errors in 5xx bodies** — stack traces and driver errors leak schema and infrastructure details; log them with the trace id, return the opaque envelope.
- **A bespoke error shape "just for this one case"** — a rate-limit or upload-size error that isn't the standard `ErrorResponse` breaks the client's single parsing path.
- **`context.Background()` inside a handler** — severs the trace, the tenant, and the deadline. Always `r.Context()`.

---

## Output Format

Produces Go source built exactly to the standards above — not a file listing to fill in freely — plus handler tests using `net/http/httptest` written first, one case per row of the decode-error and domain-error mapping tables:

```
internal/handlers/http/router.go
internal/handlers/http/decode.go               (decodeJSON, classifyDecodeError)
internal/handlers/http/errors.go               (ErrorResponse, writeError/writeDecodeError/writeDomainError)
internal/handlers/http/classify_data_asset.go
internal/handlers/http/classify_data_asset_test.go
```

Full worked handler code (route registration, mutation, validation, query, error switch): `references/worked-handler-examples.md`. Full decode/encode/validation-boundary/error-response standard: `references/request-response-standard.md`.
