---
description: Run the Design phase — domain model, architecture, UX, data, security design
disable-model-invocation: true
---

Drive the Design phase of the SDLC Artifact Factory. This phase invokes five agents in a strict dependency order — do not reorder or parallelize the first two steps.

1. Read `sdlc-context.json`. Confirm the Ideate phase is complete. If not, tell the user to complete `/sdlc-ideate` first and stop.
2. Check which Design artifacts already exist per agent. Do not re-produce approved artifacts unless the user explicitly asks for a revision.
3. **Invoke `domain-modeler` first.** It Event Storms the domain(s) and produces the Ubiquitous Language, Context Map, Aggregate designs, Domain Event catalog, Command catalog, and Read Model designs. Everything downstream depends on this. Wait for it to complete and be approved.
4. **Invoke `enterprise-architect` second**, giving it domain-modeler's output plus the NFR specification. It produces the System Context Diagram, Container Diagram, Component Diagrams, ADRs, API contracts, Integration Design, and Multi-Tenancy Design. Wait for it to complete and be approved.
5. **Invoke `ux-architect`, `data-architect`, and `security-architect`**, each given the domain model and container diagram they depend on. These three can be run in either order relative to each other — each declares its own inputs and will surface a blocker if something it needs is missing.
6. When all five agents report completion, confirm `sdlc-context.json`'s checklist reflects it, and tell the user the next step is `/sdlc-implement`. Remind them `/sdlc-event-storm` can be re-run standalone later if a new subdomain needs modelling.
