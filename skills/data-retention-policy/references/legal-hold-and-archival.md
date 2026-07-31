# Legal Hold and Archival

Two forces bend the retention schedule from opposite directions. A **legal hold**
suspends deletion *upward* — it keeps data past its window. **Archival** moves
data *sideways* — same window, cheaper storage. Both must be designed
deliberately, because both are routinely conflated with deletion and both fail
silently when they are.

---

## Part 1 — Legal Hold

### What a hold is

A legal hold is an **override** that suspends deletion of identified data. Data
under an active hold is **not deleted even when its retention window elapses**,
until the hold is explicitly lifted. It exists because destroying data that is
relevant to litigation, an investigation, or a regulatory request — even routine,
policy-compliant destruction — is **spoliation**, a serious offence with no undo.

GDPR itself carves out the space for holds: Art. 17(3)(e) says the right to
erasure does not apply where processing is necessary "for the establishment,
exercise or defence of legal claims." A hold is how the platform honours that
carve-out.

### Precedence — absolute ordering

```
legal hold  >  retention window  >  erasure request
```

- A hold **beats the retention window**: held data is not swept even when expired.
- A hold **beats an erasure request**: a subject's Art. 17 request does not
  override a lawful hold — the erasure of held artifacts is *deferred*, the
  deferral is recorded, and the requester is notified (see `deletion-mechanics.md`).

A purge job that does not check the hold before deleting is a **compliance defect
with no undo**. The hold check is part of every purge job's and every erasure
executor's contract from day one — never bolted on to a sweep written before
holds existed.

### Hold scope — found via lineage

A hold names a legal matter, but it must *reach* all the data relevant to that
matter — which is scattered across derived stores. Scope is resolved the same way
erasure scope is: forward-traverse `data-lineage-design` from the seed records to
find every derived artifact (entities, graph vertices, projections, reports), and
place a hold item on each.

```sql
CREATE TABLE legal_holds (
    id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id    uuid NOT NULL,
    matter       text NOT NULL,           -- the litigation / investigation reference
    placed_by    text NOT NULL,
    placed_at    timestamptz NOT NULL DEFAULT now(),
    released_by  text,
    released_at  timestamptz              -- NULL while the hold is ACTIVE
);

CREATE TABLE legal_hold_items (
    hold_id      uuid NOT NULL REFERENCES legal_holds(id),
    tenant_id    uuid NOT NULL,
    dataset      text NOT NULL,           -- which store/table
    ref          text NOT NULL,           -- the held row / vertex / doc id
    released_at  timestamptz,             -- mirrors the hold; NULL = still held
    PRIMARY KEY (hold_id, dataset, ref)
);
```

Every purge query joins against `legal_hold_items` with `released_at IS NULL` and
skips any matching row — the `NOT EXISTS (... released_at IS NULL)` clause shown
in `deletion-mechanics.md`.

### Hold lifecycle

| Stage | Action | Audit |
|---|---|---|
| **Place** | Resolve scope via lineage; insert `legal_holds` + `legal_hold_items` | Who placed it, matter, timestamp, count of items |
| **Active** | Every purge/erasure job skips held refs; new derived data within scope is added to the hold | — |
| **Lift** | Explicit, authorised action; set `released_at` on the hold and its items | Who lifted it, timestamp |
| **Post-lift** | Normal retention resumes; data now *past* its window becomes eligible on the next sweep | The subsequent deletion is audited normally |

**Lifting a hold does not delete anything** — it merely restores eligibility.
Data that expired *during* the hold is swept on the next run; data still within
its window continues under normal retention. The **hold reconciler** re-evaluates
eligibility whenever a hold is placed or lifted.

### Interaction with erasure requests

When an Art. 17 erasure request arrives for a subject whose data is under an
active hold, the erasure executor:

1. Erases every derived artifact *not* under hold immediately.
2. For held artifacts: **defers**, writes a deferral record, and notifies the
   requester that erasure is legally suspended pending the hold.
3. On hold lift, the deferred erasure is re-queued and completed.

This is the precedence rule made operational: the hold wins now, the erasure
completes later. Both events are audited.

---

## Part 2 — Archival vs Deletion

