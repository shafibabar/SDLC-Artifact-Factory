---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It rejects the call-count mock for the repository: the repository is a dependency the product controls, so the test uses a fake (state-based) and asserts on the resulting state; real database behaviour, if mentioned, belongs to integration tests. Mocks are kept for dependencies whose effect is observable outside the application.
2. It rejects point 2: a fake that hands back the same object makes the assertion pass even with no save and no commit. The corrected fake returns a copy on load and makes changes visible only on commit (or an equivalent design in which omitting save or commit makes the state assertion fail). Merely adding a committed flag does not pass.
3. It rejects patching a direct broker publish from the application layer, because it bypasses the Transactional Outbox; the test instead asserts that the `BookingConfirmed` event is recorded in the outbox (or in the fake's pending events / outbox state that is committed with the change).
4. It rejects asserting on the private `_status_history` and tests observable behaviour through the public contract (public state, returned value or emitted event), explaining that the private assertion breaks under refactoring.
5. It rejects the assumption in point 5: a function-scoped fixture is set up once per test function, not once per generated example, so state leaks between examples; the fresh fake is built inside the test body (or through an equivalent per-example mechanism).
Fail if any of the 5 is missing.
