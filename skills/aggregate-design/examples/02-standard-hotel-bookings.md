# Example 2 — Standard: The Has-a Trap and a Rule Spanning Bookings

Self-contained. **Harbourlight Inns** is a group of six coastal hotels, at the **standard** profile. This is the **Reservations** context (Core): bookings, guarantees, room assignment and check-in. Guest loyalty is a separate context that reacts to stays.

## Input

> **User:** "A Room has Bookings. Make Room the Aggregate holding all its bookings, so it can never be double-booked and the booking total is always right."

## Working it

- **Has-a vs must-be-atomic (§ 3).** A room "has" bookings: yes. Must a booking be changed atomically with the room's other bookings? Only if some rule needs it. Holding every booking would load an unbounded collection, put every reservation for a popular room on one version number, and make housekeeping's room-status edits collide with reservations: all three sizing angles fail.
- **The real rules, tested:**
  - "Confirmed bookings for a room type on a night never exceed the rooms of that type." Q1: yes, someone may be walked to another hotel; Q2: **yes**. The revenue team deliberately overbooks by up to 3% and walking a guest within that allowance is the accepted remedy. → **Rejected** as an invariant. It is a policy limit checked against an availability Read Model.
  - "A room holds at most one in-house stay at a time." Q1: yes, two parties at one door at 11pm; Q2: no, the second party is already at the door; Q3: no, the channel manager knows room types, not rooms. → **True Invariant.** It needs only the room's *current* stay, not all its bookings. Rooms are assigned at check-in, so `Room` holds one booking ID at most.
  - "A confirmed booking always has a guarantee covering the first night." Q1: yes, an unguaranteed no-show is lost revenue with no recourse; Q2: no, a guest who didn't come can't be charged afterwards; Q3: no, the payment provider authorises a card but doesn't know a booking needs one. → **True Invariant** inside `Booking`.
  - "The booking total equals its nightly rates." A derived value, computed from the nights. Rejected.
- **Check-in touches two Aggregates.** `Room.CheckIn` records `GuestCheckedIn`; `Booking` reacts and marks itself in-house. For a second the desk shows "checking in". One Aggregate per transaction holds.
- **Identity.** Guests quote a confirmation number, so `Booking` uses a business identifier reserved through the Repository.

## Output: `design/reservations/aggregates.md` (excerpt)

