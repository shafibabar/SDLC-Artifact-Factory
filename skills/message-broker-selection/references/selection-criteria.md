# Selection Criteria

Reference for `message-broker-selection` steps 2, 3, 5, 6 and 10. Grounded in Roy (replay and retention as the primary axis), Vernon (the in-process publisher for events inside one deployable), Richards and Ford (broker and mediator topologies), Kleppmann (partitioned logs, why replay is a property of the log) and Newman (smart endpoints, dumb pipes).

## Step 1: is a broker needed at all?

A broker is a system to run, secure and watch. Skip it when every flow stays inside one deployable: an in-process publisher keeps the same events with no topics, relay or operations (Vernon). Where an event must leave the process atomically with a write, the Transactional Outbox still applies (`event-driven-patterns`).

A broker earns its place when:
- a flow crosses a **process boundary** (separately deployed services);
- a consumer must **catch up from history** (a new Read Model, a new consumer, a reindex, an audit);
- **fan-out is wide** and consumers come and go independently.

None applies: record "no broker, in-process events" with the condition that would change it.

## The replay question (the primary axis)

> Does any consumer need to re-read messages it has already processed: a new Read Model, a reindex, bug-fix reprocessing, an audit, event sourcing, or a consumer that joins later?

- **Yes, for any consumer:** a **log**. The deciding feature is retention plus consumer-owned offsets. This holds even if replay is only a likely future need, because a queue cannot add it afterwards.
- **No, a consumed message is genuinely done** (job dispatch, RPC-style work): a **queue** is a legitimate fit.

Answer it per workload, in writing. A Domain Event stream read by several contexts now and later is nearly always a log; a render or email job is nearly always done when handled. A workload that answers "no" today but whose business keeps the facts (an audit trail) answers "yes".

## Secondary criteria (tie-breakers after the replay answer)

| Need | Leans toward | Why |
|---|---|---|
| Order under parallelism (per Aggregate or account) | Log | Per-partition order with a consumer group |
| Content-based or per-recipient routing chosen by the broker | Queue | Exchanges and bindings route without caller addressing |
| Fair dispatch of long, uneven jobs across a pool | Queue | Prefetch keeps a slow handler from hoarding |
| Several independent consumers of one stream | Log | Each group reads at its own pace |
| Delayed retry without modelling retry topics yourself | Queue | Dead-letter plus time-to-live topology |
| Compaction (keep the latest value per key) for a changelog | Log | A log feature |
| Per-message time-to-live or priority | Queue | Queue features |
| High sustained throughput of small records | Log | Sequential append and partitioned reads |

They tip a close call. They never overturn a replay need.

## Operations, cost and fit

Weigh these in writing; they are real constraints, not footnotes.
- **Hosting:** self-run or managed; who is on call; the team's existing skill. The frugality rule prefers open source and fewer systems.
- **One broker by default.** Two brokers are justified only when two workloads answer the replay question differently, and each reason is on the record; a second system is double the operations.
- **Protocol and default:** the plugin's default is a Kafka-API log (Redpanda), set in the tech-stack defaults and overridable with `message_broker` in `sdlc-config.json`. Justify using the default by the workload (replay, order, fan-out), not by the product's industry; record when the default is not used and why.
- **Retention is a cost:** state the period and the reason (a rebuild window, an audit period).
- **Smart endpoints, dumb pipes:** no business rules or filters in the broker; routing by topic or key only (Newman).

## Coexistence and migration

- **Two brokers by design** is valid when the workloads differ (events on a log, jobs on a queue). Record each broker with its replay answer so it is deliberate and reviewable.
- **A queue workload that later needs replay:** do not silently swap clients. Add a log topic for the event that now needs retention, bridge or dual-publish during a transition, move consumers to the log from the start of what is retained, then retire the queue.
- **Log to queue** is rarely warranted: it discards retention already paid for. Do it only to hand a *derived* transient task to a work pool, keeping the source log.

## When to revisit

Reopen the decision when a new consumer needs history a queue never kept; a dispatch workload starts to be replayed for audit; order under parallelism becomes a requirement; routing needs outgrow partition keys; a flow leaves (or joins) the one deployable; or operations cost or team skill changes. Each means the workload's replay or order shape changed: walk the questions again.

## When the decision earns an ADR

Choosing a broker, or questioning the default, is costly to reverse and widely depended on, so it is an ADR (`adr-authoring`): the workloads, the replay answers, the alternatives rejected and the trade-off accepted. Keep the document and the ADR consistent; the document is the working view, the ADR the decision of record.
