# Example 2 — Standard: An Anti-Corruption Adapter and a Read-Model Projector

Self-contained. **DropPoint** runs a network of parcel lockers in shopping centres and stations: couriers deposit parcels, recipients collect with a code. **Standard** profile. The container diagram's `locker` deployable (Go, chi) owns the Locker context: Aggregate `Locker` (compartments, reservations, maintenance state). Two things set it apart from the default skeleton: the lockers are driven by a **vendor's controller API** whose model (doors, sensors, firmware status codes) is unlike the domain's, and the operations dashboard needs an **occupancy read model** per site, updated from events. Default stack.

## Input

> **User:** "Draw the locker service's component diagram. Show one box for each handler and each SQL query so nothing is hidden, and label the arrows inside with HTTP or Kafka so people know the protocol."

## Working it

- **Draw it:** two departures, the vendor adapter (an anti-corruption layer, `context-map-patterns`) and the projector (the CQRS read side, `cqrs-pattern`).
- **Declined:** a box per handler or query. That is Level 4; a component is a grouping behind an interface (Brown). The handlers are one entry-point component; persistence is one adapter.
- **Declined:** protocols on inside arrows. Dependencies inside the container are in-process; protocols label only the arrows that leave the boundary (to PostgreSQL, Redpanda, the vendor API).
- **Ports:** the domain declares `LockerRepository`, `EventPublisher`, `LockerController` (the capability the domain needs, in its own words: open a compartment, read its state) and `OccupancyWriter`. Adapters implement them.

## Output: `artifacts/droppoint/design/locker/component-diagram.md`

````markdown
---
name: component-diagram
product: droppoint
service: locker
bounded-context: Locker
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-06-02
summary: The locker service as six components, with an anti-corruption adapter around the vendor's controller API and an occupancy read-model projector; all arrows point inward.
traces-to: [design/architecture/container-diagram.md, design/locker/aggregates.md]
---

# Component diagram for Locker Service

**Readers:** backend-engineer, security-engineer, reviewers
**Question it answers:** what are the building blocks inside the locker service, what does each do, and which way do the dependencies point?

## Container Context

`locker` (Go, chi): reads and writes Locker DB (PostgreSQL), publishes `ParcelDeposited`, `ParcelCollected`, `CompartmentFaulted` to Redpanda and consumes them for occupancy, calls the Locker Vendor Controller API (external system).

## Departures from the Default

- Anti-corruption adapter around the Locker Vendor Controller API
- Occupancy projector writing a per-site read model off the event stream

## Diagram

```
+-- Locker Service [Container: API, Go, chi] -------------------------------------------------+
|                                                                                             |
|  +-------------------------------+                                                          |
|  | Locker Handlers               |                                                          |
|  | [Component: entry point,      |                                                          |
|  |  handlers/http]               |                                                          |
|  | Decode requests, map to       |                                                          |
|  | commands and queries          |                                                          |
|  +-------------------------------+                                                          |
|        | maps requests to commands and calls                                                |
|        v                                                                                    |
|  +-------------------------------+        uses via port          +------------------------+ |
|  | Locker Use Cases              |------------------------------>| Locker Domain          | |
|  | [Component: use cases,        |                               | [Component: domain,    | |
|  |  application]                 |                               |  domain]               | |
|  | Reserve, deposit, collect,    |                               | Locker Aggregate,      | |
|  | fault handling                |                               | events, ports          | |
|  +-------------------------------+                               +------------------------+ |
|                                                                      ^    ^    ^    ^       |
|          - - - - - - - - implements LockerRepository, EventPublisher -+    |    |    |       |
|  +-------------------------------+                                         |    |    |       |
|  | Locker Persistence            |- - - - - - - - - - - - - - - - - - - - -+    |    |       |
|  | [Component: adapter,          |                                              |    |       |
|  |  infrastructure/postgres]     |                                              |    |       |
|  | Store the Aggregate, relay    |                                              |    |       |
|  | the outbox                    |                                              |    |       |
|  +-------------------------------+                                              |    |       |
|  +-------------------------------+   implements LockerController                |    |       |
|  | Vendor Controller Adapter     |- - - - - - - - - - - - - - - - - - - - - - - +    |       |
|  | [Component: anti-corruption   |                                                   |       |
|  |  adapter, infrastructure/     |                                                   |       |
|  |  lockervendor]                |                                                   |       |
|  | Translate vendor doors and    |                                                   |       |
|  | codes into domain terms       |                                                   |       |
|  +-------------------------------+                                                   |       |
|  +-------------------------------+   implements OccupancyWriter                      |       |
|  | Occupancy Projector           |- - - - - - - - - - - - - - - - - - - - - - - - - -+       |
|  | [Component: projector,        |                                                           |
|  |  infrastructure/occupancy]    |                                                           |
|  | Build per-site occupancy      |                                                           |
|  | from locker events            |                                                           |
|  +-------------------------------+                                                           |
+---------------------------------------------------------------------------------------------+
   Locker Persistence ---- reads and writes [SQL] ---------------> [Container: Database] Locker DB
   Locker Persistence ---- publishes locker events [Kafka] -----> [Container: Broker] Event Broker
   Occupancy Projector --- consumes locker events [Kafka] ------> [Container: Broker] Event Broker
   Occupancy Projector --- writes occupancy rows [SQL] ---------> [Container: Database] Locker DB
   Vendor Controller Adapter -- sends door commands [HTTPS] ----> [External System] Locker Vendor Controller API
```

