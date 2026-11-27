# Events and Asynchronous Effects

Self-contained. Use for an outbox relay, a consumer, a dead letter queue, or any effect that happens after the call returns. Run with aiokafka 0.15.0 against Redpanda 26.2.7.

## Contents
Waiting; isolation; what to prove; running the real consumer; proving the duplicate was consumed; breaking the code to see it fail.

## Waiting

Poll with a deadline and report the last value (the harness's `poll_until`; pass `watching=task` so a dead consumer fails the wait at once with its own error). A fixed `asyncio.sleep` is too short on a slow machine and wasted on a fast one, and proves nothing either way. Winteringham: poll with a bounded deadline and a correlation id, so a failed wait can be traced. Put the event id in `what`, and make the id come from `test_id`.

## Isolation

A published message cannot be rolled back. Each test uses a topic (`new_topic`) and a consumer group of its own; create `<topic>.dlq` the same way. A relay or consumer commits on its own connections and reads rows it did not write, so give the test its own database (`own_pool`). Every other database test keeps rollback. If a product fixes its topic name in code, make it a constructor argument, or filter every read by event id and say so.

## What to prove

| Component | Setup | Assertions |
|---|---|---|
| State plus outbox | One command; then one whose event write fails | Both rows exist; then neither does |
| Relay (`python-event-publisher`) | Seeded outbox row; drain twice | 1 then 0 published; one record on the topic with the envelope, key and the row id as `event_id` |
| Idempotent consumer (`python-event-consumer`) | The same record twice | Group committed offset 2 **and** the event id recorded; **then** exactly one effect, filtered by event id; the dead letter topic empty |
| Poison record | An undecodable record, then a good one | Original bytes and key on `<topic>.dlq` with its headers; the good one handled |
| Shutdown | Ask the consumer to stop at teardown; await it with a limit | It returns without error |

## Running the real consumer

Drive the product's consumer class with a real `AIOKafkaConsumer`, a real pool and a real dead letter producer, as an `asyncio` task on the test's loop. Never call a copy of its handler, and never replace the consumer or the broker. Commit settings are production's (`enable_auto_commit=False`, `auto_offset_reset="earliest"`).

## Proving the duplicate was consumed

"One effect" is true before the second delivery arrives. The second delivery is observed when the group's committed offset passes it (`committed_offset`). Correlate the same wait with this test's event id: poll, within one deadline, for the record of that id **and** the offset, then assert the effect filtered by that id. A per-test topic alone is not correlation by id.

The offset is evidence only when the consumer commits after processing. A consumer that commits first needs another signal that the duplicate was processed, such as a duplicate counter.

Seen with deduplication removed and the consumer slowed 200 ms per record:

| Wait | Result |
|---|---|
| For the event id's record only, then count | **Passed** 3 of 3: proves nothing |
| For the record and committed offset 2, then count | Failed 3 of 3: `assert 2 == 1` |

## Breaking the code to see it fail

Each such test goes red once before it is trusted. All run against the standard example:

| Change | Result | Proves deduplication matters? |
|---|---|---|
| Keep the `INSERT ... ON CONFLICT DO NOTHING`; ignore the `INSERT 0 0` result so the work runs again | `assert 2 == 1` | **Yes** |
| Remove only `ON CONFLICT DO NOTHING`; the primary key stays | The duplicate raises `UniqueViolationError`, which is not transient, so the consumer dead-letters it and commits the offset. The effect count stays 1 | **No** |
| The same, and the test does not read the dead letter topic | **The test passes** | No |

So the redelivery test also asserts that nothing was dead-lettered. The effect under test must be one that could happen twice: if its own table has a unique key or the write is an upsert, removing deduplication changes nothing observable; then assert on something that would repeat, or state that the test cannot show it.
