# Projections and Rebuilds

The detail behind `SKILL.md` § 3, for Read Models that `cqrs-decisions.md` puts on projections. Self-contained. Grounded in Khononov (*Learning Domain-Driven Design*: projections, like snapshots, are derived and disposable), Young (*Versioning in an Event Sourced System*: a replay meets every historical event type), Richardson (*Microservices Patterns*: Transactional Outbox, CQRS views across services) and Campbell (*Designing Backend Systems in Go*: cache-aside), as summarised in `research/domain-driven-design/learning-ddd-khononov.md`, `research/domain-driven-design/versioning-event-sourced-system-young.md`, `research/software-architecture/microservices-patterns-richardson.md` and `research/software-architecture/designing-backend-systems-go-campbell.md`. No code: projector code is `go-event-consumer`'s (`references/projector-sketches.md`).

A **projector** reads events and writes one Read Model. It is the only thing that writes it.

## 1. Three mechanics

| | From published events | In the write transaction | Change data capture |
|---|---|---|---|
| How | a consumer reads the Domain Events the Transactional Outbox publishes | the view is updated in the same transaction as the Aggregate and outbox rows | a connector reads the write database's change log and publishes row changes |
| Consistency | eventual: delivery lag, usually milliseconds to seconds, much longer in an outage | immediate | eventual |
| Cost to writes | none | every write pays for every such view | none |
| Payload speaks | the business language of the event | — | the write tables' columns: a table change changes the feed |
| Rebuilt from | the stored events | the write tables (no event history is involved) | a fresh snapshot of the tables plus the log |
| Use when | the usual choice for a projected view | one cheap summary inside one service where lag is unacceptable and writes are light | the write side publishes no events (a legacy schema) and adding an outbox is impractical |

Record the mechanic per Read Model. A view updated in the write transaction is still not something rules check, and it is still written only by its projection step, never by Command handlers directly.

## 2. Applying events safely

Every mechanic delivers **at least once**: a relay retries, a consumer restarts from its last position, partitions are reassigned. So:

| Guard | Use when | Note |
|---|---|---|
| **Apply only if newer:** the row stores the version (or sequence) of the last event applied; an event with a lower or equal version is a no-op | the row is keyed on one Aggregate's identity and events carry its version | handles duplicates and out-of-order arrival in one step |
| **Processed-event record:** the event ID is recorded in the same transaction as the view change; a recorded ID is skipped | deletes, one event touching many rows (a rename re-projecting every row that copied the name), summaries that add to a running total | without it, a duplicate `MealOrdered` adds to the day's count twice |

- **Position with the write.** The projector's consumer position is saved in the same transaction as the view change. A crash between the two then means reprocessing (which the guards absorb), never a skipped event (permanent drift).
- **Ordering.** Events of one Aggregate arrive in order when they are partitioned by its identity. A view combining several Aggregates or contexts must say what it shows while one stream lags (an order for a dish not yet on the menu: hold it, or show it with a placeholder).
- **Unknown types are ignored; known old types are not** (§ 5).
- **Projectors only write their view.** No Commands, no published events, no emails: a rebuild replays everything, and every side effect would fire again. A reaction to an event is a Policy on the write side (`domain-event-catalog`).

## 3. Where a projection lives

| Store | When |
|---|---|
| Tables in the context's own database | the default |
| A search index | the query is full-text or faceted search |
| A cache in front of a view (cache-aside) | a read-heavy view where even the view's own query is too costly; the time-to-live (or invalidation) must be no longer than the staleness the decision accepts (Campbell) |
| A separate read database | the read load or shape needs a different store, named in `cqrs-decisions.md` |

A cache is never the Read Model itself: on a miss it falls through to the view, and a cold or flushed cache must give the same answers, just slower. Store choice in detail is `data-model-design`'s.

## 4. Rebuilds

A projection is disposable (Khononov): it can always be dropped and rebuilt from its events. Rebuild when the projector's logic changes, a new Read Model is added over old history, or the view has drifted.

**Procedure (no downtime):**
1. Create a copy of the view's storage beside the live one (a second table, a new index).
2. Run the fixed projector into the copy from the first event (or from a snapshot the events since then can be applied to).
3. Watch it catch up: compare its position with the live projector's.
4. When it is within the accepted staleness, switch readers to it in one step (rename in one transaction; move the index alias).
5. Keep the old copy until the switch is confirmed, then drop it.

Never truncate the live view and replay into it: readers see an empty or half-built view for the whole replay. Never patch rows by hand: the next replay brings the error back, and the projector bug that caused it stays.

**Rebuild source.** Name where the full history comes from. A broker topic keeps events only for its retention window; a rebuild from it recovers only that window. Full history lives in an event store (event-sourced contexts), a compacted topic for current-state views, or an outbox archive. If none exists, say what a rebuild cannot recover and raise it as an open question.

**Rebuild time.** Estimate it (events × apply rate). If it is longer than the business can wait for a fix, plan snapshots or a partial rebuild (one tenant, one region).

## 5. Replaying old event types

A replay from the start meets **every event type ever stored**, not just today's (Young). An event type that was replaced by a new one (a breaking change is a new type: `event-schema-design`, D047-1) is not "unknown":
- keep its handler in the projector, or
- read old events through the upcaster that turns them into the current type.

Skipping it silently drops everything that happened before the change. Keep sample events of every historical type as test fixtures, so a projector change that breaks a replay is caught before a rebuild. Only a type the projector has never subscribed to (a future addition, another Aggregate's event on the same stream) is ignored without error (Tolerant Reader).

## 6. Event-sourced contexts and cross-service views

- **Event-sourced Aggregates** (`aggregate-design` § 6): the event stream is the record, so every query is a projection and the rebuild source is the stream itself. Internal events used to rebuild the Aggregate may be finer than the published ones; a view inside the context may read internal events, a view in another context reads only published ones.
- **Cross-service CQRS views** (Richardson): fed by the other services' published events through their outbox, never their tables. The projector translates their terms into this context's language. Their changes reach the view through `event-schema-design`'s compatibility rules, and a new event type from them needs a handler here before they retire the old one.
