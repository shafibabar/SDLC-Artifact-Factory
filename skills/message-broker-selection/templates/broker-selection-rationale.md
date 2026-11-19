---
name: broker-selection-rationale
product: [product slug]
version: 1.0.0
phase: design
owner: enterprise-architect
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: whether the product needs a broker, which kind each workload needs, and why]
traces-to: [design/architecture/integration-design.md, design/architecture/container-diagram.md, ideate/nfr-specification.md]
---

# Broker Selection Rationale for [Product]

<!-- Path: artifacts/<product>/design/architecture/broker-selection.md.
     Lean: normally not produced (skip): one deployable, in-process events, no broker.
     Standard and enterprise: optional, when a broker is chosen or the default is questioned.
     Names no code. A broker choice is costly to reverse: link its ADR.
     Competing Consumers is the queue model; a log shares work with a consumer group.
     "CDC" means Change Data Capture only; write "Consumer-Driven Contract" in full. -->

**Readers:** [enterprise-architect, backend-engineer, platform-engineer, the product owner]
**Question it answers:** does this product need a broker, and does each messaging workload need to replay what it has already handled?

- **Profile:** [lean | standard | enterprise]
- **Broker needed:** [yes | no: in-process events inside one deployable]

## Need for a Broker

[Which flows cross a process boundary, need history, or fan out widely. If none: why in-process events are enough, and the condition that would change it.]

## Workloads

<!-- One row per messaging workload. Omit this section and the next when no broker is needed. -->

| Workload | Replay needed | Order needed | Routing or fan-out | Broker model | Why |
|---|---|---|---|---|---|
| [what moves, from → to] | [yes or no, and who would re-read] | [per Aggregate, per account, none] | [by key, by content, many consumers] | [log / queue] | [the replay answer first, then any tie-breaker] |

## Decision

- **Broker:** [the product or "default (Redpanda)", per sdlc-config message_broker]
- **Why this one:** [by the workloads above, not by the product's industry; for a second broker, the workload that answers the replay question differently and its operating cost]
- **Hosting and owner:** [self-run or managed; who is on call]
- **Retention:** [period and the reason, e.g. a rebuild window or an audit period; "not applicable" for a queue]
- **ADR:** [the ADR id, or the reason none is needed]

## Delivery

Both kinds of broker deliver at-least-once, so every consumer is idempotent and effectively-once is the consumer's job; acknowledgement or the offset commit comes after the work is durable.

| Broker | Acknowledgement | Retry | Dead Letter Queue | Alert |
|---|---|---|---|---|
| [broker] | [offset committed or message acknowledged after the work is durable] | [transient failures only: how it is built on this broker] | [where failed messages go, owner, re-drive] | [what is watched: lag, depth] |

## Tenancy

<!-- Multi-tenant products only; follow multi-tenancy-design. Omit otherwise. -->

[How isolation is applied to the broker, per the tenancy model chosen.]

## Revisit When

- [A trigger: a new consumer needs history, a flow leaves or joins the deployable, order under parallelism, routing outgrows keys, cost or skills change.]

## Open Questions

- [A question for the product owner or a named role, with an owner; or "none"]
