# Command Structs, Validation and Rejections in Go

**Moved here from `command-catalog` (Wave 2, #1396; D047-10).** The design skill is now stack-neutral: it records each Command's inputs, its rejections with their kind and where each is checked, its idempotency key and its duplicate outcome. This file holds the Go that implements those records. It keeps the original `ClassifyDataAsset` worked example and is reworked when `go-service-layer` is rebuilt. Two points from the old design text no longer hold and are overridden here:
- **Tenant is not a default envelope field.** Carry `TenantID` only where the product is multi-tenant (D047-7).
- **HTTP status mapping is `api-contract-design`'s decision**; the `respondCommandError` mapping in § 6 is one implementation of it, not the source.

The `command_log` table and the handler's step order are in `./command-handler-transaction-and-idempotency.md`; the three validation tiers are in `./three-tier-validation-boundary.md`.

## 1. The Command Struct: Envelope Fields Plus Domain Fields

```go
// package commands — lives in internal/application/commands/

// BaseCommand carries envelope fields shared by every command.
// Embed this in every concrete command struct.
type BaseCommand struct {
    CommandID     uuid.UUID `json:"commandId"     validate:"required"`
    AggregateID   uuid.UUID `json:"aggregateId"   validate:"required"`
    AggregateType string    `json:"aggregateType" validate:"required"`
    IssuedBy      uuid.UUID `json:"issuedBy"      validate:"required"`
    IssuedAt      time.Time `json:"issuedAt"      validate:"required"`
    TenantID      uuid.UUID `json:"tenantId"      validate:"required"`
}

// Concrete command — embed BaseCommand, add domain fields directly.
type ClassifyDataAsset struct {
    BaseCommand

    // Domain payload — fields specific to this Command's intent.
    SensitivityLevel  domain.SensitivityLevel `json:"sensitivityLevel"  validate:"required,oneof=Public Internal Confidential Restricted"`
    ClassificationNote string                 `json:"classificationNote" validate:"max=500"`
}
```

- The struct name is the Command name, without a `Command` suffix; the handler is `ClassifyDataAssetHandler`.
- `validate` tags follow `go-playground/validator/v10`; structural validation calls `validate.Struct(cmd)` in the HTTP handler before any domain logic.
- `IssuedAt` is set by the HTTP handler at receipt. The Aggregate stamps its own occurrence time when it applies the change.

## 2. Where Each Field Comes From

| Field | Source |
|---|---|
| `CommandID` | The client's idempotency key (`Idempotency-Key` header), stable across retries of one intent. Never a fresh `uuid.New()` per request, or a retry becomes a new Command |
| `AggregateID` | The URL path parameter |
| `AggregateType` | Hard-coded in the handler for the endpoint |
| `IssuedBy` | The authenticated request context (JWT `sub` mapped to `UserID`), never the body |
| `IssuedAt` | The HTTP handler at receipt: `time.Now().UTC()` |
| `TenantID` | Multi-tenant products only: the authenticated context (JWT `tenant_id`), never the body |
| Domain fields | The JSON request body |

## 3. Structural Validation in the HTTP Handler

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
    cmd.CommandID   = idempotencyKeyFromHeader(r) // the client keeps it across retries

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

## 4. The Validation Error Shape

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

## 5. Guard Clauses Inside the Aggregate

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

## 6. Mapping Domain Errors to Responses

One implementation of the status codes `api-contract-design` chooses for each rejection kind:

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

## 7. Rules About Another Aggregate

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

## 8. When a Command Is Rejected

A rejected Command follows a deterministic flow:

1. The Aggregate method returns a domain error (typed sentinel).
2. The command handler receives the error and does **not** call `repo.Save()` — no
   state change is written.
3. The handler records the rejection in `command_log` so that a retry of the same
   `CommandID` returns the same error without re-running the Aggregate (§ 9).
4. The handler maps the domain error to an HTTP status code and returns a structured
   error response to the client.
5. No Domain Event is emitted. A rejection is not a fact worth broadcasting — it is
   a local failure in the write pipeline.

**Never panic on a domain-rule rejection.** A rejected Command is a normal, expected
outcome for the domain model. Panics are reserved for programmer errors (nil dereference,
invariant that should have been impossible to reach) — not for business rule violations.

## 9. Idempotency Edge Cases (from the old design text)

The `command_log` placement in `./command-handler-transaction-and-idempotency.md` (insert-or-replay as the first statement of the transaction) already closes the "same transaction" and "concurrent duplicates" cases. Two cases from the old text still apply:
- **Return the stored result.** A duplicate returns the same response as the original, including the original's rejection. A rejected domain call rolls the main transaction back, taking the `command_log` insert with it, so record the rejection in a separate short transaction under the same key; otherwise a retry re-runs the guards against state that may have moved and can succeed where the first attempt failed.
- **Retention window.** Prune `command_log` on a schedule (for example nightly, `DELETE … WHERE created_at < now() - interval '7 days'`), never sooner than the client's longest retry horizon including failover. An index on `created_at` keeps the delete cheap. In a multi-tenant table, key the row on `(idempotency_key, tenant_id)` so keys cannot collide across tenants.
