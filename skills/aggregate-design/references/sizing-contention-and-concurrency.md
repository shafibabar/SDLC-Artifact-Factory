# Sizing, Contention, and Concurrency

Self-contained — loadable without reading `SKILL.md` first.

Vernon is emphatic that oversized Aggregates, not undersized ones, are the single most common mistake he has seen across DDD engagements — and that the mistake is *seductive*: it comes from a well-intentioned but wrong belief that clustering more together is "safer." This file gives the full sizing methodology (three genuinely distinct angles, not one blended instinct), the coupling/cohesion vocabulary that ties Aggregate sizing to every other boundary decision in this system, the concrete concurrency hazard (write skew) that a version-column alone does not solve, an explicit decision tree for choosing a concurrency strategy, and the eager-loading trap that is the same underlying mistake as oversizing, wearing different clothes.

---

## The Three Sizing Angles — Performance, Scalability, Collaboration

Vernon argues Rule 2 (design small Aggregates) from three genuinely independent angles, kept deliberately distinct rather than blended into one "small is good" instinct. Evaluate all three separately for every candidate Aggregate — a design can fail on one angle while passing the other two.

**Performance.** Loading an Aggregate means loading its entire object graph in one round trip. If `DataAsset` embedded every `ExtractedEntity` fully in memory on every load — not just IDs, the full rows — a single `Classify()` call, which only needs to read and mutate the root's own `sensitivity` field, would pay the cost of hydrating potentially thousands of unrelated child rows it never touches. The performance cost is paid on *every* operation, regardless of whether that operation has any use for the extra data.

**Scalability.** Contention is measured **per Aggregate instance**, and a large Aggregate concentrates far more of the system's total write traffic onto one instance's lock/version than a correctly-split design would. If `StorageSource` were modeled to directly contain a live collection of every `DataAsset` connected to it (rather than `DataAsset` referencing `StorageSource` by ID, per Rule 3), every classify operation across every asset tied to that source would contend for one `StorageSource` row's version — collapsing what should be independent, parallelizable writes into serialized contention on a single hot instance.

**Collaboration.** Multiple, entirely legitimate user actions collide artificially when they operate on what feels like "the same area of the domain" but doesn't actually need to be one transactional unit. If `DataAsset` and its `ExtractedEntity` records were one Aggregate, a compliance reviewer running `Classify()` and an extraction pipeline concurrently appending newly-discovered entities via `RecordExtractedEntity()` would collide on the very same version field — a CAS failure — even though neither operation has any actual need to be consistent with the other at every instant. This is specifically a *collaboration* failure, not a performance one: the database isn't slow; the design just forces two independent, non-conflicting real-world actions to fight over one lock. Vernon frames this as a genuinely distinct, multi-user, real-world-team concern — not merely a database-tuning problem.

---

## Sizing as a Coupling/Cohesion Trade-off

Khononov reframes Aggregate sizing using the same vocabulary that governs every other boundary decision in this system, rather than a bespoke Aggregate-only heuristic. A larger Aggregate buys **cohesion** — more of the rules that must hold together are enforced by one mechanism, one lock, one transaction — at the direct cost of **coupling**: every operation touching *any* part of that Aggregate now contends for the same lock/version, regardless of whether the operations are logically related.

This is the same trade-off that governs Bounded Context sizing and service/module sizing elsewhere in this system's boundary hierarchy (Subdomain → Bounded Context → Aggregate → Module/microservice, per Khononov) — each boundary type is driven by a different *force* (strategic differentiation, linguistic consistency, transactional consistency, deployability, respectively), but the sizing question at every one of those layers reduces to the identical trade-off: *what does drawing the boundary here buy in cohesion, and what does it cost in coupling?* A modeler who reuses this one mental model across Aggregate, Bounded Context, and service-boundary decisions doesn't need three unrelated-feeling heuristics — they need to ask the same question at four different points in the hierarchy. For an Aggregate specifically: name explicitly, in writing, which rules this boundary's cohesion actually buys (list them), and which independent operations this boundary's coupling now forces to contend (list them) — a boundary that can't name a real cohesion benefit against a real coupling cost isn't a considered design decision, it's a default nobody examined.

---

## Write Skew and Why Optimistic Concurrency Isn't Automatically Safe

Kleppmann's precise vocabulary distinguishes several isolation anomalies. PostgreSQL's default (**Read Committed**) prevents dirty reads and dirty writes but not read skew, lost update, or write skew. **Snapshot Isolation** (Postgres's `REPEATABLE READ`) prevents read skew and, with the version-column CAS pattern, lost update — but **not write skew**. Only true serializability (Postgres's `SERIALIZABLE`, implemented as Serializable Snapshot Isolation) prevents it.

**Write skew** is precisely this shape: two transactions each read a *consistent* snapshot, each individually satisfies an invariant against exactly what it read, and yet the invariant is violated the moment both commit. This repo's default optimistic-concurrency pattern — the `version`-column compare-and-swap already implemented throughout `go-repository-pattern` and `data-model-design` — is a targeted, correct fix for **lost update** (two writers overwriting the same row). It does **nothing** to prevent write skew, because write skew doesn't involve two writers touching the same row at all — it involves two writers touching *different* rows, each conditioned on a read of the *other* row that was true at read time but stale by commit time.

