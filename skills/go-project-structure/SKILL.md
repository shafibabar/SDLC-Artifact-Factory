---
name: go-project-structure
description: >
  Teaches the canonical Go service project layout for this plugin — the four-layer
  Clean/Hexagonal architecture (handlers, application, domain, infrastructure)
  mapped explicitly onto Clean Architecture's Dependency Rule and its four rings
  (Entities, Use Cases, Interface Adapters, Frameworks & Drivers), inward-only
  dependencies verified by go-makefile's arch fitness function, why the generic
  per-service skeleton satisfies Screaming Architecture one level up, idiomatic
  package naming, the minimalist-interface principle (interfaces defined by the
  consumer, not the producer, with compile-time var _ Interface = (*T)(nil)
  satisfaction checks), composition over inheritance, and where generics belong.
  This is the skeleton every Go service is generated into. Full composition/
  generics worked examples are in references/composition-and-generics.md. Used
  by the backend-engineer during Implement.
version: 2.0.0
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

This is Robert C. Martin's **Dependency Rule** (Clean Architecture): source code dependencies point only inward, toward higher-level policy — never the reverse, and never sideways past a layer. It is a broader claim than the Dependency Inversion Principle alone; DIP (a consumer-defined port an implementation satisfies structurally — see Minimalist Interfaces below) is the *mechanism* this plugin uses to make the Rule hold at the domain/infrastructure boundary, not a synonym for the Rule itself.

Clean Architecture names four concentric rings; this plugin's four layers are a direct, one-to-one-ish mapping onto them:

| Clean Architecture ring | This plugin's layer | Why it maps here |
|---|---|---|
| Entities (enterprise-wide business rules) | `domain` | Aggregates, Value Objects, invariants — knows nothing outside itself |
| Use Cases (application-specific business rules) | `application` | Command/query handlers orchestrate domain objects for one use case |
| Interface Adapters (controllers, gateways, presenters) | `infrastructure` + `handlers` | `infrastructure`'s repositories are the Gateways that translate domain ↔ SQL/Kafka; `handlers` are the Controllers that translate HTTP/events ↔ application calls |
| Frameworks & Drivers (the outermost ring) | *not a directory* | `pgx`, `chi`, `kgo` are external libraries `infrastructure`/`handlers` import — this plugin writes adapters around them, never framework code of its own |

The dependency rule is verified mechanically, not just by review: `go-makefile`'s `arch` target runs `scripts/check-imports.sh`, which fails the build if `internal/domain` imports `pgx`/`chi`/`opentelemetry` — a fitness function, paired with the architecture governance hook for defence in depth.

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

**Why this generic skeleton is correct, not a Screaming Architecture violation.** Martin's Screaming Architecture argues a codebase's structure should announce its business domain, not its framework — a glance at the top-level layout should "scream" what the system does. This `cmd/` + `internal/{domain,application,infrastructure,handlers}` tree looks identical for every service in this plugin, which can look like the opposite of that. It isn't: the domain already screams one level up, at the repository/service name chosen in `container-diagram` (`classification-service`, not `generic-crud-service`), and one level down, at the file names inside `domain/` itself (`dataasset.go`, `sensitivity.go` name real business concepts, not `entity.go`/`model.go`). The four-layer skeleton is architecture's plumbing for organizing that domain content — it is supposed to be boringly the same everywhere; the domain names are supposed to differ everywhere.

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

// Compile-time assertion: forces the compiler to check DataAssetRepo's method set
// against domain.DataAssetRepository right here. A renamed or re-typed method then
// fails to compile at this file — the place that changed — instead of surfacing as
// a confusing error wherever the interface is used, possibly in another package.
var _ domain.DataAssetRepository = (*DataAssetRepo)(nil)

func (r *DataAssetRepo) FindByID(ctx context.Context, id uuid.UUID) (*domain.DataAsset, error) { ... }
func (r *DataAssetRepo) Save(ctx context.Context, a *domain.DataAsset) error { ... }
```

This is the Dependency Inversion Principle and Interface Segregation Principle in idiomatic Go: the high-level policy (application) owns the abstraction; the low-level detail (postgres) depends on it. The `var _ Interface = (*T)(nil)` line is a standard, zero-cost idiom (the blank identifier discards the value; nothing is allocated or run) — add it next to every port implementation, not just this one (`go-repository-pattern`'s concrete repositories, and any other `infrastructure` adapter satisfying a `domain` port).

---

## Composition Over Inheritance

Go has no inheritance. Reuse is by **embedding** and **small focused types**, not type hierarchies — e.g. embedding an interface (not a concrete type) to build a decorator that promotes every method and overrides only the one it instruments. Full worked example: `references/composition-and-generics.md`.

---

## Where Generics Belong

Generics (`[T any]`) eliminate duplication in **data-agnostic** containers and transformations — never to make the domain abstract (result/pagination wrappers, type-safe collection helpers, generic worker-pool plumbing). Do **not** use generics to build a `Repository[T any]` god-interface — that re-creates the weak, wide abstraction the minimalist-interface rule forbids; each Aggregate gets its own small repository port. Full guidance: `references/composition-and-generics.md`.

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

Full composition-over-inheritance and generics worked examples: `references/composition-and-generics.md`.
