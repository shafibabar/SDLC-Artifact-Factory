---
name: message-broker-selection
description: >
  Decide whether a product needs a message broker at all and, if it does,
  which kind: in-process events inside one deployable at lean; then each
  messaging workload put through the replay question first (does any consumer
  need to re-read messages it has already processed?), so replay, audit and
  late-joining consumers point to a log-based broker (Kafka API, Redpanda) and
  consume-and-discard task dispatch to a queue broker (AMQP, RabbitMQ); the log
  and the queue never treated as swappable "message queues"; Competing
  Consumers kept as the queue model and a consumer group as the log model; one
  broker unless a workload genuinely answers the replay question differently;
  delivery mechanics per broker; the default Redpanda justified by the workload
  and overridable in sdlc-config; the choice recorded and given an ADR when it
  is costly to reverse. Use when a broker is chosen, questioned, swapped or
  added. Used by enterprise-architect.
version: 2.0.0
phase: design
owner: enterprise-architect
created: 2026-07-31
tags: [design, architecture, messaging, broker, log-based, queue-based, replay, consumer-group, competing-consumers]
produces: broker-selection-rationale
domain: architecture
status: stable
related: [event-driven-patterns, integration-design, workflow-orchestration, container-diagram, multi-tenancy-design, adr-authoring, sdlc-config-management, go-event-publisher, go-event-consumer, go-amqp-publisher, go-amqp-consumer, python-amqp-publisher, python-amqp-consumer, glossary-management, methodology-review]
sources:
  - research/software-architecture/rabbitmq-in-depth-roy.md
  - research/software-architecture/designing-data-intensive-applications-kleppmann.md
  - research/software-architecture/designing-data-intensive-applications-kleppmann-part2-consistency-consensus.md
  - research/domain-driven-design/implementing-ddd-vernon.md
  - research/software-architecture/fundamentals-of-software-architecture-richards-ford.md
  - research/software-architecture/building-microservices-newman.md
---

# Message Broker Selection

## Purpose

A broker chosen by habit gets the wrong model: a log where work is done the moment it is handled, or a queue where a new Read Model needs history that was never kept. This skill makes the broker a recorded decision per workload: is one needed, which model fits, and what would change the answer. **Readers:** enterprise-architect, backend-engineer, platform-engineer, the product owner (cost and risk of running one more system). **Question:** does this product need a broker, and does each messaging workload need to replay what it has already handled?

The output is a document, `artifacts/<product>/design/architecture/broker-selection.md` (`./templates/broker-selection-rationale.md`), with frontmatter. How events flow, are published and ordered is `event-driven-patterns`; the code is `go-event-publisher` / `go-event-consumer` (log) and `go-amqp-publisher` / `go-amqp-consumer` (queue), with Python equivalents.

| Profile | What this document holds |
|---|---|
| Lean | Normally not produced (the requirement is "skip"): one deployable, in-process events, no broker. Produce it only if a flow leaves the deployable, and then one broker, short |
| Standard | Optional: when a broker is chosen or the default questioned. The workloads, the replay answer for each, the broker, the delivery mapping |
| Enterprise | As standard, plus operations (hosting, owner, retention, recovery) and the revisit triggers |

## Procedure

