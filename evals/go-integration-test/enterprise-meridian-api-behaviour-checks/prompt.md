---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Meridian Claims**, an insurance claims platform on the **enterprise** profile. Our Go claims API (chi, PostgreSQL) documents these promises in its OpenAPI spec:

- `POST /v1/claims` accepts an `Idempotency-Key`; a repeat returns the stored result.
- Each user is rate limited; going over returns `429` with a `Retry-After` header.
- The old `/v1/claims/search` route is deprecated and sends a `Deprecation` header.
- Errors `400`, `401`, `404`, `409` and `429` share one error body.

We have no tests for any of this. My plan: add them to the contract test by validating a sample `201` and a sample `400` against the OpenAPI schema. That covers all four promises. Please confirm and outline the tests.

Use this plugin's go-integration-test skill, and answer in your reply, not in a file. Keep it short: a list of tests with what each sets up and asserts, with little or no code.
