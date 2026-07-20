---
name: system-context-diagram
description: >
  Teaches how to produce a C4 Level 1 System Context Diagram — the highest-level
  architecture view showing the system being built, the external users who interact
  with it, and the external systems it depends on or integrates with. The System
  Context Diagram is the first architecture artifact produced and the entry point
  for all more detailed diagrams. Used by the enterprise-architect agent at the
  start of the Design phase architecture work, after domain modelling is complete.
version: 1.1.0
phase: design
owner: enterprise-architect
created: 2026-06-25
tags: [design, architecture, c4, system-context, diagrams]
---

# System Context Diagram

## Purpose

The System Context Diagram (C4 Level 1, Simon Brown) answers the most fundamental architecture question: **what is this system, who uses it, and what does it interact with?**

It is the first diagram an architect draws and the first one a stakeholder should see. It deliberately excludes internal detail — no services, no databases, no infrastructure. It shows only:
- The system being built (one box)
- The people who use it (user roles)
- The external systems it integrates with

The System Context Diagram is the anchor for every more detailed diagram. If the context is wrong, all detail built on top of it is wrong.

---

## C4 Model Overview

The C4 model (Simon Brown) defines four levels of abstraction for architecture diagrams:

| Level | Name | Shows | Audience |
|---|---|---|---|
| **1** | System Context | The system + users + external systems | Anyone — no technical knowledge required |
| **2** | Container | Services, databases, frontends inside the system | Technical stakeholders, architects |
| **3** | Component | Components inside a container | Engineers working on that container |
| **4** | Code | Classes, functions inside a component | Engineers — generated from code |

Always start with Level 1. Never jump to Level 2 before Level 1 is agreed upon.

---

## System Context Diagram Elements

### The System (centre box)

The system being built — one box, labelled with the system name and a one-sentence description of its purpose.

- Label: the system name from the Ubiquitous Language
- Description: what it does for its users — not how it does it
- Colour convention: blue (the system being designed)

### Persons (actors)

The human users who interact with the system. Derived from the user personas and the Actors identified in Domain Storytelling and Event Storming.

- Label: the role name from the Ubiquitous Language
- Description: how this person interacts with the system — one phrase
- Colour convention: yellow/gold

### External Systems

Systems outside the boundary of the system being built that it communicates with. These are not designed by this team.

- Label: the external system's name
- Description: what data or capability this system provides to or receives from the system being built
- Colour convention: grey (external — not owned)
- Source: External Systems identified during Event Storming (pink cards)

### Relationships

Arrows between elements, labelled with the nature of the interaction:
- Direction: the initiator points to the target
- Label: what data or request flows along the relationship
- Protocol (optional at Level 1, required at Level 2): HTTP, event stream, file, etc.

---

## What Does NOT Belong in a System Context Diagram

These elements belong in Level 2 (Container Diagram) or lower — not here:

- Individual microservices or APIs
- Databases or message brokers
- Infrastructure (Kubernetes, load balancers)
- Internal components or modules
- Technology choices
- Deployment topology

Resist the pressure to add detail. The power of the System Context Diagram is its simplicity. A diagram that shows 15 internal services as boxes next to external users is not a System Context Diagram — it is a confused Container Diagram.

---

## ASCII Representation

For this plugin, diagrams are expressed in ASCII for PM-reviewable Markdown. The enterprise-architect produces an ASCII version plus a structured description that can be rendered in any diagram tool.

