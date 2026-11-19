# Example 2 — Standard: A Six-Step Booking with Payment, One Pivot and a Human Wait

Self-contained. **ClinicBook** lets patients book appointments with private clinics. **Standard** profile, separate services: **Scheduling** (slots), **Payments** (deposits), **Clinics** (the front desk's confirmation), **Notifications**. A patient picks a slot and pays a deposit; the clinic's front desk must confirm within 24 hours.

## Input

> **User:** "Design the booking flow. Every step must be undoable so any failure rolls the whole booking back. The undo can just look up the slot and payment from the booking and reverse them. No need for any locking on the slot."

## Working it

- **Trigger check.** Long-running (up to 24 hours for the front desk) and compensation across 4 services (Scheduling, Payments, Clinics, Notifications): orchestrate. Coordination is "async · eventual · orchestrated".
- **"Everything rolls back"** is declined: each committed step is visible and cannot be rolled back, and a captured deposit is not something to silently reverse. Decision: the **pivot is capturing the deposit**, after the clinic has confirmed. Before it, abandoning the booking costs nothing (a hold released, an authorization voided). After it, the booking stands: booking the slot and sending the confirmation are retried until they succeed.
- **"The undo can look up"** is declined: the lookup races changes. Each compensatable step records what its undo needs when it runs: the hold id, the authorization id, the request id.
- **Compensations** are idempotent, retried with backoff, and if one cannot succeed an alert goes to Scheduling's or Payments' on-call owner and the flow moves to Needs repair.
- **"No locking"** is declined: between the hold and the booking, the slot is read by search and by other patients. A **semantic lock**: the slot's state is `held` from step 1; cleared to `booked` by step 5, or to `free` by the compensation; a hold older than 36 hours is released by a sweeper.
- **Timeouts:** the front desk has 24 hours; on expiry the flow compensates and tells the patient.
- Cross-service search of free slots is not decided here (`cqrs-pattern`).

## Output: `artifacts/clinicbook/design/architecture/workflow-orchestration.md`

````markdown
---
name: workflow-orchestration-design
product: clinicbook
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-11-19
summary: The booking flow is orchestrated; the deposit capture is the single point of no return, and a held slot is protected by a semantic lock.
traces-to: [design/architecture/integration-design.md, design/architecture/container-diagram.md]
---

# Workflow Orchestration Design for ClinicBook

**Readers:** enterprise-architect, backend-engineer, the product owner
**Question it answers:** for each orchestrated flow, what is done, what is undone, and what happens when a step fails or never answers?

- **Profile:** standard

## Orchestration Decision

| Flow | Trigger that fired | Why not choreography | Coordinator |
|---|---|---|---|
| Book an appointment | long-running (front desk up to 24 hours) and compensation across 4 services | A 24-hour wait has no owner among reacting services, and undoing a hold and an authorization in order needs one sequencer | hand-rolled, in the Scheduling service's deployment; one orchestrated flow does not justify an engine |

## Saga: Book an appointment

**Pivot:** step 4, capturing the deposit: until it commits the booking can be abandoned at no cost, after it the booking stands
**Coordinator:** a state record per booking inside the Scheduling deployment; owner: Scheduling team
**State persistence:** the booking's state and the next command are written in one transaction through the Transactional Outbox; one writer per booking
**Business logic in the coordinator:** none: it sends commands and records replies; each service decides

### Steps

| # | Step (command) | Owner | Class | Compensation | Captured on the way forward | Lock set or cleared |
|---|---|---|---|---|---|---|
| 1 | HoldSlot | Scheduling | compensatable | ReleaseSlot | hold id | sets slot `held` |
| 2 | AuthorizeDeposit | Payments | compensatable | VoidAuthorization | authorization id | none |
| 3 | RequestClinicConfirmation | Clinics | compensatable | WithdrawRequest | request id | none |
| 4 | CaptureDeposit | Payments | pivot | none | none | none |
| 5 | BookSlot | Scheduling | retriable | none | none | clears slot to `booked` |
| 6 | SendConfirmation | Notifications | retriable | none | none | none |

### State Machine

| State | Command sent on entry | On success | On failure |
|---|---|---|---|
| Holding slot | HoldSlot | Authorizing deposit | Compensated |
| Authorizing deposit | AuthorizeDeposit | Awaiting clinic | Releasing slot |
| Awaiting clinic | RequestClinicConfirmation | Capturing deposit | Withdrawing request |
| Capturing deposit | CaptureDeposit | Booking slot | Withdrawing request |
| Booking slot | BookSlot | Sending confirmation | retry with backoff, then Needs repair |
| Sending confirmation | SendConfirmation | Completed | retry with backoff, then Needs repair |
| Withdrawing request | WithdrawRequest | Voiding authorization | retry with backoff, then Needs repair |
| Voiding authorization | VoidAuthorization | Releasing slot | retry with backoff, then Needs repair |
| Releasing slot | ReleaseSlot | Compensated | retry with backoff, then Needs repair |
| Completed | none | none | none |
| Compensated | none | none | none |
| Needs repair | none | none | none |

### Timeouts

| Wait | Timeout | When it expires |
|---|---|---|
| Front desk confirmation | 24 hours | the flow compensates (withdraw, void, release) and the patient is told the slot is free again |
| Payment authorization reply | 30 seconds | retried twice (the command is idempotent), then treated as a failure and compensated |

### Isolation

| Record exposed | Anomaly possible | Countermeasure | Cleared by, and how a stale one is released |
|---|---|---|---|
| Slot | dirty read (search shows a held slot as free, or a patient sees it as booked) | semantic lock: slot state `held` | cleared by BookSlot (to `booked`) or ReleaseSlot (to `free`); a hold older than 36 hours is released by a sweeper |

### Progress and Repair

- **Progress view:** the coordinator's record per booking: state, time in state, outcome so far; the front desk and support read it.
- **Needs repair:** BookSlot and SendConfirmation cannot fail for good in normal operation; any step in Needs repair alerts Scheduling's on-call owner.
- **Definition changes:** not needed at standard; bookings in flight finish before a new definition is deployed.

## Open Questions

- Whether a patient may be told "your slot is held" while awaiting the clinic; owner: product owner.
````
