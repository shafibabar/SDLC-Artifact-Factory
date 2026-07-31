---
name: container-diagram
description: >
  Teaches the enterprise-architect to produce a C4 Level 2 (Container) diagram —
  the runtime building blocks of a system (services, databases, message brokers,
  front-ends) and the synchronous/asynchronous communication paths between them —
  while keeping the runtime component-and-connector concerns cleanly separated from
  deployment/allocation concerns (which belong to the deployment view). Covers C4-L2
  notation, technology-choice annotation, the Clements component-and-connector vs.
  allocation viewtype distinction, and the diagram template. Used during Design
  after the System Context view is fixed.
version: 2.0.0
phase: design
owner: enterprise-architect
created: 2026-06-25
tags: [design, architecture, c4-model, container-diagram, documentation, runtime-topology, viewtype, deployment]
related: [system-context-diagram, component-diagram, deployment-diagram, integration-design, adr-authoring, glossary-management, methodology-review]
---

# Container Diagram

## What a Container Diagram Is

A Container Diagram (C4 Level 2) zooms one level inside the system boundary drawn by the
System Context view and shows the **containers** — the independently deployable and runnable
units that make the system work: a Go API service, a PostgreSQL database, a Redpanda broker, a
React front-end, a background worker. A container is anything that must be **separately deployed
and run** and that hosts code or stores state.

The Container Diagram answers exactly three questions:

1. **What are the independently deployable/runnable units of this system?**
2. **What technology does each one use?**
3. **How do they communicate at runtime — over what protocol, synchronously or asynchronously?**

It is a **component-and-connector (C&C) view** in Clements' viewtype terminology: components are
the running containers, connectors are the runtime communication paths. This single fact governs
everything below — see `references/viewtype-distinction.md`.

### What it shows vs. what it omits

| Shows | Omits (and where it belongs) |
|---|---|
| Deployable/runnable units and their technology | Internal component/layer structure of a container → **C4 L3 Component diagram** |
| Runtime communication paths (protocol, sync/async) | Where containers physically run — nodes, pods, regions, tenant stamps → **deployment (allocation) view** |
| The system boundary; persons and external systems carried down from L1 | Class/function structure → **C4 L4 Code** |

## The Correctness Rule: C&C vs. Allocation

**A Container Diagram is a runtime C&C view. Deployment placement is a separate view. Never mix them.**

This is a correctness rule, not a style preference. The Container Diagram documents *what talks to
what, and how* at runtime. It must NOT document *where each container is deployed* — Kubernetes
nodes, pods, availability zones, per-tenant stamps, Helm release topology, or how many copies run.
That is an **allocation view** (a deployment diagram): the mapping of software onto non-software
structure.

Prior review (Clements, *Documenting Software Architectures*) flagged the earlier version of this
skill for exactly this conflation — putting deployment-flavoured annotations (cluster placement,
port bindings, tenant multiplication) onto what is nominally a C&C diagram. Symptoms that you have
drifted into an allocation view: node/pod boxes, region labels, or "×N per tenant" multipliers
appearing on the diagram. When you catch these, move them to the deployment diagram (owned by
`deployment-diagram` / `platform-engineer`) and leave a pure C&C view behind.

The two views relate through a **mapping between views** — each container in this diagram is later
allocated to nodes/pods in the deployment view — but they are drawn separately and never merged.
Full theory, the questions each view answers, and the conflation symptoms: `references/viewtype-distinction.md`.

## Standard Container Set (Default Stack)

For a Bounded Context in this repo's default stack, the standard C&C container set is:

| Container | Role | Technology annotation |
|---|---|---|
| `<BC> API` | Synchronous request/response + command handling | `Go, net/http + chi` |
| `<BC> Worker` | Consumes Domain Events, async processing | `Go, franz-go consumer` |
| `<BC> DB` | State store owned by exactly this service | `PostgreSQL 16, pgx` |
| Redpanda | Shared broker; one logical topic set per BC | `Redpanda (Kafka API)` |
| Web Shell / MFE | User-facing front-end | `React 18, TypeScript` |
| Graph store | Relationship/lineage queries | `Apache AGE (PostgreSQL ext.)` |

