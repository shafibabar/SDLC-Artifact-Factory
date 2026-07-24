# Invariants and Consistency Boundaries

Self-contained — loadable without reading `SKILL.md` first.

A **Consistency Boundary** is Vernon's precise name for the exact scope within which a True Invariant is atomically enforced — narrower than "Aggregate" as a bare structural term, because the boundary is defined *by the invariant*, not the other way around. This file exists to answer one question with real precision: how do you tell a rule that genuinely needs that boundary apart from a rule that merely *sounds* urgent? Getting this wrong in either direction is expensive — too permissive, and you build an Aggregate that can't actually enforce its own rules; too eager, and you build (per `references/sizing-contention-and-concurrency.md`) an oversized Aggregate that contends with itself for no reason.

---

## What Vernon's Three-Question Test Actually Tests

Vernon's diagnostic move is a *negative* test, not a positive one. The question is never "does this rule matter?" — almost every business rule matters. The question is whether a **brief window of staleness would cause the business real harm**, not whether it would be surprising or inconvenient. Apply all three questions, in writing, to every candidate rule before drawing a boundary around it:

1. **Would violating this rule, even momentarily, cause real business harm if left uncorrected?** Not "would it look wrong" — would it actually damage the business, a customer, or a compliance posture.
2. **Does correcting a violation after the fact require anything more than a reasonable compensating action a human or process could perform?** If a background job, a reconciliation pass, or a human review can fix it after the fact with no lasting harm, the rule tolerates staleness.
3. **Is the rule already enforced by an external system**, such that the Aggregate re-enforcing it atomically is redundant? (A payment gateway that already rejects an invalid charge, a downstream approval step that already gates a transition.)

**A "yes / no / no" is the only combination that earns a place inside a single consistency boundary.** Any other combination — a "no" to (1), or a "yes" to either (2) or (3) — means the rule can and should be handled outside the Aggregate: by eventual consistency (Rule 4), by a read-only projection, or by trusting the external system that already enforces it. This is a checklist to run explicitly, per candidate rule, not a feeling to trust:

- [ ] Q1 — real harm from momentary violation? **(must be YES)**
- [ ] Q2 — correction needs more than a reasonable compensating action? **(must be NO)**
- [ ] Q3 — already enforced by an external system? **(must be NO)**
- [ ] All three answered in writing, against this specific rule, not "these objects seem related"

---

## A Correctly Identified True Invariant, Worked

This skill's own canonical example: **"A `DataAsset` may only be marked `Restricted` if its `StorageSource` is confirmed active."** Run the test explicitly rather than taking the correctness on faith:

**Q1 — real harm from a momentary violation?** Yes. A compliance reviewer who sees a `DataAsset` classified `Restricted` treats that classification as a trustworthy compliance fact — it feeds downstream systems (Compliance Intelligence, the graph, audit exports) that other decisions get built on. If the classify operation and the storage-source-active check aren't atomic, a race window lets an asset get classified against a source that has *already* gone inactive (decommissioned, migrated, access revoked) at the moment the classification is written. The resulting `DataAssetClassified` event and the audit record it produces would assert a fact that was false the instant it was recorded — not eventually corrected, *wrong at the moment of creation*.

**Q2 — does correction need more than a reasonable compensating action?** Yes, it needs more. This isn't a display value that a background job can silently recompute. Once a `DataAssetClassified` event is published and consumed by other Bounded Contexts, correcting a false classification means an audit correction, likely a compliance-incident review, and potentially re-notifying every downstream consumer that already acted on the (wrong) event — not a routine reconciliation pass.

**Q3 — already enforced elsewhere?** No. No external system (an approval gateway, a downstream governance tool) checks storage-source activity before this Aggregate's own `Classify` method runs. If the Aggregate doesn't enforce it, nothing does.

**Yes / No / No** — this passes and earns a place inside `DataAsset`'s own consistency boundary. In practice this means the `Classify` method must check the storage-source-active condition and apply the mutation within one atomic unit of work — see "The Relationship Between an Invariant and a Database Transaction" below for the subtlety this specific example raises (the check depends on state that structurally lives in a *different* Aggregate).

