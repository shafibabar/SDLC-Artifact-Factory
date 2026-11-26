---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It keeps the expensive resource (container and/or engine) session-scoped but gives each test its own function-scoped database session whose transaction is rolled back in teardown (for example after a `yield`), instead of one shared committing session.
2. It replaces the shared mutable `demo_claim` with a per-test factory (or per-test fixture) that builds a fresh object with the values the test needs.
3. It follows the stated tenancy design: pooled-database test data carries a `tenant_id`, while large-insurer (separate database) test data is isolated by its own database and gets no `tenant_id` column or field.
4. It rejects loading production claims and uses synthetic data in place of real personal data.
5. It pins the PostgreSQL image to a specific version tag instead of relying on the default `latest`.
6. It makes the connection URL use the asyncpg driver the product uses (for example by passing the driver to `get_connection_url`), because the default is `psycopg2`.
Fail if any of the 6 is missing.
