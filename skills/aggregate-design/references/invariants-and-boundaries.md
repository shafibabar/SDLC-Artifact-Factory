# Invariants and Boundaries

The detail behind `SKILL.md` § 2–3: telling a True Invariant from a rule that only sounds urgent, deciding one Aggregate or two, and the two exceptions to Vernon's rules. Grounded in Evans (*Domain-Driven Design*, Ch. 6, 10) and Vernon (*Implementing Domain-Driven Design*, Ch. 10, "Effective Aggregate Design"), as summarised in `research/domain-driven-design/domain-driven-design-evans.md` and `research/domain-driven-design/implementing-ddd-vernon.md`.

## 1. The three-question test

Vernon's test is negative. The question is never "does this rule matter?" (almost every rule matters) but "would a brief window of staleness cause real harm?" State the candidate rule as **one sentence**, then answer in writing:

1. **Real harm:** would violating it, even for a moment, cause real business harm if left uncorrected? Not "would it look wrong": damage to the business, a customer, or a legal or compliance position.
2. **Fixable later:** can a violation be corrected after the fact by a reasonable compensating action (a reconciliation job, a human review, an apology and a refund) with no lasting harm?
3. **Enforced elsewhere:** is the rule already enforced by something else (an external system, a downstream approval, a database constraint on one record), so that this Aggregate enforcing it again adds nothing?

**Yes / No / No is the only result that earns a place inside a consistency boundary.** Any other result means the rule is handled outside the Aggregate: by eventual consistency (a Domain Event and an idempotent reaction), by a query at read time, by a Read Model field, or by trusting the system that already enforces it. Record rejected candidates with their answers: a visible rejection stops the next modeller re-adding the rule.

**A worked pair** (a library's lending context):
- "A member may not have more than five loans at once." Q1: no real harm if a sixth loan exists for a minute; Q2: yes, the desk can recall a book; → **rejected**, checked at the desk and reconciled nightly.
- "A copy may be on loan to only one member at a time." Q1: yes, two members are told they hold the same physical copy; Q2: no, one of them already left with it; Q3: no; → **True Invariant**, and it lives within one `Copy`, so the `Copy` Aggregate enforces it.

**Derived values are the commonest false invariant.** "The order's line count must always equal its lines", "the account's balance field must always equal its postings": each fails Q2 or Q3, because the value can be computed at query time or projected into a Read Model. A root field kept in lockstep with a child collection is a sign the boundary is wrong.

## 2. The consistency boundary is a transaction boundary

An invariant is only as real as the single transaction that checks and applies it. The boundary the test draws and the boundary the storage enforces **must coincide**: the check and the write happen in one transaction, guarded by the Aggregate's concurrency control. Checking in one transaction and writing in another reopens the race the check was meant to close.

This is why "check the other Aggregate first, then write mine" does not enforce a rule that spans two Aggregates. The other Aggregate can change between the read and the commit (write skew, `./sizing-and-concurrency.md` § 3). If such a rule passes the three-question test, the design has to choose openly: redraw the boundary so one Aggregate holds the rule, use a constraint the database checks directly, use serialisable isolation scoped to that rule, or take a documented exception (§ 4). Never present "checking first" as enforcement.

## 3. One Aggregate or two

For every candidate relationship, answer **two questions separately, in writing**:

- **Has-a:** does the Ubiquitous Language say one *has* or *contains* the other? A domain expert would say so unprompted.
- **Must be atomic:** is there a specific rule, passing the three-question test, that requires the two to change together in one transaction?

| Has-a | Must be atomic | Conclusion |
|---|---|---|
| Yes | No | **The has-a trap**, Vernon's named root cause of oversized Aggregates. Keep them separate, referenced by ID. The most common outcome. |
| No | No | Separate. |
| Either | Yes | A True Invariant spans them. Check the merged candidate against the three sizing angles (`./sizing-and-concurrency.md` § 1) before merging. |

If merging costs nothing on any sizing angle, merge. If any angle names a real cost: with low contention, the wider Aggregate may still be right as a documented Exception 1 (below); with high contention, keep them separate and enforce the rule another way (a constraint scoped to it, scoped serialisable isolation, or a smaller Aggregate cut along the rule itself). Vernon's own case is a `Product` that "contains" every `BacklogItem` and `Task`. Nothing requires adding a Task to be atomic with the rest of the backlog, so they become three Aggregates.

Two more signals of a wrong boundary:
- **The one-Aggregate-per-transaction count.** Count the Aggregate instances each use case changes in its transaction. More than one needs a written reason (§ 4) or a redesign.
- **A configuring concept folded into what it configures.** A pricing rule, a classification rule or a policy that governs many objects and changes on its own schedule is Evans's *Knowledge Level*. It gets its own Aggregate, and the governed object records which version applied (by ID), so an audit shows which rule produced which result.

## 4. When it is right to break the rules

Vernon is explicitly not absolutist: the rules are the default for the common case. There are exactly two named exceptions. Each must be **deliberate and written down**: which rule, which exception, and why.

- **Exception 1: a genuine cross-object invariant.** Eventual consistency for this rule would be a real defect, not an inconvenience. Vernon's example is a debit and its matching credit: a moment where one is posted and the other isn't is an accounting error. Accept the wider Aggregate (often better: model the entry that holds both postings as the Aggregate, rather than updating two accounts in one transaction).
- **Exception 2: a measured read bottleneck.** Measured, never hypothesised, data shows that looking another Aggregate up by ID is a real bottleneck on a read-heavy path. Keep a read-only, denormalised copy that is **never authoritative**; writes still go only through the owning Aggregate. Usually this is a Read Model (`read-model-design`).

An exception with no written reason against one of these two is not an exception. It is a boundary mistake.

## 5. Assertions: pre- and post-conditions per Command

Evans's *Assertion* states, for each operation, what must hold before it runs and what is guaranteed after it succeeds, in the Ubiquitous Language. It is sharper than a list of the Aggregate's invariants because it forces every mutating Command to be checked on its own. For each Command in the design, write: **requires** (the guard) and **guarantees** (the new state and the one Domain Event recorded). Two other senses of "assertion" in this plugin are different things: a test's expected-versus-actual check, and `secure-by-design`'s construction-time validity check on a Domain Primitive (a special case of Evans's sense, applied to construction).
