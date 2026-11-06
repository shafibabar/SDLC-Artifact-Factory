# Example 1 — Lean: An Internal Tool

Self-contained. **Kilnbook** keeps the firing log for one community pottery studio: the kiln technician plans each firing, loads members' pieces, and records the result. The studio's two kilns have a vendor controller that reports each firing's temperature curve to the vendor's cloud service; the studio's treasurer keeps member charges in a shared Google Sheet. **Lean** profile: one deployable, about 120 members, one technician.

## Input

> **User:** "Draw the context diagram. Put the SQLite database and the nightly export job on it too, so I can see where the data lives. And members should be on it, they're the ones whose pots get fired."

## Working it

- **Persons.** The persona file has one persona that uses Kilnbook: the **Kiln Technician**. Members never open Kilnbook; the technician logs their pieces. A member is not a person on this diagram; the rationale says why, so the omission is a decision, not an oversight.
- **External systems.** The Event Storming timeline names *Firing Curve Received* from "kiln controller cloud" and *Charges Exported* to "the treasurer's sheet". Ownership test: the controller cloud is the kiln vendor's (**external**); the Google Sheet is the studio's, outside Kilnbook (**external**, customer-owned).
- **Declined:** the SQLite database and the nightly export job are things we build and run: **containers**, Level 2. They go in the rationale by name and on the container diagram.
- **Lean:** the diagram, key and catalog; one or two sentences of rationale and boundary notes; no Mermaid.

## Output: `artifacts/kilnbook/design/architecture/system-context.md`

````markdown
---
name: system-context-diagram
product: kilnbook
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-03-10
summary: Kilnbook as one system used by the Kiln Technician, receiving firing curves from the kiln vendor's cloud and sending member charges to the studio's Google Sheet.
traces-to: [ideate/user-personas.md, design/event-storming/big-picture.md, ideate/nfr-specification.md]
---

# System Context diagram for Kilnbook

**Readers:** the product owner and the studio committee
**Question it answers:** what Kilnbook is, who uses it, and which other systems it works with.

## Diagram

```
                 ┌──────────────────────────────┐
                 │ [Person]                     │
                 │ Kiln Technician              │
                 │ Plans firings, logs pieces   │
                 │ and results                  │
                 └──────────────┬───────────────┘
                                │ Plans firings, logs pieces
                                │ and results
                                ▼
┌──────────────────────┐   ┌──────────────────────────────┐   ┌──────────────────────┐
│ [External System]    │   │ [Software System]            │   │ [External System]    │
│ Kiln Vendor Cloud    │──▶│ Kilnbook                     │──▶│ Studio Charges Sheet │
│ Reports each firing's│   │ Keeps the studio's firing    │   │ Treasurer's Google   │
│ temperature curve    │   │ log and what each member     │   │ Sheet of member      │
└──────────────────────┘   │ is charged                   │   │ charges              │
      Sends firing          └──────────────────────────────┘   └──────────────────────┘
      curves to                                Appends monthly member charges to
```

## Key

- `[Person]` a role that uses the system
- `[Software System]` the system being built (one box)
- `[External System]` a system someone else owns and runs
- Arrows point from the party that starts the exchange; the label says what flows.

## Element Catalog

### System

**Kilnbook:** Keeps the studio's firing log, which member pieces went in each firing and what each member is charged.

### Persons

| Person | Role | How they use the system | Source |
|---|---|---|---|
| Kiln Technician | Runs the studio's two kilns | Plans firings, logs pieces and results | persona: Kiln Technician |

### External Systems

| System | Owner | Kind | Provides or receives | Source |
|---|---|---|---|---|
| Kiln Vendor Cloud | The kiln manufacturer | third-party service | Provides each firing's temperature curve | Event Storming: Firing Curve Received |
| Studio Charges Sheet | The studio treasurer | customer-owned | Receives monthly member charges | Event Storming: Charges Exported |

### Relationships

| From | To | What flows | Protocol |
|---|---|---|---|
| Kiln Technician | Kilnbook | Plans firings, logs pieces and results | HTTPS |
| Kiln Vendor Cloud | Kilnbook | Sends firing curves to | webhook |
| Kilnbook | Studio Charges Sheet | Appends monthly member charges to | Google Sheets API |

## Rationale

The database and the nightly export job are containers of Kilnbook, shown on the container diagram. Members are not persons here because they never use Kilnbook; the technician logs their pieces.

## Boundary Notes

- **Constraints:** the treasurer keeps the Google Sheet as the record of charges; Kilnbook appends to it and never replaces it.
- **Out of scope:** taking payment (the treasurer collects it); controlling the kilns (the vendor's controller does).

## Open Questions

- none
````

## Why this is right

- One person, two external systems, one system box: everything Kilnbook runs stays inside.
- The database and job were declined with the reason, and named in the rationale so the container diagram picks them up.
- Members were left off on evidence (they don't use the system), and the rationale says so.
- `validate-system-context.sh` exits clean on the artifact.
