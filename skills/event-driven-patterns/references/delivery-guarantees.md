# Delivery Guarantees

Reference for `event-driven-patterns`: how an event gets out reliably and is handled safely. Design level only; the code is `go-event-publisher` (relay) and `go-event-consumer` (idempotent consumer, retry, Dead Letter Queue), and the Outbox row itself is written by the service's repository (`go-repository-pattern`). Grounded in Kleppmann (log-based brokers, effectively-once processing, why two-phase commit does not scale) and Richardson (reliable messaging as part of a transaction).

## Delivery semantics

| Guarantee | How | Cost | Use |
|---|---|---|---|
| At-most-once | Commit the offset before processing | A crash loses the message | Never for business events |
| At-least-once | Commit after processing; a crash re-delivers | Duplicates | The default, paired with an Idempotent Consumer |
| Exactly-once (broker transactions) | Atomic consume-process-produce **inside one cluster** | Latency, coordinator overhead | Only a topic-to-topic transform whose input and output are both topics in the same cluster |

Literal exactly-once across independent systems (broker, then a database, then an external API) is not available: a database write and an offset commit cannot be one atomic step. What is available is **effectively-once**: at-least-once delivery plus a deduplicating consumer, so the observable business effect happens once. The moment an effect leaves the cluster (a database write, an email), idempotency is the only guarantee.

**End-to-end argument.** Deduplication is real only at the final effect. Carry one key (the event id from the envelope) from the origin through every hop to the effect; per-hop dedup that happens to compose is not a guarantee unless the same key travels the whole way.

## Transactional Outbox

The service writes its state change and an "event to publish" row in **one local transaction**; a separate relay reads the outbox and publishes, marking rows sent.

- **Defends against:** the dual-write problem. Writing to the database and publishing as two operations means a crash between them loses the event or publishes one for a rolled-back write.
- **Guarantee:** atomic locally (one transaction, one node); at-least-once from the outbox to the broker, because the relay can re-send a row it published but had not yet marked. Consumers' idempotency absorbs that.
- **Select when:** a service emits an event together with its own write. The default for every service you own.
- **Do not select when:** the service's code cannot be changed (use Change Data Capture), or the call stays inside one deployable (an in-process publisher).
- **Orchestrators too:** an orchestrator's state transition and the command it sends are one transaction through the same Outbox (`workflow-orchestration`).

## Change Data Capture

Row changes are read from the database's write-ahead log and streamed as events, with no application change.

- **Select when:** the source cannot publish (legacy code, a vendor system, a database to migrate away from).
- **Do not select when:** the service is yours. CDC events mirror table structure: an `UPDATE` on a row is not a business fact, and consumers couple to your schema. Using it where the Outbox would do is the common mistake.
- **A relay may use log tailing:** reading the *outbox table* by log tailing is still the Outbox pattern; the events are the ones the service chose to publish.
- **Guarantee:** eventual; order follows the log sequence of each source table.
- Never abbreviate Consumer-Driven Contract to CDC.

## Idempotent Consumer

Handling the same event twice has the same effect as handling it once.

- **Always.** At-least-once delivery means a restart, a rebalance or a relay retry will repeat events.
- **Atomic:** the dedup mark and the effect commit in one local transaction. If they are separate, a crash between them repeats the effect. A unique-constraint violation on the mark means "already processed".
- **Key:** the event id from the envelope (`event-schema-design`), not one derived in the consumer.
- **Scope:** per consumer, so one consumer's replay never collides with another's.
- **Retention:** keep marks at least as long as a redelivery can happen (the broker's retention, plus the relay's retry horizon).
- **A command is idempotent too:** a duplicate returns the first outcome (`command-catalog`).

## Retry and Backoff

A failed attempt is retried after a growing delay with random jitter, so synchronized retries do not stampede a recovering dependency.

- **Retry transient failures only:** a downstream 5xx, a network blip, contention. A permanent failure (a message that fails its schema, a rejected business rule) never improves: send it straight to the Dead Letter Queue. Tell them apart by the error type before choosing.
- Retry composes with idempotency: a retry may re-run a partly succeeded handler, and idempotency makes that safe.
- **An external call made because of an event** is not retried inside the consumer while the offset is held; see `integration-design` § 5.

## Dead Letter Queue

After N failed attempts a message moves to a side topic or queue so the partition advances.

- **Defends against:** head-of-line blocking. One partition is processed in order by one consumer, so a stuck message halts everything behind it.
- **Required with it:** a retry policy (the N), an alert on DLQ depth above zero, an owner, and a way to re-drive a repaired message. DLQ contents need a human or a repair job; without one, the DLQ is silent loss.
- **Keep the original message intact** and carry failure information in metadata, so a re-drive replays what was really sent.

## Event replay

Re-reading a topic from an earlier offset to rebuild a consumer's state: a corrupted Read Model, a new Read Model, a new consumer needing history.

- **Needs:** retention long enough for the use (state the period), every consumer idempotent, a Read Model that supports a full rebuild.
- **Replay into a shadow table, then swap.** Never replay into a live, incrementally patched Read Model: replayed and live events mix into a state no history produced.
- Whether a Read Model is projected from events at all is `cqrs-pattern`'s ladder, decided first.

## What to watch

Consumer lag per partition (are we keeping up?), retry count, DLQ depth (alert above zero), and the trace id carried from the envelope so a flow can be followed across services (`opentelemetry-instrumentation`).
