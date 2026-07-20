---
name: go-chi-handler
description: >
  Teaches how to implement HTTP handlers with net/http + chi — routing from the
  OpenAPI contract, request DTO decoding and structural validation, mapping the
  application layer's domain errors to HTTP status codes via a single error
  writer, the standard error envelope, context propagation, and keeping handlers
  thin (decode → call handler → encode). Implements the enterprise-architect's
  api-contract-design. Used by the backend-engineer during Implement.
version: 1.1.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, chi, net-http, handler, dto, validation, error-mapping]
---

# Go chi Handler

## Purpose

The HTTP handler is the transport edge. Its only job is to translate between HTTP and the application layer: decode the request, validate its structure, call the relevant command/query handler, and encode the result (or map the error). It contains no business logic and no persistence — it is a thin, boring, predictable adapter. Boring transport code is correct transport code.

This implements the routes and contracts from `api-contract-design` using `net/http` + `chi` (chosen for transparency over magic frameworks — see the tech-stack defaults).

---

## Router

Routes mirror the OpenAPI contract. Middleware is layered outermost-to-innermost (see `go-middleware`). The router is constructed in one place and handed the application handlers it needs.

```go
// internal/handlers/http/router.go
package http

func NewRouter(classify *commands.ClassifyDataAssetHandler, list *queries.ListDataAssetsHandler, mw Middleware) http.Handler {
    r := chi.NewRouter()

    r.Use(mw.RequestID)        // correlation id
    r.Use(mw.Recoverer)        // panic isolation (see go-error-handling / go-middleware)
    r.Use(mw.Telemetry)        // trace span + RED metrics per request
    r.Use(mw.Logger)           // slog with trace correlation
    r.Use(mw.SecurityHeaders)
    r.Use(mw.Authenticate)     // JWT → Subject + tenant in context
    r.Use(mw.RateLimit)

    r.Route("/v1/data-assets", func(r chi.Router) {
        r.Get("/", h(list.HandleHTTP))                          // GET    /v1/data-assets
        r.Patch("/{id}/classification", h(classify.HandleHTTP)) // PATCH  /v1/data-assets/{id}/classification
    })
    return r
}
```

---

## Handler Shape: Decode → Call → Encode

```go
// internal/handlers/http/classify_data_asset.go

type classifyRequest struct {
    SensitivityLevel string `json:"sensitivityLevel"`
    ClassifiedBy     string `json:"classifiedBy"`
}

func (a *API) ClassifyDataAsset(w http.ResponseWriter, r *http.Request) {
    // 1. Path + body decode
    id, err := uuid.Parse(chi.URLParam(r, "id"))
    if err != nil {
        writeError(w, r, http.StatusBadRequest, "INVALID_ID", "data asset id must be a UUID")
        return
    }
    var req classifyRequest
    if err := decodeJSON(w, r, &req); err != nil {
        writeError(w, r, http.StatusBadRequest, "INVALID_BODY", err.Error())
        return
    }

    // 2. Structural validation (all errors at once — see go-error-handling)
    if verrs := req.validate(); len(verrs) > 0 {
        writeValidationError(w, r, verrs)
        return
    }

    // 3. Call the application layer — pass the request context (carries tenant, span, deadline)
    // Never uuid.MustParse request data — a panic on untrusted input is a DoS vector.
    // validate() already shape-checked this field, but the parse here still returns an error.
    classifiedBy, err := uuid.Parse(req.ClassifiedBy)
    if err != nil {
        writeError(w, r, http.StatusBadRequest, "INVALID_BODY", "classifiedBy must be a UUID")
        return
    }
    cmd := commands.ClassifyDataAsset{
        DataAssetID:    id,
        Sensitivity:    domain.SensitivityLevel(req.SensitivityLevel),
        ClassifiedBy:   classifiedBy,
        IdempotencyKey: r.Header.Get("Idempotency-Key"),
    }
    if err := a.classify.Handle(r.Context(), cmd); err != nil {
        writeDomainError(w, r, err) // single mapping point — see below
        return
    }

    // 4. Encode the result
    w.WriteHeader(http.StatusNoContent)
}
```

---

## Structural Validation at the Boundary

The handler validates **shape** (types, formats, required, ranges) and returns every error in one response. Business validation (e.g., "can't downgrade sensitivity") belongs to the Aggregate, not here (two-layer validation — see `command-catalog`).

```go
func (r classifyRequest) validate() []ValidationError {
    var v []ValidationError
    if !domain.SensitivityLevel(r.SensitivityLevel).IsValid() {
        v = append(v, ValidationError{Field: "sensitivityLevel",
            Message: "must be one of: Public, Internal, Confidential, Restricted"})
    }
    if _, err := uuid.Parse(r.ClassifiedBy); err != nil {
        v = append(v, ValidationError{Field: "classifiedBy", Message: "must be a UUID"})
    }
    return v
}
```

