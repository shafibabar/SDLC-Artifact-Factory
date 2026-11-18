# Example 2 — Standard: Two Contexts, One Idempotent Consumer, Per-Account Order

Self-contained. **Fieldpost** is field-service software for small plumbing and electrical firms. **Standard** profile. Two Bounded Contexts become separate services: **Work Orders** (jobs, scheduling, completion) and **Invoicing** (invoices, payments). A Work Order completed in the field must produce an invoice. Per firm (an *account*) invoices must be numbered in the order jobs were completed. The container diagram shows Redpanda as the broker; the stack is the default.

## Input

> **User:** "When a job is completed, Work Orders should call the Invoicing API to create the invoice, and if that call fails, roll back the job completion. Partition the topic by tenant, and add competing consumers to Invoicing so invoice creation keeps up."

## Working it

- **Synchronous call plus rollback** couples the two services' availability and wants a cross-service atomic step. Not as asked: no distributed transaction. Work Orders completes the job and publishes `WorkOrderCompleted` through the Transactional Outbox; Invoicing reacts. Async, eventual, choreographed: two services, an independent reaction, no compensation needed because an invoice is created after completion, never undone by it. A failed invoice creation shows as a missing invoice to retry, not a reopened job.
- **Idempotent consumer:** Invoicing records the event id in a dedup table in the same transaction that creates the invoice, so a rebalance or relay retry never produces a second invoice.
- **Retry and Backoff** for transient failures (database contention); an event that fails its schema or a business rule goes to the Dead Letter Queue, with an alert on its depth and Invoicing's support owner re-driving it.
- **Partition key:** invoices must be numbered in completion order per firm. What must stay in order is one account's events, so the key is the **account id**. "By tenant" is the same thing here only because an account *is* the tenant; the reason is recorded. A firm with a very large number of completions is a hot key (one partition's throughput), with a fallback of keying on the work order id and numbering in Invoicing at a sequence per account.
- **"Competing consumers":** the log model scales with a consumer group, one partition per member, order kept within each. Competing Consumers is the queue model and would break the per-account order the invoice numbering needs. Not as asked: a consumer group with the partition count above today's instance count.

## Output: the section in `artifacts/fieldpost/design/architecture/integration-design.md`

````markdown
## Event-Driven Pattern Decisions

- **Profile:** standard
- **Broker:** Redpanda (Kafka API log), per message-broker-selection

### Flow Classification

| Flow | Communication | Consistency | Coordination | Why |
|---|---|---|---|---|
| WorkOrderCompleted from Work Orders to Invoicing | async | eventual | choreographed | Two services, an independent reaction, no compensation; a synchronous call with rollback would couple their availability |

### Publication

| Publisher | Mechanism | Why |
|---|---|---|
| Work Orders service | Transactional Outbox | It emits WorkOrderCompleted together with its own write; no dual write |

### Topics and Ordering

| Topic | Partition key | Ordering guaranteed | Consumer groups | Retention |
|---|---|---|---|---|
| work-orders.completed | account id (invoices are numbered in completion order per firm) | Per account, within one partition; none across accounts or topics | invoicing (one group, one partition per member; partition count 12 for 3 instances) | 7 days |

### Delivery and Idempotency

| Consumer | Dedup (key and store) | Retry and Backoff | Dead Letter Queue | Alert |
|---|---|---|---|---|
| Invoicing, work-orders.completed | event id in a dedup table, committed with the invoice | transient errors only: 5 attempts, exponential backoff with jitter | work-orders.completed.dlq, re-driven by Invoicing support | DLQ depth above zero; consumer lag over 60 s |

### Open Questions

- The largest firm's completions per minute: if one account exceeds a partition's throughput, switch to the work order id key with a per-account sequence in Invoicing; owner: enterprise-architect, before launch.
````
