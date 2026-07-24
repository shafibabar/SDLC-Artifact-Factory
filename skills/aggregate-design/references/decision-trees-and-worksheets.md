# Decision Trees and Worksheets

Self-contained — loadable without reading `SKILL.md` first.

This is the "sentinel"-style content this skill exists to provide: six explicit, branching if/then decision structures a modeler — or an agent acting on a modeler's behalf — can follow mechanically to a conclusion, without needing to synthesize a branch from paragraphs of prose. Every tree cross-references the sibling `references/` file that carries the full reasoning, worked examples, and Go code behind each branch; this file's own job is the branching logic itself, stated explicitly enough to be followed step by step, not restated at length here.

**Notation, applied consistently across all six trees:** a `START:` line states the question that opens the tree. Each subsequent question is numbered or named; `├─` and `└─` mark its possible answers; indentation nests a question inside the answer that leads to it. A branch either terminates in a boxed, capitalized conclusion (e.g. `TRANSACTION SCRIPT`, `STOP. Not a True Invariant.`) or hands off explicitly to another named Decision Tree in this same file. No branch is left to trail off into unstructured prose — where more reasoning is needed to apply a branch correctly, the branch names the exact sibling file section to consult, rather than restating that section's content inline.

**How the six trees compose, top to bottom, for a single Aggregate/use case under design:**

1. **Tree 1** always runs first — it decides whether Aggregate machinery is even warranted at all.
2. If Tree 1 lands on Domain Model (or Event-Sourced Domain Model), **Tree 2** runs against every candidate invariant to confirm it's real, not merely rule-shaped.
3. **Tree 3** runs whenever two or more candidate objects/clusters are in play, to decide whether they're one Aggregate or several.
4. **Tree 4** runs once boundaries are settled, to pick a concurrency mechanism for each Aggregate and each cross-Aggregate rule.
5. **Tree 5** runs only for Aggregates that cleared Tree 1 as at least Domain Model, to decide whether Event Sourcing is a further, justified escalation.
6. **Tree 6** runs whenever a design seems to need multi-Aggregate coordination, to tell a genuine Saga apart from a boundary drawn in the wrong place.

---

## Decision Tree 1: Which Business Logic Design Pattern Does This Aggregate/Use Case Need?

Per Khononov: this is the FIRST gate, run before any of this skill's other content applies. Pattern selection happens per Aggregate or per use case — a single Bounded Context routinely mixes patterns, and a Core-classified context can still contain individual use cases too simple for full Aggregate treatment. Full four-pattern catalog and fit criteria: `SKILL.md`'s "Before You Reach for an Aggregate at All" and `research/domain-driven-design/learning-ddd-khononov.md`.