---

## A Rule That Looks Like an Invariant But Isn't — Worked Counter-Example

The harder, more common mistake isn't failing to spot a True Invariant — it's manufacturing one that doesn't exist. Vernon's own running anti-example is SaaSOvation's `Product` aggregate: an early design directly contained every `BacklogItem`, and through those, every `Task`, reasoning that "a `Product` conceptually *owns* its backlog, so consistency of the whole backlog against the product should be guaranteed." He walks through why this is wrong — nothing in the business actually requires that adding a `Task` to a `BacklogItem` be atomically consistent with every other `BacklogItem` under the same `Product`. The appearance of an invariant was really just conceptual composition ("`Product` *has* `BacklogItem`s") mistaken for a transactional requirement.

Adapted to this repo's own domain: a modeler drafting the `DataAsset` Aggregate notices that an asset accumulates `ExtractedEntity` records as it's processed, and reasons — "a `DataAsset` conceptually *has* its extracted entities, so surely the asset should always know exactly how many it has." The tempting design: add an `entityCount int` field to the `DataAsset` root, updated in the very same transaction as every `RecordExtractedEntity` call, so `entityCount` is *never* out of step with the actual rows in `extracted_entities`.

Run the same three-question test against this candidate rule — **"`DataAsset.entityCount` must always exactly equal the number of `ExtractedEntity` rows for it, atomically, with every insert":**

**Q1 — real harm from momentary staleness?** No. A compliance reviewer looking at "47 entities found, extraction still in progress" a few seconds behind the true count causes no harm — it's the expected, normal state of an asset mid-extraction. Nobody makes a compliance decision that depends on the count being exact to the millisecond.

**Q2 — does correction need more than a compensating action?** No. If the count ever did drift (a crash mid-extraction, a retried event), a trivial `SELECT COUNT(*)` reconciliation — or simply never storing the count at all and always computing it at query time — fixes it completely, with zero lasting consequence.

**Q3 — already enforced/derivable elsewhere?** Yes. The count is already, and always, derivable by querying `extracted_entities` directly, or by projecting it into a Read Model from `EntityExtracted` events (see `read-model-design`). Treating it as a field the Aggregate's own transaction must atomically maintain is pure redundancy — the answer already exists elsewhere, cheaply.

**No / No / Yes** — this fails the test on every axis. It is *not* a True Invariant. `DataAsset` genuinely "has" `ExtractedEntity` records in the Ubiquitous Language — a domain expert would say so unprompted — but that conceptual ownership does not imply the transactional consistency that would justify forcing `entityCount` into the root's own atomic write path. This is exactly Vernon's named root cause of oversized Aggregates: a domain expert saying "has" is not evidence the two need to be in the same transaction. The correct design leaves entity counting entirely outside `DataAsset`'s consistency boundary — a query-time count or an eventually-consistent Read Model field, never a root field kept in lockstep by the classify/extract transaction.

---

## The Relationship Between an Invariant and a Database Transaction

A True Invariant is not an abstract promise — it is only as real as the database transaction that enforces it. The consistency boundary and the transaction boundary **must coincide**: if the three-question test says a rule must hold at every instant, the *only* mechanism that actually makes that true is a single ACID transaction whose isolation guarantees prevent another writer from observing (or creating) a state where the rule is momentarily false and then committing on top of it. An invariant that isn't actually checked and applied inside one transaction isn't enforced — it's merely hoped for.

