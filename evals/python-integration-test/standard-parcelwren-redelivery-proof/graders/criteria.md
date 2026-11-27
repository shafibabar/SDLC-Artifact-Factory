---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It says polling until the ledger count is 1 proves nothing, because the count is already 1 after the first copy, and the test must first obtain evidence that the second copy was actually consumed (for example the committed offset passing it, a duplicate counter, or a later marker event on the same partition being processed) before asserting one effect.
2. It rejects the fixed five-second sleep and waits by polling with a bounded deadline for a condition tied to this test's own event or messages.
3. It rejects the `AsyncMock` broker for this test and uses a real Redpanda (or Kafka-compatible) broker with real PostgreSQL, because a mock that calls the handler cannot prove redelivery behaviour. Saying that a mock or fake at the publish boundary is fine in unit tests does not fail.
4. It says rolling back a test transaction cannot isolate this test, since the consumer commits on its own connection, and instead uses data scoped to the test (with cleanup or a unique key) and does not share the topic and consumer group between tests (for example a unique topic and group per test).
5. It says to pin the image tags, replacing both `postgres:latest` and reliance on the Redpanda default image with explicit versions.
Fail if any of the 5 is missing.