```
START: What is this Aggregate/use case's subdomain classification, per
       `subdomain-distillation` (Core / Supporting / Generic)?
│
├─ GENERIC →
│    Does ANY rule in this specific use case require enforcement (not just
│    storage) spanning more than one record, atomically?
│    ├─ NO  → TRANSACTION SCRIPT. A single procedure operating directly
│    │         against persistence — no object model, no invariant-enforcing
│    │         methods. The expected outcome for a Generic subdomain; do not
│    │         escalate further without a specific, named reason.
│    └─ YES → This is unusual for a Generic subdomain — re-verify the
│              classification is actually correct. If it genuinely stands,
│              fall through to the SUPPORTING branch below and decide on
│              logic complexity alone, not on the Generic label.
│
├─ SUPPORTING →
│    Does this use case need to enforce ANY invariant spanning more than one
│    record, atomically?
│    ├─ NO →
│    │    Is there meaningful single-record behavior beyond plain CRUD
│    │    (validation, simple state transitions on one row) worth
│    │    encapsulating in an object?
│    │    ├─ NO  → TRANSACTION SCRIPT.
│    │    └─ YES → ACTIVE RECORD. An object per persisted row, CRUD-shaped
│    │              behavior, object structure mirrors the storage structure
│    │              directly — no cross-object invariant, no isolation from
│    │              the persistence schema.
│    └─ YES (a candidate cross-object invariant exists) →
│         Run Decision Tree 2 (below) against the SPECIFIC candidate rule,
│         in writing.
│         ├─ FAILS the test → not actually a True Invariant — fall back to
│         │   the NO branch immediately above (TRANSACTION SCRIPT or ACTIVE
│         │   RECORD, whichever the single-record-behavior question resolves
│         │   to).
│         └─ PASSES the test → DOMAIN MODEL. This specific use case earns
│             full Aggregate treatment regardless of the subdomain's overall
│             Supporting classification.
│
└─ CORE →
     Does this use case need to enforce ANY invariant spanning more than one
     record, atomically?
     ├─ NO  → Do NOT default to Domain Model merely because the subdomain is
     │         Core. Apply the SUPPORTING branch's logic-complexity question
     │         anyway → TRANSACTION SCRIPT or ACTIVE RECORD, per that
     │         sub-branch. A Core-classified Bounded Context routinely
     │         contains individual use cases too simple for full Aggregate
     │         machinery.
     └─ YES → Run Decision Tree 2 against the specific candidate rule.
              ├─ FAILS → not a True Invariant — fall back to the NO branch
              │   immediately above.
              └─ PASSES → DOMAIN MODEL confirmed. Proceed to Decision Tree 5
                  to check whether this specific Aggregate should further
                  escalate to EVENT-SOURCED DOMAIN MODEL. Domain Model is the
                  default stopping point — Event Sourcing is never assumed
                  from Core classification alone.
```

State the chosen pattern and a one-line justification explicitly in the Worksheet below — a Bounded Context where every single use case defaults to full Domain Model without exception is a signal to re-check the classification, not evidence the context is unusually complex.

---

## Decision Tree 2: Is This a True Invariant?

Vernon's three-question test, as an explicit branching structure. Full reasoning, a worked True Invariant example (`DataAsset` may only be `Restricted` if its `StorageSource` is active), and a worked counter-example most teams get wrong (`DataAsset.entityCount`): `references/invariants-and-consistency-boundaries.md`.

```
START: State the candidate rule as ONE specific sentence — never "these
       objects seem related." If it can't be stated as a single testable
       sentence, it isn't yet a candidate invariant; sharpen it before
       entering this tree.
│
├─ Q1 — REAL HARM: Would violating this rule, even momentarily, cause real
│  business harm if left uncorrected — not "would it look wrong," actual
│  damage to the business, a customer, or a compliance posture?
│  ├─ NO  → STOP. Not a True Invariant. Nothing further to check.
│  └─ YES → continue to Q2.
│
├─ Q2 — COMPENSATABLE: Can a violation be corrected after the fact by a
│  reasonable compensating action (a background job, a reconciliation pass,
│  a human review) with no lasting harm?
│  ├─ YES → STOP. Not a True Invariant — the rule tolerates staleness.
│  │         Handle it via Rule 4 (eventual consistency), a query-time
│  │         computation, or a Read Model field — never forced into a
│  │         consistency boundary.
│  └─ NO  → continue to Q3.
│
└─ Q3 — ALREADY ENFORCED: Is the rule already enforced by an external system
   (a payment gateway, a downstream approval step), such that this
   Aggregate re-enforcing it atomically would be redundant?
   ├─ YES → STOP. Not a True Invariant for THIS Aggregate to enforce — trust
   │         the external system; re-enforcing it here duplicates existing
   │         enforcement.
   └─ NO  → PASSES (harm: yes / compensatable: no / already-enforced: no).
             This is a True Invariant. It belongs inside a single
             Aggregate's consistency boundary, enforced atomically within
             one database transaction (see `references/invariants-and-
             consistency-boundaries.md`'s "Relationship Between an Invariant
             and a Database Transaction"). Proceed to Decision Tree 3 to
             confirm the boundary drawn around it is sized correctly.
```

All three questions must be answered explicitly, in writing, against the exact candidate sentence — not felt through. Any rule failing this test that still seems to need cross-object protection is a Decision Tree 3 / Decision Tree 6 question (a boundary or coordination question), never a reason to force it into one Aggregate's transaction anyway.

