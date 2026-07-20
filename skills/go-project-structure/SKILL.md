---
name: go-project-structure
description: >
  Teaches the canonical Go service project layout for this plugin — the four-layer
  Clean/Hexagonal architecture (handlers, application, domain, infrastructure),
  inward-only dependencies, idiomatic package naming, the minimalist-interface
  principle (interfaces defined by the consumer, not the producer), composition
  over inheritance, and where generics belong. This is the skeleton every Go
  service is generated into. Used by the backend-engineer during Implement.
version: 1.1.0
phase: implement
owner: backend-engineer
created: 2026-06-25
tags: [implement, go, project-structure, clean-architecture, solid, interfaces, generics]
---

# Go Project Structure

## Purpose

Every Go service in this plugin uses the same layered layout so that any service is navigable by anyone who has seen one. The layout enforces the dependency rule from the architecture `component-diagram` skill: **dependencies point inward only**. The domain layer at the centre knows nothing of HTTP, SQL, or Kafka. This is what makes the domain testable in isolation and the infrastructure swappable.

This skill produces the directory skeleton and the package conventions. It does not implement the layers — the domain, repository, handler, and service skills do that.

---

## The Four Layers

```
        ┌─────────────────────────────────────────────┐
        │  handlers/   (transport: HTTP, event consumers)│  ← depends inward
        ├─────────────────────────────────────────────┤
        │  application/  (use cases: command/query handlers)│
        ├─────────────────────────────────────────────┤
        │  domain/   (Aggregates, Value Objects, domain logic)│  ← depends on nothing
        ├─────────────────────────────────────────────┤
        │  infrastructure/  (pgx, Redpanda, Vault, OTel)│  ← implements domain ports
        └─────────────────────────────────────────────┘
```

| Layer | May import | Must NOT import |
|---|---|---|
| `domain` | stdlib, `uuid`, `time` only | Any other layer; any framework; pgx; chi; OTel |
| `application` | `domain` | `handlers`; concrete `infrastructure` (only domain ports) |
| `infrastructure` | `domain` (to implement its ports) | `handlers`; `application` |
| `handlers` | `application`, `domain` (types) | `infrastructure` internals (wired in `main`) |

The dependency rule is verified by `go-makefile`'s import-lint target and the architecture hook — a domain package that imports `pgx` is a defect.

---

## Canonical Directory Layout

```
classification-service/
├── cmd/
│   └── server/
│       └── main.go              # composition root: wires everything, owns lifecycle
├── internal/
│   ├── domain/                  # the centre — pure business logic
│   │   ├── dataasset.go         # DataAsset Aggregate Root + invariants
│   │   ├── sensitivity.go       # SensitivityLevel Value Object
│   │   ├── events.go            # Domain Events emitted by Aggregates
│   │   ├── errors.go            # domain sentinel errors (see go-error-handling)
│   │   └── ports.go             # interfaces the domain/application NEEDS (consumer-defined)
│   ├── application/
│   │   ├── commands/            # one file per Command handler (write side)
│   │   └── queries/             # one file per Query handler (read side)
│   ├── infrastructure/
│   │   ├── postgres/            # pgx repositories implementing domain ports
│   │   ├── messaging/           # Redpanda producer/consumer
│   │   ├── telemetry/           # OTel + slog setup
│   │   └── secrets/             # Vault Agent file reader
│   └── handlers/
│       ├── http/                # chi handlers, DTOs, middleware wiring
│       └── events/              # event-consumer handlers
├── migrations/                  # SQL migrations (see go-migration)
├── api/
│   └── openapi.yaml             # the contract (see go-openapi-codegen)
├── Dockerfile
├── Makefile
├── go.mod
└── go.sum
```

**`internal/`** prevents other modules from importing the service's guts — only `cmd/` and the module's own packages can. This is enforced by the Go toolchain, not convention.

---

## Package Naming

| Rule | Good | Bad |
|---|---|---|
| Short, lower-case, no underscores | `postgres`, `messaging` | `postgres_repo`, `messagingUtils` |
| Name the thing, not the pattern | `domain`, `commands` | `models`, `helpers`, `utils`, `common` |
| Package name = directory name | `package postgres` in `postgres/` | mismatched names |
| No stutter | `domain.DataAsset` | `dataasset.DataAssetModel` |

There is no `utils` or `common` package. A "utilities" package is a sign that something lacks a home — find its real owner.

---

## Minimalist Interfaces (consumer-defined)

