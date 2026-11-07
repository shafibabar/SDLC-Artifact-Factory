---
name: container-diagram
description: >
  Draw a product's C4 Container diagram (Level 2) and decide what it is made
  of: which Bounded Contexts share a deployable (lean: one modular monolith;
  standard and enterprise: split only on a named granularity disintegrator,
  weighed against the integrators), the containers (apps, APIs, workers,
  databases, brokers; not Docker containers) with technology on each, how they
  talk (one-directional labelled arrows, protocol, sync or async, broker topics
  that keep producer-consumer pairs readable), one write authority and no
  shared database, where the API gateway sits and what it must not hold, and
  the deployment view as a section of the same artifact (environments,
  deployment nodes, instances, tenant stamps only if multi-tenancy-design chose
  them). Pods, replicas, ports, regions and per-tenant multipliers never go on
  the container picture. ASCII primary, Mermaid C4Container optional; names
  carried unchanged from the system context. Use when drawing, reviewing or
  changing a container diagram, deciding services or a modular monolith,
  placing a gateway, or drawing a deployment view. Used by enterprise-architect.
version: 3.0.0
phase: design
owner: enterprise-architect
created: 2026-06-25
tags: [design, architecture, c4-model, container-diagram, service-decomposition, modular-monolith, deployment-view, api-gateway]
produces: container-diagram
domain: architecture
status: stable
related: [system-context-diagram, component-diagram, bounded-context-mapping, multi-tenancy-design, integration-design, api-gateway-design, cqrs-pattern, adr-authoring, nfr-specification, sdlc-config-management, kubernetes-manifest, go-project-structure, glossary-management, methodology-review]
sources:
  - research/software-architecture/c4-model-brown.md
  - research/software-architecture/documenting-software-architectures-clements.md
  - research/software-architecture/software-architecture-hard-parts-ford.md
  - research/software-architecture/fundamentals-of-software-architecture-richards-ford.md
  - research/software-architecture/building-microservices-newman.md
  - research/software-architecture/system-design-interview-xu.md
  - research/devops-and-delivery/api-gateway-patterns.md
---

# Container Diagram

## Purpose

C4 Level 2 (Brown, `c4-model-brown.md`) zooms into the one system box of the system context diagram. **Readers:** engineers who will build it, platform-engineer and security-architect, and the product owner checking how many things there are to run and pay for. **Question:** what runnable units make up the system, what technology each uses, and how they talk at runtime?

One artifact per product, at every profile: `design/architecture/container-diagram.md` (`./templates/container-diagram.md`). It holds four parts, decided in this order:
1. **Decomposition:** which Bounded Contexts share a deployable (D047-6).
2. **The container view:** containers and connectors, a component-and-connector view (Clements).
3. **Gateway placement** (D047-11).
4. **The deployment view:** an allocation view, as a section, after `multi-tenancy-design` (D047-7, D047-13).

| Profile | Shape |
|---|---|
| Lean | One application container (a modular monolith, the contexts as its modules), its database, the web app if separate. Decomposition in two lines. Deployment view: one environment, a short table. No Mermaid |
| Standard | A split only where a disintegrator is named; one deployment view per environment that differs |
| Enterprise | The same, plus regions and tenant stamps in the deployment view only, with a variability guide |

What this skill does **not** hold: the Bounded Contexts (`bounded-context-mapping`); the tenancy model (`multi-tenancy-design`); how each integration behaves under failure (`integration-design`); gateway configuration (`api-gateway-design`, platform-engineer at Deploy); manifests (`kubernetes-manifest`); a container's insides (`component-diagram`).

## 1. Decomposition: Which Contexts Share a Deployable

