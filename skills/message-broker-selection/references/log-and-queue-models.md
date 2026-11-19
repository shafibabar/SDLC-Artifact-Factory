# The Log Model and the Queue Model

Reference for `message-broker-selection` step 4. Design level only; the code is the `go-*` and `python-*` skills. Grounded in Roy (*RabbitMQ in Depth*: the AMQP 0-9-1 model and its contrast with a log) and Kleppmann (*Designing Data-Intensive Applications*: replicated, partitioned logs). The research notes say Roy's chapter signposts are approximate and that the contrast is a model, not a verdict; confirm a specific broker's current features before relying on either edge.

## The log (Kafka API, Redpanda)

A **topic** is split into **partitions**; each partition is an ordered, append-only sequence of records. A record's position is its **offset**.

- **Retained, not consumed away.** Reading does not remove a record; it lives until the retention policy (time or size) evicts it. Ten consumers can read the same record independently.
- **Position belongs to the consumer.** The broker does not track who has read what. Each **consumer group** keeps its own offset. To re-read, a group moves its offset back: **replay is free**, because the data was never deleted.
- **Order is per partition.** Records with the same key land on the same partition and are read in order. There is no order across partitions or topics; that is the price of horizontal scale.
- **Sharing work is a consumer group.** A group divides a topic's partitions among its members, one owner per partition, so order within each partition holds while the group scales. Parallelism is capped by the partition count: members beyond it sit idle.
- **Fan-out is independent groups.** Each group reads the whole retained stream from its own offset. A consumer added next year starts from the beginning of what is retained.
- **A dumb broker, smart consumers:** the broker stores and serves; consumers hold the logic and the position (Roy's contrast; Newman's smart endpoints, dumb pipes).

## The queue (AMQP 0-9-1, RabbitMQ)

A producer publishes to an **exchange** with a routing key; **bindings** decide which **queues** receive a copy; a queue holds a message until a consumer acknowledges it, and then **removes** it.

- **Removed on acknowledgement.** There is no retention window, no offset, no replay. A consumer deployed tomorrow sees only what is published from then on.
- **Routing is the broker's job.** The exchange type is the delivery semantics: **direct** (exact key), **topic** (dotted key matched by pattern), **fanout** (a copy to every bound queue), **headers** (match on attributes). Content-based routing needs no caller-side addressing.
- **Sharing work is Competing Consumers.** Several consumers on one queue each get different messages. Order is kept per queue and only for a single consumer without requeues; two competing consumers can handle message N and N+1 at once, so **order across the pool is lost by design**.
- **Fair dispatch is prefetch.** A cap on unacknowledged messages per consumer keeps a slow handler from being handed a backlog while a fast one waits.
- **Fan-out needs one queue per consumer,** each with its own copy.
- **A smart broker, dumb consumers:** the broker owns routing, redelivery and dead-lettering.

## Side by side

| Property | Log | Queue |
|---|---|---|
| Message after it is handled | Retained until retention evicts it | Removed on acknowledgement |
| Replay and a late-joining consumer | Yes, from an earlier offset | No |
| Position | Consumer-owned offset | None; the broker tracks unacknowledged messages |
| Order | Per partition | Per queue, single consumer only |
| Sharing work | Consumer group (order kept within a partition) | Competing Consumers (order across the pool lost) |
| Routing | Topic and partition key | Exchange, key and bindings, including content-based |
| Fan-out | Every group reads the stream | One queue per consumer |
| Retry | Hold the offset, or a retry topic | Dead-letter exchange plus time-to-live topology |
| Producer knows it was accepted | Broker acknowledges the append | Publisher confirms; a flag returns unroutable messages |
| Back-pressure | Consumer pull rate | Prefetch |
| Easy way to lose work | Commit the offset before processing | Auto-acknowledge |

## Why they are not swappable

Both are casually called "a message queue", and a workload cannot move between them by swapping a client library.

- **Log to queue** loses replay: a new Read Model, a reindex or an audit that assumed it could rewind finds nothing. Retention and audit guarantees disappear without an error.
- **Queue to log** over-serves transient work: retention, partition planning and offset management for messages that are finished the moment they are handled, and broker-side routing is lost.
- **Ordering assumptions break both ways:** code that relied on order within a partition breaks under competing consumers; code that relied on queue order breaks on a log with several partitions.

## The edges are blurring

RabbitMQ has a **stream** queue type (log-like, retained, replayable), and a log can emulate a work queue with careful partitioning and offset handling. Use the clean contrast as the baseline for selection, because each broker's default structure is built for one model, and check the specific broker's current features before treating either model as absolute.