---

## Decision Tree 3: Should This Be One Aggregate or Two?

The has-a/must-be-atomic-with test plus the three sizing angles, as branches. Full has-a-trap narrative (SaaSOvation's `Product`/`BacklogItem`/`Task`, this repo's own `ClassificationRule` boundary case) and the coupling/cohesion framing: `references/worked-examples.md`'s Worked Example 3 and `references/sizing-contention-and-concurrency.md`.

```
START: For the candidate relationship between two objects/clusters, answer
       BOTH questions below SEPARATELY, in writing — never let one
       substitute for the other.
│
├─ Q-HAS-A: Does the Ubiquitous Language say one object "has" the other — a
│  domain expert would say so unprompted?
│  [Record: YES or NO. This question alone decides nothing.]
│
├─ Q-ATOMIC: Run Decision Tree 2 against the SPECIFIC rule that would
│  require the two objects to be modified together, atomically, in one
│  transaction.
│  [Record: PASSES (a True Invariant spans them) or FAILS (no such
│   invariant exists).]
│
├─ Combine the two recorded answers:
│  │
│  ├─ HAS-A: YES, ATOMIC: FAILS → THE HAS-A TRAP — Vernon's own named root
│  │   cause of oversized Aggregates. Conceptual ownership is not evidence
│  │   of a transactional need. → KEEP AS TWO (OR MORE) SEPARATE
│  │   AGGREGATES; reference by ID only (Rule 3). This is the single most
│  │   common outcome of this tree.
│  │
│  ├─ HAS-A: NO, ATOMIC: FAILS → No relationship strong enough to warrant
│  │   even discussing a merge. → DEFINITELY TWO SEPARATE AGGREGATES.
│  │
│  └─ ATOMIC: PASSES (regardless of the has-a answer) → A True Invariant
│      genuinely spans the two candidates. Continue to the sizing check
│      below before finalizing a merge — a passing invariant test is
│      necessary but not sufficient; an oversized merge still has a real,
│      separate cost.
│
└─ (Only reached if Q-ATOMIC passed above) Evaluate all three sizing angles
   from `references/sizing-contention-and-concurrency.md` against the
   MERGED candidate:
   │
   ├─ PERFORMANCE: would merging force routine operations that don't need
   │  the other object's data to load it anyway?
   ├─ SCALABILITY: would merging concentrate independent writers' contention
   │  onto one instance's lock/version?
   ├─ COLLABORATION: would merging force legitimate, unrelated concurrent
   │  user actions to collide on the same version field?
   │
   ├─ ALL THREE ACCEPTABLE (no real cost named on any angle) → MERGE INTO
   │   ONE AGGREGATE. The True Invariant is enforced by construction, and no
   │   sizing angle pays a real cost for it.
   │
   └─ ANY ONE ANGLE SHOWS A REAL, NAMED COST → Do not merge by default.
       Estimate concurrent-writer contention explicitly:
       ├─ Contention estimate LOW → Exception 1 (a genuine cross-object
       │   business invariant, `references/invariants-and-consistency-
       │   boundaries.md`) may still justify the wider Aggregate — accept
       │   it ONLY as a documented, deliberate exception, never a silent
       │   default.
       └─ Contention estimate HIGH → KEEP AS TWO SEPARATE AGGREGATES.
           Enforce the invariant instead via Decision Tree 6 (is this
           actually a Saga?) or Decision Tree 4's SERIALIZABLE-isolation
           branch, scoped tightly to just this one rule — never by widening
           the Aggregate.
```

---

## Decision Tree 4: Optimistic Concurrency, Pessimistic Locking, or Serializable Isolation?

Condensed skeleton of the full decision tree already built in `references/sizing-contention-and-concurrency.md`'s "Decision Tree: Optimistic Concurrency, Pessimistic Locking, or Serializable Isolation" section — reproduced here at the same branching granularity so this file stays a complete routing surface, with every worked example (the write-skew race, the reclassification-sweep `FOR UPDATE SKIP LOCKED` case, the debit/credit SERIALIZABLE case) left in that file rather than repeated here.

