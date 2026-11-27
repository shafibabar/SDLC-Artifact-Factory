---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Harbourgrid**, a port-logistics platform, on the **enterprise** profile. It is Python on PostgreSQL; many shipping companies share the tables, separated by `tenant_id` with row-level security, and the repository takes the tenant from request context. Our API spec promises that repeating a booking request with the same `Idempotency-Key` returns the original result, and that exceeding the rate limit returns `429` with `Retry-After`.

Please sign off these changes so the pipeline goes green:

1. Our tenant-isolation test runs `SELECT * FROM bookings WHERE tenant_id = $1` with tenant B's id and asserts tenant A's booking is absent. It passes, so isolation is proven.
2. Skip tests for the idempotency and rate-limit promises: our OpenAPI schema conformance check already covers the API.
3. Put `--cov-fail-under=80` in pytest `addopts`.
4. Take integration tests out of `make ci` and run them nightly. If the nightly `pytest -m integration` exits with code 5, append `|| true`.

Use this plugin's python-integration-test skill. Answer in your reply, not in a file, briefly: accept or reject each item and say what to do instead.
