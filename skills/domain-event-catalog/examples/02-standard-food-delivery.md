# Example 2 — Standard: Splitting a Generic Event, Publishing Coarse Facts

Self-contained. **Ladle & Lane** delivers from independent restaurants in one city, at the **standard** profile. This is the **Delivery** context: couriers, pick-ups and drop-offs. Its events reach **Ordering** (the customer's order screen), **Billing** (courier pay and restaurant settlement) and **Support**.

## Input

> **User:** "Publish an `OrderStatusChanged` event with the whole order on every change, including the courier's GPS pings, so every team has everything."

## Working it

- **Which facts?** `OrderStatusChanged` hides four facts with different consumers:
  - `CourierAssigned`: Ordering shows the courier;
  - `OrderPickedUp`: Ordering shows "on its way" and Billing starts courier pay;
  - `OrderDelivered`: Billing settles and Support closes the order;
  - `DeliveryFailed`: Support calls the customer.

  Each consumer would otherwise decode a status field to learn what happened.
- **GPS pings:** an internal operational stream, many per minute, and personal location data. Nobody outside Delivery needs each ping; Ordering's map reads a Read Model. Not published.
- **The whole order:** declined. It couples Billing and Support to Delivery's write model and carries the customer's address everywhere. Each event carries the identifiers and the facts its consumers act on.
- **Ordering:** per order, partitioned by the delivery's ID. Billing must not settle a delivery before its pick-up, so it halts that delivery's partition if a pick-up event is dead-lettered.

## Output: `design/delivery/domain-event-catalog.md` (excerpt)

```markdown
---
name: domain-event-catalog
product: ladle-and-lane
bounded-context: Delivery
version: 1.0.0
phase: design
owner: domain-modeler
created: 2026-11-05
summary: Delivery publishes four business facts (assigned, picked up, delivered, failed) to Ordering, Billing and Support; courier location pings stay internal.
profile: standard
traces-to: [design/delivery/aggregates.md, design/event-storming/process-delivery.md, design/delivery/ubiquitous-language.md, design/context-map.md]
---

# Domain Event Catalog: Delivery

## Events

| Event | Aggregate | Visibility | Consumers |
|---|---|---|---|
| OrderPickedUp | Delivery | published | Ordering, Billing |
| OrderDelivered | Delivery | published | Billing, Support |
| CourierLocationRecorded | Delivery | internal | none (feeds the live-map Read Model) |

## Event: OrderPickedUp

| Field | Value |
|---|---|
| **Means** | The courier collected the order from the restaurant and is on the way |
| **Aggregate** | Delivery |
| **Raised by** | Command ConfirmPickUp (courier app) |
| **Visibility** | published |
| **Published as** | see design/data/event-schemas.md |
| **Ordering** | per Aggregate |
| **Retention need** | consumer replay 30 days — Billing rebuilds courier pay for the current pay period |
| **Sensitive data** | none: courier and customer by ID only |

### Payload meaning

| Field | Meaning (in the language) | Why a consumer needs it |
|---|---|---|
| deliveryId | the delivery | key for every reaction |
| orderId | the customer's order | Ordering updates the order screen |
| courierId | who picked it up | Billing starts that courier's pay for the trip |
| restaurantId | where it was collected | Billing's settlement line |
| promisedBy | the delivery time promised to the customer | Ordering shows it; Support flags lateness |

### Consumers

| Consumer | Reaction (policy) | Idempotent on | If an event is stuck |
|---|---|---|---|
| Ordering | Whenever OrderPickedUp, then ShowOnItsWay | event id within source | tolerates out-of-order replay (latest status wins by time) |
| Billing | Whenever OrderPickedUp, then StartCourierTrip | deliveryId | halts this Aggregate's partition until fixed |

## Event: OrderDelivered

| Field | Value |
|---|---|
| **Means** | The customer received the order |
| **Aggregate** | Delivery |
| **Raised by** | Command ConfirmDropOff (courier app, with photo or code) |
| **Visibility** | published |
| **Published as** | see design/data/event-schemas.md |
| **Ordering** | per Aggregate |
| **Retention need** | audit evidence 6 years — restaurant settlements and courier pay are financial records |
| **Sensitive data** | the proof-of-delivery photo is a reference, not the image |

### Payload meaning

| Field | Meaning (in the language) | Why a consumer needs it |
|---|---|---|
| deliveryId | the delivery | key |
| orderId | the order | Support closes it |
| proofRef | a reference to the drop-off photo or code check | Support resolves "never arrived" claims |
| minutesLate | minutes past the promised time, 0 if on time | Billing applies the restaurant's late-delivery terms |

### Consumers

| Consumer | Reaction (policy) | Idempotent on | If an event is stuck |
|---|---|---|---|
| Billing | Whenever OrderDelivered, then SettleDelivery | deliveryId | halts this Aggregate's partition until fixed |
| Support | Whenever OrderDelivered, then CloseOrderCase | orderId | tolerates out-of-order replay |

## Event: CourierLocationRecorded

| Field | Value |
|---|---|
| **Means** | The courier app reported where the courier is |
| **Aggregate** | Delivery |
| **Raised by** | time: every 15 seconds while on a trip |
| **Visibility** | internal |
| **Published as** | not published — high-volume personal location data; Ordering's map reads the live-map Read Model |
| **Ordering** | per Aggregate |
| **Retention need** | operational only — 24 hours, for live tracking and same-day disputes |
| **Sensitive data** | courier location: personal data, never leaves Delivery |

### Payload meaning

| Field | Meaning (in the language) | Why a consumer needs it |
|---|---|---|
| deliveryId | the trip | key for the live map |
| position | latitude and longitude | the live map |

## Translations

| Internal or stored events | Published as | Never published |
|---|---|---|
| CourierLocationRecorded | — | CourierLocationRecorded — personal, high volume, no outside reaction |
```

## Why this is right

- The generic status event became the four facts consumers react to. Each consumer's policy is written down.
- The pings stayed internal for two stated reasons: personal data, and no outside reaction.
- "The whole order" was declined; the payload carries what each reaction needs.
- `deliveredAt` was not duplicated in the payload: the occurrence time is the envelope's `time`.
