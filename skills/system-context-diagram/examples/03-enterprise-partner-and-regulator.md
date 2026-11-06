# Example 3 — Enterprise: Partner Organisations and a Regulator

Self-contained. **Grainlink** runs grain intake and grower settlement for an agricultural cooperative with eleven country elevators. Intake operators weigh and grade each truckload; growers check their loads and settlements online; settlement clerks approve payments; the compliance officer signs off the quarterly quality returns the national regulator requires. Grain leaves by rail with **Northline Rail**, a partner carrier. Prices come from the grain exchange's daily feed. The cooperative's ledger is its **ERP**, run by the corporate IT team. The old **weighbridge software** at each elevator stays in service until the last elevator moves to Grainlink in 2027. **Enterprise** profile.

## Input

> **User:** "Corporate IT is part of the cooperative, so put the ERP inside Grainlink. We're replacing the weighbridge software anyway, so it's inside too. Add AWS and Northline's SFTP server, that's how the rail files move. And the board wants all thirty of the cooperative's systems on this one diagram."

## Working it

- **ERP:** corporate IT owns and runs it on its own schedule; Grainlink posts to it and depends on its uptime. Another team's system is its own software system (Brown): **external**, owner named. Declined, with the reason.
- **Legacy weighbridge:** it still runs and still sends weights to Grainlink until 2027, and Grainlink's team does not run it. **External** until it is retired; the boundary notes give the date and say the diagram is redrawn then.
- **AWS:** where our containers run, not a system we exchange data with: the container diagram's deployment section. Declined.
- **Northline's SFTP server:** the transport, not the system. The external system is **Northline Bookings**; "SFTP file drop" is the arrow's protocol.
- **Thirty systems:** that is a System Landscape diagram, an optional C4 extra with no single focus. It does not replace this view, which shows only what Grainlink works with. Offered as a separate drawing if the board wants it.
- **Regulator:** Grainlink submits returns to the regulator's portal (an external system); the compliance officer is a person who signs them off in Grainlink.
- **Enterprise:** every external system's owner and kind; boundary notes name the constraints and what is out of scope. A Mermaid copy was not asked for, so none is drawn.

## Output: `artifacts/grainlink/design/architecture/system-context.md`

````markdown
---
name: system-context-diagram
product: grainlink
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-05-18
summary: Grainlink as one system for intake, growers, settlement and compliance, working with Northline Rail, the grain exchange, the regulator's portal, the co-op's bank, corporate ERP and the legacy weighbridge.
traces-to: [ideate/user-personas.md, design/event-storming/big-picture.md, design/context-map.md, ideate/nfr-specification.md, strategy/stakeholder-map.md]
---

# System Context diagram for Grainlink

**Question it answers:** what Grainlink is, who uses it, and which other systems it works with, for the board, the elevator managers and the partners.

## Diagram

```
                          ┌──────────────────────────┐         ┌──────────────────────────┐
                          │ [Person]                 │         │ [Person]                 │
                          │ Intake Operator          │         │ Grower                   │
                          │ Records loads, grades    │         │ Delivers grain, checks   │
                          └───────────────────┬──────┘         │ loads and settlements    │
                                              │ Records loads  └──────┬───────────────────┘
                                              │ and grades in         │ Views loads and
                                              │                       │ settlements in
 ┌────────────────────────┐               ┌───▼───────────────────────▼────┐                ┌────────────────────────┐
 │ [External System]      │ Sends ticket  │ [Software System]              │ Books rail     │ [External System]      │
 │ Legacy Weighbridge     │ weights to    │ Grainlink                      │ slots in       │ Northline Bookings     │
 │ Weighs trucks until    ├──────────────▶│                                │───────────────▶┤ Northline Rail's       │
 │ retired (2027)         │               │ Takes grain in at the          │                │ booking system         │
 └────────────────────────┘               │ cooperative's elevators:       │                └────────────────────────┘
 ┌────────────────────────┐               │ grades and weighs each         │                ┌────────────────────────┐
 │ [External System]      │ Sends daily   │ load, books rail and           │ Submits quality│ [External System]      │
 │ Commodity Price Feed   │ prices to     │ settles growers                │ returns to     │ Grain Quality Register │
 │ The grain exchange's   ├──────────────▶│                                │───────────────▶┤ National regulator's   │
 │ daily prices           │               │                                │                │ returns portal         │
 └────────────────────────┘               │                                │                └────────────────────────┘
 ┌────────────────────────┐               │                                │                ┌────────────────────────┐
 │ [External System]      │ Posts settle- │                                │ Sends grower   │ [External System]      │
 │ Cooperative ERP        │ ments to      │                                │ payments to    │ Cooperative's Bank     │
 │ Corporate IT's ledger  ┤◀──────────────│                                │───────────────▶┤ The co-op's bank;      │
 └────────────────────────┘               │                                │ Sends payment  │ pays growers           │
                                          │                                │ results to     │                        │
                                          │                                │◀───────────────┤                        │
                                          └─────▲───────────────────▲──────┘                └────────────────────────┘
                                Approves        │                   │ Reviews quality
                                settlements in  │                   │ returns in
                                                │                   │
                                  ┌─────────────┴────────────┐  ┌───┴──────────────────────┐
                                  │ [Person]                 │  │ [Person]                 │
                                  │ Settlement Clerk         │  │ Compliance Officer       │
                                  │ Approves grower          │  │ Signs off quality        │
                                  │ settlements              │  │ returns                  │
                                  └──────────────────────────┘  └──────────────────────────┘
```

