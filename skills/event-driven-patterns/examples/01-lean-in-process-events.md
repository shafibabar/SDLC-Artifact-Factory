# Example 1 — Lean: A Broker the Product Doesn't Need

Self-contained. **BrewLog** is a web app for home brewers: log a batch, record gravity readings, get a reminder when a batch is ready to bottle. **Lean** profile, one modular monolith (Batches, Readings, Reminders modules), two developers, one PostgreSQL database. Reminders go out by email through an external provider.

## Input

> **User:** "Set up Redpanda with topics for every module, an outbox table and a dead-letter topic for each consumer, so we're event-driven from the start."

## Working it

- **Do the flows cross a process boundary?** `BatchStarted` and `ReadingRecorded` go from Batches and Readings to Reminders, all inside one deployable. An in-process publisher carries the same events with no topics, no relay and no operations (Vernon; Fairbanks: size to the risk). Not as asked: a broker, topics and dead-letter topics earn their cost when a flow leaves the deployable or a consumer needs history.
- **Classification:** async inside the process, eventual (a reminder is scheduled moments after the reading), choreographed: Reminders reacts, nobody holds the flow, two modules, no compensation.
- **Publication:** the reading and the "reminder due" row must not diverge if the process crashes, so the reminder instruction is written in the same transaction as the reading (an outbox row inside the one database). That is the Transactional Outbox applied locally; no broker is involved.
- **The email** is an external call made because of an event: recorded idempotently (dedupe on the event id), committed, then sent by a separate step with a timeout and an idempotency key (`integration-design` § 5). A failed send ends in a visible failed state that can be re-driven, so a separate dead-letter topic is not needed.
- **Topics, partition keys and delivery tables:** none; there is no broker. When a second deployable appears, this section grows. If the user then asks to scale a consumer with Competing Consumers on a topic and keep order: that is the queue model and loses order; a log scales with a consumer group keyed on what must stay in order (the batch id, never a tenant id, which BrewLog does not have), and the answer states both limits beside the key: group members beyond the partition count get no work, and one very busy batch stays on one partition, capping its throughput.

## Output: the section in `artifacts/brewlog/design/architecture/integration-design.md`

````markdown
## Event-Driven Pattern Decisions

- **Profile:** lean
- **Broker:** none: in-process events inside one deployable

### Flow Classification

| Flow | Communication | Consistency | Coordination | Why |
|---|---|---|---|---|
| Batches and Readings publish BatchStarted and ReadingRecorded; Reminders reacts | async | eventual | choreographed | Two modules, independent reaction, no compensation, no one needs a progress view; a broker is not needed inside one deployable |

### Publication

| Publisher | Mechanism | Why |
|---|---|---|
| Readings module | Transactional Outbox (an outbox row in the same database, same transaction) | The reminder instruction must be recorded atomically with the reading; no dual write |
| Batches module | in-process publisher | Both sides are in one deployable; nothing leaves the process |

### Open Questions

- When the Reminders module is split into its own service (not planned): then a broker, topics and a Dead Letter Queue are decided in this section; owner: the product owner, no date.
````

## Why this is the right size

The request would add a broker, three topics, a relay and dead-letter handling for two developers and one database. The section records the one decision that matters, atomic recording of the reminder with the reading, and the condition for growing it.
