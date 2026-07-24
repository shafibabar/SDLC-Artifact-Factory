# Entities, Value Objects, and Domain Primitives

Self-contained — loadable without reading `SKILL.md` first.

This file is the full depth behind `SKILL.md`'s Entity/Value Object table: how to tell the two apart per Bounded Context, why Value Objects are the preferred default, the local-vs-global identity test for what belongs inside an Aggregate at all, the direct equivalence between a Value Object and `access-control-model`'s Domain Primitive pattern, and three supporting patterns — Factory, Specification, and Closure of Operations — that Evans' tactical catalog provides for construction, recurring business rules, and composable Value Object operations respectively. Grounded in `research/domain-driven-design/domain-driven-design-evans.md` (Ch. 5–6, 9–10) and `research/security/secure-by-design.md`'s Domain Primitive pattern, already implemented in `access-control-model/references/domain-primitives-and-enforcement.md`.

---

## Identity vs. Attribute Equality, Per Bounded Context

Evans' test is behavioral, not structural: ask whether **continuity of identity is meaningful to the application** — should two objects with identical attribute values be treated as interchangeable, or as distinct individuals whose history must be tracked through change over time? The first answer makes something a Value Object; the second makes it an Entity. Nothing about the concept itself decides this — the decision is made fresh, per Bounded Context, and the same real-world thing can land on both sides of the line in different contexts.

Evans' own example generalizes directly: a `User` inside an Identity & Access context is unambiguously an Entity — the system must track *this specific person's* role changes, permission grants, and login history over time, and two `User`s with momentarily identical attributes are still two different people. A `User` reference embedded inside an audit record is a different question entirely: the audit record needs to know *who this was, and what their role was, at the moment the audited action happened* — not "this same user, tracked forward through whatever they become later." That is a Value Object snapshot, not an Entity reference, even though the raw material (a person) is the same.

This repo has a live instance of exactly this ambiguity worth naming explicitly, as an illustrative gap rather than a mandate to change existing code: `go-domain-model`'s `DataAssetClassified` event carries `ClassifiedBy uuid.UUID` — a bare reference to the classifying `User`'s identity. That's the correct Rule-3 shape (reference another Aggregate by ID, never by live object) for the *classification act itself*. But a compliance reviewer reading a `DataAssetClassified` event six months later, asking "who classified this, and were they authorized to at the time?", is resolving that `uuid.UUID` against whatever the `User` Aggregate's *current* state says — which may have drifted (a role change, a name change, an offboarding) since the classification happened. An `AuditActor` Value Object snapshot (`{name, role, actedAt}`, captured into the event payload at the moment of the act rather than resolved later by ID) would answer the audit question correctly regardless of what the `User` Aggregate looks like today. Whether this repo's compliance requirements actually demand that level of audit fidelity is a real product question to raise with Shafi — flagged here as the shape of the identity-vs-snapshot decision, not a claim that the current design is wrong.

---

## Why Value Objects Are Preferred: the Cost Asymmetry

`SKILL.md` already states the conclusion — prefer Value Objects — but the reasoning behind it is a genuine cost asymmetry, not a stylistic taste. **Every Entity carries ongoing identity-management costs a Value Object never incurs at all:**

| Cost | An Entity pays it | A Value Object never pays it |
|---|---|---|
| Identity generation | Needs an ID-generation strategy (client- or persistence-generated) | No ID exists to generate |
| Equality | Must compare by ID, ignoring attribute drift | Structural equality — compare all fields, always correct |
| Concurrent modification | Needs a concurrency strategy (version field, locking) if independently mutable | Immutable — there is nothing to concurrently modify |
| Lifecycle tracking | Created/active/archived/deleted states to model and enforce | No lifecycle — a "change" is a fresh instance, not a state transition |
| Storage | If an Aggregate Root, needs its own Repository; if a child Entity, needs local-uniqueness enforcement | Stored as plain columns/fields on whatever holds it — no separate storage concern |
| Test setup | A valid test instance requires establishing identity (and often persistence context) first | A valid test instance is just a constructor call with valid arguments |

This repo's own `SensitivityLevel` (`go-domain-model`) is the correct default in action: it is a small, closed set of values with no continuity to track — asking "is *this* `SensitivityLevel` the same one as *that* `SensitivityLevel`" only ever means "do they hold the same value," never "have I seen this particular instance before." Making it an Entity — its own ID, its own row, a `sensitivity_history` table it owns — would buy nothing, because `DataAssetClassified` events already capture the full history of *when* an asset moved between levels; giving the level itself identity would be paying every cost in the table above for a continuity nobody needs. The question to ask of any candidate type is not "could this be an Entity" (almost anything could) but "does anything in this domain actually need to track *this instance specifically*, through change, over time" — and only a "yes" earns the Entity's ongoing cost.