## Key

- `[Component: <role>]` a grouping of related code behind an interface, inside the locker service
- `────▶` depends on (calls, uses); `- - -▶` implements a port declared in Locker Domain
- Arrows point from the dependent component, inward toward the domain
- Protocols appear only on arrows leaving the boundary

## Element Catalog

### Components

| Component | Role | Package or module | Interface presented | Responsibility |
|---|---|---|---|---|
| Locker Handlers | entry point | `handlers/http` | chi routes on `/sites/{id}/lockers` | Decode and validate requests, map to commands and queries, encode responses; no business logic |
| Locker Use Cases | use cases | `application` | `ReserveCompartment`, `DepositParcel`, `CollectParcel`, `GetOccupancy` | Orchestrate each use case: load the Aggregate, call it, save, enqueue the event |
| Locker Domain | domain | `domain` | `Locker`, `Compartment`, `LockerRepository`, `EventPublisher`, `LockerController`, `OccupancyWriter` | Aggregate invariants (no double reservation, no deposit into a faulted compartment) and the ports |
| Locker Persistence | adapter | `infrastructure/postgres` | implements `LockerRepository`, `EventPublisher` | Store and reconstitute the Aggregate; relay outbox rows to the broker |
| Vendor Controller Adapter | anti-corruption adapter | `infrastructure/lockervendor` | implements `LockerController` | Translate the vendor's door, sensor and firmware codes into domain commands and states; keep the vendor model out of the domain |
| Occupancy Projector | projector | `infrastructure/occupancy` | implements `OccupancyWriter` | Build the per-site occupancy read model from locker events, off the write path |

### Relationships

| From | To | Nature | Direction rationale |
|---|---|---|---|
| Locker Handlers | Locker Use Cases | calls | Entry points depend inward on use cases |
| Locker Use Cases | Locker Domain | uses via port | Use cases depend on the domain's Aggregate and ports, not on adapters |
| Locker Persistence | Locker Domain | implements | The adapter conforms to ports the domain owns |
| Vendor Controller Adapter | Locker Domain | implements | The vendor model stays outside; the domain sees only `LockerController` |
| Occupancy Projector | Locker Domain | implements | The read-model writer conforms to a domain port |
| Locker Persistence | Locker DB | SQL | Inter-process |
| Locker Persistence | Event Broker | Kafka protocol | Inter-process |
| Occupancy Projector | Event Broker | Kafka protocol | Inter-process |
| Vendor Controller Adapter | Locker Vendor Controller API | HTTPS | Inter-process |

## Dependency Rule

`LockerRepository`, `EventPublisher`, `LockerController` and `OccupancyWriter` are declared in `domain`; the three adapters implement them. `domain` imports only the standard library; the use cases import `domain`, never an adapter.

## Fitness Function

- **Check:** `go-makefile`'s `arch` target runs the import check, failing the build if `internal/domain` imports anything outside the standard library or if `handlers` imports `infrastructure`

## Variability

The deployment view runs one pooled locker deployment per region (multi-tenancy-design: pool). The component structure is the same in each region; only configuration (vendor API endpoint per region) differs.

## Rationale

- **Vendor Controller Adapter as an anti-corruption layer:** the vendor's model (doors, sensor states, firmware codes) changes with each hardware generation; translating it in one adapter keeps those changes out of the Aggregate.
- **Occupancy Projector apart from persistence:** the dashboard's per-site read model is updated from events on the read side, so read-model changes never touch the write path.

## Open Questions

- none
````

## Why this is right

- Two named departures earned the diagram; the boxes are groupings, not handlers or queries.
- Every inside arrow points inward and has no protocol; protocols appear only where arrows leave the boundary.
- The vendor's model is behind a domain-owned port, and a fitness function keeps the domain free of drivers.
- Variability comes from multi-tenancy-design, not an assumed stamp.
- `validate-component-diagram.sh` exits clean on the artifact.
