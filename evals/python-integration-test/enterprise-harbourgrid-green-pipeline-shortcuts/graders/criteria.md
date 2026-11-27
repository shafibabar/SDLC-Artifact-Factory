---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It rejects item 1 because the test runs its own filtered SQL and never exercises the code under test: the test must call the repository (or the application path that uses it) in tenant B's context and show tenant A's booking cannot be reached.
2. It rejects item 2 because schema conformance checks shape, not behaviour, and asks for integration tests that replay a request with the same `Idempotency-Key` and assert the original result is returned, and that exceed the limit and assert `429` with `Retry-After`.
3. It rejects item 3 on both counts: the coverage flag belongs on the make test target, not in `addopts` (where it fails subset runs such as integration only), and the required floor is 100% of lines and branches, not 80. Mentioning listed exclusions or a product-owner waiver above 90% does not fail.
4. It rejects removing integration tests from `make ci`: they stay in the standard check (an additional nightly run is fine).
5. It rejects `|| true`: exit code 5 means no tests were collected and must fail the build, so the selection or marker problem is to be fixed.
Fail if any of the 5 is missing.
