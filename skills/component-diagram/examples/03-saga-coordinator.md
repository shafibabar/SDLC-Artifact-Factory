# Example 3 — Enterprise: A Service Hosting a Saga Coordinator

Self-contained. **TripWeave** sells package holidays: one checkout books a flight, a hotel and a transfer from three supplier systems, then takes payment. **Enterprise** profile. The container diagram's `checkout` deployable (Go, chi) owns the Checkout context. It departs from the default skeleton in two ways: it hosts a **saga coordinator** (`workflow-orchestration`) that drives the three bookings and payment, with its own state store and compensations; and it reaches the three suppliers through **supplier ports** with one adapter each. The `Booking` Aggregate holds the customer-facing state. Multi-tenancy design: pooled, one deployment per region.

## Input

> **User:** "The saga calls the payment adapter and the payment adapter calls back into the saga, so draw a two-way arrow between them. The domain should also import the Redpanda client so the saga can publish directly. And just do the diagram in Mermaid, it renders in our wiki."

## Working it

- **Draw it:** the coordinator and the supplier ports are departures a reviewer must see before implementation.
- **Declined:** a two-way arrow. It is a cycle. The coordinator depends on a `PaymentGateway` port declared in the domain; the payment adapter implements it, and payment results come back as events the coordinator's use case consumes, not as calls into the coordinator.
- **Declined:** the domain importing the broker client. The innermost ring would know the outermost (Dependency Rule). The coordinator emits commands and events through the `EventPublisher` port; the outbox adapter implements it.
- **Mermaid:** offered as an optional copy; the ASCII picture and the tables stay primary (D047-13).

## Output: `artifacts/tripweave/design/checkout/component-diagram.md`

````markdown
---
name: component-diagram
product: tripweave
service: checkout
bounded-context: Checkout
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-08-14
summary: The checkout service with a saga coordinator driving flight, hotel, transfer and payment through domain-owned ports, one adapter per supplier, and no cycles.
traces-to: [design/architecture/container-diagram.md, design/checkout/aggregates.md, design/architecture/orchestration-design.md]
---

# Component diagram for Checkout Service

**Readers:** backend-engineer, security-engineer, reviewers
**Question it answers:** what are the building blocks inside the checkout service, what does each do, and which way do the dependencies point?

## Container Context

`checkout` (Go, chi): reads and writes Checkout DB (PostgreSQL: bookings and saga state), publishes and consumes checkout events on Redpanda, calls the Flight, Hotel and Transfer supplier systems and the Payment Provider (external systems).

## Departures from the Default

- Saga coordinator with its own persisted state and compensations
- Supplier ports with one anti-corruption adapter per supplier

## Diagram

```
+-- Checkout Service [Container: API, Go, chi] -----------------------------------------------+
|                                                                                             |
|  +----------------------------+          +----------------------------+                     |
|  | Checkout Handlers          |          | Checkout Event Consumer    |                     |
|  | [Component: entry point,   |          | [Component: entry point,   |                     |
|  |  handlers/http]            |          |  handlers/events]          |                     |
|  | Start checkout, status     |          | Supplier and payment       |                     |
|  +----------------------------+          | results into commands      |                     |
|        | calls                           +----------------------------+                     |
|        v                                       | calls                                      |
|  +---------------------------------------------v--+                                         |
|  | Checkout Use Cases and Saga Coordinator        |       uses via ports                    |
|  | [Component: coordinator, application/checkout] |------------------------------+          |
|  | Drive book flight, hotel, transfer, pay;       |                              |          |
|  | compensate on failure                          |                              v          |
|  +------------------------------------------------+         +-------------------------+     |
|                                                             | Checkout Domain          |    |
|                                                             | [Component: domain,      |    |
|                                                             |  domain]                 |    |
|                                                             | Booking Aggregate, saga  |    |
|                                                             | state, ports             |    |
|                                                             +-------------------------+     |
|                                                                ^     ^      ^               |
|  +----------------------------+  implements BookingRepository, |     |      |               |
|  | Checkout Persistence       |  SagaStateStore, EventPublisher|     |      |               |
|  | [Component: adapter,       |- - - - - - - - - - - - - - - - +     |      |               |
|  |  infrastructure/postgres]  |                                      |      |               |
|  | Bookings, saga state,      |                                      |      |               |
|  | outbox relay               |                                      |      |               |
|  +----------------------------+                                      |      |               |
|  +----------------------------+  implements FlightSupplier,          |      |               |
|  | Supplier Adapters          |  HotelSupplier, TransferSupplier     |      |               |
|  | [Component: anti-corruption|- - - - - - - - - - - - - - - - - - - +      |               |
|  |  adapter, infrastructure/  |                                             |               |
|  |  suppliers/{flight,hotel,  |                                             |               |
|  |  transfer}]                |                                             |               |
|  +----------------------------+                                             |               |
|  +----------------------------+  implements PaymentGateway                  |               |
|  | Payment Adapter            |- - - - - - - - - - - - - - - - - - - - - - -+               |
|  | [Component: adapter,       |                                                             |
|  |  infrastructure/payment]   |                                                             |
|  +----------------------------+                                                             |
+---------------------------------------------------------------------------------------------+
   Checkout Persistence ---- reads and writes [SQL] ------------> [Container: Database] Checkout DB
   Checkout Persistence ---- publishes checkout events [Kafka] -> [Container: Broker] Event Broker
   Checkout Event Consumer - consumes result events [Kafka] ----> [Container: Broker] Event Broker
   Supplier Adapters ------- book and cancel [HTTPS] -----------> [External System] Flight, Hotel, Transfer suppliers
   Payment Adapter --------- authorise, capture, refund [HTTPS] > [External System] Payment Provider
```

