# Skill: implement/api-implementation-guide

## Purpose
Produce the API Implementation Guide — the developer-facing reference for how to correctly implement HTTP handlers in this product. Covers request decoding, validation, command dispatch, response encoding, error mapping, and observability wiring. Every handler in every service follows this guide.

## Inputs
- `artifacts/implement/standards/coding-standards.md`
- `artifacts/design/contracts/{service}-api.md` (one per service)
- `sdlc-config.json`

## Output
**File:** `artifacts/implement/guides/api-implementation-guide.md`
**Registers in manifest:** yes

## Artifact Template

```markdown
# API Implementation Guide

**Product:** {product_name}
**Phase:** Implement
**Artifact:** API Implementation Guide
**Language:** Go / net/http + chi
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Handler Anatomy

Every HTTP handler follows this exact structure. Do not deviate:

```
Request → Decode → Validate → Command/Query → Execute → Encode Response
             ↓ (error)    ↓ (error)               ↓ (error)
          400           422                    domain-specific 4xx / 500
```

---

## Standard Handler Template

```go
// RegisterStorageLocation handles POST /api/v1/file/storage-locations
func RegisterStorageLocation(h *commands.RegisterStorageLocationHandler) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        ctx := r.Context()

        // 1. Extract tenant from context (set by TenantScope middleware)
        tenantID := middleware.TenantIDFromContext(ctx)

        // 2. Decode request body
        var req RegisterStorageLocationRequest
        if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
            writeProblem(w, http.StatusBadRequest, "INVALID_REQUEST_BODY",
                "Request body could not be decoded as JSON", r.URL.Path)
            return
        }

        // 3. Validate input
        if err := req.Validate(); err != nil {
            writeProblem(w, http.StatusUnprocessableEntity, err.Code, err.Message, r.URL.Path)
            return
        }

        // 4. Build command
        cmd := commands.RegisterStorageLocationCommand{
            TenantID:        tenantID,
            StoragePath:     req.StoragePath,
            Platform:        domain.StoragePlatform(req.Platform),
            CredentialRef:   req.CredentialRef,
            ScanConfig:      req.ScanConfiguration.toDomain(),
        }

        // 5. Execute command
        result, err := h.Handle(ctx, cmd)
        if err != nil {
            handleDomainError(w, err, r.URL.Path)
            return
        }

        // 6. Encode response
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusCreated)
        json.NewEncoder(w).Encode(RegisterStorageLocationResponse{
            StorageLocationID: result.ID,
            Status:            string(result.Status),
            CreatedAt:         result.CreatedAt,
        })
    }
}
```

---

## Domain Error → HTTP Status Mapping

All services use the same error mapping function. Never return raw domain errors to callers:

```go
func handleDomainError(w http.ResponseWriter, err error, instance string) {
    switch {
    case errors.Is(err, domain.ErrDuplicateStorageLocation):
        writeProblem(w, http.StatusConflict, "ALREADY_EXISTS",
            "A storage location with this path already exists for this tenant", instance)
    case errors.Is(err, domain.ErrWriteScopeCredential):
        writeProblem(w, http.StatusUnprocessableEntity, "WRITE_SCOPE_REJECTED",
            "The credential must have read-only scope", instance)
    case errors.Is(err, domain.ErrStorageLocationNotFound):
        writeProblem(w, http.StatusNotFound, "NOT_FOUND",
            "The storage location was not found", instance)
    case errors.Is(err, domain.ErrScanInProgress):
        writeProblem(w, http.StatusConflict, "SCAN_IN_PROGRESS",
            "A scan is already in progress for this location", instance)
    case errors.Is(err, domain.ErrLocationDeregistered):
        writeProblem(w, http.StatusConflict, "LOCATION_DEREGISTERED",
            "The storage location has been deregistered", instance)
    default:
        slog.ErrorContext(r.Context(), "unhandled domain error", "error", err)
        writeProblem(w, http.StatusInternalServerError, "INTERNAL_ERROR",
            "An unexpected error occurred", instance)
    }
}
```

---

## RFC 7807 Problem Details Writer

```go
type Problem struct {
    Type     string `json:"type"`
    Title    string `json:"title"`
    Status   int    `json:"status"`
    Detail   string `json:"detail"`
    Instance string `json:"instance"`
    TraceID  string `json:"trace_id,omitempty"`
}

