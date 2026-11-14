# Example 1 — Lean: Two External Calls, Sized to Risk

Self-contained. **PawRoute** books dog walks: owners book a walk, walkers accept it, owners pay by card. **Lean** profile, one modular monolith (Bookings, Walkers, Payments modules), two developers. It calls **Stripe** (payment intents, with a webhook back) and **Postmark** (booking emails). Default stack.

## Input

> **User:** "Wrap every call in timeouts, retries and circuit breakers, including Bookings calling Payments, so we're safe. If Stripe times out when we create a payment, just retry it three times."

## Working it

- **Module calls** (Bookings → Payments) are in-process inside the monolith: no network, so no resilience stack. They aren't listed.
- **Stripe:** the booking can't be confirmed without the payment intent, so request/response. A timeout is an unknown outcome: a blind retry could create a second intent and charge twice. Retry only with Stripe's idempotency key (the booking id); otherwise reconcile. The webhook arrives at least once and possibly out of order: handle it idempotently.
- **Postmark:** losing one booking email is low-cost; a timeout and one keyed retry; no breaker, recorded as risk-accepted.
- **Breakers and bulkheads:** two low-traffic external calls from one app; the cost outweighs the risk at this profile, recorded as risk-accepted (Fairbanks).

## Output: `artifacts/pawroute/design/architecture/integration-design.md`

````markdown
---
name: integration-design
product: pawroute
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-04-08
summary: PawRoute's two external integrations: Stripe with a timeout, keyed retries and an idempotent webhook; Postmark with a timeout and a risk-accepted lighter stack.
traces-to: [design/architecture/container-diagram.md, ideate/nfr-specification.md]
---

# Integration Design for PawRoute

**Readers:** enterprise-architect, backend-engineer, the product owner
**Question it answers:** for every external call, how does it talk, what does it promise, and what happens when the other side is slow or down?

- **Profile:** lean

## Integration Inventory

| From | To | Shape | Consistency | Protocol | Contract strictness | Contract test | Resilience |
|---|---|---|---|---|---|---|---|
| PawRoute App | Stripe (create payment intent) | request/response | eventual (reconciled by the webhook) | HTTPS/JSON | loose (tolerant reader) | none: Stripe's published API, pinned version; recorded-response test of the fields read | timeout 3 s; retry 2× with jitter only with idempotency key = booking id; risk-accepted: no breaker or bulkhead (one low-traffic downstream) |
| Stripe | PawRoute App (webhook) | event | eventual | HTTPS/JSON | loose (tolerant reader) | none: signature check and recorded payloads | idempotent: store the Stripe event id, ignore repeats, move payment state only forward |
| PawRoute App | Postmark (send email) | request/response | eventual | HTTPS/JSON | loose (tolerant reader) | none: recorded-response test | timeout 2 s; 1 retry keyed by message id; risk-accepted: no breaker (a lost email costs little; failures logged and visible on the booking) |

## Synchronous Integrations

### PawRoute App → Stripe

- **Why sync:** the booking can't be confirmed without the payment intent
- **Timeout:** 3 s per attempt
- **Retry:** 2 retries, 200 ms then 400 ms with jitter, always with the booking id as Stripe's idempotency key; on a final timeout the booking stays "payment pending" and the webhook or a 10-minute check settles it
- **Circuit breaker:** not needed: risk-accepted at lean (one downstream, low traffic)
- **Bulkhead:** not needed: risk-accepted
- **Fallback:** "payment pending" shown to the owner; a metric counts pending bookings older than 10 minutes

### PawRoute App → Postmark

- **Why sync:** the email is sent when the booking is confirmed
- **Timeout:** 2 s
- **Retry:** 1 retry keyed by the message id
- **Circuit breaker:** not needed: risk-accepted
- **Bulkhead:** not needed: risk-accepted
- **Fallback:** the booking is confirmed regardless; a failed send is logged and shown on the booking

## Asynchronous Integrations

| Topic | Publisher (mechanism) | Consumers (group) | Idempotency | Retry and DLQ |
|---|---|---|---|---|
| none (in-process module events) | — | — | — | — |

## Coordination

- none

## Anti-Corruption Layers

| Foreign system or context | Domain port | Adapter | What is translated |
|---|---|---|---|
| Stripe | `PaymentGateway` (start a payment, read its outcome) | payments adapter | intent id, status, amount; Stripe error codes to domain outcomes |
| Postmark | `Notifier` (send a booking message) | email adapter | template id, recipient |

## Cross-Context Reads

| Reader | Data owned by | Option | Why not the others |
|---|---|---|---|
| none (modules of one deployable call each other's interfaces) | — | — | — |

## Consumer-Driven Contract Plan

| Consumer | Provider | Contract | Where the test runs | Gate |
|---|---|---|---|---|
| none: both providers are third parties | — | — | — | recorded-response tests in the app build |

## Related ADRs

- none

## Open Questions

- none
````

## Why this is right

- Module calls stayed in-process; only the two remote calls are designed.
- The payment retry is keyed, and an unknown outcome is reconciled rather than repeated.
- The webhook is idempotent, because it can arrive twice.
- Every lighter choice is written down as risk-accepted, with its reason.
- `validate-integration-design.sh` exits clean on the artifact.
