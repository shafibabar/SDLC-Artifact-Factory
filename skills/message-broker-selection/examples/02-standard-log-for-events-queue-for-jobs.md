# Example 2 — Standard: Domain Events on a Log, Render Jobs on a Queue

Self-contained. **Printwell** is an online photo-printing service. **Standard** profile, separate services: **Orders**, **Payments**, **Fulfilment** and **Rendering** (turns an uploaded photo into a print-ready file). Orders publishes Domain Events (`OrderPlaced`, `OrderShipped`) that Fulfilment and a planned Reporting service read. Rendering handles one job per print: from 10 seconds to 5 minutes, and nobody needs a finished job again.

## Input

> **User:** "Use RabbitMQ for everything: it's easier, and a message queue is a message queue. Scale the Fulfilment consumers with competing consumers on the events topic and keep each order's events in order."

## Working it

- **Is a broker needed?** Yes: separate services, and Reporting must be able to read history.
- **Replay question, per workload.**
  - *Order events:* Reporting will be built later from past events, and a consumer will join after launch. **Replay needed: yes, a log.**
  - *Render jobs:* a finished job is done; nobody re-reads it. Replay needed: no, so a queue is a legitimate fit. Jobs are long and uneven, so fair dispatch matters.
- **"A message queue is a message queue"** is declined: on a queue the events are gone once acknowledged, so Reporting could never be built from history, and order under parallel consumption changes.
- **Two brokers or one?** One would be cheaper to run. A log can carry the render jobs, but fair dispatch of long, uneven jobs and a retry delay are queue features the team would otherwise build. The team already runs RabbitMQ for another product, so the second system costs little. Decision: a log for events, a queue for render jobs, with the reason and cost on record.
- **"Competing consumers on the events topic"** is declined as worded: Competing Consumers is the queue model. On the log, Fulfilment scales with a **consumer group**, keyed by order id so each order's events stay in order, with the partition count above today's instance count (members beyond it sit idle).
- **Delivery:** at-least-once on both, acknowledging after the work is durable, every consumer idempotent.

## Output: `artifacts/printwell/design/architecture/broker-selection.md`

````markdown
---
name: broker-selection-rationale
product: printwell
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-11-19
summary: Order events run on a log because Reporting must replay history; render jobs run on a queue because a finished job is done and needs fair dispatch.
traces-to: [design/architecture/integration-design.md, design/architecture/container-diagram.md]
---

# Broker Selection Rationale for Printwell

**Readers:** enterprise-architect, backend-engineer, platform-engineer, the product owner
**Question it answers:** does this product need a broker, and does each messaging workload need to replay what it has already handled?

- **Profile:** standard
- **Broker needed:** yes

## Need for a Broker

Orders, Payments, Fulfilment and Rendering are separate services, so flows cross process boundaries; Reporting must read history. In-process events are not enough.

## Workloads

| Workload | Replay needed | Order needed | Routing or fan-out | Broker model | Why |
|---|---|---|---|---|---|
| Order events, Orders → Fulfilment and Reporting | yes: Reporting is built from past events and joins after launch | per order | two or more consumers, each at its own pace | log | replay first; per-order order from a consumer group keyed by order id |
| Render jobs, Orders → Rendering | no: a finished job is done | none | one worker pool | queue | long, uneven jobs need fair dispatch and a retry delay the queue provides |

## Decision

- **Broker:** Redpanda (the default) for events; RabbitMQ for render jobs
- **Why this one:** events need replay, which only the log provides; the render workload answers the replay question differently, and the team already runs RabbitMQ, so the second system's operating cost is small and accepted
- **Hosting and owner:** both self-run on the platform team's cluster; platform-engineer on call
- **Retention:** 30 days on the log, for a Reporting rebuild window; not applicable for the queue
- **ADR:** ADR-0004, two brokers by workload

## Delivery

Both kinds of broker deliver at-least-once, so every consumer is idempotent and effectively-once is the consumer's job; acknowledgement or the offset commit comes after the work is durable.

| Broker | Acknowledgement | Retry | Dead Letter Queue | Alert |
|---|---|---|---|---|
| Redpanda | offset committed after the work is durable | transient failures only, through a retry topic with backoff | a dead-letter topic with the failure reason, re-driven by Fulfilment | consumer lag; dead-letter depth above zero |
| RabbitMQ | acknowledged after the print file is stored | transient failures only, through a delay queue | a dead-letter queue, re-driven by Rendering support | queue depth; dead-letter depth above zero |

## Revisit When

- Render jobs need replay (for audit), or the second broker's operating cost outgrows its benefit: move jobs to the log.
- A flow joins or leaves a service boundary.

## Open Questions

- Whether render jobs need a priority lane for rush orders; owner: product owner.
````
