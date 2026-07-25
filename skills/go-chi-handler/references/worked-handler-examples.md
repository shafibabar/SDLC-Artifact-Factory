# Worked Handler Examples

Full worked code referenced from `SKILL.md`'s "Handler Shape", "Success Response: Query Handler", and "One Error Mapping Point" sections — the mutation handler, the query handler, and the error-mapping switch in full.

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

// writeJSON is the success-path counterpart to writeDomainError: sets Content-Type,
// writes the status, and encodes the body — the one place a 2xx response is built.
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
        // Unknown error: log with trace id, return opaque 500 (never echo internals).
        slog.ErrorContext(r.Context(), "unhandled error", "err", err)
        writeError(w, r, http.StatusInternalServerError, "INTERNAL", "an unexpected error occurred")
    }
}
```
