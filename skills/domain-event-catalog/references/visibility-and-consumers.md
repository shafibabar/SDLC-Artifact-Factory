# Visibility, Consumers and Retention Need

The detail behind `SKILL.md` § 4–5: which events leave the context, who reacts and how, and how long the business needs each event. Grounded in Khononov (internal versus published events), Vernon (*Implementing Domain-Driven Design*, Ch. 8, reliable publication and idempotent consumers), Richardson (*Microservices Patterns*, the Transactional Outbox) and Brandolini (policies), as summarised in `research/domain-driven-design/learning-ddd-khononov.md`, `research/domain-driven-design/implementing-ddd-vernon.md`, `research/software-architecture/microservices-patterns-richardson.md` and `research/domain-driven-design/introducing-eventstorming-brandolini.md`. How events are delivered (outbox, relay, Change Data Capture, Dead Letter Queue) is `event-driven-patterns`'; the code is `go-event-publisher` and `go-event-consumer`.

## 1. Visibility: internal, published or stored

| Visibility | What it is | Contract? |
|---|---|---|
| **Internal** | stays inside the context: an in-process reaction (Vernon's in-process publisher) or a step other contexts don't need | no; can change with the code |
| **Stored** | an event-sourced Aggregate's own event, replayed to rebuild its state (`aggregate-design`) | not to other contexts; changes by upcasting, never by edit (`event-schema-design`) |
| **Published** | a fact another context reacts to, sent through the Transactional Outbox | **yes**: changes only by `event-schema-design`'s protocol |

**Publish the business-meaningful fact, not every internal step** (Khononov). An event-sourced Aggregate's stream is as fine-grained as its own state needs. Other contexts get a coarser, translated event (`ClaimDecided` instead of `ClaimReviewStarted`, `ClaimNoteAdded` and `ClaimReviewCompleted`). Publishing the internal stream couples consumers to how this Aggregate happens to store itself. Record the translation in the catalog: which internal or stored events map to which published one, and which are never published.

A published event is a contract on the line between two contexts. The context map's pattern for that line (`context-map-patterns`) says what the contract obliges: consumer-driven contract tests for a Customer/Supplier consumer, versioned protocol discipline for an Open Host Service.

## 2. Consumers and policies

For each published event, list every known consumer and its reaction, written as Brandolini's policy: **"Whenever `PaymentOverdue`, then `SendReminder`."** The Command belongs to the consumer's context, not the producer's. A published event with no consumer yet is allowed: mark it "none yet", with the reason it is published.

What each consumer can rely on, and must cope with:
- **At least once** (Vernon): delivery is durable and may repeat. Every reaction is **idempotent**, keyed by the envelope's event ID within its source, or by a business key when the same fact can arrive under two IDs (during a dual-publish window, for instance).
- **Order only within one Aggregate.** Events for the same Aggregate arrive in order when the broker is partitioned by the Aggregate's ID. Nothing orders events across Aggregates; a consumer that needs a cause-and-effect chain follows `correlationid` and `causationid`.
- **What a stuck event does to order.** If a consumer parks an unprocessable event in a Dead Letter Queue, later events for that Aggregate can overtake it. Record per consumer whether it halts that Aggregate's partition until the event is fixed, or tolerates out-of-order replay.

**A correlation and causation chain:**
- `SubmitClaim` (Command `c1`) → `ClaimSubmitted` (`e1`): causationid `c1`, correlationid `c1`.
- A Policy in Assessment reacts and issues `AssignAssessor` → `AssessorAssigned` (`e2`): causationid `e1`, correlationid still `c1`.

The correlation ID stays fixed for the whole flow; the causation ID points at the immediate cause.

## 3. Retention need

The catalog records **why and for how long the business needs each event**, not the broker configuration. The schedule is `data-retention-policy`'s, and topic settings are platform work.

| Need | Typical answer | Example reason |
|---|---|---|
| Audit or legal evidence | kept long-term in an audit store, beyond the broker | the regulator asks for every decision for 7 years |
| Replay for consumers | broker retention long enough to rebuild a consumer or a Read Model | a new projection must be built from the last 90 days |
| Operational only | short broker retention | a reminder is useless after a week |

State the reason with each event. "Keep everything forever" is not a reason, and every retained copy of personal data is something that may have to be erased later.