---

## Immutability Enables Sharing

A Value Object never changes after construction — a "change" is always a new instance replacing the old one, never a mutation in place. This is what makes it safe to share: **because the value can never change out from under a holder, any number of Aggregates, goroutines, or call sites can hold a copy of "the same" Value Object with zero risk that one holder's action corrupts another's view of it.**

In this repo's Go idiom, this is precisely why `go-domain-model`'s rule — Value Objects are passed by value, never by pointer — is a direct, load-bearing consequence of this principle, not a style preference. `func (a *DataAsset) Sensitivity() SensitivityLevel` returning a plain value (not `*SensitivityLevel`) means any caller holding the returned value has an independent, safe copy: nothing the `DataAsset` does afterward, and nothing any concurrent goroutine does with its own copy, can reach back and change what the first caller is holding. Contrast this with what a `*SensitivityLevel` pointer would invite: two goroutines each holding "the same" pointer would actually be aliased to one shared, mutable cell — exactly the concurrency hazard `go-domain-model`'s "Pointer-to-Value-Object" anti-pattern exists to forbid, and exactly why the anti-pattern is correct even though Go's garbage collector makes the pointer itself perfectly memory-safe. Memory safety and value safety are different guarantees; immutability is what supplies the second one, and only a true (never-mutated-after-construction) Value Object can make that guarantee for free.

---

## Local vs. Global Identity: the Test for What Belongs Inside

Evans draws a second identity distinction, orthogonal to Entity-vs-Value-Object: even among Entities, an **Aggregate Root needs a global identifier** — findable and referenceable from anywhere in the system — while an **Entity that only exists as part of one Aggregate needs only a local identifier**, unique within that Aggregate, found exclusively by loading the root and traversing into it. A child Entity is never independently looked up by a query that doesn't first go through its root.

**The actual test, stated as a question to ask of every candidate collaborator inside an Aggregate:** would any code *outside* this Aggregate ever legitimately need to look this object up directly, by its own ID, independent of loading the root first? If no, the collaborator is either a Value Object or a locally-identified child Entity — never a second Repository-eligible root hiding inside the cluster it was supposed to belong to.

This repo has a live, unresolved instance of exactly this question, worth stating explicitly rather than silently assuming an answer: `SKILL.md`'s own Go sketch gestures at a `DataAsset` holding `entities []ExtractedEntity` without settling whether `ExtractedEntity` is a locally-identified child Entity or deserves to be its own Aggregate. Apply the test:

- **Does anything outside `DataAsset` need to fetch one specific `ExtractedEntity` directly** — a UI deep-link ("show me extraction result X"), a downstream service that reacts to individual extraction events rather than the asset as a whole, a query that filters across all `ExtractedEntity` rows regardless of which asset they belong to? If **yes**, `ExtractedEntity` needs global identity and structurally wants to be its own Aggregate, referenced from `DataAsset` by ID only (Rule 3) — and per `references/sizing-contention-and-concurrency.md`'s Eager-Loading-Trap section, `DataAsset` should answer "how many entities / does this asset have any high-confidence PII" by query, never by holding the collection in memory.
- **If nothing outside `DataAsset` ever needs that** — extraction results are only ever meaningful in the context of the asset that produced them, found by loading that asset and looking inside — `ExtractedEntity` is correctly a locally-identified child Entity: unique by an ID scoped to its parent `DataAsset`, with no independent Repository, found only by traversing the root.

This file does not settle which answer is correct for this repo's actual `ExtractedEntity` — that structural choice belongs to `references/go-implementation-patterns.md` and `references/worked-examples.md`, per `SKILL.md`'s own routing. What this section supplies is the test itself, so that choice is made by asking the right question rather than by whichever shape happened to get typed first.

---

## Value Objects Are Domain Primitives Too

This is the connection Shafi will care about most, because it resolves what could otherwise look like two competing vocabularies for the same idea. `access-control-model/references/domain-primitives-and-enforcement.md` already implements `TenantID`, `Permission`, and `Sensitivity` as **Domain Primitives** — types that are immutable, constructible only through a single validating constructor, and structurally unable to hold an invalid value once they exist. **This is not a separate concept from "Value Object" that happens to live in a security skill. It is the same concept, taught twice: once with a security framing (Secure by Design, in `access-control-model`), once with a general DDD framing (Evans, here).** A Domain Primitive is precisely a Value Object with the *totality* guarantee made explicit and load-bearing: immutable (already required of every Value Object), no identity (already required), and — the sharpening Secure by Design adds — validity is a *type* guarantee enforced once at construction, not a runtime check a caller might forget to run.