**One database per service** is a hard rule: no two containers share a database; cross-service data
flows through APIs (sync) or Domain Events on Redpanda (async), never a shared schema. Every
container carries an explicit technology label — an unlabelled container is an incomplete artifact.
Annotation conventions and the technology vocabulary: `references/runtime-topology-and-template.md`.

## Notation (summary)

- **Container box** — name + technology + one-line responsibility. Nothing about placement.
- **Sync connector** — solid arrow, labelled with protocol and payload, e.g. `HTTP/JSON`, `gRPC`.
- **Async connector** — dashed arrow via the broker, labelled with the topic, e.g. `Kafka/Redpanda: dataasset.discovered`.
- **System boundary box** — everything inside is a container of *this* system.
- **Person / external system** — carried down unchanged from the System Context (L1) view.

Full notation catalogue — box anatomy, arrow semantics, boundary and external-element rules:
`references/c4-container-notation.md`.

## Deciding Container Boundaries

Container boundaries follow Bounded Context boundaries from the domain model. Split further only
when a concern genuinely demands an independently deployable unit:

| Driver | Effect |
|---|---|
| Independent scaling | A unit that must scale on its own (scanning worker) is its own container |
| Change rate | A fast-changing unit is not coupled into a stable one |
| Team ownership | Different owners → different containers |

Note: physical multi-tenancy and data-residency constraints affect *where* and *how many times* a
container is deployed — that is allocation reasoning and is captured in the deployment view, not by
adding tenant copies to this C&C diagram. The container boundary stays singular here.

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Pure C&C view | No nodes, pods, replicas, regions, or tenant multipliers | Deployment placement drawn on the diagram |
| Technology labelled | Every container states its technology | Container labelled with a name only |
| Protocol labelled | Every connector names protocol + sync/async | Unlabelled arrows |
| One DB per service | No shared databases | Two services against one DB |
| External systems consistent | Match the System Context view exactly | New external systems appearing here |

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Deployment on a C&C view** | Nodes/pods/replicas make it an unlabelled combined view that answers no question cleanly | Move placement to the deployment (allocation) diagram; keep this a pure C&C view |
| **Shared database** | Silent coupling; the DB becomes an unmanaged Shared Kernel | One DB per service; cross-service via API or Domain Event |
| **Invisible infrastructure** | An omitted broker/DB/worker is an unplanned one | Every deployable and datastore appears |
| **Business logic in the gateway** | The BFF becomes an unowned service coupled to every BC | Gateway does routing/auth/rate-limiting only |
| **Aspirational technology labels** | Diagram silently overrides `sdlc-config.json` | Labels come from the agreed stack; deviations need an ADR |

## Producing the Artifact

Follow the template in `references/runtime-topology-and-template.md`: a Mermaid/textual C4 primary
presentation, a Containers catalogue table, a Communication Matrix (pure C&C — from, to, protocol,
sync/async), a Bounded-Context→Container mapping, and a pointer to where the deployment/allocation
view lives. That reference includes a fully worked, deployment-free Container diagram for this
repo's system (DataAsset Management + Compliance + Reporting services, Postgres, Redpanda, React shell).

## References

- `references/c4-container-notation.md` — full C4-L2 notation: box anatomy, sync/async connectors, system boundary, persons and external systems carried down from L1.
- `references/viewtype-distinction.md` — Clements' module / C&C / allocation viewtypes; why a Container diagram is C&C and a deployment diagram is allocation; conflation symptoms; how the two views relate.
- `references/runtime-topology-and-template.md` — technology-annotation conventions, the diagram artifact template, and a fully worked pure-C&C Container diagram for this repo's system.
