---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It does not confirm the plan: it says schema validation of sample responses proves only their shape, not that the behaviour happens, and puts these behaviour checks in the integration tests, run through the service's real router with a real PostgreSQL. Keeping schema conformance checks in the contract test as well does not fail.
2. For idempotency, a test sends a request, replays it with the same `Idempotency-Key`, and asserts the stored result is returned unchanged and that the database holds no second claim.
3. For rate limiting, a test actually sends requests beyond the limit as one user and asserts that a `429` is returned with the `Retry-After` header.
4. For deprecation, a test calls the deprecated route and asserts the `Deprecation` header is present on the response.
5. For errors, each of the five listed statuses (`400`, `401`, `404`, `409`, `429`) is triggered by its own real condition and its error body is checked, rather than sampling one. A table-driven test, or covering `429` within the rate-limit test, satisfies this.
Fail if any of the 5 is missing.