```
START: Does this rule involve exactly one Aggregate's own consistency
       boundary?
│
├─ YES (the normal, single-Aggregate case) →
│    Is the write path interactive (user-facing request/response)?
│    ├─ YES →
│    │    Is contention on this instance LOW (correctly sized, per Decision
│    │    Tree 3) AND is a failed attempt CHEAP to retry?
│    │    ├─ YES → OPTIMISTIC CONCURRENCY (default). Version-column CAS;
│    │    │         retry with backoff or surface a conflict to the caller.
│    │    └─ NO  → PESSIMISTIC LOCKING (`SELECT ... FOR UPDATE`) as a
│    │              documented, narrow exception — name the specific
│    │              condition (hot row / high failure cost) that justifies
│    │              it, even though the path is interactive.
│    └─ NO (batch/administrative job) →
│         PESSIMISTIC LOCKING if rows are processed sequentially with no
│         interactive user waiting (simpler than a retry loop for a
│         non-latency-sensitive job). OPTIMISTIC CONCURRENCY remains
│         acceptable if the job already retries idempotently — pick
│         whichever is simpler to operate.
│
└─ NO (the rule genuinely spans two or more Aggregates — only reached after
        `references/invariants-and-consistency-boundaries.md`'s exception
        process confirms this is a deliberate, documented exception, never
        an oversight) →
     Is a short, reconciled staleness window actually acceptable for this
     specific rule (Rule 4 — a Domain Event, a background reconciliation)?
     ├─ YES → Reconsider whether this is really a True Invariant at all —
     │         re-run Decision Tree 2. Most cross-Aggregate rules resolve
     │         here: no special concurrency mechanism needed.
     └─ NO (zero tolerance for any race window — a genuine Exception-1-class
          invariant) →
          SERIALIZABLE isolation (Postgres `SERIALIZABLE`/SSI), scoped
          tightly to only the specific statements reading/writing this
          invariant's data — never the whole service by default. A
          database uniqueness/exclusion constraint scoped to the invariant
          is an acceptable alternative where the rule can be expressed as a
          constraint the database checks directly.
```

