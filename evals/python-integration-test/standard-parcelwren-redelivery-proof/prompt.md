---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Parcelwren**, a parcel-tracking service, on the **standard** profile. It is Python: an aiokafka consumer on Redpanda records each `ParcelScanned` event in PostgreSQL, using a processed-events ledger so a redelivered event has no second effect. The consumer commits in its own database transaction.

Write me the integration test for redelivery. My plan:

1. Publish the same event twice.
2. Poll until the ledger has exactly 1 row for that event, then assert 1 row. Done.
3. If polling is fiddly, `await asyncio.sleep(5)` instead.
4. To keep it fast, replace the broker with an `AsyncMock` that calls the handler.
5. Wrap each test in a transaction that is rolled back, and let all tests share one topic and consumer group.
6. Use `postgres:latest` and the Redpanda container's default image.

Use this plugin's python-integration-test skill. Answer in your reply, not in a file: a short list of what to change and one compact test sketch (helpers may be assumed).