**This repo's own `SensitivityLevel` (`go-domain-model`) is a Value Object that is *not yet* a Domain Primitive, and the gap is instructive.** It is `type SensitivityLevel string` with an `IsValid()` method — but `SensitivityLevel("banana")` compiles and type-checks without complaint; invalidity is *representable*, merely *checkable* by a caller who remembers to call `IsValid()`. Contrast `access-control-model`'s `Sensitivity` (a closed `int` enum, constructible only via `NewSensitivity(raw string)`, whose four `switch` cases are the *only* way a valid instance comes into existence) — there, an invalid sensitivity level cannot be constructed at all, full stop. Both are Value Objects; only the second is a Domain Primitive. Applying the same discipline to `SensitivityLevel` — or to any new Aggregate-internal Value Object — is not importing a foreign security pattern into the domain layer; it is finishing the Value Object discipline this skill already asks for.

**Worked Go example — applying self-validating construction to an Aggregate-internal Value Object, `FilePath`:**

```go
// FilePath is a Value Object AND a Domain Primitive: the two words describe
// the same type from two angles. Immutable, no identity, and — the totality
// guarantee — no invalid FilePath can exist once constructed.
type FilePath struct {
    value string
}

func NewFilePath(raw string) (FilePath, error) {
    if raw == "" {
        return FilePath{}, fmt.Errorf("file path cannot be empty")
    }
    if strings.Contains(raw, "..") {
        return FilePath{}, fmt.Errorf("file path %q contains a path-traversal segment", raw)
    }
    if len(raw) > maxFilePathLength {
        return FilePath{}, fmt.Errorf("file path %q exceeds %d characters", raw, maxFilePathLength)
    }
    return FilePath{value: raw}, nil
}

func (p FilePath) String() string          { return p.value }
func (p FilePath) Equal(other FilePath) bool { return p.value == other.value }
```

Every point on `access-control-model`'s Assertion Checklist applies unchanged: can `FilePath` ever hold a value the domain considers dangerous once constructed (a `../../etc/passwd` traversal) — if so, it isn't yet a Domain Primitive, which is exactly why the `..` check exists above; is validity checked in more than one place — collapse to this one constructor, never re-validate ad hoc at call sites that happen to remember; does the Go zero value (`FilePath{}`) accidentally look valid — it does not, because `value: ""` fails the empty check the moment anyone tries to construct one legitimately, but a caller who skips `NewFilePath` entirely and writes `FilePath{value: "../../etc/passwd"}` directly (unexported field, same package only) bypasses it, which is exactly why the field must stay unexported outside the type's own package; and is the constructor's error return ever discarded (`fp, _ := NewFilePath(raw)`) — doing so silently reintroduces the exact illegal-state risk the whole pattern exists to prevent, in Go more sharply than in the book's exception-based source language, because Go offers no automatic propagation of a discarded error. This is not a second checklist to maintain — it is `access-control-model`'s existing checklist, applied to an Aggregate-internal type instead of an ABAC type, because the underlying pattern was never ABAC-specific to begin with.

---

## Rule 3 One Level Deeper: Value Objects Referencing Other Aggregates

