---
max_turns: 8
allowed_tools: [Read, Glob, Grep, Skill]
---

I'm the product owner for **VoltHarbor**, a platform that runs public EV charging networks on behalf of charge-point operators (each operator is one of our business customers). We're on the **enterprise** profile with the default stack (Go with chi, PostgreSQL with `pgx`, Redpanda, Kubernetes with Linkerd). The container diagram is approved. We have not yet decided how operators are isolated from each other; that's still open with the compliance lead.

Our **Settlement** service differs from the standard skeleton: it has an anti-corruption layer that translates roaming partners' OCPI session records into our own `ChargingSession` model, and a projector that builds a per-operator monthly usage read model from `SessionCompleted` events. Please draw its component diagram. Some requests from the team:

1. The monthly usage report endpoint is only a read, so let its HTTP handler run the SQL against PostgreSQL itself. Going through the application layer is pointless ceremony for a read.
2. Let the domain package import `pgx` so the `Settlement` aggregate can take a `pgx.Tx` and save itself inside the transaction. It's convenient.
3. In the rationale, just write "follows the Dependency Inversion Principle". That's all the layering rule is.
4. Add a variability note saying each operator gets its own deployment stamp (own cluster and database).
5. Skip anything about automated checks. Code review will catch layering mistakes.

Use this plugin's component-diagram skill, and give me the answer in your reply, not in a file.