## Key

- `[Person]` a role that uses the system
- `[Software System]` the system being built (one box)
- `[External System]` a system someone else owns and runs
- Arrows point from the party that starts the exchange; the label says what flows.

## Element Catalog

### System

**Grainlink:** Takes grain in at the cooperative's elevators: grades and weighs each load, books rail for it, and settles growers for what they delivered.

### Persons

| Person | Role | How they use the system | Source |
|---|---|---|---|
| Intake Operator | Staff at a country elevator | Records loads and grades | persona: Intake Operator |
| Grower | A cooperative member who delivers grain | Views loads and settlements | persona: Grower |
| Settlement Clerk | Head-office finance staff | Approves grower settlements | persona: Settlement Clerk |
| Compliance Officer | Accountable for quality reporting | Reviews and signs off quality returns | persona: Compliance Officer |

### External Systems

| System | Owner | Kind | Provides or receives | Source |
|---|---|---|---|---|
| Legacy Weighbridge | Elevator managers, with the weighbridge vendor | another team in our organisation | Provides ticket weights until retired in 2027 | Event Storming: Ticket Weighed |
| Commodity Price Feed | The grain exchange | third-party service | Provides daily prices by grade | Context Map: Pricing ACL |
| Cooperative ERP | Corporate IT team, the cooperative | another team in our organisation | Receives approved settlements | Context Map: Ledger (Customer-Supplier) |
| Northline Bookings | Northline Rail | partner organisation | Receives rail slot bookings | Event Storming: Rail Slot Booked |
| Grain Quality Register | The national grain regulator | regulator | Receives quarterly quality returns | NFR: statutory quality reporting |
| Cooperative's Bank | The cooperative's bank | third-party service | Receives grower payments; sends payment results | Context Map: Payments ACL |

### Relationships

| From | To | What flows | Protocol |
|---|---|---|---|
| Intake Operator | Grainlink | Records loads and grades in | HTTPS |
| Grower | Grainlink | Views loads and settlements in | HTTPS |
| Settlement Clerk | Grainlink | Approves settlements in | HTTPS |
| Compliance Officer | Grainlink | Reviews quality returns in | HTTPS |
| Legacy Weighbridge | Grainlink | Sends ticket weights to | SFTP file drop |
| Commodity Price Feed | Grainlink | Sends daily prices to | HTTPS |
| Grainlink | Cooperative ERP | Posts settlements to | HTTPS |
| Grainlink | Northline Bookings | Books rail slots in | SFTP file drop |
| Grainlink | Grain Quality Register | Submits quality returns to | HTTPS |
| Grainlink | Cooperative's Bank | Sends grower payments to | bank payment file |
| Cooperative's Bank | Grainlink | Sends payment results to | bank payment file |

## Rationale

Grainlink's web app, intake tablet app, API, worker and database are its containers, shown on the container diagram. The ERP is external because corporate IT owns and runs it; Grainlink posts to its published interface. The legacy weighbridge is external because each elevator runs it until it is retired. The SFTP server and the cloud hosting are transport and infrastructure, not systems on this view.

## Boundary Notes

- **Constraints:** the regulator fixes the quarterly return's content and deadline; grower bank details stay with the bank, Grainlink holds only a payment reference; the weighbridge stays until 2027, then this diagram is redrawn without it.
- **Out of scope:** the general ledger and grower tax statements (Cooperative ERP); train planning and freight billing (Northline Rail); price setting (the exchange). The cooperative's other systems are not on this view; a System Landscape diagram can show them if the board asks.

## Open Questions

- none
````

## Why this is right

- The ERP and the weighbridge are external on the ownership rule, and the weighbridge's exit date is a boundary note, so the redraw is planned.
- AWS and the SFTP server are not elements: one is the deployment view, the other an arrow's protocol.
- Partner, regulator and third-party systems each name their owner and kind; the out-of-scope list says which system does what Grainlink doesn't.
- The thirty-system request is pointed to a System Landscape diagram, not crammed into this view.
- `validate-system-context.sh` exits clean on the artifact.