`decodeJSON` rejects unknown fields and bodies that are too large:

```go
func decodeJSON(w http.ResponseWriter, r *http.Request, dst any) error {
    r.Body = http.MaxBytesReader(w, r.Body, 1<<20) // 1 MiB cap — DoS protection
    dec := json.NewDecoder(r.Body)
    dec.DisallowUnknownFields()
    return dec.Decode(dst)
}
```

---

## One Error Mapping Point

Domain errors are mapped to HTTP status codes in exactly one place, using `errors.Is`/`errors.As` (see `go-error-handling`). Handlers never build status logic inline — they call `writeDomainError`.

```go
func writeDomainError(w http.ResponseWriter, r *http.Request, err error) {
    switch {
    case errors.Is(err, domain.ErrNotFound):
        writeError(w, r, http.StatusNotFound, "NOT_FOUND", "resource not found")
    case errors.Is(err, commands.ErrUnauthenticated):
        writeError(w, r, http.StatusUnauthorized, "AUTHENTICATION_REQUIRED", "authentication required")
    case errors.Is(err, domain.ErrForbidden):
        writeError(w, r, http.StatusForbidden, "FORBIDDEN", "not permitted") // never leak why
    case errors.Is(err, domain.ErrConcurrentModification):
        writeError(w, r, http.StatusConflict, "CONFLICT", "resource was modified concurrently")
    case errors.Is(err, domain.ErrInvalidSensitivity):
        writeError(w, r, http.StatusUnprocessableEntity, "UNPROCESSABLE", err.Error())
    default:
        // Unknown error: log with trace id, return opaque 500 (never echo internals).
        slog.ErrorContext(r.Context(), "unhandled error", "err", err)
        writeError(w, r, http.StatusInternalServerError, "INTERNAL", "an unexpected error occurred")
    }
}
```

---

## Standard Error Envelope

Every error response uses the same envelope from `api-contract-design`:

```go
type ErrorResponse struct {
    Error struct {
        Code    string            `json:"code"`
        Message string            `json:"message"`
        Fields  []ValidationError `json:"fields,omitempty"`
        TraceID string            `json:"traceId,omitempty"` // for support correlation
    } `json:"error"`
}
```

The `traceId` lets a user quote it to support, who can pull the exact trace — observability and UX in one field.

---

## Rules

- **Thin.** Decode, validate, call, encode. No SQL, no business rules.
- **Pass `r.Context()`** to the application layer — never `context.Background()`.
- **Never echo internals.** 500s are opaque; the detail goes to the log with the trace id.
- **`ReadHeaderTimeout` is set on the server** (see `go-service-skeleton`) — handlers assume bounded bodies via `MaxBytesReader`.
- **Status codes come from the contract** — the mapping point is the single source of truth.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Thin handler | Decode/validate/call/encode only | Business logic or SQL in the handler |
| Structural validation | Shape validated at the boundary, all errors at once | Validation mixed with business rules or one-at-a-time |
| Single error mapping | Domain errors mapped in one `writeDomainError` | Status codes scattered/inlined per handler |
| Context propagation | `r.Context()` passed inward | `context.Background()` in handlers |
| Opaque 500s | Internal errors logged with trace id, generic body | Internal error details returned to the client |
| Body limits | `MaxBytesReader` + `DisallowUnknownFields` | Unbounded bodies / silent extra fields |

---

## Anti-Patterns

- **`uuid.MustParse` (or any `Must*`) on request-derived data** — a panic on untrusted input turns a bad request into a crash-inducing DoS vector. Parse with the error-returning form and map the failure to 400.
- **Fat handlers** — business rules, SQL, or event publishing inline. The handler is an adapter; the Aggregate and application layer own behaviour.
- **Per-handler status logic** — `w.WriteHeader(409)` scattered through handlers instead of the single `writeDomainError` mapping point.
- **Swallowing the decode error detail** — returning a bare 400 with no field information forces clients to guess; return every structural error at once.
- **`context.Background()` inside a handler** — severs the trace, the tenant, and the deadline. Always `r.Context()`.
- **Echoing internal errors in 500 bodies** — stack traces and driver errors leak schema and infrastructure details; log them, return the opaque envelope.

---

## Output Format

Produces Go source plus handler tests using `net/http/httptest`:

```
internal/handlers/http/router.go
internal/handlers/http/classify_data_asset.go
internal/handlers/http/errors.go               (writeError / writeDomainError / envelope)
internal/handlers/http/classify_data_asset_test.go   (httptest; written first)
```