### The distinction the schedule must not blur

Reaching the end of an **access need** is not reaching the end of a **retention
need**. An audit-log entry from 100 days ago is almost never queried, yet it must
survive until its 7-year disposal date. That data is an **archival** candidate:
retain it, but on cheaper storage.

| | Archival | Deletion |
|---|---|---|
| Window | Unchanged — data is still retained | Window has elapsed |
| Purpose | Cost (FinOps) — retained data that's rarely accessed | Compliance / minimisation |
| Reversible | Yes — data is retrievable | No |
| Satisfies erasure? | **No** | Yes |

**Archival never shortens a window and never substitutes for deletion.**
Cold-tiering data past its access need does not satisfy an erasure obligation —
the window still governs, and the disposal date is still the disposal date.
Treating archival as disposal is an anti-pattern: the data is cheaper, not gone,
and still fully in scope for every regulation and every legal hold.

### Storage temperature — a FinOps tiering lever

This is the lever the *Fundamentals of Data Engineering* FinOps undercurrent
names: retained-but-rarely-accessed data (e.g. audit-log entries past 90 days but
short of their 7-year disposal date) belongs on a colder, cheaper tier. It is a
cost decision, **separate from and prior to** the eventual disposal decision this
policy already owns.

| Tier | Access pattern | Retrieval latency | Cost | Use for |
|---|---|---|---|---|
| **Hot** | Frequently queried | Milliseconds | Highest | Live data-asset records, recent audit logs (< 90 days), active projections |
| **Warm** | Occasionally queried | Seconds | Medium | Audit logs 90 days–1 year; compliance reports for the current audit cycle |
| **Cold / archive** | Rarely, compliance-driven | Minutes to hours | Lowest | Audit logs > 1 year but < 7-year disposal; superseded compliance reports |

For this repo's Postgres-centric stack, cold-tiering maps concretely to:

- **Partition-and-detach.** Time-partition high-volume append-only classes (audit
  log, telemetry) by month; detach aged partitions and move them to object
  storage (S3) for cheap retention, re-attachable if queried. Disposal at the
  window is then a partition drop, not a row-by-row delete.
- **Compressed columnar export.** Export aged audit ranges to Parquet on S3 for
  cheap long-term retention with occasional query via an external engine.

### The window interplay — one timeline, three events

A single class can have three distinct time triggers on one timeline; keep them
separate:

```
create ───────────► cold-tier trigger ───────────► disposal date ──────► [purge]
        (hot/warm)   (access need ends —           (retention window
                      FinOps move, still retained)   elapses — delete,
                                                      UNLESS a hold is active)
```

- The **cold-tier trigger** is a cost event: move to cheaper storage, still retained.
- The **disposal date** is a compliance event: the window elapsed, delete.
- A **legal hold** overrides the disposal date — held data stays, on whatever tier
  it's on, until the hold lifts.

Archival changes *where* data lives, never *whether* or *when* it is deleted.

### Retrieval SLA — state it

Cold storage trades retrieval speed for cost. If a regulator or an auditor can
demand archived audit logs, the policy must state the **retrieval SLA** (e.g.
"archived audit logs retrievable within 4 hours") so the tiering choice doesn't
silently break a compliance obligation to *produce* data on request. Cheaper
storage that can't meet a legal production deadline is a false economy.

---

## Artifact Fragments

```markdown
## Legal Hold
- Trigger: [litigation / investigation / regulatory request]
- Scope resolution: forward lineage traversal from [seed records]
- Mechanism: legal_hold_items checked (released_at IS NULL) by every purge/erasure job
- Precedence: legal hold > retention window > erasure request
- Lifecycle: place → active → lift (restores eligibility, deletes nothing)

## Archival Tiers
| Class | Cold-tier trigger | Tier target | Retrieval SLA | Disposal date (unchanged) |
|---|---|---|---|---|
```

---

## Cross-References

- The windows a hold overrides and archival preserves: `retention-schedule.md`
- Deferred-erasure mechanics when a hold blocks an Art. 17 request: `deletion-mechanics.md`
- Lineage traversal that resolves hold scope: `data-lineage-design`
