---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Haulgrid**, a multi-tenant freight dispatch platform in Go, on the **enterprise** profile. `Dispatcher.Dispatch`:

- asks an outside carrier's API for a quote (`CarrierQuotes.Quote`),
- applies our own domain objects, `RatePolicy` and the `Shipment` aggregate,
- saves the shipment through our own `ShipmentStore` (our PostgreSQL),
- publishes `ShipmentDispatched` through `EventPublisher.Publish` to the broker that other companies' systems consume.

Our rule from now on: every collaborator gets a mock, including `RatePolicy` and `Shipment`, and every test asserts every call, with counts, in exact order. That way nothing changes without a test noticing. Please give me the plan for the doubles and one example test.

Use this plugin's mock-generation skill. Answer in your reply, not in a file, and keep it short: under 400 words plus brief Go snippets.