`SKILL.md`'s Rule 3 states the mechanical form at the Aggregate Root: store another Aggregate's ID, never a live reference. Evans' own text extends this one level deeper than the root's own fields, and the current `SKILL.md` Go example (which only shows the root's own struct) would not catch the extended violation: **a Value Object nested inside the Aggregate that embeds a live reference to another Aggregate's Entity is the same boundary violation as the root doing it directly — it is just wearing a Value Object's syntax instead of the root's.**

```go
// Correct: a Value Object composed of other Value Objects, and an ID
// reference where it names another Aggregate — the same discipline as
// the root's own fields, applied one level deeper.
type StorageSourceSummary struct {
    storageSourceID StorageSourceID  // ID only
    displayName     string           // a denormalized copy, per the narrow
                                     // Exception 2 in invariants-and-consistency-boundaries.md
}

// Wrong: a Value Object smuggling a live Entity reference past the root's
// own boundary check — the root's struct fields alone would look correct;
// this violation is one level deeper and easy to miss on a surface review.
type StorageSourceSummary struct {
    source *StorageSource  // live reference to another Aggregate's root — same violation as
                           // the root holding *StorageSource directly, just nested
}
```

This does not forbid Value Objects composed of other Value Objects — that composition is safe and common (a `DateRange` built from two `Date` Value Objects, below, is exactly this shape) — the rule only bites when the referenced type is itself an Entity belonging to a *different* Aggregate. A review that only checks the Aggregate Root's own struct fields for stray pointers will miss this; the check has to walk into every nested Value Object's own fields as well.

---

## The Factory Pattern: When a Constructor Isn't Enough

`SKILL.md` never currently names the Factory pattern, even though this repo already implements one correctly. Evans' decision test is not "does the constructor have more than N parameters" — it's whether construction itself carries enough responsibility to deserve encapsulation separate from the object's ongoing lifecycle methods. A Factory (which in Go is usually a plain constructor *function*, not a separate Factory type) is warranted when construction needs to do at least one of:

1. **Enforce invariants spanning multiple objects created together** — not just validating the new object's own fields, but a rule that only makes sense across several objects coming into existence at once.
2. **Choose among several concrete implementations** — the constructing code must decide, based on input, which of multiple concrete shapes to build.
3. **Follow a materially different path for reconstitution-from-storage versus genuine creation** — because reconstitution must skip creation-time invariant checks and must never re-fire creation events.

**`go-domain-model`'s `NewDataAsset`/`Reconstitute` pair is already a textbook factory-method pair satisfying criterion 3 — correctly built, never previously credited as a Factory.** `NewDataAsset` validates identity, constructs a fully valid new instance, and records `DataAssetRegistered`; `Reconstitute` takes already-valid stored data, builds the same struct shape, and records nothing — exactly the "reconstitution needs a materially different path than creation" criterion Evans names. The skill's own comment ("conflating it with creation would double-fire events on every load") states the *consequence* of getting this right without ever naming *why* two separate functions were the correct call in the first place: this is Factory-pattern discipline, already present, previously unlabeled.

**A worked example of a genuinely more complex Factory case** (illustrative — no such requirement is currently specified elsewhere in this repo), satisfying criteria 1 and 2 together: suppose registering a new `DataAsset` from a connected `StorageSource` must, based on the file's detected MIME type, construct one of two *different* concrete Aggregate Root shapes — a `StructuredDataAsset` (carries a `SchemaID` and column-level classification) or an `UnstructuredDataAsset` (carries only asset-level classification) — and must simultaneously validate that the `StorageSource` referenced is actually active before either concrete type is allowed to exist at all (a cross-object invariant at construction time, not merely a single object's own field validation). A plain per-type constructor can't make that choice; a dedicated Factory is the correct home for it:

```go
// DataAssetFactory owns construction logic complex enough to deserve its own
// type — it decides between two concrete Aggregate shapes AND enforces an
// invariant (source must be active) that spans the new asset and an
// Aggregate it doesn't own, entirely at construction time, before either
// concrete DataAsset variant is allowed to exist.
type DataAssetFactory struct {
    sourceRepo StorageSourceRepository // read-only lookup, same shape as the
                                       // pre-transaction read in invariants-and-consistency-boundaries.md
}

func (f *DataAssetFactory) NewFromDetectedFile(
    ctx context.Context, id uuid.UUID, tenantID uuid.UUID, sourceID uuid.UUID,
    mimeType string, now time.Time,
) (DataAsset, error) {
    source, err := f.sourceRepo.FindByID(ctx, sourceID)
    if err != nil {
        return nil, fmt.Errorf("resolving storage source %s: %w", sourceID, err)
    }
    if !source.IsActive() {
        return nil, fmt.Errorf("cannot register asset against inactive source %s: %w", sourceID, ErrSourceInactive)
    }
    if isStructuredMIMEType(mimeType) {
        return NewStructuredDataAsset(id, tenantID, sourceID, now)
    }
    return NewUnstructuredDataAsset(id, tenantID, sourceID, now)
}
```

This is the escalation path from "a plain constructor function suffices" (the common case, `NewDataAsset`) to "a dedicated Factory type is warranted" (this case) — reserved for when construction logic genuinely doesn't have a single obvious home on either concrete type being built.

---

## The Specification Pattern: Naming a Recurring Business Rule

