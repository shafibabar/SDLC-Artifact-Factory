# Saga Isolation: Anomalies and Countermeasures

Reference for `workflow-orchestration` step 8. A saga gives atomicity (by compensation), consistency and durability, but not **isolation**: each local transaction commits and is visible at once, so other requests can read or overwrite the mid-saga state before the flow completes or is compensated. Grounded in Richardson (countermeasures for the missing isolation) and Kleppmann (weak-isolation anomalies). Design level only; examples use a generic order, and the code is the `go-*` skills.

## The anomalies

- **Lost update.** A saga step reads a record; another request changes it; the saga's later step or compensation overwrites that change. Example: an order is mid-saga, a customer edits its delivery note, the saga fails, and the compensation restores the old record, discarding the edit.
- **Dirty read.** A reader sees a change a saga wrote but may still compensate. Example: a report counts an order as "paid" a moment before the saga fails and refunds it; the report stated something that never durably happened.
- **Fuzzy (non-repeatable) read.** A step reads the same record twice and sees different values because another saga committed in between, so one decision rests on two snapshots.

## The five countermeasures

| Countermeasure | One line | Reach for it when |
|---|---|---|
| **Semantic lock** | An application-level state marking a record as mid-saga | The default; name it first for any compensatable saga |
| **Commutative updates** | Design updates so order does not matter | The operations are naturally order-independent (add to a count, add to a set); a lost update disappears |
| **Pessimistic view** | Reorder steps so the riskiest exposure comes last | Two orderings are both correct and one closes a dirty-read window |
| **Reread value** | Re-read and confirm the record is unchanged before writing | Optimistic concurrency is acceptable and a lost update must be caught at write time |
| **By value** | Route each request down a strict or relaxed path by its business risk | Most requests tolerate eventual consistency, a few need strong isolation |

### Semantic lock

A **state** (for example `pending approval`) set by the saga's first compensatable step and cleared by a later retriable step or by a compensation. It does not block anyone the way a database lock does; it announces "mid-saga" and every reader and writer decides what to do: wait, fail fast, or proceed knowingly.

- **Design it per record:** name the state, which step sets it, which clears it, and on every path (success, compensation, expiry).
- **Teach every reader and writer** of the record to honour it: a report excludes locked records or labels them; a writer that must not collide is refused with a clear "locked by a running flow" answer.
- **Release a stale lock.** A saga that stops without clearing the lock needs a limit (the saga's longest allowed duration) and a sweeper or the timeout path to release it. A lock with no release rule is a defect.

### Commutative updates

Model the change as a delta, not an absolute set: add to a total, union into a set. Any order gives the same result, so concurrent sagas cannot overwrite each other. Use only where the business operation really is order-independent.

### Pessimistic view

Where steps can be reordered, commit the one that exposes the most damaging intermediate state last. Example: if a flow both makes an item visible to customers and runs an approval, run the approval first, so no unapproved item is ever visible. It costs a little parallelism and no locking.

### Reread value

Before a step writes, it re-reads the record's version and writes only if nothing changed since the saga first read it; otherwise the saga aborts and compensates instead of clobbering the other change. This specifically defeats the lost update.

### By value

Choose the mechanism by the request's risk. An ordinary request takes the standard eventual-consistency saga; a high-value or high-risk request takes a stricter path (a semantic lock held through the whole flow, or a synchronous check). The application pays the strict cost only where the value justifies it.

## Choosing

1. **Start with a semantic lock.** It applies to almost every compensatable saga.
2. Prefer **commutative updates** where the domain allows; they remove the anomaly by construction.
3. Add a **pessimistic view** where a reorder closes a window at no cost.
4. Add **reread value** where a lost update must be caught at write time.
5. Use **by value** where isolation strength should follow business risk.

**Review rule.** Each saga names, per record it exposes, the anomaly that is possible and the countermeasure that defends it (usually a semantic lock and its state). Exposed intermediate state with no countermeasure named, or one accepted explicitly as a risk with a reason, is the same severity as a missing compensation.
