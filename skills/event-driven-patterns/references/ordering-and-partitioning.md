# Ordering and Partitioning

Reference for `event-driven-patterns` step 7. Applies to a log-based broker (partitioned, retained, consumer groups). Whether the broker is a log or a queue is `message-broker-selection`'s decision; this file says what each means for ordering. Grounded in Kleppmann (partitioning, hot keys, rebalancing, log-based brokers) and Roy (queues and competing consumers).

## Two models, two meanings of "consumers sharing work"

| | Log (Kafka API, Redpanda) | Queue (AMQP, RabbitMQ) |
|---|---|---|
| Message after it is handled | Stays, up to retention; readers keep their own offset | Removed on acknowledgement |
| How consumers share work | **Consumer group**: each partition goes to one member | **Competing Consumers**: members race on one queue |
| Order | Kept within a partition | Not kept across the pool, by design |
| Replay | Yes, from an earlier offset | No |

Use **Competing Consumers** for the queue model and **consumer group** for the log. The two are not interchangeable: adding competing consumers to a queue to "scale and keep order" cannot work, and a consumer group is how a log scales while keeping order within each partition.

## Choosing the partition key

1. **Name what must stay in order.** One Aggregate's events (a work order's), one account's, one tenant's, one device's. If nothing needs order, any even spread will do.
2. **Key on that.** Events with the same key land on the same partition and are handled in order by one consumer.
3. **Default: the Aggregate id.** It gives per-Aggregate order and spreads load across all Aggregates.
4. **`tenant_id` only for a multi-tenant product that needs per-tenant order.** The ceiling is then one partition's throughput per tenant: a very large tenant is a **hot key**. If it is hit, key on a finer value (the Aggregate id) or split the hot tenant across keys, accepting weaker order inside it.
5. **Never round-robin or a random key** for a flow that depends on order: one entity's events interleave across consumers.
6. **Write down the guarantee and its limit** in the decisions section (the "Ordering guaranteed" column).

## What ordering does not give you

- **Order only within one partition.** Two causally related events on different Aggregates may sit on different partitions and be seen out of order. `causationid` is tracing metadata, not an ordering mechanism. If a flow needs cross-Aggregate order, name it as a design constraint and choose: put them on one key, accept and handle out-of-order arrival, or make the later step check the earlier one's state.
- **Order across topics.** Two topics have no relative order at all.
- **Order after a retry or a dead letter.** A retried or re-driven message arrives after later ones for the same key; consumers that need strict order must handle that (or stop that key's processing until the failed message is resolved).

## Sizing the partition count

A topic has a fixed partition count, and members beyond it get nothing. Choose the count above today's consumer count so scale-out does not mean repartitioning (Kleppmann's guidance on fixed partitions assigned to nodes). Raising it later changes which partition a key maps to; plan the change, and do not rely on order across it.

## Rebalancing

When a member joins or leaves, partitions move. A message handled but not yet acknowledged will be delivered again to the new owner. That is why every consumer is idempotent (`./delivery-guarantees.md`) and why an offset is committed only after the work is durable.
