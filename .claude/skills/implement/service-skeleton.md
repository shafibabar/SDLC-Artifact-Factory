# Skill: implement/service-skeleton

## Purpose
Generate the service skeleton — the complete, compilable Go repository scaffold for one bounded context service. Produces the directory structure, `go.mod`, `main.go`, middleware chain, router, empty handler stubs, repository interfaces, Makefile, and CI workflow. This is the starting point a developer checks out and immediately runs.

## Inputs
- `artifacts/implement/standards/coding-standards.md`
- `artifacts/implement/standards/repo-structure.md`
- `artifacts/design/bounded-contexts.md`
- `artifacts/design/domain/aggregates/` (for the target BC)
- `artifacts/design/domain/commands.md` (for the target BC)
- `artifacts/design/contracts/{service-name}-api.md`
- `sdlc-config.json`
- **Argument required:** bounded context name (e.g. `file-domain`)

## Output
**Directory:** `artifacts/implement/scaffolds/{bc-name}/`
**Registers in manifest:** yes

## Scaffold Rules (enforced)
- The skeleton compiles with `go build ./...` — no placeholder code that fails to compile.
- All stubs return `http.StatusNotImplemented` (501) — never panics, never empty handlers.
- Dependency injection is explicit in `main.go` — no global state, no magic.
- The Makefile `make test` and `make build` targets run successfully on the generated skeleton.
- Linkerd-compatible: Kubernetes deployment YAML includes Linkerd annotation.

## Artifact Template

The skill generates text representations of each file. A developer copies them to the actual repository.

```markdown
# Service Skeleton: {bc-name}

**Product:** {product_name}
**Bounded Context:** {bc-name}
**Phase:** Implement
**Artifact:** Service Skeleton
**Date:** {date}

---

## File: go.mod

```go
module github.com/{github_org}/{product-codename}-{bc-name}

go 1.23

require (
    github.com/go-chi/chi/v5 v5.1.0
    github.com/google/uuid v1.6.0
    github.com/jackc/pgx/v5 v5.7.0
    github.com/twmb/franz-go v1.17.0
    github.com/golang-migrate/migrate/v4 v4.18.0
    go.opentelemetry.io/otel v1.29.0
    go.opentelemetry.io/otel/sdk v1.29.0
    go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp v0.54.0
    golang.org/x/exp v0.0.0-20240909161429-701f63a606c0
)
```

---

## File: cmd/server/main.go

```go
package main

import (
    "context"
    "log/slog"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/{github_org}/{product-codename}-{bc-name}/internal/api"
    "github.com/{github_org}/{product-codename}-{bc-name}/internal/application/commands"
    "github.com/{github_org}/{product-codename}-{bc-name}/internal/application/queries"
    "github.com/{github_org}/{product-codename}-{bc-name}/internal/infrastructure/persistence"
    "github.com/{github_org}/{product-codename}-{bc-name}/internal/infrastructure/messaging"
)

func main() {
    logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo}))
    slog.SetDefault(logger)

    cfg := mustLoadConfig()
    db := mustConnectDB(cfg.DatabaseURL)
    defer db.Close()

    // Repositories
    locationRepo := persistence.NewStorageLocationRepository(db)
    outboxRepo   := persistence.NewOutboxRepository(db)

    // Command handlers
    registerHandler     := commands.NewRegisterStorageLocationHandler(locationRepo, outboxRepo)
    initiateScanHandler := commands.NewInitiateScanHandler(locationRepo, outboxRepo)

    // Query handlers
    listLocationsHandler := queries.NewListStorageLocationsHandler(locationRepo)
    getLocationHandler   := queries.NewGetStorageLocationHandler(locationRepo)

    // Router
    router := api.NewRouter(api.RouterDeps{
        RegisterHandler:     registerHandler,
        InitiateScanHandler: initiateScanHandler,
        ListLocationsHandler: listLocationsHandler,
        GetLocationHandler:  getLocationHandler,
    })

    // Outbox relay
    relay := messaging.NewOutboxRelay(db, cfg.RedpandaBrokers)
    go relay.Run(context.Background())

    srv := &http.Server{
        Addr:         ":" + cfg.Port,
        Handler:      router,
        ReadTimeout:  10 * time.Second,
        WriteTimeout: 10 * time.Second,
        IdleTimeout:  120 * time.Second,
    }

    slog.Info("server starting", "port", cfg.Port)
    go func() {
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            slog.Error("server failed", "error", err)
            os.Exit(1)
        }
    }()

    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()
    if err := srv.Shutdown(ctx); err != nil {
        slog.Error("graceful shutdown failed", "error", err)
    }
    slog.Info("server stopped")
}
```

---

## File: internal/api/router.go

```go
package api

import (
    "net/http"

    "github.com/go-chi/chi/v5"
    "github.com/go-chi/chi/v5/middleware"
    "go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"

    "github.com/{github_org}/{product-codename}-{bc-name}/internal/api/handlers"
    apimiddleware "github.com/{github_org}/{product-codename}-{bc-name}/internal/api/middleware"
)

