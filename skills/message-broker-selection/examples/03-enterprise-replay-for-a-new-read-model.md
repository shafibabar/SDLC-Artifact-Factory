# Example 3 — Enterprise: A Swap to a Queue Declined Because a New Consumer Must Replay

Self-contained. **Gridlane** collects smart-meter readings for electricity retailers. **Enterprise** profile, separate services, deployed in two regions because customer data may not leave its region (a stated constraint of the product, not a default). Today `ReadingRecorded` events run on a Kafka-API log. Billing needs them in order per meter; regulators can ask for the readings behind any bill; and next quarter a **Usage Analytics** read model must be built from the earliest retained readings, 13 months back.

## Input

> **User:** "Our platform team wants to cut cost. Swap Kafka for RabbitMQ: it's only a client library change, so confirm that and give me the steps. Also scale the Billing consumers with competing consumers and keep each meter's readings in order."

## Working it

- **Replay question.** Usage Analytics must start from the earliest readings, and an audit must reproduce readings behind a bill. **Replay needed: yes.** A queue removes a message once it is acknowledged; the readings would be gone. The swap is declined as "only a client change": replay, audit and the new consumer are lost.
- **It is more than a client change in other ways.** Order: per-partition order under a consumer group becomes per-queue order that competing consumers break. Routing: exchanges and bindings are the broker's; keys are the producer's. Retry: dead-letter exchange and delay queues instead of a retry topic or a held offset.
- **Cost is judged on the workload.** The saving is real but small beside losing the audit trail. Options on record: keep the log and reduce its footprint (retention sized to 13 months, fewer partitions where lag is low), or move a workload that does not need replay. RabbitMQ's stream type is log-like and a log can emulate a queue; the team checks the broker's current features, but the choice still follows the replay question.
- **"Competing consumers"** is declined as worded: on the log, Billing scales with a **consumer group**, keyed by meter id, so each meter's readings stay in order; members beyond the partition count sit idle.
- **Two clusters:** one per region because of the residency constraint in the product's own requirements. This product is not otherwise multi-tenant at the broker, so no tenancy section.
- **ADR:** costly to reverse and widely depended on, so ADR-0011 records the decision and the rejected swap.

## Output: `artifacts/gridlane/design/architecture/broker-selection.md`

````markdown
---
name: broker-selection-rationale
product: gridlane
version: 1.1.0
phase: design
owner: enterprise-architect
created: 2026-11-19
summary: Meter readings stay on a log because audit and a new analytics consumer need replay; a swap to a queue is declined and cost is cut inside the log.
traces-to: [design/architecture/integration-design.md, design/architecture/container-diagram.md, ideate/nfr-specification.md]
---

# Broker Selection Rationale for Gridlane

**Readers:** enterprise-architect, backend-engineer, platform-engineer, the product owner
**Question it answers:** does this product need a broker, and does each messaging workload need to replay what it has already handled?

- **Profile:** enterprise
- **Broker needed:** yes

## Need for a Broker

Services are separate and deployed in two regions; Usage Analytics and the audit need history. In-process events are not an option.

## Workloads

| Workload | Replay needed | Order needed | Routing or fan-out | Broker model | Why |
|---|---|---|---|---|---|
| ReadingRecorded, Ingest → Billing, Usage Analytics, Audit | yes: audit and a 13-month analytics build | per meter | three consumers, each at its own pace | log | replay and audit first; per-meter order from a consumer group keyed by meter id |

## Decision

- **Broker:** Redpanda (the default), one cluster per region
- **Why this one:** the workload needs replay and per-meter order under parallel consumption; the two clusters follow the residency constraint in the product's requirements. A swap to a queue was considered and rejected: replay and audit would be lost
- **Hosting and owner:** managed service in each region; platform-engineer owns it; recovery by replicated partitions, with a tested restore of the audit topic
- **Retention:** 13 months, for the analytics build and the audit window
- **ADR:** ADR-0011, log retained for replay; queue swap rejected

## Delivery

Both kinds of broker deliver at-least-once, so every consumer is idempotent and effectively-once is the consumer's job; acknowledgement or the offset commit comes after the work is durable.

| Broker | Acknowledgement | Retry | Dead Letter Queue | Alert |
|---|---|---|---|---|
| Redpanda | offset committed after the work is durable; consumers idempotent on the event id | transient failures only, through a retry topic with backoff | a dead-letter topic keeping the original reading and the failure reason, re-driven by Billing support | consumer lag per partition; dead-letter depth above zero |

## Revisit When

- Retention cost grows past the budget: move derived, non-audit streams to a cheaper tier, not the audit stream.
- A workload appears that is done once handled (a bulk export job): evaluate a queue for it alone.

## Open Questions

- Whether regulators need readings beyond 13 months; owner: product owner, with the compliance lead.
````
