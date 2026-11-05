# Sizing, Identity and Concurrency

The detail behind `SKILL.md` § 4–5: how big an Aggregate should be, how its identity is generated, and how concurrent writes are handled. Grounded in Vernon (*Implementing Domain-Driven Design*, Ch. 5, 10), Khononov (*Learning Domain-Driven Design*, coupling and cohesion) and Kleppmann (*Designing Data-Intensive Applications*, Ch. 7, isolation anomalies), as summarised in `research/domain-driven-design/implementing-ddd-vernon.md`, `research/domain-driven-design/learning-ddd-khononov.md` and `research/software-architecture/designing-data-intensive-applications-kleppmann-part2-consistency-consensus.md`. Stack-neutral: the code is `go-domain-model` and `go-repository-pattern`.

## 1. Three sizing angles, kept separate

Vernon argues "design small Aggregates" from three angles. Check each on its own: a design can fail one and pass two.

- **Performance.** Loading an Aggregate loads its whole graph. A Command that touches only the root still pays for every child it never reads.
- **Scalability.** Contention is per instance. A large Aggregate concentrates many writers on one version number, serialising writes that could have run in parallel.
- **Collaboration.** Unrelated, legitimate actions collide because they share one Aggregate: a receptionist editing a guest's notes and the booking engine confirming a stay should not conflict. The database isn't slow; the design makes two people fight over one lock.

Khononov's framing makes the trade explicit: a bigger boundary buys **cohesion** (more rules enforced by one transaction) at the cost of **coupling** (every operation on any part contends with every other). Write both lists for each Aggregate: the rules its size buys, and the independent operations it forces to contend. A boundary that cannot name a real cohesion benefit against its coupling cost is a default nobody examined.

## 2. Unbounded collections

Referencing children by ID does not make an Aggregate safe if the root loads every ID "for convenience". Vernon's `Product` that loads all its `BacklogItem` IDs just to answer "does it have any?" is the same oversizing mistake in another form. A root with a collection that grows without limit (all bookings of a room, all orders of a customer, all postings of an account) is a scaling hazard however it references them. Answer such questions with a query or a Read Model. If a valid instance cannot be built or loaded without a large graph, the boundary or the loading strategy is wrong (Vernon's testability signal).

## 3. Write skew: why a version number isn't enough

Kleppmann's isolation anomalies. A version check on an Aggregate's own row (optimistic concurrency) prevents **lost update**: two writers overwriting the same row. It does **nothing** about **write skew**: two transactions each read a consistent snapshot, each checks a rule against what it read, each writes a *different* row, and the rule is broken once both commit.

A timeline (a clinic's rota rule: "at least one doctor is on call"):

```
Doctor A's request: reads "B is on call"  → takes A off call → version check on A's row passes → commits
Doctor B's request: reads "A is on call"  → takes B off call → version check on B's row passes → commits
Result: nobody on call. Each version check matched the row it wrote; no row's version ever conflicted.
```

Snapshot isolation (PostgreSQL's `REPEATABLE READ`) doesn't prevent it either; only serialisable isolation does. A rule that spans rows of different Aggregates needs one of: a boundary redrawn so one Aggregate holds the rule, a constraint the database checks directly (a uniqueness or exclusion constraint), serialisable isolation scoped to the statements of that rule, or acceptance of eventual consistency with a compensating action. "Add more version columns" is never the fix.

## 4. Choosing a concurrency strategy

```
Does the rule live inside one Aggregate's boundary?
├─ Yes
│   ├─ Interactive request, low contention per instance, retry is cheap → OPTIMISTIC (default):
│   │    a version check; on conflict, retry a few times with backoff, then tell the user.
│   ├─ Interactive, but a hot instance or an expensive retry → PESSIMISTIC, as a documented
│   │    exception naming the condition (hot row, costly retry). Lock only inside one transaction.
│   └─ Batch job, rows processed one at a time, nobody waiting → PESSIMISTIC is simpler; optimistic
│        is also fine if the job already retries idempotently.
└─ No (spans Aggregates; only after the three-question test and a written exception)
    ├─ A short, reconciled staleness window is acceptable → it isn't a True Invariant; re-run
    │    the test. Eventual consistency, no special mechanism.
    └─ Zero tolerance (Exception 1 class) → SERIALISABLE isolation scoped to that rule's
         statements, or a database constraint that expresses it. Never the whole service.
```

**Retries as a signal.** Occasional conflicts mean the mechanism works. Conflicts on a meaningful share of ordinary writes mean the boundary is wrong: it is the collaboration angle showing up in production. Re-size the Aggregate; a bigger retry budget only hides the problem until it becomes a throughput ceiling. Track the conflict rate per Aggregate type.

## 5. Identity generation

Vernon's order of preference, recorded per Aggregate root:

1. **Client-generated (default):** an opaque identifier (a UUID) assigned by the application before any write. A complete, valid instance exists before it is stored, so its creation event can carry its identity and a unit test needs no database.
2. **A business-meaningful identifier** (a case number a regulator quotes, an invoice number): reserved through the Repository (`nextIdentity`) before construction. The constructor still receives a ready-made identity.
3. **Storage-generated** (a database sequence assigned on insert): disfavoured. The instance has no identity until it is stored, so its creation event can't carry one. Use only with a written reason, such as a legacy system that expects sequential numbers.

Child Entities inside an Aggregate need only **local** identity, unique within their root (`./building-blocks.md` § 3).
