---
name: component-diagram
description: >
  Teaches the enterprise-architect to produce a C4 Level 3 (Component) diagram
  for a single service/container — decomposing it into the major structural
  building blocks (handlers, application services, domain, repositories,
  adapters, event publishers), their responsibilities, and the permitted
  dependency directions between them. Covers the C4-L3 notation rules, the
  layering and dependency-inversion constraints (Clean Architecture:
  source-code dependencies point inward toward the domain), the mapping from Go
  package structure to components, and the diagram artifact template. Used
  during Design after the Container view is fixed, once a service's internal
  structure is non-obvious enough to be worth drawing.
version: 2.0.0
phase: design
owner: enterprise-architect
created: 2026-06-25
tags: [design, architecture, c4-model, component-diagram, documentation, layering, dependency-direction, clean-architecture]
related: [container-diagram, system-context-diagram, go-project-structure, go-repository-pattern, go-service-layer, adr-authoring]
---

# Component Diagram

## What This Diagram Shows

A C4 Level 3 Component diagram zooms into **exactly one container** — a single
deployable service — and shows its *internal* structure: the named components
inside it, each component's single responsibility, and the direction of the
dependencies between them. It answers one question:

> What are the logical building blocks inside *this* service, what does each
> one do, and in which direction do source-code dependencies flow?

**Scope is one container, always.** If you find yourself drawing two services in
one component diagram, you are drawing a Container diagram instead. One diagram
per container is the discipline — see `container-diagram` for the level above
and `system-context-diagram` for the level above that.

**What it deliberately omits.** In *Documenting Software Architectures* terms
this is a **layered module view**, not a runtime (component-and-connector)
view. So it carries no runtime/process semantics: no request timelines, no
"step 1 → step 2" call-sequence numbers, no message ordering, no deployment
placement (that is the Container diagram's allocation concern). Adding a
sequence number to this diagram is a category error. It shows *allowed-to-use*
structure at compile time, nothing about what happens while the system runs.

## Is It Even Worth Drawing?

A component diagram is worth the artifact **only when the internal structure is
non-obvious** (Fairbanks; Richards & Ford). Every Go service in this repo uses
the same four-layer skeleton, so a diagram that merely restates
API→Application→Domain→Infrastructure adds nothing. Draw one when *this* service
departs from the default in a way a reader must understand before touching code:

| Draw it when | Skip it when |
|---|---|
| The service has an Anti-Corruption Layer wrapping a messy external system | The layering is the plain four-layer default with nothing unusual |
| Multiple aggregates, projectors, or a saga coordinator live in one container | One aggregate, one repository, standard CRUD-plus-events shape |
| A non-obvious dependency (a shared read-model, an internal port) needs review | The Go package tree already makes the structure self-evident |
| A reviewer must see *why* two components are split before implementation | Nothing here would surprise an engineer reading `go-project-structure` |

## The Standard Component Set

A Go API service in this repo decomposes into these components. Each has **one**
responsibility (SOLID's S). A component is a *grouping of related functionality
behind an interface*, never a single struct — the full abstraction-level rule is
in `references/c4-component-notation.md`.

| Component | Package | Single responsibility |
|---|---|---|
| **HTTP Handler** | `handlers/` | Decode/validate the request, map DTO→Command/Query, call the application service, encode the response. No business logic. |
| **Application Service** | `application/` | Orchestrate one use case: load the Aggregate, call its methods, save, enqueue the outbox event. No invariants of its own. |
| **Domain Model** | `domain/` | Aggregates, Value Objects, Domain Events, and the port *interfaces*. The only place invariants live. Imports nothing but the standard library. |
| **Repository** | `infrastructure/postgres/` | Persist and reconstitute Aggregates via `pgx`. A Humble Object — thin, logic-free, integration-tested. |
| **Event Publisher** | `infrastructure/events/` | Relay Transactional Outbox rows to Redpanda. Implements a domain port. |
| **External Adapter** | `infrastructure/adapters/<name>/` | Anti-Corruption Layer: translate an external system's types to/from domain types. |

Worker (event-consumer) services swap the HTTP Handler for a **Consumer**
component (Redpanda consumer group, deserialize, idempotency check); everything
else is identical.

## The Dependency-Direction Rule

This is the architecture — the rest is folders. Clean Architecture's
**Dependency Rule**: *source-code dependencies point only inward, toward
higher-level policy.* Concretely, in this repo's Go layers:

- **Domain depends on nothing** (standard library only). It is the innermost
  ring and knows nothing of HTTP, SQL, or Redpanda.
- **Application** depends on Domain.
- **Handlers** depend on Application.
- **Infrastructure** depends on Domain — it *implements* domain interfaces.

The inward-pointing arrow from Infrastructure to Domain is achieved by
**Dependency Inversion**: the interface (`Repository`, `EventPublisher`) is
declared in `domain/`, and the infrastructure package implements it. The inner
ring owns the abstraction; the outer ring conforms to it. The Dependency Rule is
the architecture-wide invariant; Dependency Inversion is the one mechanism it
uses at each inward-facing crossing — they are not synonyms, and
`references/layering-and-dependency-rules.md` draws that distinction in full.

Two forbidden arrows tell you the layering has collapsed: **`domain/` importing
`pgx` or `chi`**, and a **handler importing `pgx` directly** (layer skipping).
Both are covered — with a worked violation-and-fix and the fitness function that
catches them in CI — in `references/layering-and-dependency-rules.md`.

## Producing the Artifact

Draw the boundary box for the container, place each component inside it with its
name/technology/responsibility, and draw only inward-pointing dependency arrows.
Accompany the picture with an **element catalog** (a table of every component and
its properties — the picture's boxes cannot carry a responsibility or an
interface on their own) and a short **rationale** for any non-default split. The
diagram is produced *before* code; the backend-engineer scaffolds the Go package
tree from it, so a drift between the diagram and the tree is a defect in the
diagram, not the code.

## References

- **`references/c4-component-notation.md`** — full C4-L3 notation: box contents,
  relationship arrows and labels, the abstraction level (component vs. class),
  the container boundary box, and Clements' element/relation/property structure
  for a documentation-package-complete view.
- **`references/layering-and-dependency-rules.md`** — Clean Architecture's four
  rings mapped onto this repo's Go layers, the Dependency Rule vs. Dependency
  Inversion distinction, the interface-ownership mechanism, the forbidden
  dependencies, a worked violation-and-fix, and the import fitness function.
- **`references/diagram-template.md`** — the component diagram artifact template
  (Mermaid and textual C4) plus a fully worked Component diagram for this repo's
  DataAsset Management service.