### A Concrete Example in This Repo's Domain

Suppose a (hypothetical, illustrative) cross-Aggregate rule exists: *"a `StorageSource` may be marked `Decommissioned` only if zero `DataAsset` rows attached to it are currently `Restricted`."* This genuinely spans two Aggregates — `StorageSource` and `DataAsset` — and is exactly the shape `references/invariants-and-consistency-boundaries.md`'s exception process exists to flag, not something to enforce silently.

Two transactions run concurrently, each under Postgres's default isolation:

```
TxA (compliance admin decommissions StorageSource S):
  BEGIN
  SELECT sensitivity_level FROM data_assets
    WHERE source_id = $1 AND tenant_id = $2 AND deleted_at IS NULL;
  -- snapshot shows: zero rows are 'Restricted'  → precondition holds, proceed
  UPDATE storage_sources SET status = 'Decommissioned', version = version + 1
    WHERE id = $1 AND tenant_id = $2 AND version = $3;
  -- 1 row affected → CAS succeeds, TxA commits
  COMMIT

TxB (classifier marks DataAsset A as Restricted, concurrently):
  BEGIN
  SELECT status FROM storage_sources
    WHERE id = $1 AND tenant_id = $2;
  -- snapshot shows: status = 'Active' (TxA hasn't committed yet) → precondition holds, proceed
  UPDATE data_assets SET sensitivity_level = 'Restricted', version = version + 1
    WHERE id = $1 AND tenant_id = $2 AND version = $3;
  -- 1 row affected → CAS succeeds, TxB commits
  COMMIT
```

Both CAS checks succeed — each transaction's `version` predicate matched, because each was checking the version of the row **it itself was writing**, not the row it merely *read*. Both commit. The result: `StorageSource` S is now `Decommissioned`, and `DataAsset` A is now `Restricted` and still attached to it — the invariant is violated, even though neither individual transaction violated anything it could see, and even though both used the correctly-implemented, textbook version-column CAS pattern from `go-repository-pattern`. **A version check on one Aggregate's own row can never catch a conflict that lives in the relationship between two different Aggregates' rows** — there is no single row whose version-mismatch would ever fire.

This is why the sizing/boundary decisions in this skill and the concurrency mechanism in `go-repository-pattern` are not substitutes for each other: correctly-sized Aggregates with correct CAS still leave a genuine write-skew hole at any point where a business rule (even an informally-assumed one, never explicitly modeled as an invariant) spans two Aggregates. The fix is never "add more version columns" — see the decision tree below.

---

## Decision Tree: Optimistic Concurrency, Pessimistic Locking, or Serializable Isolation

Work through this explicitly for every Aggregate and every cross-Aggregate rule under design — do not default silently to optimistic concurrency out of habit.

```
START: Does this rule involve exactly one Aggregate's own consistency boundary?
│
├─ YES (single-Aggregate invariant, the normal case)
│    │
│    ├─ Is the write path interactive (a user-facing request/response command)?
│    │    │
│    │    ├─ YES →
│    │    │    ├─ Is expected concurrent-writer contention on this specific instance LOW
│    │    │    │  (Aggregate correctly sized per the three angles above) AND is a failed
│    │    │    │  attempt CHEAP to retry (no expensive side effect already committed)?
│    │    │    │    ├─ YES → Use OPTIMISTIC CONCURRENCY (default). Version-column CAS;
│    │    │    │    │         on 0-rows-affected, retry with backoff or surface a
│    │    │    │    │         "someone else changed this" conflict to the caller.
│    │    │    │    └─ NO  → (contention is HIGH on this instance, or a failed attempt
│    │    │    │              is costly to redo) → Use PESSIMISTIC LOCKING
│    │    │    │              (`SELECT ... FOR UPDATE`) as the documented, narrow
│    │    │    │              exception — even though the path is interactive. Name the
│    │    │    │              specific condition (hot row / high failure cost) that
│    │    │    │              justifies it.
│    │    │    └─ (continue to the batch branch only if NOT interactive)
│    │    │
│    │    └─ NO (batch or administrative job — e.g. a nightly reclassification sweep,
│    │         a bulk source migration) →
│    │         Use PESSIMISTIC LOCKING if the job processes rows sequentially and no
│    │         interactive user is waiting on the lock — holding a short lock is simpler
│    │         and safer here than designing a retry loop for a process that isn't
│    │         latency-sensitive. OPTIMISTIC CONCURRENCY remains acceptable too if the
│    │         job already retries idempotently; pick whichever is simpler to operate.
│    │
│    └─ (Either branch above defaults to OPTIMISTIC; PESSIMISTIC is always the
│         documented exception, never the default — see `go-repository-pattern`'s
│         existing CAS pattern as the baseline both branches build on.)
│
└─ NO (the rule genuinely spans two or more Aggregates — run this only after
        `references/invariants-and-consistency-boundaries.md`'s three-question test AND
        exception process confirm this is a documented, deliberate exception, not an
        oversight)
     │
     ├─ Is a short, reconciled staleness window (Rule 4 — eventual consistency, a
     │  Domain Event, a background reconciliation job) actually acceptable for this
     │  specific rule?
     │    ├─ YES → Reconsider whether this is really a True Invariant at all — re-run
     │    │         the three-question test. Most cross-Aggregate rules resolve here:
     │    │         no special concurrency mechanism needed, because the rule was never
     │    │         a candidate for atomic, cross-Aggregate enforcement in the first
     │    │         place.
     │    └─ NO (zero tolerance for any race window — a genuine Exception-1-class
     │         invariant, e.g. Vernon's debit/credit example) →
     │         Use SERIALIZABLE isolation (Postgres `SERIALIZABLE` / SSI), scoped
     │         tightly around only the specific statements reading and writing this
     │         invariant's data. Never set the whole service to `SERIALIZABLE` by
     │         default — the throughput cost is real and unscoped serializability
     │         punishes every unrelated transaction in the service for one rule's
     │         needs. An explicit application-level lock or a database uniqueness/
     │         exclusion constraint scoped to the invariant is an acceptable
     │         alternative to full SERIALIZABLE where the invariant can be expressed
     │         as a constraint the database can check directly.
```

