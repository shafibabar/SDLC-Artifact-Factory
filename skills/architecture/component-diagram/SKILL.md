---
name: component-diagram
description: >
  Teaches how to produce a C4 Level 3 Component Diagram — showing the internal
  structure of a single container (service) as named components with defined
  responsibilities. Component diagrams establish the package structure, the
  layered architecture, and the dependency direction rules within a service before
  code is written. They are the primary input to the backend-engineer's Go project
  structure and the frontend-engineer's React component architecture. Used by the
  enterprise-architect agent per service, after the Container Diagram is approved.
version: 1.0.0
phase: design
owner: enterprise-architect
tags: [design, architecture, c4, component-diagram, layered-architecture, go, solid]
---

# Component Diagram

## Purpose

The Component Diagram (C4 Level 3) zooms into a single container and shows its internal structure — the named components, their responsibilities, and the dependencies between them. A component is a grouping of related code with a defined interface and a clear responsibility.

The Component Diagram answers: **what are the logical building blocks inside this service, what does each one do, and in which direction do dependencies flow?**

Component diagrams enforce SOLID principles at the architectural level before a single line of code is written.

---

## Standard Layered Architecture for Go Services

Every Go service in this plugin follows a layered architecture with strict dependency direction rules. The Component Diagram for a Go API service always uses this structure:

```
┌───────────────────────────────────────────────────────┐
│ [Service Name] — Go, net/http + chi                   │
│                                                       │
│  ┌──────────────────────────────────────────────┐    │
│  │  API Layer (handlers/)                       │    │
│  │  HTTP handlers, request/response mapping,    │    │
│  │  input validation, auth middleware           │    │
│  └────────────────────┬─────────────────────────┘    │
│                       │ calls                         │
│  ┌────────────────────▼─────────────────────────┐    │
│  │  Application Layer (application/)            │    │
│  │  Command handlers, query handlers,           │    │
│  │  orchestration — no domain logic here        │    │
│  └────────────────────┬─────────────────────────┘    │
│                       │ calls                         │
│  ┌────────────────────▼─────────────────────────┐    │
│  │  Domain Layer (domain/)                      │    │
│  │  Aggregates, Domain Events, Commands,        │    │
│  │  Value Objects, domain interfaces            │    │
│  │  NO external dependencies                    │    │
│  └────────────────────┬─────────────────────────┘    │
│                       │ implemented by                │
│  ┌────────────────────▼─────────────────────────┐    │
│  │  Infrastructure Layer (infrastructure/)      │    │
│  │  Repository implementations (PostgreSQL/pgx) │    │
│  │  Outbox relay, event publisher (Redpanda)    │    │
│  │  External service ACL adapters               │    │
│  └──────────────────────────────────────────────┘    │
│                                                       │
└───────────────────────────────────────────────────────┘
```

**Dependency direction rule:** Dependencies flow inward only. The domain layer has no imports from infrastructure or API. The application layer imports from domain. Infrastructure imports from domain (to implement domain interfaces). API imports from application. This is the Dependency Inversion Principle applied at the architectural level.

---

## Component Responsibilities

### API Layer (`handlers/`)

- Receives HTTP requests via chi router
- Validates request structure (structural validation only — not business rules)
- Maps request DTOs to Command or Query objects
- Calls the Application layer
- Maps Application layer responses to HTTP response DTOs
- Returns HTTP responses
- Handles authentication middleware (JWT validation via Linkerd or middleware)

**Does NOT:** Contain any business logic. Does not call the Domain layer directly. Does not access databases.

### Application Layer (`application/`)

- Receives Commands and Queries from the API layer
- Orchestrates the domain — loads the Aggregate from the repository, calls domain methods, saves back
- Publishes domain events to the outbox (via infrastructure)
- Handles idempotency (checks command log)
- **Command handlers:** one handler per Command; all in `application/commands/`
- **Query handlers:** one handler per Read Model query; all in `application/queries/`

**Does NOT:** Contain domain logic (invariants, business rules). Does not construct domain objects from raw data — the domain layer owns its own construction.

### Domain Layer (`domain/`)

- Aggregates and their methods (the only place invariants are enforced)
- Value Objects (immutable, equality by value)
- Domain Events (structs — the data the event carries)
- Commands (structs — the data passed to Application handlers)
- Domain interfaces (Repository interface, EventPublisher interface — implemented in Infrastructure)
- Domain errors (business errors, not system errors)

**Does NOT:** Import from any other layer. Has no external dependencies. Depends only on the Go standard library. This is what makes the domain testable in complete isolation.

### Infrastructure Layer (`infrastructure/`)

