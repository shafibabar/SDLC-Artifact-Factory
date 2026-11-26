---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It makes each database test run inside its own transaction that is rolled back at the end, as the default isolation here (the tests described need no real commit).
2. It does not add a `tenant_id` (or any tenant column, field or tenant-scoped data) and says why: the product's design has no tenancy, so the fixtures must not invent one.
3. It rejects truncating tables in per-test cleanup, wherever the call sits, and explains that parallel tests sharing the database have their data wiped by each other.
4. It explains that the `defer` inside the helper runs when the helper returns, before the test body, and registers the teardown (the rollback) with `t.Cleanup` instead.
5. The builder starts from valid defaults that are fixed (or generated from a fixed, reproducible seed), not freshly random on each run, and lets a test override only the fields it cares about.
Fail if any of the 5 is missing.