type RouterDeps struct {
    RegisterHandler     *commands.RegisterStorageLocationHandler
    InitiateScanHandler *commands.InitiateScanHandler
    // add handlers here as they are implemented
}

func NewRouter(deps RouterDeps) http.Handler {
    r := chi.NewRouter()

    r.Use(middleware.RequestID)
    r.Use(middleware.RealIP)
    r.Use(apimiddleware.StructuredLogger())
    r.Use(apimiddleware.Tracing())
    r.Use(apimiddleware.Auth())        // JWT validation + tenant extraction
    r.Use(apimiddleware.TenantScope()) // Enforces tenant_id from JWT on all requests
    r.Use(middleware.Recoverer)

    r.Get("/health/live",  handlers.Liveness)
    r.Get("/health/ready", handlers.Readiness)

    r.Route("/api/v1/file", func(r chi.Router) {
        r.Route("/storage-locations", func(r chi.Router) {
            r.Post("/",        handlers.RegisterStorageLocation(deps.RegisterHandler))
            r.Get("/",         handlers.ListStorageLocations(deps.ListLocationsHandler))
            r.Get("/{id}",     handlers.GetStorageLocation(deps.GetLocationHandler))
            r.Delete("/{id}",  handlers.DeregisterStorageLocation(deps.DeregisterHandler))
            r.Post("/{id}/scan", handlers.InitiateScan(deps.InitiateScanHandler))
        })
    })

    return otelhttp.NewHandler(r, "file-domain-service")
}
```

---

## File: internal/domain/errors.go

```go
package domain

import "errors"

var (
    ErrStorageLocationNotFound  = errors.New("storage location not found")
    ErrScanInProgress           = errors.New("scan already in progress")
    ErrCredentialsNotValidated  = errors.New("credentials have not been validated")
    ErrLocationDeregistered     = errors.New("storage location is deregistered")
    ErrWriteScopeCredential     = errors.New("credential must have read-only scope")
    ErrDuplicateStorageLocation = errors.New("storage location already exists")
)
```

---

## File: internal/domain/aggregates/storage_location.go (stub)

```go
package aggregates

import "github.com/google/uuid"

// StorageLocation is the aggregate root for the storage location lifecycle.
// All state changes happen through domain methods that return domain events.
type StorageLocation struct {
    id       uuid.UUID
    tenantID uuid.UUID
    // TODO: implement full aggregate state
}

func (s *StorageLocation) ID() uuid.UUID       { return s.id }
func (s *StorageLocation) TenantID() uuid.UUID { return s.tenantID }

// InitiateScan begins a scan on an Active storage location.
// Returns ErrScanInProgress if already scanning.
// Returns ErrCredentialsNotValidated if in Pending state.
func (s *StorageLocation) InitiateScan() ([]DomainEvent, error) {
    // TODO: implement — guided by TDD spec artifacts/implement/specs/{story-id}-tdd-spec.md
    return nil, nil
}
```

---

## File: .github/workflows/ci.yml

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  test:
    name: Test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-go@v5
        with:
          go-version: '1.23'
          cache: true

      - name: Secret scan
        uses: gitleaks/gitleaks-action@v2

      - name: Lint
        uses: golangci/golangci-lint-action@v6
        with:
          version: latest

      - name: Vulnerability check
        run: go install golang.org/x/vuln/cmd/govulncheck@latest && govulncheck ./...

      - name: Unit tests
        run: go test -race -count=1 -cover ./...

      - name: Integration tests
        run: go test -race -count=1 -tags=integration ./...
        # testcontainers-go starts Docker — available on GitHub Actions ubuntu runners

      - name: Build
        run: go build ./...

      - name: Architecture check
        run: |
          go install github.com/roblaszczak/go-cleanarch@latest
          go-cleanarch
```

---

## File: Makefile

```makefile
.PHONY: build test test-integration lint migrate-up migrate-down run generate

build:
	go build ./...

test:
	go test -race -count=1 -cover ./...

test-integration:
	go test -race -count=1 -tags=integration ./...

lint:
	golangci-lint run

migrate-up:
	migrate -path migrations -database "$$DB_URL" up

migrate-down:
	migrate -path migrations -database "$$DB_URL" down 1

run:
	go run ./cmd/server

generate:
	go generate ./...
```
```

## Quality Checks
- [ ] All generated Go files are syntactically valid (no placeholder syntax errors)
- [ ] `main.go` wires all dependencies explicitly — no global state
- [ ] All handlers stub `http.StatusNotImplemented` — never panic, never empty response
- [ ] Health check endpoints are present (`/health/live` and `/health/ready`)
- [ ] CI workflow includes: secrets scan, lint, vuln check, unit tests, integration tests, build
- [ ] Domain errors file pre-declares all sentinel errors from the aggregate definition
- [ ] Linkerd-compatible: no hardcoded mTLS setup (Linkerd injects the proxy sidecar)