- PostgreSQL repository implementations (`infrastructure/postgres/`)
- Outbox relay implementation (`infrastructure/outbox/`)
- Redpanda event publisher (`infrastructure/events/`)
- ACL adapters for external systems (`infrastructure/adapters/[external-name]/`)
- Read Model projectors (`infrastructure/projectors/`)

**Does NOT:** Contain business logic. Adapters translate between external models and domain types — the translation logic is in the ACL, not the domain.

---

## Component Diagram for a Worker Service

Background worker services (event consumers) follow a simpler structure:

```
┌─────────────────────────────────────────────────────────┐
│ [Worker Name] — Go                                      │
│                                                         │
│  ┌────────────────────────────────────────────────┐    │
│  │  Consumer Layer (consumer/)                    │    │
│  │  Redpanda consumer group setup,                │    │
│  │  message deserialization, idempotency check    │    │
│  └────────────────────┬───────────────────────────┘    │
│                       │ calls                           │
│  ┌────────────────────▼───────────────────────────┐    │
│  │  Application Layer (application/)              │    │
│  │  Event handlers — one per consumed event type  │    │
│  └────────────────────┬───────────────────────────┘    │
│                       │ calls                           │
│  ┌────────────────────▼───────────────────────────┐    │
│  │  Domain Layer (domain/)                        │    │
│  │  Domain objects and interfaces                 │    │
│  └────────────────────┬───────────────────────────┘    │
│                       │ implemented by                  │
│  ┌────────────────────▼───────────────────────────┐    │
│  │  Infrastructure Layer (infrastructure/)        │    │
│  │  Repository implementations, external calls    │    │
│  └────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

---

## Go Package Structure

The Component Diagram maps directly to the Go package structure:

```
[service-name]/
├── cmd/
│   └── server/
│       └── main.go              ← wires everything together (DI)
├── internal/
│   ├── domain/                  ← Domain layer
│   │   ├── [aggregate].go
│   │   ├── events.go
│   │   ├── commands.go
│   │   ├── errors.go
│   │   └── ports.go             ← repository and event publisher interfaces
│   ├── application/             ← Application layer
│   │   ├── commands/
│   │   │   └── [command]_handler.go
│   │   └── queries/
│   │       └── [query]_handler.go
│   ├── handlers/                ← API layer (or consumer/ for workers)
│   │   ├── [resource]_handler.go
│   │   └── middleware/
│   └── infrastructure/          ← Infrastructure layer
│       ├── postgres/
│       │   └── [aggregate]_repository.go
│       ├── outbox/
│       │   └── relay.go
│       ├── events/
│       │   └── publisher.go
│       └── adapters/
│           └── [external-name]/
│               ├── client.go    ← calls the external API
│               └── translator.go ← maps external types to domain types
└── api/
    └── openapi.yaml             ← API contract
```

---

## SOLID at Component Level

| Principle | How it is enforced |
|---|---|
| **S** — Single Responsibility | One handler per Command; one component per layer responsibility |
| **O** — Open/Closed | Domain interfaces in `ports.go` — new implementations added without changing the interface |
| **L** — Liskov Substitution | Infrastructure implements domain interfaces; any implementation is substitutable |
| **I** — Interface Segregation | Repository interface is specific to the domain — only the methods the domain actually needs |
| **D** — Dependency Inversion | Domain defines interfaces; Infrastructure implements them; Application depends on the interface, not the implementation |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Layer separation | Four distinct layers with names matching the standard | Flat package structure with no layer separation |
| Inward dependencies | No domain import of infrastructure or API | Domain importing from `infrastructure/` or `handlers/` |
| Domain purity | Domain layer has no external library imports | Domain importing database drivers, HTTP libraries |
| Interface in domain | Repository and EventPublisher interfaces defined in `domain/ports.go` | Interfaces defined in `infrastructure/` |
| One handler per command | One Go file per Command handler | Handlers grouped by entity rather than by command |
| ACL in infrastructure | External API translations in `infrastructure/adapters/` | External API types appearing in domain layer |

---

## Output Format

```markdown
---
artifact: component-diagram
product: [product name]
service: [service / container name]
bounded-context: [bounded context name]
version: 1.0.0
phase: design
created: [date]
owner: enterprise-architect
---

# Component Diagram: [Service Name]

## Diagram
[ASCII diagram showing layers and dependencies]

## Components

| Component | Package path | Responsibility | Dependencies |
|---|---|---|---|

## Go Package Structure
[Directory tree]

## SOLID Compliance Notes
[Per-principle note on how this service's structure enforces SOLID]

## Key Design Decisions
[Non-obvious choices that deviate from the standard layered template, with rationale]
```