Never default silently to optimistic concurrency out of habit — work through this tree explicitly for every Aggregate and every cross-Aggregate rule under design. Full write-skew hazard this tree exists to route around (why a version column alone never catches a conflict living in the relationship between two different Aggregates' rows): `references/sizing-contention-and-concurrency.md`'s "Write Skew" section.

---

## Decision Tree 5: Should This Aggregate Adopt Event Sourcing?

Khononov's three-question justification test, as explicit branches. Full worked justification (`ComplianceGap`, passing on two of three questions) and the full costs accepted (upcasting, snapshotting, replay-based testing): `references/worked-examples.md`'s Worked Example 4. Full Go pattern (the `Apply`/`applyNew` shape, conditional append, snapshotting, upcasting): `references/go-implementation-patterns.md`.

```
START: Did this Aggregate/use case clear Decision Tree 1 as at least DOMAIN
       MODEL (not Transaction Script or Active Record)? Event Sourcing is an
       escalation ABOVE Domain Model, never a substitute for it and never
       reached for directly.
│
├─ NO  → STOP. Not eligible for Event Sourcing — resolve Decision Tree 1
│         first.
└─ YES → Apply Khononov's three-question justification test, in writing,
    against THIS SPECIFIC Aggregate. "The subdomain is Core Domain, and
    deserves the best patterns" is explicitly NOT a fourth qualifying
    question — see `SKILL.md`'s "Premature Event Sourcing" anti-pattern.
    │
    ├─ Q1 — TEMPORAL QUERY: Does the business genuinely need to reconstruct
    │  this Aggregate's state as of an arbitrary PAST point in time — not
    │  just "what is it now"?
    │  ├─ YES → at least one qualifying need found → skip to ADOPT, below.
    │  └─ NO  → continue to Q2.
    │
    ├─ Q2 — RETROACTIVE PROJECTION: Will new Read Models plausibly need to
    │  be built later from history that already happened, BEFORE that Read
    │  Model was designed — history a current-state row would have already
    │  overwritten?
    │  ├─ YES → at least one qualifying need found → skip to ADOPT, below.
    │  └─ NO  → continue to Q3.
    │
    └─ Q3 — AUDIT-AS-RECORD: Must the event stream ITSELF — not a bolted-on,
       separately-maintained log that can drift from a current-state row —
       be the authoritative compliance/audit record a regulator or auditor
       points to?
       ├─ YES → at least one qualifying need found →
       │   ADOPT EVENT-SOURCED DOMAIN MODEL. Only ONE "yes" out of the
       │   three is required, not all three. Name explicitly, in the
       │   Worksheet below, which question(s) passed. Accept the attendant
       │   costs (an upcasting chain maintained forever per event type, a
       │   snapshotting cadence, replay-based test fixtures) as a
       │   deliberate trade, not an afterthought.
       └─ NO (all three answered NO) →
           DO NOT ADOPT EVENT SOURCING, REGARDLESS OF CORE DOMAIN STATUS.
           Use current-state persistence
           (`references/go-implementation-patterns.md`'s "Aggregate Root in
           Go — Current-State Persistence"). Record "not applicable —
           current-state, no qualifying need" in the Worksheet.
```

---

## Decision Tree 6: Is a Cross-Aggregate Operation a Modeling Smell or a Genuine Saga?

Condensed skeleton of the full decision tree already built in `references/cross-aggregate-coordination-and-sagas.md`'s "Decision Tree: Is This a Modeling Smell or a Genuine Business Process?" section — reproduced here at the same branching granularity, with the full worked Saga shape (the `StorageSource` decommission-with-`Restricted`-assets example, the compensatable/pivot/retryable classification) left in that file.

```
START: Does correctness genuinely require two or more Aggregates to reflect
       one business fact with ZERO tolerance for any staleness window — real
       business harm from a moment of visible inconsistency, not "it would
       be nice if this were instant"?
│
├─ YES → Re-run Decision Tree 2 against the specific rule, in writing,
│         before concluding this needs multi-Aggregate machinery at all.
│         │
│         ├─ FAILS the test (the common outcome — staleness turns out
│         │  tolerable, or the "atomicity" was really conceptual has-a
│         │  ownership mistaken for a transactional requirement) →
│         │  THIS IS A MODELING SMELL, not a Saga candidate. Either the
│         │  boundary itself is wrong (re-run Decision Tree 3), or the
│         │  correct answer was ordinary Rule 4 eventual consistency all
│         │  along — a Domain Event and an idempotent consumer, no Saga.
│         │
│         └─ PASSES the test even under honest scrutiny (a true Exception-
│            1-class invariant — e.g. a literal debit/credit pair) →
│            NOT A SAGA EITHER. Re-run Decision Tree 3's sizing check to
│            redraw the boundary so both facts live inside one consistency
│            boundary, or apply Decision Tree 4's SERIALIZABLE-isolation
│            branch. A Saga's whole premise is tolerating an observable
│            intermediate state; a rule with zero tolerance for that state
│            is, by definition, not a Saga candidate.
│
└─ NO (some staleness is acceptable) →
    Is there a real, ordered, multi-step business process — one a domain
    expert would name and recognize as a single thing with its own identity
    ("Decommissioning a Storage Source") — where an intermediate step can
    fail AFTER prior steps have already committed, such that the business
    must decide what happens to that already-committed state?
    │
    ├─ NO (each Aggregate's reaction is independent; no step's failure
    │   creates a decision about undoing a prior, already-committed step)
    │   → PLAIN RULE 4 CHOREOGRAPHY SUFFICES. Publish the Domain Event(s);
    │      each interested Bounded Context reacts independently and
    │      idempotently. No `saga_instances` table, no compensations, no
    │      orchestrator.
    │
    └─ YES → THIS IS A GENUINE SAGA. Classify every step compensatable,
             pivot, or retryable (`event-driven-patterns`); choose
             choreography (≤3 participants) or orchestration (4+
             participants, or complex compensations) per that skill's
             selection guide; confirm every compensating action is a real,
             named, invariant-checking Command against its target
             Aggregate's own root — never a direct field write reached for
             because "it's just a compensation."
```

**The single fastest tell, in practice:** if the "coordination" being designed would disappear entirely the moment Decision Tree 2's three questions are honestly answered against the specific rule — not the general area of the domain — it was never a Saga candidate.

---

## The Aggregate Design Worksheet (Expanded)

Fill in every field for each Aggregate under design. Each row states, in parentheses, which Decision Tree resolves it — leaving a field blank or answered by intuition rather than by the named tree is itself a defect, per `SKILL.md`'s Quality Criteria table. `references/worked-examples.md`'s four Worked Examples are this worksheet, filled in, for a full precedent of what a completed row should look like.

| Field | What to record | Resolved by |
|---|---|---|
| **Aggregate name** | The Aggregate's name in the Ubiquitous Language. | — |
| **Root Entity** | The Aggregate Root's name (usually the same as the Aggregate name). | — |
| **Business Logic Pattern chosen** | One of Transaction Script / Active Record / Domain Model / Event-Sourced Domain Model, plus a one-line justification naming which branch was taken. | Decision Tree 1 |
| **Invariants** | Every rule that passed the True Invariant test, stated as a specific sentence, with its Q1/Q2/Q3 answers noted (not just the conclusion). | Decision Tree 2 |
| **Rejected candidate invariants** | Any rule considered and correctly rejected (per `references/invariants-and-consistency-boundaries.md`'s `entityCount` counter-example pattern) — named explicitly so the rejection is visible, not silently absent. | Decision Tree 2 |
| **Entities** | Every locally-identified child Entity, with a one-line note on why it's local rather than its own Aggregate (the outside-lookup test). | `references/entities-value-objects-and-domain-primitives.md`'s "Local vs. Global Identity" test |
| **Value Objects** | Every Value Object, noting which are also Domain Primitives (self-validating construction). | `references/entities-value-objects-and-domain-primitives.md` |
| **Commands/Events** | Every command → event pair; for an event-sourced Aggregate, note which internal events are published as-is vs. translated/coarsened vs. dropped. | `references/go-implementation-patterns.md`'s "Distinguishing Internal Events from Published Domain Events" (event-sourced Aggregates only) |
| **Cross-Aggregate relationships** | One sub-row per referenced Aggregate: **Referenced Aggregate**, **Has-a?** (Y/N), **Must-be-atomic-with?** (PASSES/FAILS), **Conclusion** (merge / keep separate / documented exception), **Reference shape** (ID only / denormalized copy under Exception 2). A bare list of IDs with no has-a/atomic answer per relationship is an incomplete worksheet. | Decision Tree 3 |
| **Identity generation strategy** | Client-generated (default) / persistence-generated / `NextIdentity()`, with reasoning if not the default. | `references/go-implementation-patterns.md`'s "Identity Generation in Go" |
| **Concurrency strategy** | Optimistic (default) / pessimistic / serializable, with the specific branch of Decision Tree 4 taken and, if not optimistic, the named justifying condition. | Decision Tree 4 |
| **Event Sourcing justification** | Which of Q1/Q2/Q3 passed, or "not applicable — current-state, no qualifying need." Never "Core Domain" alone as the reason. | Decision Tree 5 |
| **Cross-Aggregate coordination** | For every multi-step or multi-Aggregate process touching this Aggregate: modeling smell (redraw boundary) / plain choreography / genuine Saga (with step classification). | Decision Tree 6 |
| **Contention estimate** | Low / medium / high, per instance, with the specific reasoning (write frequency, population of writers, burstiness). | `references/sizing-contention-and-concurrency.md`'s three sizing angles |
| **Exceptions taken** | Any rule-break against Rules 1–4, matched explicitly to Exception 1 or Exception 2 — never left as an unexplained special case. | `references/invariants-and-consistency-boundaries.md`'s "When It's OK to Break These Rules" |
