# Command Validation Patterns Reference

Self-contained reference for implementing the two-layer Command validation hierarchy
in Go. Covers structural validation in the API handler, business-rule validation
inside the Aggregate, guard clause patterns, validation error shapes, and the
flow when a Command is rejected. Read alongside `SKILL.md`'s Validation Hierarchy
section.

---

## Layer 1: Structural Validation (API Handler)

Structural validation runs in the API handler before any domain logic executes.
It never touches the database or loads an Aggregate. Its sole purpose is to
reject malformed Commands at the boundary — missing required fields, out-of-range
values, wrong types — so the Aggregate never receives a syntactically invalid input.

### Using go-playground/validator

The standard approach: tag struct fields and call `validator.Validate(cmd)`.

```go
import "github.com/go-playground/validator/v10"

var validate = validator.New()

// In the API handler, before calling the command handler:
func (h *DataAssetHandler) ClassifyDataAsset(w http.ResponseWriter, r *http.Request) {
    var cmd commands.ClassifyDataAsset
    if err := json.NewDecoder(r.Body).Decode(&cmd); err != nil {
        respondError(w, http.StatusBadRequest, "invalid JSON body", err)
        return
    }

    // Fill envelope fields from request context — these are never trusted from
    // the client body; they come from the authenticated session.
    cmd.AggregateID = chi.URLParam(r, "id") // parsed to uuid.UUID with error handling
    cmd.IssuedBy    = auth.UserIDFromContext(r.Context())
    cmd.TenantID    = auth.TenantIDFromContext(r.Context())
    cmd.IssuedAt    = time.Now().UTC()
    cmd.CommandID   = uuid.New() // Generated per-invocation for idempotency

    if err := validate.Struct(cmd); err != nil {
        respondValidationErrors(w, err)
        return
    }

    if err := h.classifier.Handle(r.Context(), cmd); err != nil {
        respondCommandError(w, err)
        return
    }

    w.WriteHeader(http.StatusAccepted)
}
```

### Manual Structural Validation

For Commands where the domain type requires a richer check than a tag can express
(e.g., a Value Object's `IsValid()` method), add a `Validate()` method on the
Command struct that is called in addition to the tag-based check.

```go
func (c ClassifyDataAsset) Validate() error {
    var errs []FieldError

    if c.AggregateID == uuid.Nil {
        errs = append(errs, FieldError{Field: "aggregateId", Message: "required"})
    }
    if !c.SensitivityLevel.IsValid() {
        errs = append(errs, FieldError{
            Field:   "sensitivityLevel",
            Message: "must be one of: Public, Internal, Confidential, Restricted",
        })
    }
    if len(c.ClassificationNote) > 500 {
        errs = append(errs, FieldError{Field: "classificationNote", Message: "max 500 characters"})
    }

    if len(errs) > 0 {
        return ValidationError{Fields: errs}
    }
    return nil
}
```

**Rule:** Structural validation never makes a business decision. It does not check
"is this asset allowed to be classified at this level?" — that is Layer 2. It only
checks "is this input well-formed enough to hand to the domain model?"

---

## Validation Error Shape

Structural validation errors must be machine-readable and field-scoped. Return a
consistent envelope rather than a bare error string, so API clients can display
per-field messages.

```go
// FieldError is a single field-level validation failure.
type FieldError struct {
    Field   string `json:"field"`
    Message string `json:"message"`
}

// ValidationError is the structured envelope returned for Layer 1 failures.
// It implements the error interface so handlers treat it uniformly.
type ValidationError struct {
    Fields []FieldError `json:"errors"`
}

func (e ValidationError) Error() string {
    parts := make([]string, len(e.Fields))
    for i, f := range e.Fields {
        parts[i] = f.Field + ": " + f.Message
    }
    return "validation failed: " + strings.Join(parts, "; ")
}
```

HTTP response for a Layer 1 failure:

```json
{
  "status": 400,
  "code":   "VALIDATION_ERROR",
  "errors": [
    {"field": "sensitivityLevel", "message": "must be one of: Public, Internal, Confidential, Restricted"},
    {"field": "aggregateId",      "message": "required"}
  ]
}
```

---

## Layer 2: Business Rule Validation (Inside the Aggregate)

Business-rule validation runs inside the Aggregate Root's own method — not in the
handler, not in a Domain Service, not in the Repository. The Aggregate is the only
object that knows the full invariant state it must enforce.

### Guard Clause Pattern

The standard Go idiom for Aggregate-level invariants is an early-return guard clause
at the top of the mutating method. Guards check the rule and return a typed domain
error if it fails — they never panic.

```go
// DataAsset is the Aggregate Root in the DataAsset Bounded Context.
func (a *DataAsset) Classify(cmd commands.ClassifyDataAsset) error {
    // Guard 1: Cannot classify an archived asset.
    if a.IsArchived() {
        return domain.ErrCannotClassifyArchivedAsset
    }

    // Guard 2: The command's TenantID must match the asset's TenantID.
    // This prevents cross-tenant mutation even if the Repository checked it —
    // defence in depth; the Aggregate enforces it independently.
    if a.tenantID != cmd.TenantID {
        return domain.ErrTenantMismatch
    }

    // Guard 3: The command's AggregateID must match — defensive check.
    if a.id != cmd.AggregateID {
        return domain.ErrAggregateMismatch
    }

    // Guard 4: No re-classification to the same level (business rule).
    if a.sensitivityLevel == cmd.SensitivityLevel {
        return domain.ErrSensitivityLevelUnchanged
    }

    // All guards passed — apply the change and emit the Domain Event.
    a.sensitivityLevel = cmd.SensitivityLevel
    a.version++

    event := domain.DataAssetClassified{
        EventID:          uuid.New(),
        AggregateID:      a.id,
        TenantID:         a.tenantID,
        SensitivityLevel: cmd.SensitivityLevel,
        ClassifiedBy:     cmd.IssuedBy,
        Note:             cmd.ClassificationNote,
        OccurredAt:       time.Now().UTC(),
    }
    a.recordEvent(event)
    return nil
}
```

### Domain Error Types

Business-rule rejections use typed sentinel errors — never bare `errors.New()` strings
that require string-matching at call sites.

```go
// package domain — lives in internal/domain/errors.go

var (
    ErrCannotClassifyArchivedAsset = errors.New("cannot classify an archived data asset")
    ErrTenantMismatch              = errors.New("command tenant does not match aggregate tenant")
    ErrAggregateMismatch           = errors.New("command aggregate ID does not match loaded aggregate")
    ErrSensitivityLevelUnchanged   = errors.New("data asset is already classified at this sensitivity level")
    ErrStorageSourceInactive       = errors.New("cannot classify a data asset whose storage source is inactive")
)
```

The API handler maps domain errors to HTTP status codes:

```go
func respondCommandError(w http.ResponseWriter, err error) {
    switch {
    case errors.Is(err, domain.ErrCannotClassifyArchivedAsset),
         errors.Is(err, domain.ErrSensitivityLevelUnchanged):
        respondError(w, http.StatusUnprocessableEntity, "DOMAIN_RULE_VIOLATION", err)
    case errors.Is(err, domain.ErrTenantMismatch),
         errors.Is(err, domain.ErrAggregateMismatch):
        // These indicate a programming error or an attack — treat as 403, not 422.
        respondError(w, http.StatusForbidden, "ACCESS_DENIED", err)
    default:
        respondError(w, http.StatusInternalServerError, "INTERNAL_ERROR", err)
    }
}
```

---

## Guards Requiring Cross-Aggregate State

Some invariants reference state from a *different* Aggregate. For example:
"A DataAsset cannot be classified as Restricted while its StorageSource is Inactive."

The Aggregate Root cannot directly load another Aggregate's state (that would
violate the single-Aggregate-per-transaction rule). The resolution:

