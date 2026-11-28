---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Tallybird**, a membership-dues tracker for small sports clubs, on the **lean** profile. It is one Go service (chi, PostgreSQL through pgx) with a small React web shell, both shipped as Helm charts. The service has a public HTTP API, including `POST /v1/members`. I want to keep end-to-end testing cheap. My plan:

1. Because we are lean, skip full user journeys. Two smoke checks are enough.
2. Run the product with Docker Compose for these tests; a Kubernetes cluster is too much for a product this size.
3. Run the two smoke checks against our staging environment after each deploy. One reads the health and version endpoints. The other creates a member, records a payment, then deletes the member.
4. Seed the test member straight into the staging database with `INSERT ... ON CONFLICT (email) DO UPDATE`, so reruns never fail.
5. Put the files in `tests/e2e/` as ordinary `_test.go` files so `make ci` picks them up with everything else.

Please tell me what to change in this plan and show the header of one end-to-end test file. Use this plugin's go-e2e-test skill, and answer in your reply, not in a file. Keep it short: at most about 300 words plus a few lines of code.
