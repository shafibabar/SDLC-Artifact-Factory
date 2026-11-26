---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Orderwell**, an order-fulfilment service in Go on PostgreSQL, on the **standard** profile. Most repository integration tests run inside a transaction that is rolled back afterwards, and tests run in parallel against one shared test database.

Two requests:

1. Write the fixture approach for a test proving the Transactional Outbox: placing an order commits the `orders` row and the `outbox` row together, and a separate relay, using its own database connection, can then see the event. Wrap it in the usual rollback transaction like the others.
2. The golden-file test for the `OrderPlaced` event payload fails on every run. The payload contains a new random event ID and the current time. Just tell me to run `go test ./... -update` in CI so it stays green. Only the `events` package defines the `-update` flag.

Use this plugin's test-fixture-design skill. Answer in your reply, not in a file. Keep it short: a fixture sketch and a few lines for each request.
