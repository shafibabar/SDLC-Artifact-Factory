# Saga Isolation Countermeasures — Anomalies and Their Defences

Reference for `workflow-orchestration`. A Saga gives **ACD** — atomicity (via compensation), consistency, durability — but **not I (isolation)**. Because each local transaction commits and is immediately visible, other transactions can read and act on the intermediate, mid-Saga state before the whole flow completes (or before a compensation unwinds it). This file catalogues the three anomalies that lack-of-isolation produces and the **five countermeasures** Richardson (*Microservices Patterns*, Ch. 4) prescribes, grounded in this repo's DataAsset / compliance domain with Go + SQL sketches. This is the biggest genuine gap in the repo's existing Saga material.

---

## 1. The anomalies

The absence of isolation reproduces the classic read-phenomena of weak database isolation levels, but now **across services** and across the whole Saga's duration (which may be seconds, or — for a human-approval flow — hours).

### Lost update
Saga A reads a record, and Saga B (or a plain request) overwrites that record before Saga A commits its own later step — then Saga A's compensation or continuation clobbers B's write. Example: onboarding Saga A registers a DataAsset and is mid-flight; a tenant admin concurrently edits the asset's retention label; Saga A fails and its `MarkDataAssetAbandoned` compensation overwrites the record, silently discarding the admin's edit. The admin's update is **lost**.

### Dirty read
A transaction reads state that a Saga wrote but has not yet "confirmed" (a step that may still be compensated). Example: the compliance dashboard reads a DataAsset that step 3 has just labelled `SENSITIVE`, and reports it — but the Saga then fails at step 3's reply and compensates, detaching the label. The dashboard reported a fact that **never durably happened**.

### Fuzzy / non-repeatable read
One Saga reads the same record twice and sees different values because another Saga's step committed in between. Example: a compliance-check step reads a DataAsset's classification at the start of its evaluation and again at the end; a concurrent reclassification Saga changes it mid-evaluation, so the check reasons over **two inconsistent snapshots**.

---

## 2. The five countermeasures

| Countermeasure | One line | Reach for it when |
|---|---|---|
| **Semantic lock** | Application-level flag marking a record as mid-Saga | The primary, default defence — almost every compensatable Saga uses one |
| **Commutative updates** | Design updates so order does not matter | Updates are naturally order-independent (increments, set-union) → lost update disappears |
| **Pessimistic view** | Reorder Saga steps so the step most at risk runs last | Reordering is possible and eliminates a dirty-read window cheaply |
| **Reread value** | Re-read and verify a record is unchanged before writing | Optimistic concurrency is acceptable and you must catch a lost update at write time |
| **By-value** | Route each request down a strict or relaxed path by its business risk | Some requests need strong isolation and most do not — pick per request |

### Semantic lock — the primary defence
An application-level lock: a **state flag** set by the **first compensatable** step and cleared by a **later retriable** step (or by a compensation). It does *not* block other transactions the way a database lock would — instead it advertises "this record is mid-Saga; treat it with care," and concurrent transactions decide how to react (wait, fail fast, or proceed knowingly).

For the DataAsset onboarding Saga, the lock is the `ONBOARDING_PENDING` state set by `RegisterDataAsset` and cleared to `ACTIVE` by the final `IndexDataAsset` step (or to `ABANDONED` by compensation).

```sql
-- Set by the first compensatable step, in its local transaction.
UPDATE data_asset
   SET state = 'ONBOARDING_PENDING', locked_by_saga = $1, updated_at = now()
 WHERE id = $2 AND state = 'NEW';   -- guard: only lock a NEW asset
```

Concurrent actors consult the flag. A reader that must not see mid-Saga assets filters them out:

```sql
-- Compliance dashboard: never report an asset still mid-onboarding.
SELECT * FROM data_asset
 WHERE tenant_id = $1 AND state NOT IN ('ONBOARDING_PENDING', 'ABANDONED');
```

A writer that must not collide fails fast (or waits and retries):

