# C4 Level 1 (System Context) Notation

Complete notation reference for the System Context Diagram — the highest-level
C4 view (Simon Brown), grounded in Clements et al.'s *Documenting Software
Architectures* view discipline. Self-contained: everything needed to draw and
document a correct Level 1 view is here.

---

## The C4 Level Ladder — Where L1 Sits

The C4 model defines four levels of abstraction. Level 1 is the entry point;
never draw a lower level before the level above it is agreed.

| Level | Name | Shows | Audience |
|---|---|---|---|
| **1** | System Context | The system + its people + external systems | Anyone — no technical knowledge required |
| **2** | Container | Deployable/runnable units (services, DBs, SPAs) inside the system | Technical stakeholders, architects |
| **3** | Component | Groupings of functionality inside one container | Engineers working on that container |
| **4** | Code | Classes/functions inside one component | Engineers — usually generated, rarely hand-drawn |

C4 is a deliberately simplified, opinionated profile of Clements' richer,
stakeholder-driven view catalog. In Clements' vocabulary a System Context
Diagram is a **component-and-connector (C&C) view at its coarsest grain**: one
runtime component ("the system"), the external components it talks to, and the
connectors (labelled arrows) between them. Naming it a C&C viewpoint matters
because it explains why the view has **no time/sequence dimension** and **no
static module structure** — those are different view types, not lower zoom
levels of this one.

---

## The Three Element Types (and only three)

### 1. The System Box (exactly one)

The single box representing the system being built.

- **Label:** the system name, taken verbatim from the Ubiquitous Language
  (`glossary-management`). Not a codename, not "the platform" — the canonical
  product name.
- **Description:** one sentence stating *what it does for its users*, never
  *how*. "Maps a customer's data estate across cloud storage, classifies files,
  and flags compliance gaps" — not "Go microservices behind a chi gateway."
- **Colour convention:** solid blue. Blue means "the system we are designing."
- **Count:** always one. Two blue boxes means the boundary has fragmented (see
  the split-system anti-pattern) — merge them or you are drawing Level 2.

### 2. Person Elements

Each distinct human role that interacts with the system.

- **Label:** the role name from the personas (`user-persona`) and the Actors
  surfaced in Event Storming / Domain Storytelling — e.g. `Data Steward`,
  `Compliance Officer`, `IT Administrator`. Never a generic "User."
- **Description:** one phrase for *how this person uses the system* — "configures
  and reviews estate scans," "reviews compliance gaps and signs off reports."
- **Colour convention:** yellow/gold, usually drawn as a stick-figure or a
  rounded person shape.
- **Rule:** one element per role, not per named individual. Ten compliance
  officers are one `Compliance Officer` element.

### 3. External System Elements

Each system *outside the boundary* that the system integrates with — systems
this team does not build or own.

- **Label:** the external system's real name — `Google Drive`, `Amazon S3`,
  `Okta (Identity Provider)`, `PagerDuty`.
- **Description:** what data or capability it provides to, or receives from, the
  system — "customer's source file storage," "SSO / OIDC identity assertions,"
  "receives compliance risk alerts."
- **Colour convention:** grey. Grey means "external — someone else owns and
  operates this."
- **Source:** the External System (pink) cards from Event Storming, cross-checked
  against the `nfr-specification` for data-residency constraints.

There is no fourth element type at Level 1. Databases, message brokers,
load balancers, caches, and individual microservices are **containers** — they
live at Level 2 and must not appear here.

---

## The Internal-Container vs. External-System Distinction

This is the notation's sharpest rule and the one most often broken:

> **An internal container is NEVER shown at Level 1. An external system is
> ALWAYS shown at Level 1.**

- A **container** is a separately deployable/runnable thing *inside* the system
  box — an API service, the React SPA, a PostgreSQL instance you provision, a
  Redpanda broker you run. It is part of the system being built. At Level 1 it
  is hidden inside the single blue box; it first appears at Level 2.
