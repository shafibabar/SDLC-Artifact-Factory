---
name: integration-design
product: [product slug]
version: 1.0.0
phase: design
owner: enterprise-architect
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: how the services and external systems talk, and how each integration is made safe]
traces-to: [design/context-map.md, design/architecture/container-diagram.md, ideate/nfr-specification.md]
---

# Integration Design for [Product]

<!-- Path: artifacts/<product>/design/architecture/integration-design.md.
     Lean: only when the product calls an external system, and SHORT: frontmatter, title, readers and question,
     profile, the Integration Inventory (external calls only; module calls are in-process and not listed),
     one "Notes" line per call if needed, Open Questions. Omit every other section.
     Standard: optional. Enterprise: required, every section.
     "CDC" means Change Data Capture only; always write "Consumer-Driven Contract" in full. -->

**Readers:** [enterprise-architect, backend-engineer, platform-engineer, the product owner]
**Question it answers:** for every integration, how does it talk, what does it promise, and what happens when the other side is slow or down?

- **Profile:** [lean | standard | enterprise]

## Integration Inventory

| From | To | Shape | Consistency | Protocol | Contract strictness | Contract test | Resilience |
|---|---|---|---|---|---|---|---|
| [caller or publisher] | [callee, topic or external system] | [request/response (sync) / request/acknowledge (sync, then async) / event (async)] | [atomic / eventual] | [HTTPS/JSON, gRPC, Kafka protocol] | [strict / loose (tolerant reader)] | [Consumer-Driven Contract / event schema compatibility / none: reason] | [sync: timeout, retry (idempotent or keyed), breaker, bulkhead, fallback, or "risk-accepted: <reason>"; async: outbox, idempotent consumer, DLQ] |

## Synchronous Integrations

<!-- One subsection per sync row. -->

### [From] → [To]

- **Why sync:** [the criterion: the caller needs the answer to finish]
- **Timeout:** [per attempt; the budget along the chain if any]
- **Retry:** [attempts, backoff, jitter; idempotent, or the idempotency key; or "no auto-retry: reconcile"]
- **Circuit breaker:** [threshold, window, reset; one per downstream | not needed: reason]
- **Bulkhead:** [own pool or concurrency limit | not needed: reason]
- **Fallback:** [the degraded response, and how it is observed]

## Asynchronous Integrations

| Topic | Publisher (mechanism) | Consumers (group) | Idempotency | Retry and DLQ |
|---|---|---|---|---|
| [topic] | [service, Transactional Outbox / Change Data Capture: reason] | [service (group)] | [key] | [policy; DLQ name] |

<!-- Design of the outbox, consumers and DLQ: event-driven-patterns. Orchestrated flows: workflow-orchestration. -->

## Coordination

- **[flow name]:** communication: [sync / async] · consistency: [atomic / eventual] · coordination: [orchestrated / choreographed] ([archetype, e.g. parallel saga]); [pointer to the orchestration design, where steps and compensations are designed] | none
<!-- Never atomic with choreographed (the "horror story"): accept eventual, or orchestrate. -->

## Anti-Corruption Layers

| Foreign system or context | Domain port | Adapter | What is translated |
|---|---|---|---|
| [system] | [port, in our language] | [adapter location] | [the fields and codes the domain uses] |

## Cross-Context Reads

| Reader | Data owned by | Option | Why not the others |
|---|---|---|---|
| [context] | [context] | [API composition / event replication / Change Data Capture] | [reason] |

## Consumer-Driven Contract Plan

| Consumer | Provider | Contract | Where the test runs | Gate |
|---|---|---|---|---|
| [consumer] | [provider] | [fields relied on] | [repo or pipeline] | [provider build fails on breakage] |

## Related ADRs

- [ADR-nnn: decision]

## Open Questions

- [an assumption or missing input — who answers it | none]
