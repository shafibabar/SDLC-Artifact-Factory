# Skill: implement/coding-standards

## Purpose
Produce the Coding Standards document — the definitive rules for how code is written, reviewed, and structured across all bounded context repositories. These standards are enforced in CI and code review. Generated code in subsequent skills must conform to these standards.

## Inputs
- `sdlc-config.json` (target_language, github_org)
- `artifacts/design/bounded-contexts.md`
- `artifacts/design/architecture/c4-component-*.md` (for package structure conventions)

## Output
**File:** `artifacts/implement/standards/coding-standards.md`
**Registers in manifest:** yes

## Standards Rules (enforced)
- Standards are specific enough to resolve disagreements — no "write clean code" platitudes.
- Every standard has a rationale (why), not just a rule (what).
- Automated enforcement is named for every standard that can be enforced by tooling.
- Standards cover: package structure, naming, error handling, logging, testing, and concurrency.

## Artifact Template

```markdown
# Coding Standards

**Product:** {product_name}
**Phase:** Implement
**Artifact:** Coding Standards
**Language:** Go ({target_language})
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Guiding Principles

1. **Explicit over implicit** — if the behaviour is not obvious from reading, make it obvious.
2. **Errors are values** — handle every error at the call site; never ignore with `_`.
3. **Small packages** — a package should have one reason to exist.
4. **No magic** — no `init()` side effects, no global mutable state, no framework injection.

---

## Package Structure

All bounded context services follow the hexagonal architecture layout:

```
{service}/
├── cmd/
│   └── server/
│       └── main.go              # Wire-up only — no business logic
├── internal/
│   ├── api/
│   │   └── handlers/            # HTTP handlers — decode request, call handler, encode response
│   ├── application/
│   │   ├── commands/            # Command handlers — one file per command
│   │   ├── queries/             # Query handlers — one file per query
│   │   └── eventhandlers/       # Domain event handlers
│   ├── domain/
│   │   ├── aggregates/          # Aggregate structs and methods
│   │   ├── valueobjects/        # Immutable value types
│   │   ├── events/              # Domain event types
│   │   └── services/            # Domain services (stateless)
│   └── infrastructure/
│       ├── persistence/         # Repository implementations (pgx)
│       │   └── outbox/          # Outbox table write
│       ├── readmodels/          # Read model repositories
│       └── messaging/
│           ├── consumer/        # Redpanda consumer
│           └── publisher/       # Outbox relay publisher
├── migrations/                  # Numbered SQL migration files
├── helm/                        # Helm chart for this service
└── Makefile                     # build, test, lint, migrate targets
```

**Rule:** The `domain/` package must have zero imports from `infrastructure/` or `api/`. Verified by `go-cleanarch` in CI.

---

## Naming Conventions

### Files
- All lowercase, hyphen-separated: `storage-location.go`, `storage-location_test.go`
- Test files: same name as source file with `_test.go` suffix

### Packages
- Lowercase, no hyphens, single word preferred: `handlers`, `commands`, `persistence`
- Avoid generic names: `utils`, `helpers`, `common` are banned

### Types
- Exported types: PascalCase — `StorageLocation`, `RegisterStorageLocationCommand`
- Unexported types: camelCase — `storageLocationRow`, `outboxEntry`

### Functions and methods
- Command handlers: `Handle{CommandName}(ctx, cmd) error`
- Query handlers: `Handle{QueryName}(ctx, query) ({Result}, error)`
- Repository methods: `Load{AggregateName}(ctx, id) ({Aggregate}, error)` / `Save{AggregateName}(ctx, agg) error`
- Event handlers: `Handle{EventName}(ctx, event) error`

### Constants and enums
```go
// Use typed string constants for domain enums — not raw strings
type StorageLocationStatus string

const (
    StorageLocationStatusPending      StorageLocationStatus = "PENDING"
    StorageLocationStatusActive       StorageLocationStatus = "ACTIVE"
    StorageLocationStatusScanning     StorageLocationStatus = "SCANNING"
    StorageLocationStatusScanError    StorageLocationStatus = "SCAN_ERROR"
    StorageLocationStatusDeregistered StorageLocationStatus = "DEREGISTERED"
)
```

---

## Error Handling

```go
// CORRECT: wrap errors with context; use sentinel errors for domain conditions
var ErrStorageLocationNotFound = errors.New("storage location not found")
var ErrScanInProgress = errors.New("scan already in progress")

