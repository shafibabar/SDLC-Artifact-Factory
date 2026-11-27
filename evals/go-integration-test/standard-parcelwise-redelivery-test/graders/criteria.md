---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. Before asserting that the effect happened only once, the test waits for evidence that the consumer actually received and finished handling the second delivery (for example a committed consumer offset past it, or a handled or duplicate-skipped counter or signal). It explains that otherwise the test passes whether or not the consumer deduplicates. A count of 1 checked right away, after a sleep, or polled only until it equals 1 does not satisfy this.
2. It rejects the fixed sleep and waits by polling or receiving with a bounded deadline (such as a context timeout), correlated to this test's own event by an event or correlation id.
3. It verifies the outcome as end state in the real PostgreSQL, with the real consumer running against a real Redpanda, so that exactly one effect is recorded for the event.
4. It says a per-test rollback cannot isolate this test, since the relay and consumer commit in their own transactions and do not see the test's uncommitted work, and uses data unique to the test (with its cleanup, a database reset, or a throwaway database) instead.
5. It rejects taking the first message on the shared topic and running the relay tests in parallel over one outbox: a test matches only its own events (by id filter or a per-test topic), and tests that drain the shared outbox do not run in parallel unless each has its own isolated outbox. Giving data a unique id or tenant alone does not make parallel relay tests safe.
Fail if any of the 5 is missing.
