---
max_turns: 8
timeout_seconds: 300
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **Parcelwise**, a delivery-tracking product on the **standard** profile. Go services, PostgreSQL, Redpanda. A relay publishes rows from the outbox table to the `shipment-events` topic, and a consumer records each event once in the database. Both commit their own transactions. We need an integration test showing that a redelivered event is processed only once. My plan:

1. Publish the same event twice, then immediately assert that the processed count is 1.
2. If that is flaky, add `time.Sleep(3 * time.Second)`.
3. Wrap the test in a transaction and roll it back for cleanup.
4. Run all the relay and consumer tests with `t.Parallel()` on the one shared topic and outbox table, taking whatever message arrives first.

Write the test the right way. Use this plugin's go-integration-test skill, and answer in your reply, not in a file. Keep it short: an outline with brief code and a few lines on what you changed.
