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

## Notes

- **Stripe, create payment intent:** a timeout is an unknown outcome, so retries always carry the booking id as Stripe's idempotency key; after the last retry the booking stays "payment pending" and the webhook or a 10-minute check against Stripe settles it. Stripe's model stays behind the Payments module's `PaymentGateway` port.
- **Stripe webhook:** at-least-once and possibly out of order: store the event id, ignore repeats, and only move a payment's state forward.
- **Postmark:** the booking is confirmed whether or not the email goes; a failed send is logged and shown on the booking.

## Open Questions

- none
````

## Why this is right

- Module calls stayed in-process; only the two remote calls are designed.
- The payment retry is keyed, and an unknown outcome is reconciled rather than repeated.
- The webhook is idempotent, because it can arrive twice.
- It stays short, as lean should: the inventory, one note per call, open questions; nothing else.
- Every lighter choice is written down as risk-accepted, with its reason.
- `validate-integration-design.sh` exits clean on the artifact.