Start from the Context Map, never from a rule that each context is a service. A Bounded Context is a language boundary, not a deployment decision: **a Bounded Context is not automatically a service.**
- **Lean: a modular monolith.** One deployable; each context is a module that owns its own tables or schema (Hard Parts' Single Owner). A module that needs another's data calls that module's published interface in-process, or reacts to its events (Delegate); it never reads or writes another module's tables, or imports its internals. Split later, on evidence.
- **Standard and enterprise: weigh both checklists** (Hard Parts, `software-architecture-hard-parts-ford.md`). Split a group of contexts off only on a named **disintegrator** with evidence: distinct scope, very different change rate, independent scaling or throughput, fault isolation, security isolation, extensibility. Keep together on an **integrator**: one transaction across them, chatty workflows between them, heavy shared code, tight data relationships. Record the forces both ways for each split; a non-obvious one gets an ADR.
- **Rules at every profile:** a context is never split between two deployables that both write its Aggregates (one write authority); an API and a worker of one context are two containers of one deployable; no two deployables share a database (within a monolith, one schema per module); a team boundary is a constraint, and another team's service is an external system (Brown; Newman's Conway's Law).

Detail, merge and split cases, naming, anti-patterns: `./references/service-decomposition.md`.

## 2. Containers

- A **container** is a separately runnable or deployable unit that runs code or stores data: a web app, a mobile app, an API, a worker, a database, a broker, a file store, a scheduled job (Brown). **Not a Docker container**: images, pods and replicas are deployment details (§ 5).
- Each box: **type tag** (`[Container: API]`, `[Container: Database]`), **name** in the product's language, **technology**, one-line **responsibility**.
- **Technology** comes from `sdlc-config.json` and the plugin defaults (`sdlc-config-management`); a deviation is an ADR before it appears here.
- **Persons and external systems** come from the system context diagram with identical names. One that is missing there goes back to be added there first.
- **Every datastore and the broker appear.** An omitted one is an unplanned one.

## 3. Connectors

- **One direction, from the caller or publisher;** the label says what flows and reads start to end ("Publishes `BookingConfirmed` to"), plus the **protocol** (mandatory at Level 2) and **sync or async**. The key states what an arrow means.
- **Through the broker,** keep producer-consumer pairs readable (Brown): label each arrow with its topic, or draw the broker and list who publishes and who consumes each topic in the communication matrix. A hub where every arrow just points at the broker hides who depends on whom.
- **Smart endpoints, dumb pipes** (Newman): no business rules in the broker, the gateway or the mesh.
- Each synchronous call between deployables is a coupling point: name it, and leave timeouts, retries and breakers to `integration-design`.

Notation, box anatomy, the broker options: `./references/c4-container-notation.md`.

## 4. Gateway Placement (D047-11, D047-12)

Decide whether there is a gateway and where it sits; platform-engineer configures it at Deploy (`api-gateway-design`).
- **Two planes, both marked:** one north-south entry for client traffic (the gateway, or the ingress when there is none); east-west calls between containers go through the mesh (Linkerd, mutual TLS), not back through the gateway. Complementary, never alternatives (`api-gateway-patterns.md`).
- **It holds routing, TLS, token validation, rate limits. Never business logic** (pricing, eligibility, workflow) (Xu, Newman). Client-specific aggregation is a backend-for-frontend container behind it.
- **Services still verify identity** themselves; the gateway is the first check, not the only one (D047-12).
- **Lean** usually needs no gateway: the ingress routes straight to the one application. Say so.

Detail: `./references/gateway-placement.md`.

## 5. The Deployment View (a Section, D047-13)

The container view says what talks to what; the deployment view says **where each container runs, how many instances, in which environment** (Clements' allocation view; Brown's deployment diagram). Keep them apart: nothing in this section goes on the container picture.
- One per environment that differs (production always; staging if its shape differs).
- **Deployment nodes**, nested (region, cluster, namespace, managed database service), **infrastructure nodes** (load balancer, ingress, CDN, DNS) and the **container instances** in each, with counts.
- **Tenancy:** only what `multi-tenancy-design` chose: a pooled deployment, a stamp per tenant or per region, or a mix. There is no default; never assume a per-tenant stamp or a shared broker. No tenancy needed means a single deployment.
- **Tenancy not designed yet:** still draw what the NFRs already fix: the environment, the regions data residency requires (EU data in an EU region), cluster and namespaces, infrastructure nodes, container instances and counts. Mark only the tenant dimension (stamps, which tenants where) *pending multi-tenancy-design*, list it as an open question, and say in the variability guide what will vary per tenant once it is decided.
- A **mapping table** (every container to the node it runs on) and a **variability guide** (what changes per environment, region or tenant).
- platform-engineer turns it into manifests at Deploy; it doesn't redraw it.

Detail and vocabulary: `./references/deployment-view.md`. Why the two views stay apart: `./references/viewtype-distinction.md`.

## 6. Notation and the Package

- **Title** `Container diagram for <System>`, **readers and question**, **key** (types, solid sync, dashed async, what an arrow means) (Brown).
- **ASCII primary** inside a system boundary box, with the catalog tables; **Mermaid `C4Container` optional**, never at lean (D047-13); the deployment view in ASCII or a table, Mermaid `C4Deployment` optional.
- **Catalog:** containers; communication matrix (from, to, what flows, protocol, sync or async); context to deployable mapping. **Rationale:** why this shape. **Fitness functions** (Richards & Ford): the automated check that keeps each rule true (a module import test, no cross-schema queries, one writer per table).

## Procedure

1. **Read** the approved system context diagram, `design/context-map.md`, the domain model, `cqrs-decisions.md`, the NFR specification's architecture handoff, `sdlc-config.json`, and `multi-tenancy-design.md` if it exists. Missing input: carry on, mark each assumption, list it under *Open questions*.
2. **Decompose** (§ 1): profile, deployables, the forces for each split, the context mapping.
3. **List containers** (§ 2) and **connectors** (§ 3); place the gateway (§ 4).
4. **Draw** the ASCII container view with title, readers, question and key; write the catalog, rationale and fitness functions.
5. **Deployment view** (§ 5): draw it from the NFRs; the tenant dimension from `multi-tenancy-design`, or marked pending until it exists.
6. **Validate, then loop.** Run `./scripts/validate-container-diagram.sh design/architecture/container-diagram.md design/architecture/system-context.md`, fix every FAIL, re-run until clean; then `./resources/checklist.md`.
7. **Present** for approval (the phase gate after the deployment view), with the reason for every request declined (§ Gotchas). Hand on: integrations, tenancy, component diagrams for non-default containers, API contracts.

Examples: `./examples/01-lean-modular-monolith.md` (a box office: two contexts in one app, no gateway, one environment), `./examples/02-standard-split-on-disintegrators.md` (a veterinary group: three deployables from four contexts, each split justified, a gateway without business logic, broker topics readable, staging and production), `./examples/03-enterprise-regions-and-stamps.md` (a freight platform: per-region deployment views, dedicated stamps for two large customers chosen by multi-tenancy-design, a variability guide).

## Gotchas

Each trap comes with the reason to give in full.

- **"Each Bounded Context is its own service,"** even for a small tool. *Reason:* a context is a language boundary; deployables are chosen by granularity forces and the profile (Hard Parts; D047-6), and every split adds a network, a deployment and a failure mode. *Instead:* lean is one modular monolith; split on a named disintegrator.
- **"Put the pod counts, replicas, ports and '×N per tenant' on the diagram."** *Reason:* they change where things run, not what talks to what; mixed in, the picture answers neither question (Clements). *Instead:* the deployment view section.
- **"List our Docker images as the containers."** *Reason:* a C4 container is a runnable unit (an app, an API, a database), not a Docker container (Brown). *Instead:* containers here; images and pods in the deployment view.
- **"Let the two services share the database; it's simpler."** *Reason:* a shared schema is an unmanaged shared model and couples their releases. *Instead:* one owner per database; the other asks through an API or an event. In a monolith, one schema per module.
- **"Put the discount and eligibility rules in the gateway."** *Reason:* a smart gateway becomes an unowned service coupled to every context (Xu, Newman). *Instead:* rules in the owning service; the gateway routes, validates tokens, limits rates.
- **"The gateway checks the token, so services don't need to."** *Reason:* anything that reaches a service another way bypasses it (D047-12). *Instead:* services verify identity too.
- **"One shared broker and a stamp per tenant,"** before any tenancy decision. *Reason:* there is no tenancy default (D047-7); the model comes from the NFRs and compliance input. *Instead:* run `multi-tenancy-design` first; mark the deployment view pending.
- **"Draw every arrow into the broker."** *Reason:* the real producer-consumer pairs vanish (Brown). *Instead:* topic labels, and who publishes and consumes each topic in the matrix.
- **"Draw a component diagram for every service, so the set is complete."** *Reason:* component diagrams are drawn only for a container whose insides differ from the default skeleton (D047-13; Brown: optional, only where they add value). *Instead:* name the container that needs one and why; for the rest, one line saying the default skeleton applies.
- **"Make a separate deployment-diagram artifact."** *Reason:* the plugin keeps the deployment view as a section of this artifact (D047-13). *Instead:* the section, one per environment that differs.
- **"Call Stripe 'Payments API' here,"** or add an external system not on the context diagram. *Reason:* names that differ between levels look like different systems; hand-drawn diagrams don't keep in step. *Instead:* identical names; a new external system is added to the context diagram first.
- **"Mermaid flowchart only."** *Reason:* one rule for all C4 diagrams: ASCII primary plus tables, Mermaid optional (D047-13). *Instead:* ASCII first; a `C4Container` copy at standard or enterprise if asked.

## References

| Question | File |
|---|---|
| Which contexts share a deployable; merge and split; naming; anti-patterns | `./references/service-decomposition.md` |
| Box anatomy, technology labels, connectors, broker options, key | `./references/c4-container-notation.md` |
| Gateway or none, north-south vs east-west, BFF, identity | `./references/gateway-placement.md` |
| Environments, nodes, instances, tenancy, variability guide | `./references/deployment-view.md` |
| Why container and deployment views stay apart | `./references/viewtype-distinction.md` |
| The artifact skeleton | `./templates/container-diagram.md` |
| Checking before hand-off | `./resources/checklist.md` |
