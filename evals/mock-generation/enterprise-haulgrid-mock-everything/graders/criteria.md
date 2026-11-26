---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It declines to mock `RatePolicy` and `Shipment`: the product's own domain objects are used for real, and doubles replace only true external dependencies.
2. It declines asserting every call in exact order, explaining that over-specified interaction checks break on refactors that change no observable behaviour; any order or count check kept is tied to a real behavioural requirement.
3. It uses a mock for `EventPublisher` and verifies the publication with the expected event content, because the message is seen outside the product.
4. It treats `CarrierQuotes.Quote` as a stub that supplies a canned quote, and neither the plan nor the example test asserts on its calls.
5. It does not verify `ShipmentStore` by call assertions: the product's own store is checked through its resulting state, with a state-based fake or a real database in an integration test.
6. The publisher double is generated with moq from a Go interface (`go:generate` with moq), and the example test uses its `PublishFunc` field and `PublishCalls()` record.
Fail if any of the 6 is missing.
