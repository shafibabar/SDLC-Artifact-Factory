# Broker Selection Decision Guide

A repeatable path from a workload's characteristics to a broker choice, the delivery-guarantee mapping for each broker, how per-tenant physical isolation is expressed on each, and the migration/coexistence options when a workload needs to move or when both brokers run side by side. Use this after the skill body has framed the primary replay/retention axis.

---

## Part 1 — The decision tree

Answer top to bottom; the first decisive branch wins.

```
1. Does ANY consumer need to re-read messages already processed?
   (reindex, rebuild read model, bug-fix reprocessing, audit trail, event sourcing)
      YES ─────────────────────────────────► LOG (Redpanda)   [decisive — stop here]
      NO  ─► continue

2. Is this an immutable record of "what happened" that other Bounded
   Contexts subscribe to as Domain Events?
      YES ─────────────────────────────────► LOG (Redpanda)
      NO  ─► continue

3. Is the message transient task dispatch — a consumed message is
   genuinely done, nobody re-reads it (RPC-style work, job queue)?
      YES ─► continue to 4
      NO  ─► default to LOG (Redpanda) and re-examine assumptions

4. Does the workload need content-based routing (route different
   messages to different handlers by key/header), OR per-tenant
   queue-level routing, OR fair-dispatch of uneven work across a pool?
      YES ─────────────────────────────────► QUEUE (RabbitMQ)
      NO  ─► either works; default to LOG (Redpanda) — the repo standard —
             unless queue-only features (below) tip it
```

**Queue-only features that can tip an otherwise-either workload to RabbitMQ:**
- `topic`/`headers` exchange content-based routing without the caller addressing a destination.
- `basic.qos` prefetch fair-dispatch for long, uneven handlers.
- Per-message TTL and priority queues.
- Broker-side DLX retry topology when you do not want to model retry topics yourself.

**Log-only features that can tip an otherwise-either workload to Redpanda:**
- Any future replay/reindex, even if not needed today.
- Multiple independent consumer groups over one retained stream.
- Per-partition ordering under parallelism.
- Compaction (retain only the latest value per key) for a stateful changelog.

---

## Part 2 — Delivery-guarantee mapping

Neither broker gives exactly-once end-to-end for free. Both reach **at-least-once**, which means **Idempotent Consumers are mandatory on either** (dedupe on a business key or an event/message id). See `event-driven-patterns` for the idempotency pattern itself.

| Guarantee | Redpanda (log) | RabbitMQ (queue) |
|---|---|---|
| **At-most-once** | Commit offset **before** processing → a crash loses the record | `autoAck=true` → a crash loses in-flight work |
| **At-least-once** (target) | Process, **then** commit offset → a crash re-reads from the last commit | Publisher confirms + manual `basic.ack` **after** success → a crash requeues the unacked message |
| **Effectively-once** | At-least-once delivery **+ idempotent consumer** (dedupe on event id) | At-least-once delivery **+ idempotent consumer** (dedupe on message id) |
| **Producer accept** | Broker ack of the partition append (+ `acks=all` / idempotent producer) | `confirm.select` publisher confirms; `mandatory` + `basic.return` catch zero-route silent loss |

Rules of thumb:
- On **either** broker, order operations as *process → then acknowledge position*. The reverse is at-most-once.
- On Redpanda, an **idempotent producer** de-dupes producer-side retries; on RabbitMQ, **publisher confirms** are the analogous producer-side safety, and the `mandatory` flag is the only defense against a routing key matching zero bindings.
- Effectively-once is a consumer responsibility on both — the broker cannot deliver it for you.

---

## Part 3 — Per-tenant physical isolation on each broker

The repo's physical multi-tenancy requirement is **orthogonal** to the log-vs-queue choice — both brokers can enforce per-tenant isolation; the mechanism differs.

| Isolation level | Redpanda (log) | RabbitMQ (queue) |
|---|---|---|
| Namespace | Per-tenant **topic prefix** (`tenant.acme.data-asset.scanned`) | Per-tenant **vhost** (`/acme`) — the AMQP isolation boundary |
| Hard isolation | Per-tenant **cluster** (strongest; separate brokers) | Per-tenant vhost with its own users/permissions, or a per-tenant cluster |
| Queue/topic scoping | Per-tenant topic; ACLs restrict a tenant's principal to its prefix | Per-tenant queues bound in the tenant's vhost; user permissions scoped to the vhost |
| Ordering unit under isolation | Partition key includes `tenant_id` so a tenant's events stay ordered | One queue per tenant keeps a tenant's messages FIFO to a single consumer |

Choose the isolation strength (prefix/vhost vs. full cluster) from the compliance requirement, independently of the broker model. A vhost is RabbitMQ's native tenancy boundary — separate exchanges, queues, users, and permissions, with no cross-vhost visibility.

---

## Part 4 — Migration and coexistence

### Both brokers can legitimately run in one platform

This repo standardizes on Redpanda but does not forbid RabbitMQ for a genuinely queue-shaped workload. Running both is a valid architecture: the DataAsset event stream on Redpanda (log), per-tenant report dispatch on RabbitMQ (queue). Record each broker choice in the integration design with its replay answer, so the split is deliberate and reviewable — not two brokers by accident.

### Bridging a queue workload onto the log later

If a workload starts as transient dispatch (queue) but later needs replay/audit, do **not** silently swap clients. Migrate:

1. Introduce a Redpanda topic for the event that now needs retention.
2. Dual-write (or bridge from the queue) during a transition window; consumers move to the log group at offset 0.
3. Retire the queue once all consumers read the log.

A bridge in the other direction (log → queue) is rarely warranted — you would be discarding the retention you already paid for; only do it to hand a *derived* transient task to a work pool, keeping the source log intact.

### RabbitMQ streams and Kafka work-queue emulation — check before treating models as absolute

The clean "removed-on-ack vs. retained" contrast describes the **classic** AMQP 0-9-1 queue and the classic Kafka log — the correct teaching baseline for selection. In practice RabbitMQ also offers a **stream** queue type (a log-like, replayable, retained structure), and Kafka/Redpanda can emulate work-queue semantics with careful partitioning and offset handling. These blur the edges. A real design should check the current feature set of the specific broker before treating either model as an absolute — but should still make the primary selection on the replay question, because that is what the *default* structure of each broker is optimized for.

### When to revisit the choice

Re-open the broker decision when: a new consumer needs history that a queue never kept; a task-dispatch workload starts being replayed for audit; ordering-under-parallelism requirements appear where competing consumers had been fine; or per-tenant routing complexity outgrows partition keys. Each of these is a signal the workload's replay/ordering shape changed — re-walk the tree in Part 1.
