---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It rejects the hand-written checker with BACKWARD applied to every topic: each event is checked in the compatibility mode its own event design declares. It also says a topic declared with mode NONE is refused (it must declare a real mode), not skipped.
2. It says the compatibility-mode check alone is not enough: a second, add-only pass on closed copies of the schemas also runs, so every event change gets both passes.
3. It rejects Pact message contracts for the `shipment-dispatched` event: events are covered by the schema compatibility checks, and Pact is kept for direct request/response calls between services.
4. It says the new enum value in a response fails the API-description gate by default and passes only as a case the product owner approves, recorded in the exceptions file (which is printed on every run). It also says that file cannot hold the `eta` rename: any other breaking change ships as a new major version.
5. It says a passed sunset date is not enough to delete `GET /v1/manifests`: removal also needs a recorded product-owner sign-off stating the evidence that no caller remains.
Fail if any of the 5 is missing.