func writeProblem(w http.ResponseWriter, status int, code, detail, instance string) {
    w.Header().Set("Content-Type", "application/problem+json")
    w.WriteHeader(status)
    json.NewEncoder(w).Encode(Problem{
        Type:     "https://{product-domain}/problems/" + strings.ToLower(code),
        Title:    codeToTitle(code),
        Status:   status,
        Detail:   detail,
        Instance: instance,
    })
}
```

---

## Request Validation Pattern

Each request type implements `Validate() *ValidationError`:

```go
type RegisterStorageLocationRequest struct {
    StoragePath       string             `json:"storage_path"`
    Platform          string             `json:"platform"`
    CredentialRef     string             `json:"credential_ref"`
    ScanConfiguration *ScanConfigRequest `json:"scan_configuration,omitempty"`
}

var allowedPlatforms = map[string]bool{
    "GOOGLE_DRIVE": true, "AWS_S3": true, "SHAREPOINT": true, "DROPBOX": true,
}

func (r *RegisterStorageLocationRequest) Validate() *ValidationError {
    if r.StoragePath == "" {
        return &ValidationError{Code: "MISSING_FIELD", Message: "storage_path is required"}
    }
    if !allowedPlatforms[r.Platform] {
        return &ValidationError{Code: "INVALID_PLATFORM",
            Message: fmt.Sprintf("platform must be one of: %s", strings.Join(allowedPlatformList(), ", "))}
    }
    if r.CredentialRef == "" {
        return &ValidationError{Code: "MISSING_FIELD", Message: "credential_ref is required"}
    }
    if r.ScanConfiguration != nil {
        cap := r.ScanConfiguration.ResourceCapPercent
        if cap < 1 || cap > 100 {
            return &ValidationError{Code: "INVALID_RESOURCE_CAP",
                Message: "resource_cap_percent must be between 1 and 100"}
        }
    }
    return nil
}
```

---

## Middleware Chain

Every service uses the standard middleware chain in this order:

```go
r.Use(middleware.RequestID)       // Adds X-Request-ID header
r.Use(middleware.RealIP)          // Extracts real client IP
r.Use(apimiddleware.Tracing())    // OpenTelemetry span + trace injection
r.Use(apimiddleware.StructuredLogger()) // Structured request log (INFO) + response log
r.Use(apimiddleware.Auth())       // Validates JWT; 401 if missing/invalid
r.Use(apimiddleware.TenantScope()) // Extracts tenant_id; adds to context
r.Use(middleware.Recoverer)        // Panic recovery → 500 (last resort)
```

**Order matters.** Tracing must come before logging so trace_id is available in logs. Auth must come before TenantScope so the JWT is validated before reading claims.

---

## Pagination (Collection Endpoints)

All collection endpoints use cursor-based pagination:

```go
type PageParams struct {
    After string // base64-encoded cursor (e.g. encoded last ID + sort field)
    Limit int    // default 20, max 100
}

func pageParamsFromRequest(r *http.Request) PageParams {
    limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
    if limit <= 0 || limit > 100 {
        limit = 20
    }
    return PageParams{
        After: r.URL.Query().Get("after"),
        Limit: limit,
    }
}

type PagedResponse[T any] struct {
    Items      []T    `json:"items"`
    NextCursor string `json:"next_cursor"` // empty string if no next page
    TotalCount int    `json:"total_count"`
}
```

---

## Sensitive Field Handling

Fields marked sensitive in the API contract must never appear in:
- Response bodies (return `[REDACTED]` or omit)
- Log entries (use `slog` with a redacting value handler)
- Error messages

```go
// credential_ref: return masked value in responses
type StorageLocationResponse struct {
    // ...
    CredentialRef string `json:"credential_ref"` // always "[REDACTED]" in responses
}
```

---

## Health Check Handlers

```go
func Liveness(w http.ResponseWriter, r *http.Request) {
    w.WriteHeader(http.StatusOK)
    w.Write([]byte(`{"status":"ok"}`))
}

func Readiness(w http.ResponseWriter, r *http.Request) {
    // Check DB connectivity
    if err := db.PingContext(r.Context()); err != nil {
        w.WriteHeader(http.StatusServiceUnavailable)
        w.Write([]byte(`{"status":"not_ready","reason":"database_unavailable"}`))
        return
    }
    w.WriteHeader(http.StatusOK)
    w.Write([]byte(`{"status":"ready"}`))
}
```
```

## Quality Checks
- [ ] Standard handler template covers: decode → validate → command → execute → encode
- [ ] Domain error → HTTP status mapping covers all sentinel errors from `domain/errors.go`
- [ ] RFC 7807 Problem Details format is used for all errors
- [ ] Middleware chain order is specified and justified
- [ ] Sensitive field handling prevents credential values from appearing in responses or logs
- [ ] Pagination pattern is cursor-based (not offset)
- [ ] Health check endpoints are specified with liveness vs readiness distinction