func (r *StorageLocationRepository) Load(ctx context.Context, id uuid.UUID) (*domain.StorageLocation, error) {
    // ...
    if errors.Is(err, pgx.ErrNoRows) {
        return nil, fmt.Errorf("Load %s: %w", id, ErrStorageLocationNotFound)
    }
    return nil, fmt.Errorf("Load %s: %w", id, err)
}

// WRONG: do not ignore errors; do not return raw database errors to callers
result, _ := repo.Load(ctx, id)   // banned
return nil, err                    // naked error — banned; must wrap with context
```

**Rules:**
- Every `error` return is handled — `//nolint` requires a justification comment
- Domain errors (business rule violations) use sentinel `var Err* = errors.New(...)` errors
- Infrastructure errors are wrapped with `fmt.Errorf("context: %w", err)` at every layer boundary
- HTTP handlers translate domain errors to HTTP status codes — no raw errors in API responses

---

## Context Propagation

```go
// context.Context is always the first parameter of any function that touches I/O
func (h *RegisterStorageLocationHandler) Handle(ctx context.Context, cmd RegisterStorageLocationCommand) error

// Never store context in structs
type Handler struct {
    ctx context.Context  // BANNED
}
```

---

## Logging

All services use Go's standard `slog` package with JSON output:

```go
// CORRECT: structured fields, no string interpolation in message
slog.InfoContext(ctx, "scan initiated",
    "storage_location_id", locationID,
    "tenant_id", tenantID,
    "scan_type", "INCREMENTAL",
)

// WRONG: string interpolation loses structured fields
slog.Info(fmt.Sprintf("scan initiated for location %s", locationID))
```

**Rules:**
- Log level: DEBUG (local dev only), INFO (production), WARN (unexpected but handled), ERROR (unexpected and unhandled)
- Always use `slog.InfoContext(ctx, ...)` — never `slog.Info(...)` (loses trace propagation)
- Never log: entity values, credential references, JWT tokens, file content
- `trace_id` and `span_id` are injected automatically by the OpenTelemetry middleware — do not add manually

---

## Testing

```go
// Unit tests: table-driven, parallel, no external deps
func TestStorageLocation_InitiateScan(t *testing.T) {
    t.Parallel()
    tests := []struct {
        name    string
        initial domain.StorageLocationStatus
        wantErr error
    }{
        {"active location can initiate scan", domain.StorageLocationStatusActive, nil},
        {"scanning location rejects scan", domain.StorageLocationStatusScanning, domain.ErrScanInProgress},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()
            // ...
        })
    }
}
```

**Rules:**
- Unit tests: no real database, no real network; use interfaces and test doubles
- Integration tests: real PostgreSQL (via `testcontainers-go`); no mocks at DB boundary
- Every test file ends in `_test.go` and is in the same package as the code under test (white-box) or a `_test` package (black-box)
- Test names: `Test{Type}_{Method}_{Scenario}` — e.g. `TestStorageLocation_InitiateScan_RejectsScanInProgress`
- Coverage target: 80% minimum for `domain/` packages; enforced in CI

---

## Concurrency

```go
// CORRECT: use context cancellation; name goroutines with recover
go func() {
    defer func() {
        if r := recover(); r != nil {
            slog.ErrorContext(ctx, "panic in outbox relay", "recovered", r)
        }
    }()
    relay.Run(ctx)
}()

// WRONG: fire-and-forget goroutines without lifecycle management
go relay.Run()  // BANNED — no cancellation, no panic recovery
```

---

## Linting and CI Gates

| Tool | Purpose | Config |
|------|---------|--------|
| `golangci-lint` | Meta-linter (includes `govet`, `staticcheck`, `errcheck`, `gosec`) | `.golangci.yml` |
| `go-cleanarch` | Enforces hexagonal layer isolation (`domain` has no infra imports) | CI step |
| `gitleaks` | Secrets detection | `.gitleaks.toml` |
| `govulncheck` | Dependency vulnerability check | CI step |
| `go test -race` | Race condition detection | CI step |

All gates must pass; no `-nolint` exceptions without a co-author comment explaining the specific suppression.
```

## Quality Checks
- [ ] Package structure matches hexagonal architecture diagram
- [ ] Error handling rules cover sentinel errors, wrapping, and HTTP translation
- [ ] Logging rules prohibit PII in log fields
- [ ] Testing rules distinguish unit (no real deps) from integration (real DB via testcontainers)
- [ ] CI tooling named with config file references
- [ ] All linting tools listed are open-source and free-tier compatible