```markdown
---
name: aggregate-design
product: harbourlight
bounded-context: Reservations
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-11-05
summary: Reservations has two Aggregates — Booking (guarantee invariant) and Room (one in-house stay); room-type overbooking is a policy limit, not an invariant.
profile: standard
traces-to: [design/reservations/ubiquitous-language.md, design/event-storming/software-design.md, design/subdomain-classification.md, design/context-map.md]
---

# Aggregate Design: Reservations

## Aggregate: Booking

| Field | Value |
|---|---|
| **Root** | Booking: one guest's stay at one hotel, from quote to departure |
| **Pattern** | Domain Model — the guarantee invariant spans the booking's status and its guarantee |
| **Identity** | business identifier via the Repository — the confirmation number guests quote (HL-6 digits) |
| **Concurrency** | optimistic |
| **Event sourcing** | not used — checked temporal query, retroactive projection and audit-as-record: none applies; booking events go to the audit store |
| **Contention** | low — one guest and the desk edit a booking, rarely at once |
| **Cohesion buys / coupling costs** | the guarantee rule / guest edits and desk edits on one booking contend (rare) |

### Invariants

| Invariant (one sentence) | Q1 real harm? | Q2 fixable later? | Q3 enforced elsewhere? | Verdict |
|---|---|---|---|---|
| A confirmed booking always has a guarantee covering the first night. | yes | no | no | True Invariant |

### Rejected candidates

| Rule considered | Q1 real harm? | Q2 fixable later? | Q3 enforced elsewhere? | Handled instead by |
|---|---|---|---|---|
| The booking total equals the sum of its nightly rates. | no | yes | yes | computed from the nights at query time |
| Confirmed bookings for a room type on a night never exceed rooms of that type. | yes | yes | no | availability Read Model and the revenue team's 3% overbooking limit |

### Members

| Member | Kind | Identity or equality | Why inside this Aggregate |
|---|---|---|---|
| Night | Entity (local) | date within the booking | carries the rate quoted for that night |
| Guarantee | Value Object, self-validating | all attributes | the invariant's subject; card authorisation or deposit |
| StayDates | Value Object, self-validating | all attributes | departure after arrival |
| Rate | Value Object | all attributes | price and currency as quoted |

### Commands and events

| Command | Requires (guard) | Guarantees | Domain Event | Published |
|---|---|---|---|---|
| ConfirmBooking | a guarantee covers the first night | status confirmed | BookingConfirmed | as-is |
| ChangeStayDates | not yet in-house | nights re-quoted at current rates | StayDatesChanged | as-is |
| CancelBooking | not yet in-house | status cancelled; fee per policy | BookingCancelled | as-is |
| MarkInHouse | guest checked in to a room | status in-house | BookingMarkedInHouse | internal only |

### Relationships to other Aggregates

| Other Aggregate | Has-a? | Must be atomic? | Conclusion | Reference |
|---|---|---|---|---|
| Room | yes | no | separate | by ID, once assigned |

### Coordination

GuestCheckedIn (from Room) → MarkInHouse on the booking, idempotent; the desk shows "checking in" until it lands. StayCompleted is published for Loyalty.

### Exceptions taken

None.

## Aggregate: Room

| Field | Value |
|---|---|
| **Root** | Room: one physical room's current state (in service, out of order, in-house stay) |
| **Pattern** | Domain Model — one in-house stay at a time, plus out-of-order rooms can't be assigned |
| **Identity** | client-generated |
| **Concurrency** | optimistic |
| **Event sourcing** | not used — none of the three needs applies |
| **Contention** | low — the desk and housekeeping, a few writes a day per room |
| **Cohesion buys / coupling costs** | occupancy and service status checked together / none observed |

### Invariants

| Invariant (one sentence) | Q1 real harm? | Q2 fixable later? | Q3 enforced elsewhere? | Verdict |
|---|---|---|---|---|
| A room holds at most one in-house stay at a time. | yes | no | no | True Invariant |
| A room that is out of order cannot be checked in to. | yes | no | no | True Invariant |

### Rejected candidates

| Rule considered | Q1 real harm? | Q2 fixable later? | Q3 enforced elsewhere? | Handled instead by |
|---|---|---|---|---|
| A room never has two bookings on the same future night. | no | yes | no | rooms are assigned at check-in, so future bookings hold a room type, not a room |

### Members

| Member | Kind | Identity or equality | Why inside this Aggregate |
|---|---|---|---|
| ServiceStatus | Value Object | all attributes | blocks check-in when out of order |

### Commands and events

| Command | Requires (guard) | Guarantees | Domain Event | Published |
|---|---|---|---|---|
| CheckIn | in service, no in-house stay | in-house stay set to the booking | GuestCheckedIn | as-is |
| CheckOut | an in-house stay | room vacant, needs cleaning | GuestCheckedOut | as-is |
| MarkOutOfOrder | no in-house stay | out of order with reason | RoomTakenOutOfOrder | as-is |

### Relationships to other Aggregates

| Other Aggregate | Has-a? | Must be atomic? | Conclusion | Reference |
|---|---|---|---|---|
| Booking | yes | no | separate | by ID (the in-house stay only) |

### Coordination

GuestCheckedIn → Booking marks in-house. GuestCheckedOut → Housekeeping's cleaning list (another context).

### Exceptions taken

None.

## Use case: Update guest preferences

| Field | Value |
|---|---|
| **Pattern** | Active Record — a guest profile's single-record validation; no rule across records |
| **Records touched** | guest profile |
| **Rules** | none beyond field validation |

## Open questions

- Is 3% the overbooking limit at every hotel, or set per hotel by the revenue team? (assumed: per hotel)
```

## Why this is right

- The request is declined with its reason: a Room holding every booking is the has-a trap, and it fails all three sizing angles.
- Double-booking was split into two rules. One failed the test because walking a guest within the allowance is the accepted remedy. The other passed, and it needs only the current stay.
- Check-in changes one Aggregate; the Booking follows by event.
- Identity follows what the business quotes: a confirmation number for bookings, an opaque ID for rooms.
