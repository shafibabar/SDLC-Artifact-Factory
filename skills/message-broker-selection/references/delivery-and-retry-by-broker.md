# Delivery and Retry, Broker by Broker

Reference for `message-broker-selection` step 8. The guarantees (at-most-once, at-least-once, effectively-once, the Idempotent Consumer, Retry and Backoff, the Dead Letter Queue) are `event-driven-patterns`' (`delivery-guarantees.md`); this file holds only what differs per broker. Design level only; code is the `go-*` and `python-*` skills. Grounded in Roy (confirms, acknowledgements, dead-letter exchanges, prefetch) and Kleppmann (offsets, why literal exactly-once across systems is not available).

## What both brokers share

Both reach **at-least-once** and neither gives exactly-once end to end. So **every consumer is idempotent** on either, and the rule is the same: **do the work and make it durable, then acknowledge position.** The reverse order is at-most-once and loses work on a crash. Effectively-once is the consumer's job on both.

## Per broker

| Question | Log (Kafka API, Redpanda) | Queue (AMQP, RabbitMQ) |
|---|---|---|
| How the producer knows the message was accepted | The broker acknowledges the append; use the strongest acknowledgement level and the idempotent-producer setting so producer retries do not duplicate | **Publisher confirms**; the **mandatory** flag returns a message that matched no queue |
| What an unroutable message does | Not applicable: a keyed record always lands on a partition | Silently dropped unless the mandatory flag and a handler for returns are used; treat a return as a configuration error and alert |
| What the consumer acknowledges | **Commit the offset** after the work is durable | **Acknowledge** after the work is durable; negative-acknowledge to requeue or dead-letter |
| The at-most-once trap | Committing the offset before processing | Auto-acknowledge |
| Redelivery after a crash or rebalance | From the last committed offset | The broker requeues unacknowledged messages |
| Retry with backoff | Hold the offset (blocks the partition), or publish to a **retry topic** consumed after a delay, then a terminal dead-letter topic after N attempts | A work queue dead-letters to a **retry queue** whose time-to-live is the delay and which dead-letters back; the death count caps the cycles, then a parked queue |
| Dead Letter Queue | A topic, built by the team; keep the original record and the failure reason beside it | A dead-letter exchange and queue, native to the broker |
| Back-pressure | The consumer controls how much it pulls | **Prefetch** caps unacknowledged messages per consumer: 1 for long, uneven jobs (fair dispatch), higher only when handlers are quick and uniform |
| What to watch | Consumer lag per partition, retry count, dead-letter depth | Queue depth, unacknowledged count, redelivery rate, dead-letter depth, returns |

## Durability

- **Log:** durability comes from replication of each partition across brokers and the retention period; the replicated log is provided by the broker (Kleppmann: the consensus underneath is provided, not designed).
- **Queue:** durability comes from a durable exchange and queue plus persistent delivery mode; there is no retained log to fall back on, so a lost queue is lost work. State the recovery plan in the document.

## Ordering after a failure

On a log, a retried or dead-lettered record arrives after later ones for the same key; on a queue, a requeued message does too, and competing consumers already interleave. A consumer that needs strict order handles that, or holds the key's processing until the failed message is resolved (`event-driven-patterns`, `ordering-and-partitioning.md`).