```
                    ┌─────────────────────────────┐
                    │     [User Role 1]            │
                    │  Compliance Officer          │
                    │  Reviews compliance gaps     │
                    └──────────────┬──────────────┘
                                   │ Views dashboards,
                                   │ runs reports
                                   ▼
┌──────────────┐    ┌─────────────────────────────┐    ┌──────────────────┐
│ Google Drive │◀───│                             │───▶│    AWS S3        │
│ (External)   │    │   Data Estate Mapping &     │    │ (External)       │
│ Customer's   │    │   Compliance Intelligence   │    │ Customer's files │
│ file storage │    │                             │    └──────────────────┘
└──────────────┘    │   Maps data estates,        │
                    │   classifies files,          │    ┌──────────────────┐
┌──────────────┐    │   detects compliance gaps   │◀───│  Identity        │
│  IT Lead     │───▶│                             │    │  Provider (IdP)  │
│ Deploys and  │    └─────────────────────────────┘    │ Customer's SSO   │
│ configures   │                   │                   └──────────────────┘
│ the platform │                   │ Raises alerts
└──────────────┘                   ▼
                    ┌─────────────────────────────┐
                    │  [User Role 2]              │
                    │  CISO / Security Lead       │
                    │  Receives risk alerts       │
                    └─────────────────────────────┘
```

---

## Step-by-Step Production

1. Read the product name and description from `sdlc-context.json → first_product`.
2. Read user personas — each persona maps to a Person element.
3. Read Event Storming output — External Systems (pink cards) map to external system elements.
4. Read NFR specification — data residency constraints determine which external systems are within vs. outside the boundary.
5. Draw the system in the centre.
6. Place all Person elements around it.
7. Place all external system elements around it.
8. Draw relationships with direction and labels.
9. Apply the "does NOT belong" check — remove any internal detail that crept in.
10. Present to Shafi for approval before proceeding to Container Diagram.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Single system box | Exactly one box for the system being built | Multiple internal service boxes visible |
| Named persons | All user roles from personas are represented | Generic "User" without a role name |
| All external systems | Every external integration identified in Event Storming is shown | Missing external systems |
| Labelled relationships | Every arrow has a label describing what flows | Unlabelled arrows |
| No internal detail | No databases, services, or infrastructure inside the system box | Internal components visible at this level |
| Plain English | All descriptions are readable by Shafi without technical background | Technical jargon in element descriptions |

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Container Diagram in disguise** — internal services, databases, or brokers drawn at Level 1 | The one diagram every stakeholder can read is destroyed by detail only engineers need | One system box; push all internal structure down to Level 2 |
| **The split system** — "Frontend" and "Backend" as two context-level boxes | The system boundary fragments; users appear to interact with implementation halves | One box for the whole system being built; frontend/backend is a Level 2 concern |
| **Generic "User"** | Hides the distinct roles, goals, and permissions discovered in personas and Domain Storytelling | One Person element per role, named in the Ubiquitous Language |
| **Forgotten supporting systems** — the IdP, email/alerting gateway, or monitoring SaaS omitted | These integrations carry auth, compliance, and availability consequences that surface late | Cross-check against Event Storming pink cards and the NFR specification before approval |
| **Technology labels at Level 1** — "React SPA", "PostgreSQL" on context elements | Invites technology debate before the boundary is agreed; excludes non-technical reviewers | Technology first appears on the Container Diagram |
| **Ambiguous arrows** — unlabelled or double-headed relationships | "Integrates with" hides who initiates, what flows, and which side depends on which | Every arrow: initiator → target, labelled with what flows |
| **Context set in stone** — the diagram never revisited when a new external integration is added | Detail diagrams start contradicting Level 1; the anchor becomes misleading | Any new external system or user role triggers a context diagram update and re-approval |

---

## Output Format

```markdown
---
name: system-context-diagram
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: enterprise-architect
---

# System Context Diagram: [Product Name]

## Diagram

[ASCII diagram]

## Elements

### System
**[System Name]:** [One-sentence description]

### Persons
| Person | Role description | Interaction with system |
|---|---|---|

### External Systems
| System | Owner | What it provides / receives |
|---|---|---|

### Relationships
| From | To | Description | Protocol |
|---|---|---|---|

## Boundary Notes
[Any data residency or tenant isolation constraints that affect what is inside vs. outside the system boundary]
```
