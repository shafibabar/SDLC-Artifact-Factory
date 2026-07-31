# Worked Handler Examples

Full worked code referenced from `SKILL.md`'s "Route Registration Conventions", "Handler Shape", "Structural Validation at the Boundary", "Response Encoding Standard", and "Error Response Standard" sections — route registration, the mutation handler, the structural-validation method, the query handler, and the error-mapping switch, in full. The `json.Decoder` configuration, the complete decode-error mapping table, and the `ErrorResponse` envelope's exact shape are in the sibling `references/request-response-standard.md` — this file is the handler bodies that call into that standard, not the standard itself.

---

## Route Registration

```go
// internal/handlers/http/router.go
package http

func NewRouter(classify *commands.ClassifyDataAssetHandler, list *queries.ListDataAssetsHandler, mw Middleware) http.Handler {
    r := chi.NewRouter()

    r.Use(mw.RequestID)        // correlation id — see go-middleware
    r.Use(mw.Recoverer)        // panic isolation (see go-error-handling / go-middleware)
    r.Use(mw.Telemetry)        // trace span + RED metrics per request
    r.Use(mw.Logger)           // slog with trace correlation
    r.Use(mw.SecurityHeaders)
    r.Use(mw.CORS)
    r.Use(mw.Authenticate)     // JWT → Subject + tenant in context
    r.Use(mw.RateLimit)

    // Health/readiness routes are mounted OUTSIDE this router entirely — see
    // go-service-skeleton / health-check-design; probes never carry a JWT.

    r.Route("/v1/data-assets", func(r chi.Router) {
        r.Get("/", h(list.HandleHTTP))                          // GET    /v1/data-assets
        r.Get("/{id}", h(get.HandleHTTP))                        // GET    /v1/data-assets/{id}
        r.Patch("/{id}/classification", h(classify.HandleHTTP)) // PATCH  /v1/data-assets/{id}/classification
    })
    return r
}
```

The route table mirrors the OpenAPI contract path-for-path (`api-contract-design`) — a route that exists in the contract but not here, or vice versa, is a contract-drift defect, not a style choice. `h()` adapts a handler method to `http.HandlerFunc`; it is a thin type-conversion helper, never a place to inject cross-cutting behavior (that belongs to `mw.*` above it).

---

## Handler Shape: Decode → Call → Encode (mutation)

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
    if err := decodeJSON(w, r, &req); err != nil { // see references/request-response-standard.md
        writeDecodeError(w, r, err)
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

## Structural Validation: `classifyRequest.validate()`

The full worked example of the boundary rule in `SKILL.md`'s "Structural Validation at the Boundary" and `references/request-response-standard.md`'s comparison table — shape only, no business rule, all failures collected in one pass:

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

func writeValidationError(w http.ResponseWriter, r *http.Request, verrs []ValidationError) {
    writeErrorWithFields(w, r, http.StatusBadRequest, "VALIDATION_FAILED", "the request failed validation", verrs)
}
```

Note what this method does **not** do: it never calls a repository, never checks the asset's current sensitivity, never checks the caller's permissions. Every one of those questions requires state beyond the request body and belongs to `domain.DataAsset.Classify(...)`, called in step 3 above — see the boundary table in `references/request-response-standard.md`.

---

## Success Response: Query Handler

The mutation example above returns `204 No Content` — no body. A query handler does return a body, using the same envelope discipline as `ErrorResponse`: a single top-level named key, never a bare array or object, so a later addition (pagination metadata, a `next` link) extends the envelope without breaking existing clients that read the named key.

```go
// internal/handlers/http/list_data_assets.go

type dataAssetResponse struct {
    ID               string `json:"id"`
    SensitivityLevel string `json:"sensitivityLevel"`
}

type dataAssetsResponse struct {
    DataAssets []dataAssetResponse `json:"dataAssets"`
}

func (a *API) ListDataAssets(w http.ResponseWriter, r *http.Request) {
    assets, err := a.list.Handle(r.Context(), queries.ListDataAssets{})
    if err != nil {
        writeDomainError(w, r, err)
        return
    }

    resp := make([]dataAssetResponse, len(assets))
    for i, da := range assets {
        resp[i] = dataAssetResponse{
            ID:               da.ID.String(),
            SensitivityLevel: string(da.Sensitivity),
        }
    }

    writeJSON(w, r, http.StatusOK, dataAssetsResponse{DataAssets: resp})
}

// writeJSON is the success-path counterpart to writeDomainError: sets Content-Type
// BEFORE WriteHeader (see references/request-response-standard.md's header-ordering
// rule), writes the status, and encodes the body — the one place a 2xx response is built.
func writeJSON(w http.ResponseWriter, r *http.Request, status int, v any) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(status)
    if err := json.NewEncoder(w).Encode(v); err != nil {
        slog.ErrorContext(r.Context(), "encoding response", "err", err)
    }
}
```

---

## One Error Mapping Point (full switch)

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
        // Unknown error: log with trace id, return opaque 500 (never echo internals —
        // see request-response-standard.md's Error Message Standards).
        slog.ErrorContext(r.Context(), "unhandled error", "err", err)
        writeError(w, r, http.StatusInternalServerError, "INTERNAL", "an unexpected error occurred")
    }
}

// writeError and writeErrorWithFields build the canonical ErrorResponse envelope
// (references/request-response-standard.md), reading traceId from r.Context() —
// never a hardcoded or empty string.
func writeError(w http.ResponseWriter, r *http.Request, status int, code, message string) {
    writeErrorWithFields(w, r, status, code, message, nil)
}

func writeErrorWithFields(w http.ResponseWriter, r *http.Request, status int, code, message string, fields []ValidationError) {
    var resp ErrorResponse
    resp.Error.Code = code
    resp.Error.Message = message
    resp.Error.Fields = fields
    resp.Error.TraceID = middleware.GetReqID(r.Context()) // or span.SpanContext().TraceID() — see go-middleware
    writeJSON(w, r, status, resp)
}
```