This is why Vernon's Rule 1 (True Invariants) and Rule 3 (One Aggregate per Transaction, called Rule 3 in `SKILL.md`) are, in his own framing, really one continuous argument rather than two independent rules: **the transaction is the enforcement mechanism the invariant test exists to justify using.** Concretely, `go-repository-pattern`'s compare-and-swap `UPDATE ... WHERE id = $N AND version = $M` pattern is exactly this — the invariant check (does the incoming mutation still make sense given the *current*, not stale, state) and the write happen inside one transaction, and a concurrent writer's conflicting change is caught as "0 rows affected," not silently lost. That skill's own named anti-pattern — **"fetch-then-update in two transactions"** — is precisely a violation of this section's rule: loading the version in one transaction and writing in a second re-opens exactly the race window the version field exists to close, because the boundary you *drew* (the invariant's scope) no longer matches the boundary you *enforce* (a single transaction's atomicity).

This section is also where the True Invariant worked example above gets harder in practice. "`DataAsset` may only be `Restricted` if `StorageSource` is active" is a True Invariant by the three-question test, but `StorageSource` is a *different* Aggregate — Rule 3 (reference by ID only) forbids `DataAsset` from holding a live reference to it, and the "one Aggregate per transaction" default forbids locking both rows in one write. In practice, the storage-source-active check is a read taken *before* the `Classify` transaction begins (the application service queries `StorageSource`'s own repository, read-only, and passes the result into `Classify` as a plain boolean), and `DataAsset`'s own transaction is the only thing that's actually atomic. This is an honest gap, not a solved one: if `StorageSource`'s state can change in the window between that read and `DataAsset`'s commit, the invariant can still be violated by a race — this is precisely the **write-skew** hazard covered in `references/sizing-contention-and-concurrency.md`'s "Write Skew" section, and if the business genuinely cannot tolerate that window even briefly, it pushes toward one of the two named exceptions below, not toward pretending the boundary problem has been solved by "checking first."

---

## When It's OK to Break These Rules

Vernon is **explicitly not absolutist** about any of his four rules — he states directly that they are guidelines for the common case, not universal laws, and gives his own criteria for when breaking one is the correct engineering call. This section replaces any framing of these rules as "non-negotiable": a documented, deliberate exception is legitimate engineering judgment; an undocumented one reached for out of convenience is a defect, full stop. There are exactly two named exception categories — no others:

### Exception 1 — A Genuine Cross-Object Business Invariant

Some rules really do span what would otherwise be two separate Aggregates, and eventual consistency for that specific rule would be a real business defect, not merely an engineering inconvenience. Vernon's own example category: **financial transactions requiring literal atomicity** — a debit and its corresponding credit, where a system that briefly shows the debit posted but not the credit (or vice versa) has produced an actual accounting error, not a display lag. In that case, the correct move is to accept a wider Aggregate (or a genuinely atomic multi-row transaction) rather than dogmatically splitting it merely because "small is the rule."

Adapted, hypothetically, to this repo's own domain: if the business genuinely required that no window ever exist where a `DataAsset` remains non-`Restricted` after its `StorageSource` is revoked — not "eventually reconciled," but *zero tolerance* — that would be a candidate for this exception. This is flagged here as an illustration of the *shape* of a legitimate exception, not a claim that this product currently has such a requirement; whether it does is a real business question to validate with Shafi, not an assumption to bake in by default.

### Exception 2 — A Measured Performance Bottleneck, Fixed With a Read-Only Denormalized Copy

Real, **measured** performance data (never a hypothesis) may show that the ID-reference-plus-separate-query pattern (Rule 3) is a genuine, material bottleneck on a specific read-heavy path. In that narrow case, Vernon allows a read-only, explicitly-denormalized copy of data sourced from another Aggregate — with the hard constraint that the copy is **never authoritative**, and the write/modification path still goes exclusively through the owning Aggregate's own Repository.

Concretely for this repo: if a `DataAsset` list view frequently needs its `StorageSource`'s display name, and a measured query showed a per-row join or lookup at scale was a genuine bottleneck, the sanctioned fix is a denormalized `source_name` field — most idiomatically implemented as a Read Model (per `read-model-design`) projected from `StorageSource` events — never a live join enforced at write time, and never a field `DataAsset`'s own transaction is responsible for keeping current.

### The Non-Negotiable Part of the Exception Process

Both categories share the same hard requirement: the exception must be **deliberate and documented** — the specific rule, which category it matches, and why — never a default reached for because splitting felt like more work, or because a denormalized copy seemed easier than designing the query properly. `SKILL.md`'s Quality Criteria table names this directly ("Exceptions documented — Any rule-break is deliberate, documented, and matches a named exception criterion" vs. "Undocumented exception, or one reached for out of convenience"). An exception with no written justification against one of these two categories is not an exception — it's an unexamined boundary mistake wearing the exception process's clothing.

---

## Assertions: Pre- and Post-Conditions as a Design Discipline

Evans' **Assertion** is a general supple-design discipline, sharper than a static list of named invariants: it attaches an explicit pre-condition and post-condition to a *specific operation*, in the Ubiquitous Language, ideally testable — "before `Classify()` runs, X must hold; after it returns without error, Y is guaranteed." A bare list of invariants tells you what must always be true of the Aggregate as a whole; an Assertion tells you, for each individual method, exactly what it requires on entry and exactly what it promises on successful exit. This is a stronger, more actionable unit of documentation than "here are this Aggregate's invariants" — it forces the modeler to check every mutating method individually, not just the Aggregate's state as an undifferentiated whole.

This repo's existing `go-domain-model`'s `Classify` method already embodies this discipline without naming it:

| Operation | Precondition | Postcondition (on success) |
|---|---|---|
| `Classify(level, by, now)` | `level.IsValid()` is true; `a.sensitivity.IsHigherThan(level)` is false (no silent downgrade) | `a.Sensitivity() == level`; `a.classifiedBy == by`; exactly one `DataAssetClassified` event recorded |
| `NewDataAsset(id, tenantID, sourceID, now)` | `id != uuid.Nil`; `tenantID != uuid.Nil` | A fully valid, unclassified `DataAsset` exists in memory; exactly one `DataAssetRegistered` event recorded |
| `Reconstitute(...)` | The supplied fields were valid when originally persisted | A valid `DataAsset` exists in memory; **zero** events recorded (reconstitution is not creation) |

**Disambiguate this sense of "Assertion" explicitly from two other senses already in this repo's vocabulary**, because the same word means three different things across three artifacts:

- **The testing-assertion sense** — a runtime check inside a *test* (`assert.Equal(t, want, got)`) verifying expected-versus-actual after the fact. This is a verification tool used *by* a test, not a design discipline attached to an operation's contract.
- **`secure-by-design`'s security-hardening sense** — a fail-fast, constructor-embedded validity check enforcing "totality" (no partially-valid instance of a security-relevant type, like a `TenantID`, can ever exist in circulation). This is Evans' Assertion concept applied *narrowly*, to construction only, and specifically in service of security hardening.
- **Evans' own sense, used in this section** — broader than either: a documented pre/post-condition pair for *any* operation, mutating or not, motivated by design clarity and correctness generally, not specifically by security or by test verification. `secure-by-design`'s Assertions are a special case of this general discipline, not a competing definition.

A modeler writing a new Aggregate method should be able to state both halves — precondition and postcondition — for every state-changing method before writing its implementation, the same way `Classify`'s table row above can be read straight out of its existing Go code.

---

## Quality Checklist for This File's Content

Run this against any candidate invariant before finalizing an Aggregate boundary:

- [ ] The candidate rule is stated as one specific sentence — never "these objects seem related."
- [ ] All three of Vernon's questions were applied explicitly, in writing, against that exact sentence — not felt through.
- [ ] Any answer other than Yes/No/No means the rule is redrawn as eventually consistent (Rule 4), a query-time computation, or a Read Model field — never forced into the boundary anyway.
- [ ] The has-a question ("does the Ubiquitous Language say this object has these others?") and the must-be-atomic question were answered **separately, in writing** — a mismatch (has-a: yes, atomic: no) is treated as a defect signal, not resolved by intuition.
- [ ] The proposed consistency boundary is actually achievable inside one database transaction, in one repository's `Save` — not split across two transactions that "usually" run close together in time.
- [ ] Every state-changing method on the Aggregate has a written pre-condition and post-condition (an Assertion), not just a static list of the Aggregate's invariants.
- [ ] Any rule that breaks one of the four Aggregate design rules is matched, explicitly and in writing, against one of the two named exception categories above — never left as an unexplained special case.
