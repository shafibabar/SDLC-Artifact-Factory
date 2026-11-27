# Events and Asynchronous Effects

Self-contained. Use for an outbox relay, a consumer, a dead letter queue, or any effect that happens after the call returns. Run against Redpanda 26.2.7 with franz-go v1.22.3.

## Waiting

Poll with a deadline and report the last error (the harness's `Await`). A fixed sleep is too short on a slow machine and wasted time on a fast one, and proves nothing either way (Winteringham: bounded polling with a correlation id). Pick a deadline generous for the operation: it costs nothing when the test passes. Call `Await` from the test's goroutine.

To make a failure traceable, put an identifier derived from the test into the request header or event the test sends, and assert or log on it (`distributed-tracing-design` owns propagation).

## Isolation

A published message cannot be rolled back. Each test uses a topic and a consumer group of its own (`NewTopic`, `Name`). A relay or consumer commits on its own connections and reads rows it did not write, so give the test its own database (`NewDatabase`); every other database test keeps rollback.

## What to prove

| Component | Setup | Assertions |
|---|---|---|
| State plus outbox | One command; then one whose event write fails | Both rows exist; then neither does (`go-event-publisher`) |
| Relay | Seeded outbox row; drain twice | 1 then 0 published; the record's content; topic end offset 1 |
| Idempotent consumer | The same record twice, then start | Group committed offset 2, **then** exactly one effect (`go-event-consumer`) |
| Poison record | An undecodable record, then a good one | Original bytes on `<topic>.dlq` with its headers; the good one handled |
| Shutdown | Cancel the context in cleanup | The consumer returns, with no error; report it if it does not |

## Proving the duplicate was seen

"One effect" is true before the second delivery arrives. Observed with deduplication removed and the consumer slowed by 200 ms per record:

| Test | Result |
|---|---|
| Wait for the first effect, publish the duplicate, count at once | **Passed** 3 of 3 runs: proves nothing |
| Wait until the group committed offset 2, then count | Failed 3 of 3: `2 reminders sent, want 1` |

The committed offset is evidence only when the consumer commits after processing (`go-event-consumer`: manual commit). A consumer that commits first needs another signal that the duplicate was processed, such as a counter it increments for duplicates.

Each such test goes red once with the deduplication removed before it is trusted.