The Go proverb governs every interface: **"The bigger the interface, the weaker the abstraction."** Two rules:

1. **Interfaces are small** — ideally one method, rarely more than three. Model on `io.Reader`/`io.Writer`.
2. **Interfaces are defined where they are consumed, not where they are implemented.** The `application` layer declares the port it needs; the `infrastructure` layer implements it. The implementation does not declare the interface.

```go
// internal/domain/ports.go — defined by the CONSUMER (the application needs this)
package domain

type DataAssetRepository interface {
    FindByID(ctx context.Context, id uuid.UUID) (*DataAsset, error)
    Save(ctx context.Context, a *DataAsset) error
}
```

```go
// internal/infrastructure/postgres/dataasset_repo.go — the IMPLEMENTATION
// note: it does NOT declare the interface; it just satisfies it structurally
package postgres

type DataAssetRepo struct{ pool *pgxpool.Pool }

func (r *DataAssetRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.DataAsset, error) { ... }
func (r *DataAssetRepo) Save(ctx context.Context, a *domain.DataAsset) error { ... }
```

This is the Dependency Inversion Principle and Interface Segregation Principle in idiomatic Go: the high-level policy (application) owns the abstraction; the low-level detail (postgres) depends on it.

---

## Composition Over Inheritance

Go has no inheritance. Reuse is by **embedding** and **small focused types**, not type hierarchies.

```go
// Embed to compose behaviour, not to "extend a base class"
type instrumentedRepo struct {
    domain.DataAssetRepository           // embedded interface — decorator pattern
    tracer trace.Tracer
}

func (r instrumentedRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.DataAsset, error) {
    ctx, span := r.tracer.Start(ctx, "repo.FindByID")
    defer span.End()
    return r.DataAssetRepository.FindByID(ctx, id) // delegate to the embedded impl
}
```

---

## Where Generics Belong

Generics (`[T any]`) eliminate duplication in **data-agnostic** containers and transformations — never to make the domain abstract. Use them for:

- Reusable result/pagination wrappers: `Page[T any]`, `Result[T any]`
- Type-safe collection helpers: `Map[T,U any](in []T, f func(T) U) []U`
- Generic worker-pool/pipeline plumbing (see `go-concurrency-patterns`)

Do **not** use generics to build a `Repository[T any]` god-interface — that re-creates the weak, wide abstraction the minimalist-interface rule forbids. Each Aggregate gets its own small repository port.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Dependency rule | Imports point inward only; domain imports no framework | `domain` importing pgx/chi/OTel |
| Layer layout | Four layers under `internal/`; `cmd/server/main.go` is the only composition root | Business logic in `main`; layers blurred |
| Interface ownership | Ports defined by the consumer (domain/application) | Interfaces declared next to their implementation |
| Small interfaces | Interfaces ≤ 3 methods, single-responsibility | Wide "manager"/"service" interfaces |
| No junk packages | No `utils`/`common`/`helpers` | A grab-bag package with no clear owner |
| Generics used correctly | Generics only for data-agnostic plumbing | Generic god-repository over the domain |

---

## Anti-Patterns

- **Layer-skipping imports** — a handler reaching into `infrastructure/postgres` directly "just this once". The dependency rule has no exceptions; wiring happens only in the composition root.
- **Producer-defined interfaces** — `postgres` declaring `DataAssetRepository` next to its implementation inverts ownership: the abstraction ends up shaped by the database, not by what the use case needs.
- **`utils` / `common` / `helpers` packages** — a landfill that every package imports and no one owns. Each function has a real home; find it.
- **Package-by-pattern** — `models/`, `interfaces/`, `impl/` directories scatter one concept across the tree. Package by layer and by domain concept, not by language construct.
- **A fat `pkg/` of "shared" code between services** — sharing domain types across services couples Bounded Contexts at the source level; share contracts (OpenAPI, event schemas), not structs.
- **Business logic in `main.go`** — the composition root wires and starts; the moment it decides anything, that decision is untestable without booting the process.
- **`Repository[T any]`** — a generic god-repository is a wide, weak abstraction that forces every Aggregate through the same CRUD shape. One small port per Aggregate.

---

## Output Format

This skill produces a directory skeleton and `go.mod`, not a document. Generated artifacts:

```
cmd/server/main.go            (stub composition root)
internal/domain/ports.go      (consumer-defined interfaces)
internal/{domain,application,infrastructure,handlers}/  (package dirs with doc.go)
go.mod
```
