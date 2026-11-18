## Event-Driven Pattern Decisions

<!-- A SECTION of the Integration Design (artifacts/<product>/design/architecture/integration-design.md),
     not a separate file: no frontmatter. Written by enterprise-architect with event-driven-patterns.
     Lean: SHORT. Profile, Broker, Flow Classification, Publication, Open Questions; omit Topics and Ordering
     and Delivery and Idempotency unless a flow leaves the deployable.
     Standard: every section for each cross-service flow. Enterprise: as standard, with an owner and retention per topic.
     Always write "Consumer-Driven Contract" in full; "CDC" means Change Data Capture only. -->

- **Profile:** [lean | standard | enterprise]
- **Broker:** [the broker chosen in message-broker-selection, or "none: in-process events inside one deployable"]

### Flow Classification

| Flow | Communication | Consistency | Coordination | Why |
|---|---|---|---|---|
| [what moves, from → to] | [sync / async] | [atomic / eventual] | [choreographed / orchestrated] | [for orchestrated: which of Richardson's triggers fired, and "designed in workflow-orchestration"; for choreographed: why it is simple enough; any synchronous exception] |

### Publication

| Publisher | Mechanism | Why |
|---|---|---|
| [service or module] | [Transactional Outbox / Change Data Capture / in-process publisher] | [Outbox: it emits an event with its own write. Change Data Capture: why the source cannot publish. In-process: both sides in one deployable] |

### Topics and Ordering

| Topic | Partition key | Ordering guaranteed | Consumer groups | Retention |
|---|---|---|---|---|
| [topic name] | [the key, and what must stay in order] | [what order holds, and its limit] | [one per consuming service] | [period, and the replay reason if long] |

### Delivery and Idempotency

| Consumer | Dedup (key and store) | Retry and Backoff | Dead Letter Queue | Alert |
|---|---|---|---|---|
| [consuming service and topic] | [event id in a dedup table committed with the effect] | [transient errors only: attempts, backoff, jitter] | [DLQ name and who re-drives it] | [DLQ depth above zero; consumer lag] |

<!-- A lighter choice at a smaller profile is written in the row as "risk-accepted: <reason>". -->

### Open Questions

- [A decision still open, who answers it, and what it blocks.]