- An **external system** is a whole system *outside* the box that you integrate
  with but do not build — Google Drive, S3, an identity provider. It is always
  a grey box at Level 1.

The test that separates them is ownership, not network location (see
`boundary-identification.md`): a PostgreSQL database *you* provision and operate
per tenant is an internal container (hidden at L1); a customer's own S3 bucket
you read from is an external system (grey box at L1), even though both are
"databases/storage over the network."

---

## Relationships (Connectors)

Every line on the diagram is a **connector** carrying data or control flow. At
Level 1 each relationship carries:

- **Direction:** the arrow points from **initiator → target**. The party that
  starts the interaction owns the arrowhead's tail. A user *reads* a report:
  the system pushes to the user, so the arrow points system → user only if the
  system initiates (an alert push); a user pulling a dashboard points user →
  system. Pick the direction that matches who *starts* the exchange.
- **Label:** what flows — "Uploads scan configuration," "Reads compliance
  report," "Fetches file metadata and content," "Verifies user identity via
  OIDC," "Sends risk alert."
- **Protocol:** optional at Level 1, mandatory at Level 2. When shown at L1,
  keep it plain: "HTTPS/JSON," "OIDC," "S3 API," "event webhook." Never a
  library or framework name.

Rules:

- No **unlabelled** arrows. "Integrates with" is not a label — it hides who
  initiates and what flows.
- No **double-headed** arrows. If interaction genuinely flows both ways, draw
  two arrows, each labelled with its own payload and direction.
- No arrows between two external systems. Level 1 shows only relationships that
  touch the system box. Google Drive talking to S3 (if it ever did) is not our
  concern and not on our diagram.

---

## What Does NOT Belong at Level 1

Push all of the following down to Level 2 or lower:

- Individual microservices, APIs, or the API gateway / BFF
- Databases (PostgreSQL, Apache AGE), caches (Redis), message brokers (Redpanda)
- Infrastructure — Kubernetes, Helm, Linkerd, load balancers, ingress
- Observability stack — OpenTelemetry, Prometheus, Tempo, Grafana
- Internal components or Go packages
- Technology choices and version numbers
- Deployment topology and per-tenant namespace layout

If it is inside the box, it is invisible here. Resist the pressure to add
detail — a diagram showing fifteen internal services next to two users is a
confused Container diagram, not a System Context Diagram.

---

## Clements' Documentation-Package Additions

A picture alone is, in Clements' words, "just a picture." A complete Level 1
view carries a small documentation package beyond the diagram:

- **Primary presentation** — the diagram itself (ASCII / Mermaid / textual C4).
- **Element catalog** — a table enumerating every person and external system
  with its description and the properties the picture cannot carry (e.g. an
  external system's protocol, whether it is customer-owned or third-party SaaS,
  its data-residency implications). This repo's Output Format tables already
  serve as the element catalog.
- **Rationale** — one or two sentences on *why this boundary and these external
  systems*. This is distinct from Boundary Notes: Boundary Notes records the
  *constraints* (data residency, tenant isolation) that force the boundary;
  Rationale records *why the view is shaped this way* — "Google Drive and S3 are
  external because the customer owns their content stores; we only read from
  them and never become the system of record." Rationale is the view-level,
  lighter-weight sibling of an ADR — it explains this diagram's shape, not a
  cross-cutting architectural decision.

A Level 1 view missing its element catalog and rationale is reviewable by eye
but not usable as a specification the Container diagram can be built from.

---

## Colour Convention Summary

| Element | Colour | Meaning |
|---|---|---|
| System being built | Blue | We design, build, and own this |
| Person | Yellow/gold | A human role that interacts with the system |
| External system | Grey | Someone else owns and operates this; we integrate |

In ASCII (this repo's PM-reviewable default) colour is conveyed by an explicit
`(External)` / `(Person)` tag on the box rather than fill colour — the semantics
survive even in monochrome Markdown.
