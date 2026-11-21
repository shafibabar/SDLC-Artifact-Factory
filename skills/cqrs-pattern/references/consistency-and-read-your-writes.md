# Consistency on the Read Side

The detail behind `SKILL.md` § 4. Grounded in Kleppmann (*Designing Data-Intensive Applications*: replication lag and its anomalies, Ch. 5; consistency models, Ch. 9) and Khononov (*Learning Domain-Driven Design*: projections are derived and disposable), as summarised in `research/software-architecture/designing-data-intensive-applications-kleppmann.md`, `research/software-architecture/designing-data-intensive-applications-kleppmann-part2-consistency-consensus.md` and `research/domain-driven-design/learning-ddd-khononov.md`.

## 1. What each rung guarantees

- **Rung 1 (Simple Read Model):** a query reads the tables the Command just committed to. A reader sees every committed write. If the write tables are themselves read from replicas, the replica lag applies (see § 4).
- **Rung 2 (projections):** the view is **eventually consistent** with the write side. After a commit, the event travels through delivery to the projector, which updates the view. In normal running that takes milliseconds to seconds; during an outage or a rebuild it can take much longer.

Eventual consistency on its own promises neither how soon a change shows nor that the person who made it sees it; it only says the view catches up if writes stop. State the guarantee honestly in the decisions record. "Real-time" is not a guarantee; "updated within 5 seconds in normal running; shows a pending state meanwhile" is.

## 2. Staleness per view

For each projected view, record the lag the business accepts and why:

| View | Acceptable | Why |
|---|---|---|
| A public league table | a minute | nobody acts on it within seconds |
| A warehouse pick list | seconds | pickers act on it, and a stale item is a wasted trip, not a loss |
| A loyalty-points balance in a shopping app | seconds, with read-your-writes after the customer redeems | each redemption is checked by the Aggregate; the screen is information |
| Seats left, shown when choosing to book | seconds | the booking Command checks availability in the Aggregate; a stale count costs a retry, not a double booking |
| An approval screen whose "Approve" acts on the amount shown, with no version check | none | the person acts on the figure and no rule protects it: keep it on rung 1, or make the Command carry the version seen (`command-catalog`) |

The test is not "is the number important" but "does anyone act on it with no rule in the Aggregate behind them". Only such a view must stay on rung 1.

## 3. Read-your-writes

The person who just made a change must see it, even when others may lag. Without it, a user saves, the screen reloads from a view that has not caught up, and the change seems lost; they save again.

Ways to provide it, in order of preference:
1. **The Command returns the new version** (`command-catalog`: an acknowledgement and identifiers). The writer's screen shows the change as *pending* until the view reports that version.
2. **The writer's query waits** until the view has applied at least that version, with a short timeout, then falls back to pending.
3. **The writer's own reads go to the write side** for a short window after writing (rung 1 for that person only).

Record which one each projected context uses.

## 4. Monotonic reads and consistent prefix

Where a view (or the write tables on rung 1) is served from several replicas or regions:
- **Monotonic reads:** a reader must not see a newer state and then an older one because a second request hit a copy further behind. Pin a reader to one copy for a session, or compare the version they last saw.
- **Consistent prefix:** a reader must not see an effect before its cause (a reply before the question). Views fed from one Aggregate's ordered stream keep order; views combining several streams need to say what they do when one stream lags.

## 5. Why rules never read a view

A guard checked against a projection compares the Command with the past. Two Commands can both pass against the same stale view and break the rule together. Rules are checked inside the Aggregate against the state it loaded in the same transaction (`aggregate-design`). A view may be used to *show* a person likely options (seats that look free); the Aggregate still decides.

## 6. Views are disposable

A projected view is never the source of truth (Khononov). It can be dropped and rebuilt from the events (or the stream). A view that has drifted is rebuilt, never patched by hand. How rebuilds run is `read-model-design`'s.
