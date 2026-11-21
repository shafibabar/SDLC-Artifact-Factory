# Example 2 — Standard: Where Each Rejection Is Checked

Self-contained. **Ember Table** takes reservations for a group of six independent restaurants, at the **standard** profile. This is the **Reservations** context: tables, sittings and bookings. Guests book through the website and an app; hosts work from a tablet at the door; a no-show Policy runs after each sitting.

## Input

> **User:** "Add `CancelReservation`. The app already checks the 2-hour cut-off, so the server can just cancel. Pass the guest's ID in the body so we know who cancelled. Return the updated reservation so the app can redraw."

## Working it

- **The cut-off in the app only:** declined. Hosts cancel from the tablet and the no-show Policy cancels too; neither runs the app's check. "No guest cancellation within 2 hours of the sitting" is a rule about the reservation, checked in the Reservation Aggregate. The app may show it early as a hint.
- **Who cancels is not the same as what may happen.** Guests may cancel only their own reservation, and hosts only at their own restaurant: an access check (*not permitted*). Inside 2 hours a guest is refused, but a host may still cancel (a kitchen fire): a rule (*rule violated*) that depends on who issued it.
- **Guest ID in the body:** declined. Anyone could cancel anyone's table by changing it. Who issued the Command comes from the signed-in session.
- **Return the reservation:** declined. The Command returns an acknowledgement; the app redraws from the "My reservations" Read Model.
- **Input vs rule:** a missing reason code is invalid input (checked from the request alone). "Already seated" needs the reservation's state: a rule, in the Aggregate.
- **Retries:** guests on restaurant Wi-Fi retry. The app keeps one request ID per cancel tap. A repeat returns the first outcome, including a refusal; otherwise a retry after the host seats the guest could return a different answer.

## Output: `design/reservations/command-catalog.md` (excerpt)

```markdown
---
name: command-catalog
product: ember-table
bounded-context: Reservations
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-05-14
summary: Reservations accepts CancelReservation from guests, hosts and the no-show Policy, with the 2-hour rule held by the Reservation Aggregate.
profile: standard
traces-to: [design/reservations/aggregates.md, design/event-storming/process-reservation.md, design/reservations/ubiquitous-language.md, design/reservations/domain-event-catalog.md]
---

# Command Catalog: Reservations

## Commands

| Command | Aggregate | Issued by | Records |
|---|---|---|---|
| CancelReservation | Reservation | guest, host, no-show Policy | ReservationCancelled |

## Command: CancelReservation

| Field | Value |
|---|---|
| **Intent** | Give up a reserved table so the restaurant can offer it again |
| **Aggregate** | Reservation — by reservation reference |
| **Issued by** | the guest who holds it; a host at its restaurant; Policy: Whenever SittingClosedWithNoShow, then CancelReservation |
| **Records** | ReservationCancelled (with who cancelled and the reason code) |
| **Idempotency key** | guest and host: request ID kept across retries of one cancel; Policy: the SittingClosedWithNoShow event ID |
| **On a duplicate** | returns the first outcome, refusal included; keys kept 48 hours (the app retries queued requests for up to a day) |
| **Already in effect** | succeeds and records nothing — the table is already free |
| **Concurrency** | none needed — the rules are re-checked on the reservation's current state |
| **Caller needs** | the outcome now (the guest is waiting on the screen) |
| **Source** | design/event-storming/process-reservation.md |

### Inputs

| Input | Meaning (in the language) | From | Input rule (checked before the Aggregate) |
|---|---|---|---|
| reservation reference | the reservation to give up | target | present, 8 characters |
| reason code | why: changed plans, illness, restaurant closed, no-show | request | one of the four codes |
| cancelled by | who issued it: guest, host or the no-show Policy | authenticated context | — |

### Rejections

| Rejection (in the language) | Kind | Checked where |
|---|---|---|
| Choose a reason for cancelling | invalid input | input |
| You can only cancel your own reservation | not permitted | access check |
| Hosts can only cancel at their own restaurant | not permitted | access check |
| We can't find that reservation | not found | loading the target |
| The guest is already seated | rule violated | Aggregate |
| Guests can't cancel within 2 hours of the sitting; please call the restaurant | rule violated | Aggregate |
| A no-show can only be recorded after the sitting has started | rule violated | Aggregate |

## Open questions

- Does a host cancellation inside 2 hours need a manager's approval? (product owner)
```

## Why this is right

- The cut-off moved from "the app checks it" to the Aggregate, because three ways in issue the Command.
- Who may cancel (access) is kept apart from what may happen (rules), and the guest's identity comes from the session.
- The reply is an acknowledgement; HTTP methods and status codes are left to `api-contract-design`, which maps the kinds.
- `validate-command-catalog.sh` exits clean on the excerpt.