1. **Read** the Event-Driven Pattern Decisions and the Integration Design (which flows cross a process boundary), the NFR specification (throughput, retention, loss tolerance, ordering), the container diagram, and `sdlc-config.json` (`message_broker`, stack, `scale_profile`, team skills, hosting).
2. **Ask first whether a broker is needed.** Flows inside one deployable use an in-process publisher; no broker. A broker earns its place when a flow crosses a process boundary, a consumer must catch up from history, or fan-out is wide. None of these: record "no broker" and stop.
3. **List the workloads** that need one (a Domain Event stream, a job dispatch, a notification fan-out). For each, answer the **replay question** (`./references/selection-criteria.md`): does any consumer need to re-read messages it has already processed (a new Read Model, a reindex, a bug-fix reprocessing, an audit, a consumer that joins later)?
4. **Map the answer to a model** (`./references/log-and-queue-models.md`): replay needed means a **log** (retained records, consumer-owned offsets, rewind); a consumed message that is genuinely done means a **queue** (removed on acknowledgement, routing by the broker). Never call the two interchangeable.
5. **Check the secondary criteria** only after the replay answer: order under parallelism, content-based routing, fair dispatch of uneven work, fan-out, throughput, operations and cost. They break a tie; they do not overturn a replay need.
6. **Choose one broker** unless two workloads answer the replay question differently and each reason is on record; a second system is a second thing to run, secure and watch (frugality). The default is the one in the tech-stack defaults (Redpanda, a log) and `sdlc-config.json` can override it; justify it by the workload, never by the product's industry.
7. **Name how work is shared:** a log scales with a **consumer group** (one partition per member, order kept within a partition, members beyond the partition count idle); a queue with **Competing Consumers** (order across the pool is lost by design). Keys and ordering limits are `event-driven-patterns`.
8. **Map delivery to the chosen broker** (`./references/delivery-and-retry-by-broker.md`): at-least-once on both, the acknowledgement or offset commit after the work is durable, retry and dead-lettering built the broker's way, an Idempotent Consumer on every consumer. The guarantees themselves are `event-driven-patterns`.
9. **Tenancy only if the product is multi-tenant:** isolation follows `multi-tenancy-design`; do not assume it.
10. **Record and gate.** A broker is costly to change and widely depended on, so write an ADR (`adr-authoring`) for the choice or for questioning the default. Add the revisit triggers.
11. **Validate, then loop.** Run `./scripts/validate-broker-selection.sh <file>`, fix every FAIL, re-run until clean; then `./resources/checklist.md`.
12. **Present** with the reason for every request declined (§ Gotchas). Always state seven things: a log and a queue are not interchangeable (a log keeps records and each consumer owns its offset and can rewind; a queue deletes a message once it is acknowledged), and putting an event stream on a queue loses replay and per-partition order under parallel consumption; RabbitMQ has a log-like stream type and a log can emulate a work queue, so check the specific broker's current features, but still decide on the replay question; both broker kinds deliver at-least-once, so every consumer is idempotent and effectively-once is the consumer's job (write the words "at-least-once"); Redpanda is only the plugin's default and `message_broker` in `sdlc-config.json` can override it, so a broker is justified by its workload; smart endpoints, dumb pipes (routing by topic or key only, business rules in the services); the choice is costly to reverse, so it earns an ADR that records the alternative rejected; and it is the enterprise-architect's decision, taken from the workload and not from cost alone or the product's industry (a cost concern is answered inside the chosen model first). Say in one line that this is a document at `design/architecture/broker-selection.md`, that it names no code, and that the code is the `go-*` / `python-*` skills. Answering in a reply: the declined requests and their reasons once, then the document once, without its YAML frontmatter block (added when the file is written): a reply carries no YAML, code or broker configuration.

Examples: `./examples/01-lean-no-broker.md` (a small tracker that asks for two brokers and needs none), `./examples/02-standard-log-for-events-queue-for-jobs.md` (domain events on a log and a render-job workload on a queue, with the reason for two), `./examples/03-enterprise-replay-for-a-new-read-model.md` (a requested swap to a queue declined because a new consumer must replay).

## Gotchas

- **"Install Kafka and RabbitMQ so we're ready for scale."** *Reason:* at lean, modules share one deployable; a broker is operations cost for no boundary, and a second broker doubles it. *Instead:* in-process events; name what would change it (a flow leaves the deployable, a consumer needs history).
- **"Swap Kafka for RabbitMQ; it's just a client change."** *Reason:* the models differ in what they keep. A queue drops a message once it is acknowledged, so replay, audit and a late-joining consumer are gone, and order under parallelism changes (Roy). *Instead:* decide on the replay question; if replay is needed, stay on the log.
- **"Rebuild the Read Model from last month's events" on a queue.** *Reason:* the queue did not keep them. *Instead:* a log with retention long enough for the rebuild, or a Read Model built another way (`cqrs-pattern`).
- **"Add Competing Consumers to the topic."** *Reason:* Competing Consumers is the queue model; on a log a pool racing for messages is not how it scales. *Instead:* a consumer group over partitions, keyed on what must stay in order, with the partition-count limit stated.
- **"RabbitMQ is easier, so use it for the Domain Event stream."** *Reason:* an event stream is read by several consumers now and later; ease of setup does not replace replay. *Instead:* the log for the event stream; a queue only for a workload that is done once handled.
- **"Use Redpanda because we are a compliance (or data) product."** *Reason:* the industry does not select the model; the workload does. *Instead:* say Redpanda is only the tech-stack default, overridable with `message_broker` in `sdlc-config.json`; justify using it by the replay answer, and record when it is not used.
- **"Every tenant needs its own cluster."** *Reason:* tenancy is not a plugin requirement, and isolation strength is a separate decision. *Instead:* mention tenancy only for a multi-tenant product, and follow `multi-tenancy-design`.
- **"Put the routing rules and filters in the broker."** *Reason:* business logic in the pipe is invisible to the services (Newman: smart endpoints, dumb pipes). *Instead:* routing by key or topic only; rules live in producers and consumers.
- **"The queue has streams, so models don't matter."** *Reason:* a stream type is log-like and a log can emulate a work queue, but each broker's default structure is built for one model. *Instead:* choose on the replay question, then check the broker's current features.

## References

| Question | File |
|---|---|
| How the log and the queue work, and what each keeps | `./references/log-and-queue-models.md` |
| The replay question, secondary criteria, operations and cost, revisiting, migration | `./references/selection-criteria.md` |
| Acknowledgement and offsets, retry and dead-lettering on each broker | `./references/delivery-and-retry-by-broker.md` |
| The artifact | `./templates/broker-selection-rationale.md` |
| Checking before hand-off | `./resources/checklist.md` |
