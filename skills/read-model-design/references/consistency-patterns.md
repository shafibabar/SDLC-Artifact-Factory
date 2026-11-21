# Freshness and Read-Your-Writes for One Read Model

The detail behind `SKILL.md` § 3 step 4. Self-contained. `cqrs-pattern` decides **which** staleness and guarantees each projected view gets (`references/consistency-and-read-your-writes.md` there); this file is how a Read Model's design carries them out. Grounded in Kleppmann (*Designing Data-Intensive Applications*: replication lag and its three anomalies, Ch. 5; eventual consistency as a weak guarantee, Ch. 9), as summarised in `research/software-architecture/designing-data-intensive-applications-kleppmann.md` and `research/software-architecture/designing-data-intensive-applications-kleppmann-part2-consistency-consensus.md`. No code: see `go-repository-pattern` (`references/read-model-query-sketches.md`).

Rung-1 Read Models read the write tables and are immediately consistent; this file applies to them only if the write tables are read from replicas (§ 4).

## 1. The version on every row

Every row of a projected Read Model carries the **version of the Aggregate** whose event it last applied: the Aggregate's own optimistic-concurrency counter, carried in each event, not a counter of the view's own. It does three jobs:
- the "apply only if newer" guard (`./projection-mechanics.md` § 2);
- read-your-writes (§ 2): the writer compares it with the version their Command returned;
- monotonic reads across copies (§ 4).

A row combining several Aggregates (a prep sheet counting orders under dish names) carries the version of each source it holds, or the event position, and the design says which one the writer compares.

## 2. Read-your-writes

Eventual consistency alone promises nothing a person can rely on (Kleppmann): not how soon a change appears, nor that the person who made it sees it. A writer who saves, reloads and sees the old value saves again.

Apply the method `cqrs-decisions.md` chose; the usual one:
1. The Command returns an acknowledgement with the new version (`command-catalog`), never the updated view.
2. The writer's screen shows the change as *pending* until the Read Model row reports at least that version, or waits briefly for it, then falls back to pending.
3. Other readers simply see the view as it is.

Never fix it by having the Command write the view, or by reading the Aggregate for the view: the first makes the view unrebuildable, the second puts query load on the write side.

## 3. Showing how fresh it is

- **Summaries carry an *as of* time** (the time of the last event applied) and the caller shows it. A dashboard that cannot say how old it is is trusted until the first outage: "no overdue invoices" and "projector stopped six hours ago" look the same.
- **A lag alert** fires when the view falls behind by more than a threshold below the staleness accepted (accepted 1 minute → alert at 30 seconds), so operations know before users do. Per-region views alert per region.
- **Accepted staleness is stated in normal running and in a rebuild.** "Within 5 seconds normally; during a rebuild the old copy keeps serving" is a guarantee; "real-time" is not.

## 4. Kleppmann's three anomalies, per view

| Anomaly | On a Read Model | What the design says |
|---|---|---|
| **Read-your-writes** | the writer queries before the projector applied their event | the method in § 2 |
| **Monotonic reads** | a reader refreshes, hits a copy further behind (another replica, another region) and sees an older state | pin a reader to one copy for a session, or the client ignores a response with a lower version or older *as of* than one it has already shown |
| **Consistent prefix** | an effect shows before its cause (a change to an order the view has not seen placed) | events of one Aggregate arrive in order when partitioned by its identity; a view combining streams says how it holds or shows an effect whose cause hasn't arrived |

## 5. When nobody may see a stale value

If a person acts on a value with no rule in the Aggregate behind the action, that view should not be projected at all; `cqrs-pattern` keeps it on rung 1. If, while designing, you find such a view on projections, send it back to enterprise-architect rather than designing around it. Audit and compliance questions ("what exactly did the record say at the time") are answered from the record itself (the event stream, or an audit log the write side keeps), not from a view that may lag or be mid-rebuild.
