---
name: component-diagram
description: >
  Decide whether a service needs a C4 Component diagram (Level 3) and draw it
  when it does: only for a container whose insides differ from the default
  service skeleton (an anti-corruption adapter, a read-model projector, a saga
  coordinator, several aggregates, an unusual port); a default service gets one
  line saying the skeleton applies, never a diagram. One container per
  diagram; components are groupings behind an interface, never one box per
  struct or function; a static layered module view with no numbered steps
  (runtime sequences belong in a dynamic diagram); arrows labelled, pointing
  inward by the Dependency Rule (not merely Dependency Inversion), no two-way
  arrows, protocols only on arrows leaving the container. ASCII primary,
  Mermaid optional, element catalog, rationale for every departure, a named
  fitness function that keeps the domain free of frameworks. Use when drawing,
  reviewing or deciding whether to draw a component diagram, or checking a
  service's layering and dependency direction. Used by enterprise-architect.
version: 3.0.0
phase: design
owner: enterprise-architect
created: 2026-06-25
tags: [design, architecture, c4-model, component-diagram, module-view, layering, dependency-rule, clean-architecture, fitness-function]
produces: component-diagram
domain: architecture
status: stable
related: [container-diagram, system-context-diagram, go-project-structure, go-service-layer, go-repository-pattern, go-makefile, context-map-patterns, cqrs-pattern, read-model-design, workflow-orchestration, integration-design, multi-tenancy-design, sdlc-config-management, adr-authoring, glossary-management, methodology-review]
sources:
  - research/software-architecture/c4-model-brown.md
  - research/software-architecture/documenting-software-architectures-clements.md
  - research/software-architecture/clean-architecture-martin.md
  - research/software-architecture/fundamentals-of-software-architecture-richards-ford.md
  - research/software-architecture/just-enough-software-architecture-fairbanks.md
---

# Component Diagram

## Purpose

C4 Level 3 (Brown, `c4-model-brown.md`) zooms into **one container** from the container diagram. **Readers:** the backend-engineer who will scaffold it, security-engineer (where the controls sit), reviewers. **Question:** what are the building blocks inside this service, what does each do, and which way do the source-code dependencies point?

In Clements' terms it is a **layered module view** (`documenting-software-architectures-clements.md`): static, compile-time, *allowed-to-use* structure. It has no time dimension: no numbered steps, no request flow, no deployment placement.

## 1. Draw It or Skip It (D047-13)