**Option A — Denormalized state on the Aggregate.**
The `DataAsset` Aggregate carries a `storageSourceStatus StorageSourceStatus` field
that is kept eventually consistent via a projection from `StorageSourceStatusChanged`
Domain Events. The guard checks `a.storageSourceStatus == StorageSourceInactive` —
always atomic within the Aggregate's own transaction, but reflects the status as of
the last projection, not the exact current state.

```go
// Guard on DataAsset using denormalized cross-aggregate state:
if cmd.SensitivityLevel == domain.SensitivityRestricted && a.storageSourceStatus == domain.StorageSourceInactive {
    return domain.ErrStorageSourceInactive
}
```

**Option B — Domain Service pre-check.**
A `ClassificationPolicyService` loads both Aggregates *before* calling the Command,
checks the cross-Aggregate rule, and then passes a pre-validated `cmd` to
`asset.Classify(cmd)`. The Aggregate's own guard skips the cross-check because the
policy service already ran it.

Use Option A (denormalized) when the cross-Aggregate state changes rarely and eventual
consistency is acceptable. Use Option B (Domain Service) when real-time consistency
is a genuine business requirement.

---

## What Happens When a Command Is Rejected

A rejected Command follows a deterministic flow:

1. The Aggregate method returns a domain error (typed sentinel).
2. The command handler receives the error and does **not** call `repo.Save()` — no
   state change is written.
3. The handler records the rejection in `command_log` so that a retry of the same
   `CommandID` returns the same error without re-running the Aggregate (see
   `references/command-format.md` for the idempotency implementation).
4. The handler maps the domain error to an HTTP status code and returns a structured
   error response to the client.
5. No Domain Event is emitted. A rejection is not a fact worth broadcasting — it is
   a local failure in the write pipeline.

**Never panic on a domain-rule rejection.** A rejected Command is a normal, expected
outcome for the domain model. Panics are reserved for programmer errors (nil dereference,
invariant that should have been impossible to reach) — not for business rule violations.

---

## Validation Layer Boundary: Decision Table

| Check type | Where it lives | Accesses DB? | Example |
|---|---|---|---|
| Required field present | Layer 1 — handler `Validate()` | No | `commandId` is non-nil UUID |
| Enum value valid | Layer 1 — handler or tag | No | `sensitivityLevel` is one of four allowed values |
| String length limit | Layer 1 — handler or tag | No | `classificationNote` ≤ 500 chars |
| Aggregate-own state rule | Layer 2 — Aggregate method guard | Yes (Aggregate loaded) | Asset is not archived |
| Cross-Aggregate state rule | Layer 2 — Aggregate method (Option A) or Domain Service (Option B) | Yes | StorageSource is active |
| Business workflow rule | Layer 2 — Aggregate method guard | Yes | No re-classification to same level |
| Tenant/ownership check | Layer 2 — Aggregate method guard | Yes (Aggregate loaded) | TenantID matches |

If a check requires a database lookup of data *not* owned by the target Aggregate,
it is either an Option A denormalization or an Option B Domain Service pre-check —
not a Layer 1 check, and not a Repository method called directly from the handler.