This is genuinely new content — no skill in this repo currently names or uses the Specification pattern. Evans introduces it to solve a specific, recurring failure: a business rule that legitimately needs to be checked in more than one place (a batch query filter, a command handler's validation guard, a UI-facing eligibility indicator) gets implemented three separate times, and the three implementations drift out of sync the first time the rule changes and someone updates only one of them.

**A Specification is an explicit, named, testable predicate object** — it answers "does this candidate satisfy the rule," and the same object is reused everywhere the rule is needed, instead of the rule being reimplemented per call site.

**A concrete, illustrative example in this repo's own compliance domain** (a plausible rule, not one currently specified elsewhere in this repo's artifacts — labeled accordingly): *a `DataAsset` is eligible for retention purge only if its `Sensitivity` is not `Restricted`, its retention period has elapsed, and it is not under an active legal hold.* This rule plausibly needs to be checked in three places that would otherwise drift: a nightly batch job selecting purge candidates, a `PurgeDataAsset` command handler's guard (never trust that the batch job's selection is still valid by the time the command executes), and a compliance dashboard's "eligible for purge" badge shown to a human reviewer.

```go
// RetentionPurgeEligibility is a Specification: a named, reusable predicate
// over a DataAsset, evaluated identically everywhere the rule is needed —
// not reimplemented per call site.
type RetentionPurgeEligibility struct {
    now time.Time
}

func (s RetentionPurgeEligibility) IsSatisfiedBy(a *DataAsset) bool {
    return a.Sensitivity() != SensitivityRestricted &&
        a.RetentionElapsed(s.now) &&
        !a.HasActiveLegalHold()
}
```

The command handler and the dashboard call `spec.IsSatisfiedBy(asset)` directly against an already-loaded `DataAsset` — a single, reused implementation. The batch job's SQL query is the one place a Specification's in-memory predicate doesn't translate for free: a query needs a SQL `WHERE` clause, not a Go closure. The honest answer here (worth stating rather than glossing over) is that a Specification does not eliminate the translation problem, it *localizes* it — either maintain the SQL predicate as a second, deliberately-paired implementation with one shared test suite asserting both agree on the same fixture data, or have the batch job select a broad candidate set by a cheap SQL filter and apply `IsSatisfiedBy` in memory as the authoritative check before acting. Either is legitimate; what the Specification pattern actually buys is that the *rule's logic* — what "eligible" means — has exactly one authoritative statement, and the command handler and the dashboard can never drift from each other, even if the batch query's SQL still has to be kept in sync by discipline rather than by the type system.

---

## Closure of Operations

An operation defined on a Value Object that returns the **same type** is easier to understand, test, and compose than one that degrades to bare primitive types — the caller never has to reason about an unfamiliar result shape, and the result can be fed straight into another operation of the same kind.

**Worked Go example — a `DateRange` Value Object**, illustrating the pattern this repo's existing Value Object examples (`SensitivityLevel`, a simple comparable enum) don't currently demonstrate:

```go
// DateRange is a Value Object composed of two Value Objects (start, end) —
// itself a legitimate Value-Object-referencing-Value-Object composition,
// distinct from the Entity-reference violation covered above.
type DateRange struct {
    start, end time.Time
}

func NewDateRange(start, end time.Time) (DateRange, error) {
    if end.Before(start) {
        return DateRange{}, fmt.Errorf("date range end %s before start %s", end, start)
    }
    return DateRange{start: start, end: end}, nil
}

// Overlap exhibits Closure of Operations: it returns a DateRange, not a bare
// pair of time.Time values — the result composes directly with any other
// DateRange operation, and the caller never has to reason about a different,
// unfamiliar shape just because this particular operation happened to
// combine two ranges.
func (r DateRange) Overlap(other DateRange) (DateRange, bool) {
    start := r.start
    if other.start.After(start) {
        start = other.start
    }
    end := r.end
    if other.end.Before(end) {
        end = other.end
    }
    if end.Before(start) {
        return DateRange{}, false // no overlap
    }
    return DateRange{start: start, end: end}, true
}

func (r DateRange) Contains(t time.Time) bool {
    return !t.Before(r.start) && !t.After(r.end)
}
```

A plausible, illustrative use in this repo's own compliance domain: a `DataAsset`'s remediation window (the period during which a detected `ComplianceGap` must be resolved) and a compliance reviewer's active audit period are each naturally a `DateRange` — `remediationWindow.Overlap(auditPeriod)` composes directly into a further `Contains(now)` check without ever dropping down to a bare pair of timestamps the caller has to re-validate or re-interpret. This is the general shape Closure of Operations names: a Value Object's own operations stay in its own type's vocabulary, all the way through a chain of composition.