A model earns its cost by answering a question someone has (Fairbanks, `just-enough-software-architecture-fairbanks.md`); Brown calls component diagrams optional, worth drawing for a complex container. Every service starts from the same default skeleton (`go-project-structure`, or the overriding stack's equivalent in `sdlc-config.json`), so a diagram that restates it adds nothing.

| Draw one when the service has | Skip when |
|---|---|
| An anti-corruption adapter around a messy external system | The plain default layers, one aggregate, standard handlers and events |
| A read-model projector, or several aggregates in one container | Nothing a reader of the default skeleton wouldn't expect |
| A saga coordinator or process manager with its own state and ports | |
| An unusual port or a shared internal read model that needs review | |

- **Skip output:** one line in the service's record, *"<service>: default skeleton (<skeleton skill>), no component diagram"*, and no artifact. Lean: always skip.
- **Draw output:** `design/<service>/component-diagram.md` (`./templates/component-diagram.md`), whose rationale names each departure from the default.
- A request to "draw one for every service so the set is complete" is answered with this rule: the set is complete when every non-default service has one and every default service has its one line.

## 2. Components

- A **component** is a grouping of related functionality behind an interface, inside one container, not separately deployable (Brown). In code it is usually a package or module, **never one box per struct, class or handler function** (that is Level 4, Code).
- Each box: **name** in the Ubiquitous Language, **type and technology**, one-sentence **responsibility**. A responsibility that needs "and" to join two duties is two components.
- The default roles, by ring:

| Role | Holds | Default stack (Go) |
|---|---|---|
| Entry point | Decode, validate, map to a Command or Query, encode; no business logic | `handlers/` (HTTP), or a consumer for a worker |
| Use cases | Orchestrate one use case: load, call the Aggregate, save, enqueue the event | `application/` |
| Domain | Aggregates, Value Objects, Domain Events, the port interfaces; the only place invariants live | `domain/` |
| Adapters | Implement domain ports: persistence, outbox relay, external systems | `infrastructure/<system>/` |

A departure adds a role (an anti-corruption adapter, a projector, a coordinator) and says why in the rationale.

## 3. The Dependency Rule

**Source-code dependencies point only inward, toward the domain** (Martin, `clean-architecture-martin.md`). Nothing inside knows a name, signature or data format from outside.
- Domain depends on nothing but the language's standard library; use cases on the domain; entry points on use cases; adapters on the domain, by **implementing ports the domain declares**.
- That last crossing uses **Dependency Inversion**: the inner ring owns the interface, the outer ring conforms. Dependency Inversion is one mechanism of the Dependency Rule, not a synonym for it.
- **Forbidden:** the domain importing a framework or driver (database, HTTP router, broker client); an entry point reaching the database directly, even "just for a read" (it skips use cases, authorization and idempotency).
- **A fitness function enforces it** (Richards & Ford, `fundamentals-of-software-architecture-richards-ford.md`): an automated import check in the build that fails when the domain imports outside the standard library (default stack: `go-makefile`'s `arch` target). The diagram names it; without it the arrows are a wish.

Rings, port ownership, forbidden dependencies, violations and fixes: `./references/layering-and-dependency-rules.md`.

## 4. Notation

- **One container boundary,** named with its technology; nothing inside it is another container.
- **Arrows** are source-code dependencies, labelled with a verb phrase read tail to head ("implements", "calls", "loads and saves via"). **Never two-way:** a pair pointing at each other is a cycle; break it with a port in the inner ring.
- **Protocols only on arrows that leave the boundary** (to a database, broker, other container); inside it, dependencies are in-process.
- **No numbered steps.** Runtime order belongs in a C4 **dynamic diagram** (Brown) or a sequence diagram; say so when asked.
- **ASCII primary,** with the element catalog tables; **Mermaid optional** (D047-13), never Mermaid alone.
- **Package:** container context (its Level 2 neighbours), the picture, key, element catalog (components with interface and responsibility; relationships with nature and direction), Dependency Rule statement, fitness function, variability, rationale (Clements).
- **Variability:** what differs per deployment, taken from the container diagram's deployment view and `multi-tenancy-design`. The component structure is the same in every instance; never assume a stamp per tenant. Tenancy not decided yet: say so, mark it *pending multi-tenancy-design*, and leave tenant copies to the container diagram's deployment view.

Detail: `./references/c4-component-notation.md`.

## Procedure

1. **Read** the approved container diagram (the container, its neighbours, its deployment view), the Bounded Context's aggregates and the context map, `cqrs-decisions.md`, `sdlc-config.json` (stack), `multi-tenancy-design.md` if it exists.
2. **Decide** (§ 1) for each service: draw or skip. Write the one-line record for every skipped service.
3. **For each drawn service:** list the components (§ 2), naming each departure from the default and why.
4. **Draw** the boundary, components and inward arrows in ASCII (§ 4); write the key, element catalog, Dependency Rule statement, fitness function, variability and rationale.
5. **Validate, then loop.** Run `./scripts/validate-component-diagram.sh design/<service>/component-diagram.md`, fix every FAIL, re-run until clean; then `./resources/checklist.md`.
6. **Present** with the API contracts (the enterprise-architect's second gate), with the reason for every request declined (§ Gotchas). Answering in a reply: the declined requests and their reasons once, then the artifact once.

Examples: `./examples/01-default-service-skipped.md` (a library catalogue's loans service: default skeleton, no diagram, the one-line record), `./examples/02-acl-and-projector.md` (a parcel-locker network's locker service: an adapter around a vendor's controller API and an occupancy read-model projector), `./examples/03-saga-coordinator.md` (a travel-booking checkout service: a saga coordinator with its own state store, ports and compensations).

## Gotchas

Each trap comes with the reason to give in full.

- **"Number the arrows step 1, 2, 3 so people can follow the flow."** *Reason:* a component diagram is a static module view of what may depend on what; it has no time dimension (Clements), and numbers turn dependencies into a sequence they aren't. *Instead:* keep the dependency arrows; draw the flow as a C4 dynamic diagram or a sequence diagram.
- **"Draw one for every service so the set is complete."** *Reason:* a diagram of the default skeleton answers no question (Fairbanks; Brown: optional, where it adds value; D047-13). *Instead:* one line per default service; a diagram for each non-default one, saying what departs.
- **"One box per handler, struct or query."** *Reason:* that is Level 4, Code; components are groupings behind an interface (Brown). *Instead:* one box per package or module role.
- **"The repository and the use case point at each other."** *Reason:* a two-way arrow is a cycle. *Instead:* the domain declares the port; the adapter implements it; arrows point inward.
- **"Label the internal arrows HTTP or Kafka."** *Reason:* inside the container dependencies are in-process; protocols are for inter-process arrows. *Instead:* protocols only where an arrow leaves the boundary.
- **"The handler can query the database directly; it's only a read."** *Reason:* it skips use cases (authorization, idempotency) and points outward. *Instead:* even a read goes through a query handler.
- **"The domain imports the database driver for one lookup."** *Reason:* the inner ring now knows the outer one and can't be tested alone (Martin). *Instead:* the state the invariant needs lives on the Aggregate; the use case loads it through a domain-owned port.
- **"Dependency direction is just DIP."** *Reason:* the Dependency Rule governs every crossing, including data formats; Dependency Inversion is the mechanism at one crossing (Martin). *Instead:* name the Dependency Rule; show DIP where an adapter implements a port.
- **"Add a note that each tenant gets its own stamp."** *Reason:* there is no tenancy default (D047-7), and where things run is the container diagram's deployment view, not Level 3. *Instead:* variability taken from `multi-tenancy-design`, or marked pending it.
- **"Mermaid is enough."** *Reason:* one rule for all C4 diagrams (D047-13). *Instead:* ASCII and the catalog; Mermaid as an optional copy.
- **"The diagram shows the layering; that's enforcement."** *Reason:* a rule only in a picture drifts with the next import. *Instead:* name the fitness function that fails the build.

## References

| Question | File |
|---|---|
| Box anatomy, arrows and labels, the boundary, the documentation package | `./references/c4-component-notation.md` |
| Rings, the Dependency Rule vs DIP, port ownership, forbidden dependencies, fitness function | `./references/layering-and-dependency-rules.md` |
| The artifact skeleton | `./templates/component-diagram.md` |
| Checking before hand-off | `./resources/checklist.md` |
