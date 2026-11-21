---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It asks the "do we need a broker at all?" question first and answers it: inside one deployable the modules can publish and consume events **in-process**, so the lean modular monolith needs **no broker**, and it recommends installing neither Kafka nor RabbitMQ now (`research/domain-driven-design/implementing-ddd-vernon.md`, Core Concepts, in-process publisher for one deployable; `discovery/fresh-eyes/wave-2-findings.md`, W2-30 and the `### message-broker-selection` section; D047-6).
2. It rejects installing both brokers "to be ready": a second (or first) system is a cost with no workload to justify it, and the choice is made later when a trigger appears. It names at least one concrete trigger that would reintroduce a broker (for example a module split into its own deployable, or a consumer that must re-read past messages) (`wave-2-findings.md`, W2-30; `research/software-architecture/fundamentals-of-software-architecture-richards-ford.md`, Core Concepts, trade-off analysis rather than "just in case"; CLAUDE.md, Budget and Frugality).
3. It says Redpanda is only the plugin's tech-stack **default**, overridable in `sdlc-config`, and is not a reason in itself: a broker is justified by the workload, not by what other companies use or by a default (`wave-2-findings.md`, W2-21 and W2-30; CLAUDE.md, Tech Stack Defaults).
4. It does not rank Kafka against RabbitMQ as "the better message queue". It says they are **not interchangeable**: a **log-based** broker (Kafka API, Redpanda) retains records and lets a consumer re-read them, a **queue** broker (AMQP, RabbitMQ) removes a message once acknowledged, and the choice turns on the **replay question** (does any consumer need to re-read messages already processed?) (`research/software-architecture/rabbitmq-in-depth-roy.md`, Core Concepts and Caveats; `research/software-architecture/designing-data-intensive-applications-kleppmann.md`, Core Concepts, log-based messaging; `wave-2-findings.md`, `### message-broker-selection`).
5. It says what to do about the in-process events so a later move is cheap: keep the modules talking only through published Domain Events behind one publisher, so a broker can replace the in-process publisher later (`implementing-ddd-vernon.md`, Core Concepts, in-process publisher; D047-6).
6. It does not introduce per-tenant brokers or tenant isolation, since the request describes a single company (D047-7).
7. The reply contains no code (no Go, JSON, proto, YAML, or broker configuration) (D047-10).
Fail if any of the 7 is missing.