## Key

- `[Component: <role>]` a grouping of related code behind an interface, inside the checkout service
- `────▶` depends on (calls, uses); `- - -▶` implements a port declared in Checkout Domain
- Arrows point from the dependent component, inward toward the domain; results return as events, not calls back
- Protocols appear only on arrows leaving the boundary

## Element Catalog

### Components

| Component | Role | Package or module | Interface presented | Responsibility |
|---|---|---|---|---|
| Checkout Handlers | entry point | `handlers/http` | chi routes on `/checkouts` | Start a checkout, report its status; no business logic |
| Checkout Event Consumer | entry point | `handlers/events` | consumer group on checkout result topics | Turn supplier and payment results into commands, idempotently |
| Checkout Use Cases and Saga Coordinator | coordinator | `application/checkout` | `StartCheckout`, `RecordSupplierResult`, `RecordPaymentResult` | Drive the saga steps in order, persist its state, issue compensations when a step fails |
| Checkout Domain | domain | `domain` | `Booking`, `SagaState`, `BookingRepository`, `SagaStateStore`, `EventPublisher`, `FlightSupplier`, `HotelSupplier`, `TransferSupplier`, `PaymentGateway` | Booking invariants, saga state transitions and compensation rules, the ports |
| Checkout Persistence | adapter | `infrastructure/postgres` | implements `BookingRepository`, `SagaStateStore`, `EventPublisher` | Store bookings and saga state; relay the outbox |
| Supplier Adapters | anti-corruption adapter | `infrastructure/suppliers/{flight,hotel,transfer}` | implement the three supplier ports | Translate each supplier's booking model and errors into domain terms |
| Payment Adapter | adapter | `infrastructure/payment` | implements `PaymentGateway` | Authorise, capture and refund with the payment provider |

### Relationships

| From | To | Nature | Direction rationale |
|---|---|---|---|
| Checkout Handlers | Checkout Use Cases and Saga Coordinator | calls | Entry points depend on use cases |
| Checkout Event Consumer | Checkout Use Cases and Saga Coordinator | calls | Results arrive as events and become commands; nothing calls back into the coordinator |
| Checkout Use Cases and Saga Coordinator | Checkout Domain | uses via port | The coordinator depends on domain ports, never on an adapter |
| Checkout Persistence | Checkout Domain | implements | Adapter conforms to domain ports |
| Supplier Adapters | Checkout Domain | implements | Supplier models stay outside the domain |
| Payment Adapter | Checkout Domain | implements | Replaces the requested two-way arrow: the adapter implements `PaymentGateway` |
| Checkout Persistence | Checkout DB | SQL | Inter-process |
| Checkout Persistence | Event Broker | Kafka protocol | Inter-process |
| Checkout Event Consumer | Event Broker | Kafka protocol | Inter-process |
| Supplier Adapters | Flight, Hotel, Transfer suppliers | HTTPS | Inter-process |
| Payment Adapter | Payment Provider | HTTPS | Inter-process |

## Dependency Rule

All nine ports are declared in `domain`; the three adapter components implement them. `domain` imports only the standard library (no broker client: events leave through the `EventPublisher` port and the outbox). There is no cycle: payment results return as events through the consumer.

## Fitness Function

- **Check:** `go-makefile`'s `arch` target fails the build if `internal/domain` imports outside the standard library, if `application` imports `infrastructure`, or if any import cycle appears between packages

## Variability

Per multi-tenancy-design (pool), one checkout deployment per region; the component structure is identical in each, and supplier endpoints are per-region configuration.

## Rationale

- **Saga coordinator in this service:** checkout owns the customer's booking, so it orchestrates the steps and their compensations (orchestration design); its state is persisted beside the bookings so a crash resumes from the last step.
- **One adapter per supplier behind domain ports:** suppliers change contracts independently; each adapter absorbs its supplier's model and errors.

## Open Questions

- Mermaid copy for the wiki: optional, to follow the ASCII picture if the user wants it
````

## Why this is right

- The two-way arrow became a port plus events, so there is no cycle.
- The broker client stays out of the domain; events leave through a port.
- ASCII is primary, with Mermaid offered as an optional copy, not a replacement.
- `validate-component-diagram.sh` exits clean on the artifact.
