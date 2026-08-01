---
name: system-context-diagram
description: >
  Teaches the enterprise-architect to produce a C4 Level 1 (System Context)
  diagram — the system as a single box, the people (personas/roles) who use it,
  and the external systems it depends on or is depended upon by, with the key
  interactions labeled. Covers the C4-L1 notation, the procedure for identifying
  external actors and drawing the correct system boundary (what is inside vs.
  outside the system being built), and the diagram artifact template. The first
  architecture view produced, before Container and Component views. Used at the
  start of Design.
version: 2.0.0
phase: design
owner: enterprise-architect
created: 2026-06-25
tags: [design, architecture, c4-model, system-context, documentation, external-actors, system-boundary]
produces: system-context-diagram
domain: architecture
status: stable
related: [container-diagram, component-diagram, user-persona, event-storming-facilitation, nfr-specification, glossary-management]
---

# System Context Diagram

## What This View Shows

The System Context Diagram is **C4 Level 1** (Simon Brown) — the highest-level
architecture view, drawn first. It answers one question every stakeholder,
technical or not, must be able to answer: **what is this system, who uses it,
and what does it interact with?**

It shows exactly three kinds of thing and nothing else:

- **One system box** — the system being built, labelled with its name and a
  one-sentence purpose. Never how it works; only what it is.
- **Person elements** — the human roles who interact with the system, drawn
  from the user personas and the Actors surfaced in Event Storming.
- **External system elements** — systems outside the boundary that the system
  integrates with. Not built or owned by this team.

Internal detail is deliberately absent: no services, no databases, no message
brokers, no infrastructure, no technology labels. Those belong to Level 2
(Container) and lower. The power of this view is its simplicity — the one
diagram Shafi can read without an IDE, without knowing Go, and use to confirm
the scope is right before any detail is built on top of it.

In *Documenting Software Architectures* (Clements) terms this is a
**component-and-connector view at its coarsest grain**: one component ("the
system"), a handful of external components, and connectors labelled with what
flows. It is a **viewpoint** — a fixed set of conventions for what may and may
not appear — not a free-form sketch.

---

## The System-Boundary Rule

The single most important decision this view makes is **where the boundary
sits**. Apply one rule:

> **Exactly one box is "the system we are building." Everything else on the
> diagram is either a person or an external system.**

There is no third category at Level 1. If an element is neither a human role
nor a system outside our ownership, it does not appear — it is internal, and
internal structure is a Level 2 concern. A frontend and backend are not two
context boxes; they are two containers *inside* the one system box.

To classify any candidate element, apply the **"do we build and own it?" test**
(worked in full in `references/boundary-identification.md`):

- **We build and own it** → it is *inside* the system box, therefore invisible
  at Level 1 (it is a container, shown at Level 2).
- **A human uses or operates it** → it is a **person** element.
- **It runs and is owned by someone else, and we integrate with it** → it is an
  **external system** element.

Ambiguous cases — a shared platform service, a third-party API, an identity
provider, a customer's own storage — are resolved by ownership and control, not
by network location. `references/boundary-identification.md` walks each case.

---

## Identifying the Actors

An actor is anything outside the box connected to it by a relationship. Find
them with three signals:

- **Who initiates work?** A person or system that sends the system a request or
  command. (Data Steward uploads a scan config; a webhook fires an event in.)
- **Who receives output?** A person or system the system pushes results to.
  (Compliance Officer reads a report; an alerting gateway receives a risk
  alert.)
- **Which external systems are consumed, and which consume us?** Upstream
  dependencies the system calls out to (Google Drive, S3, an IdP) and
  downstream consumers that call the system.

Every persona from the `user-persona` skill maps to at most one person element;
every External System (pink card) from `event-storming` maps to one external
system element. Cross-check both inventories plus the `nfr-specification`
(data-residency constraints move some systems across the boundary) before you
call the actor list complete.

---

## When and Why to Draw It

Draw it **first**, at the start of Design, after domain modelling and before
the Container view. Never jump to Level 2 before Level 1 is agreed.

Its purpose (Fairbanks/Xu: "clarify scope before drawing boxes") is a shared
big-picture that non-technical stakeholders can read and approve. It also
records what is **out of scope** — an external system on the diagram is an
explicit statement of "we integrate with this, we do not build it." If the
context is wrong, every detailed diagram built on it is wrong, so it is the
cheapest possible place to catch a scope error.

Redraw it whenever a new external integration or user role appears; a stale
context diagram silently contradicts the detail diagrams beneath it.

---

## Reference Material

This skill's detail lives in three self-contained reference files. Load the one
that matches the task:

- **`references/c4-context-notation.md`** — the full C4-L1 notation: the system
  box, person elements (role + description), external-system elements,
  relationship arrows with interaction labels and protocols, the colour
  convention, and Clements' element-catalog / per-view Rationale guidance. Read
  this when you need the exact vocabulary and what each element must carry. The
  key distinction it settles: an **internal container is never shown at L1; an
  external system always is**.
- **`references/boundary-identification.md`** — the step-by-step procedure to
  inventory personas and upstream/downstream systems, apply the "do we build
  and own it?" test, resolve ambiguous cases (shared service, third-party API,
  identity provider, customer-owned storage), and avoid the boundary
  anti-patterns (internal service drawn as external, omitted human actor, data
  store shown at L1). Read this when deciding what goes inside vs. outside.
- **`references/diagram-template-and-example.md`** — the artifact template
  (Mermaid + textual C4 + ASCII) and a fully worked System Context Diagram for
  this repo's product: the data-estate / compliance platform, with Data Steward
  and Compliance Officer personas, external Google Drive / S3 / identity
  provider systems, and the platform as the single system box. Read this when
  producing the actual artifact.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Single system box | Exactly one box for the system being built | Multiple internal service boxes visible |
| Named persons | Every user role from personas is a distinct element | Generic "User" without a role name |
| All external systems | Every integration from Event Storming is shown | A supporting system (IdP, alerting) omitted |
| Labelled relationships | Every arrow states what flows and who initiates | Unlabelled or double-headed arrows |
| No internal detail | No databases, services, or infrastructure inside the box | Containers or technology visible at L1 |
| Plain English | Descriptions readable by Shafi without technical background | Jargon or technology labels on elements |
| Rationale captured | A sentence on why this boundary, distinct from constraint notes | Boundary asserted with no reasoning |

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Container diagram in disguise** — internal services/databases drawn at L1 | Destroys the one diagram every stakeholder can read | One box; push all internal structure to Level 2 |
| **The split system** — "Frontend" and "Backend" as two context boxes | Fragments the boundary; users appear to use implementation halves | One box for the whole system; frontend/backend is Level 2 |
| **Generic "User"** | Hides the distinct roles found in personas and Event Storming | One person element per role, named in the Ubiquitous Language |
| **Forgotten supporting system** — IdP, alerting, monitoring omitted | These carry auth, compliance, availability consequences that surface late | Cross-check Event Storming pink cards + NFR spec before approval |
| **Technology labels at L1** — "React SPA", "PostgreSQL" on elements | Invites tech debate before the boundary is agreed; excludes reviewers | Technology first appears on the Container diagram |
| **Data store at L1** — a database drawn as an external system | A database we own is internal; only externally-owned storage is external | Apply the "do we build and own it?" test |
| **Context set in stone** — never revisited when an integration is added | Detail diagrams start contradicting L1; the anchor misleads | Any new external system or role triggers a redraw and re-approval |