---

## Unbounded Collections and the Eager-Loading Trap

Vernon's own example: a `Product` root that must eagerly load every `BacklogItem` ID it "contains" into an in-memory collection field, just to answer a simple question like "does this product have any backlog items" — a scaling hazard if the collection is unbounded, **even though each individual `BacklogItem` is correctly its own Aggregate, correctly referenced by ID.** This is worth stating precisely because it is easy to assume that once Rule 3 (reference by ID) is satisfied, sizing is automatically safe. It isn't — the referencing discipline and the sizing discipline are the **same underlying mistake surfacing in two different rules at once**, not two unrelated concerns.

Adapted to this repo: even where `ExtractedEntity` is correctly modeled as its own locally-identified child (or its own Aggregate, per the specific structural choice made in `references/go-implementation-patterns.md` and `references/entities-value-objects-and-domain-primitives.md`), a `DataAsset` root that eagerly loads every `ExtractedEntity` ID or instance into an in-memory slice "for convenience" — just to answer "does this asset have any high-confidence PII entities" — reintroduces the exact same problem this file's Performance sizing angle names above, in a different guise. A `DataAsset` can accumulate thousands of extracted entities; a collection with no bound on its size is a scaling hazard regardless of how correctly its members are referenced.

The correct fix is the same shape as the entity-count discussion in `references/invariants-and-consistency-boundaries.md`'s worked counter-example: answer the question at **query time**, never by loading the unbounded collection into the Aggregate's own construction/reconstitution path.

```sql
-- Correct: answer the question with a targeted query, not a loaded collection
SELECT EXISTS (
    SELECT 1 FROM extracted_entities
     WHERE data_asset_id = $1 AND tenant_id = $2 AND entity_type IN ('SSN','ACCOUNT_NUMBER')
);
```

```go
// Wrong: the Aggregate itself pays to hydrate an unbounded collection on every load
type DataAsset struct {
    id       uuid.UUID
    entities []ExtractedEntity  // could be thousands of rows, loaded every single time
}
```

If a design needs a collection field on an Aggregate to feel "complete," that need is itself the diagnostic signal — per Vernon's testability criterion, if constructing or loading a valid instance requires an elaborate or unbounded object graph, that difficulty is evidence the boundary (or the loading strategy) is drawn wrong, not an inconvenience to route around with a bigger struct.

---

## Retry-on-Conflict: Normal Operation vs. a Boundary Smell

A rejected optimistic write (`ErrConcurrentModification`, `0` rows affected on the CAS) is not, by itself, a problem — it is the mechanism working exactly as designed. The distinction that matters is **frequency and context**:

- **Healthy:** conflicts are rare, occur only under genuine edge-case collisions (two administrators editing the same record within the same second, a retried client request racing its own first attempt), and are handled with a small bounded retry (a handful of attempts with jittered backoff) followed by surfacing an explicit conflict to the caller if retries are exhausted — never a silent overwrite, never an unbounded retry loop.
- **A boundary smell:** if conflict retries appear routinely, as a load-bearing part of *normal* request handling under ordinary (non-adversarial) traffic — not an edge case, but something that happens on a meaningful fraction of writes — **the boundary is wrong, not the retry logic.** This is precisely the Collaboration sizing angle from this file's first section showing up as an operational symptom: if two legitimate, unrelated user actions collide on the same Aggregate instance often enough that retries are routine, the Aggregate is absorbing more than it should, and no amount of smarter backoff fixes a design problem.

**Concrete operational signal:** track the `ErrConcurrentModification` rate per Aggregate type as a real metric. An occasional, low-rate signal confirms the mechanism is working. A sustained, non-trivial rate is a paging-worthy signal to re-open the Aggregate's boundary design — re-run the three sizing angles and the coupling/cohesion trade-off above — not a signal to add a larger retry budget or a longer backoff window. Papering over a boundary problem with more aggressive retries only delays the point at which the underlying oversizing becomes visible as a throughput ceiling under real load.