```go
tag, err := tx.Exec(ctx,
	`UPDATE data_asset SET retention_label = $1
	   WHERE id = $2 AND locked_by_saga IS NULL`, label, assetID)
if err == nil && tag.RowsAffected() == 0 {
	return ErrAssetLockedBySaga // record is mid-Saga; caller retries later
}
```

The semantic lock converts a silent lost update / dirty read into an **explicit, handled** condition. Its cost: every reader/writer of the record must be taught to honour the flag, and a Saga that crashes without clearing the lock needs a timeout/sweeper to release stale locks (bound the lock with the Saga's max duration and reap expired `locked_by_saga` rows).

### Commutative updates
If the operations a record undergoes are **commutative** — order-independent — then a lost update cannot occur, because applying them in any order yields the same result. Model the update as a **delta**, not an absolute set. A running byte-count on a scan, or membership in a label set, are commutative:

```sql
-- Commutative: two concurrent Sagas both adding to a set never lose each other's write.
UPDATE data_asset
   SET sensitivity_labels = sensitivity_labels || $1::text[]   -- array/set union
 WHERE id = $2;
-- vs. the NON-commutative, lost-update-prone form:  SET sensitivity_labels = $1
```

Use when the domain operation is genuinely additive/idempotent; it removes the anomaly by construction rather than by locking.

### Pessimistic view
**Reorder the Saga's steps** so the step that would expose the most damaging intermediate state runs **as late as possible** — shrinking or eliminating the dirty-read window. Where two orderings are both correct, choose the one that commits the risky, externally-visible change last (nearest the pivot / retriable tail). Example: if onboarding both (a) marks an asset visible in search and (b) runs the compliance authorization, order compliance *before* visibility so no un-vetted asset is ever readable — the pessimistic ordering trades a little parallelism for a closed dirty-read window at zero locking cost.

### Reread value
An optimistic-concurrency check: before a step writes a record, it **re-reads** the record and verifies it has not changed since the value the Saga first read; if it has, the Saga aborts (and compensates) rather than clobbering the concurrent write. Implement with a version column:

```go
// Step read the asset at version v0 earlier. Before writing, confirm unchanged.
tag, _ := tx.Exec(ctx,
	`UPDATE data_asset SET classification = $1, version = version + 1
	   WHERE id = $2 AND version = $3`, cls, assetID, v0)
if tag.RowsAffected() == 0 {
	return ErrConcurrentModification // someone wrote since v0 → abort & compensate
}
```

This specifically defeats the **lost update**: the write only lands if nobody has touched the row since the Saga read it.

### By-value
A **dispatching** strategy: choose the concurrency mechanism per request based on the request's **business risk / value**. Low-risk requests take the fast Saga path (accepting eventual consistency); high-risk requests are routed to a stricter path — a fully orchestrated Saga with semantic locks, or even a synchronous, more-isolated handling. Example: onboarding an ordinary document asset uses the standard eventual-consistency Saga; onboarding an asset a pre-scan flags as likely containing regulated PII is routed `by-value` to a stricter path that holds a semantic lock through the entire flow and blocks all concurrent access until compliance authorizes it. The application picks the countermeasure strength from the data's value, rather than paying the strict cost uniformly.

---

## 3. Choosing among them

1. **Start with a semantic lock** — it is the general, always-applicable defence and the one to name first for any compensatable Saga.
2. **Prefer commutative updates** where the domain operation is naturally order-independent — it removes the anomaly for free, no lock to honour.
3. **Add a pessimistic-view reordering** when steps can be reordered to close a dirty-read window at no locking cost.
4. **Add reread-value** where you run optimistic concurrency and must catch a lost update exactly at write time.
5. **Use by-value** when isolation strength should track business risk and paying the strict cost on every request is wasteful.

Design rule for review: **each Saga must name, per record it exposes, which anomaly is possible and which countermeasure (usually the semantic lock and its state) defends it.** A compensatable Saga whose intermediate state is readable with *no* countermeasure named is an incomplete design — the same severity as a missing compensation.
