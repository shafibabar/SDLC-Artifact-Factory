# Example 3 — Enterprise: A Six-Service Choreography With Compensation

Self-contained. **Meridian Freight** is a freight marketplace for forwarders in several regions. **Enterprise** profile. Booking a shipment touches six services: **Booking**, **Pricing**, **Customs**, **Carrier**, **Billing** and **Notifications**. The current design is choreographed: each reacts to the previous service's event, and Billing is expected to "undo everything if Customs rejects the shipment, atomically". Operations cannot say where a given booking is when it stalls.

## Input

> **User:** "Keep it choreographed so the services stay decoupled, but make a customs rejection roll back pricing, the carrier hold and the billing authorization together, in one go, so nothing is left half-done."

## Working it

- **Classify what is asked:** async communication, **atomic** consistency, **choreographed** coordination. That is the Horror Story (Ford): no coordinator and an assumed all-or-nothing across asynchronous calls. Not as asked; the two requirements cannot both be met.
- **Atomic across six services** means a distributed transaction, which blocks and collapses availability (Kleppmann). Consistency becomes **eventual**, with compensations: release the carrier hold, void the billing authorization, expire the price quote.
- **Coordination:** Richardson's rule fires on three triggers at once: the flow has six steps with branching (customs may reject or request documents), compensation spans four services (Pricing, Carrier, Billing, Notifications), and operations need one place to ask "where is this booking?". Orchestrated, designed in `workflow-orchestration`; this section records the decision and what the orchestrator needs from the event layer. The orchestrator persists each transition and sends each command through the Transactional Outbox.
- **Choreography stays where it fits:** `BookingConfirmed` reaching Notifications is a two-service independent reaction.
- **Ordering:** a booking's events must stay in order, so the key is the booking id. Per-forwarder order is not needed. A forwarder with thousands of bookings is therefore not a hot key.
- **Delivery:** each participant is an Idempotent Consumer on the command id; the orchestrator tolerates a repeated command by re-dispatching from its last persisted state and relying on that. Retry and Backoff for transient failures; a Dead Letter Queue per topic, owned by the service that consumes it, alert on depth.

## Output: the section in `artifacts/meridian/design/architecture/integration-design.md`

````markdown
## Event-Driven Pattern Decisions

- **Profile:** enterprise
- **Broker:** Redpanda (Kafka API log), per message-broker-selection

### Flow Classification

| Flow | Communication | Consistency | Coordination | Why |
|---|---|---|---|---|
| Book a shipment: Booking, Pricing, Customs, Carrier, Billing | async | eventual | orchestrated | Richardson's triggers: six steps with branching, compensation across four services, one view of progress needed; designed in workflow-orchestration. The requested atomic rollback is not possible without a distributed transaction |
| BookingConfirmed to Notifications | async | eventual | choreographed | Two services, an independent reaction, nothing to compensate |

### Publication

| Publisher | Mechanism | Why |
|---|---|---|
| Booking, Pricing, Customs, Carrier, Billing services | Transactional Outbox | Each emits events and replies together with its own write; no dual write |
| Booking orchestrator | Transactional Outbox | Each state transition and the command it sends are one transaction |

### Topics and Ordering

| Topic | Partition key | Ordering guaranteed | Consumer groups | Retention |
|---|---|---|---|---|
| booking.commands | booking id (a booking's commands in order) | Per booking, within one partition; none across bookings | one per participant service | 7 days |
| booking.replies | booking id | Per booking, within one partition; none across bookings | booking-orchestrator | 7 days |
| booking.confirmed | booking id | Per booking, within one partition | notifications | 7 days |

### Delivery and Idempotency

| Consumer | Dedup (key and store) | Retry and Backoff | Dead Letter Queue | Alert |
|---|---|---|---|---|
| Each participant, booking.commands | command id in a dedup table, committed with the effect | transient errors only: 5 attempts, backoff with jitter | booking.commands.dlq per participant, re-driven by its owning team | DLQ depth above zero; consumer lag |
| Booking orchestrator, booking.replies | reply id in a dedup table, committed with the state transition | transient errors only: 5 attempts, backoff with jitter | booking.replies.dlq, re-driven by the Booking team | DLQ depth above zero; stuck saga age |

### Open Questions

- Customs documents requested by the authority can take days: whether the orchestrator waits in a long-running state or the booking returns to the forwarder; owner: product owner, decided in workflow-orchestration.
````

## Why this is the right size

The flow is a Horror Story as designed: the request asks for decoupling (choreography) and an all-or-nothing rollback (atomic) together. The answer keeps the decoupling where it fits, moves the six-step flow to an orchestrator, and records the eventual consistency honestly. The saga's steps, pivot and compensations are `workflow-orchestration`'s, not copied here.
