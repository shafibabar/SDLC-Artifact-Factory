---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It recommends API Composition as the starting point for this cross-service page: a composer (a gateway, a backend-for-frontend or a small dedicated service) calls Bookings, Memberships and Billing, each answering from its own data, and combines the results, instead of building an event-fed combined read table (microservices-patterns-richardson, Core Concepts, "Queries that span services — API Composition vs. CQRS": "API Composition first"; Actionable Techniques, "Default queries to API Composition"; Decision D047-4: API Composition across services).
2. It names the specific conditions under which a dedicated, event-fed read view (a CQRS view) would replace composition — for example the composition fanning out to too many services, a join over large data, or the same data having to answer many differently shaped queries — and it states the cost that view brings: the page becomes eventually consistent with the owning services and needs event-replication machinery to keep it fed (microservices-patterns-richardson, Core Concepts, Ch. 7: CQRS handles complex queries "at the cost of eventual consistency and the replication machinery"; Actionable Techniques: "graduate to CQRS on a named trigger … Name the trigger in the design").
3. It points out that the order is backwards: whether Kilnworks uses API Composition, a simple read model or projections is an architecture decision made at design time, before any Read Model is designed, so the `MemberAccountView` should not have been designed ahead of that decision (Decision D047-4: the read-side ladder is owned by the enterprise architect and "decided before `read-model-design` runs"; wave-2-findings W2-14: "decide CQRS before Read Model design").
4. It declines to write the read-side design as Go code: the design describes the read side in plain, stack-neutral terms (which services are called, what each returns, how results combine, the escalation trigger), and the Go code is written later, during implementation (Decision D047-10: design skills are stack-neutral, with no code in the design artifact).
Fail if any of the 4 is missing.
