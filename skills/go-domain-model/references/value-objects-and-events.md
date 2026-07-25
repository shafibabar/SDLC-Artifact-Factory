# Value Objects and Domain Events — Worked Examples

Full worked material referenced from `SKILL.md`'s "Value Object Immutability Standard" and "Domain Event Standard" sections. Self-contained — reads without the parent body already in context.

---

## Value Objects

A Value Object is immutable, compared by value, and has no identity. Implement it as a small value type (often a defined string/int, or a struct of unexported fields) with behaviour attached, always passed by value.

```go
// internal/domain/sensitivity.go
package domain

type SensitivityLevel string

const (
    SensitivityUnclassified SensitivityLevel = ""
    SensitivityPublic       SensitivityLevel = "Public"
    SensitivityInternal     SensitivityLevel = "Internal"
    SensitivityConfidential SensitivityLevel = "Confidential"
    SensitivityRestricted   SensitivityLevel = "Restricted"
)

// sensitivityRank is a package-level lookup table, not rebuilt on every call —
// the map literal only pays its allocation cost once, at package init.
var sensitivityRank = map[SensitivityLevel]int{
    SensitivityUnclassified: 0, SensitivityPublic: 1, SensitivityInternal: 2,
    SensitivityConfidential: 3, SensitivityRestricted: 4,
}

// IsValid is deliberately a switch, not "does it appear in sensitivityRank" — the
// rank table includes SensitivityUnclassified (rank 0, so comparisons still order
// correctly), but Unclassified is not itself a valid *assigned* classification.
func (s SensitivityLevel) IsValid() bool {
    switch s {
    case SensitivityPublic, SensitivityInternal, SensitivityConfidential, SensitivityRestricted:
        return true
    }
    return false
}

func (s SensitivityLevel) IsHigherThan(other SensitivityLevel) bool {
    return sensitivityRank[s] > sensitivityRank[other]
}
```

Because `SensitivityLevel` is a defined `string` — a comparable underlying type — two values compare correctly with plain `==`, and it is safe as a map key. This is the common, cheap case and the one to prefer whenever the Value Object's data fits a primitive or a small comparable struct.

### The Comparability Trap: a Value Object With a Slice or Map Field

Go structs are comparable with `==` only when **every** field is itself comparable. Slices, maps, and functions are not comparable — a struct containing one of them fails to compile at the `==` site, not merely at runtime (Donovan & Kernighan, ch. 4, on slice/map reference semantics: neither type supports `==` except against a literal `nil`). This is a real, common shape once a Value Object needs to hold a small collection — a set of tags, a list of allowed formats:

```go
// A Value Object that legitimately needs a collection field.
type AllowedFormats struct {
    formats []string // unexported — still immutable from the outside, but not ==-comparable
}

func NewAllowedFormats(f []string) AllowedFormats {
    cp := make([]string, len(f))
    copy(cp, f) // defensive copy — the caller's backing array must never alias into the VO
    sort.Strings(cp)
    return AllowedFormats{formats: cp}
}

// af1 == af2 // does NOT compile: "invalid operation: struct containing []string cannot be compared"

// Equals is the required substitute — explicit, and cheap relative to reflect.DeepEqual.
func (a AllowedFormats) Equals(other AllowedFormats) bool {
    if len(a.formats) != len(other.formats) {
        return false
    }
    for i, f := range a.formats {
        if f != other.formats[i] {
            return false
        }
    }
    return true
}
```

Two consequences follow from the same fact: first, `AllowedFormats` cannot be used as a map key or compared with `==` anywhere, including inside a table-driven test's `want` comparison — the test must call `.Equals(...)`, not `==` or a bare `reflect.DeepEqual` (which works, but is reflection-based and the wrong default for a hot path per `go-performance-optimization`; reserve it for test code, not production comparisons). Second, the defensive copy in the constructor is not optional — without it, `formats` aliases the caller's original slice, and a caller mutating that slice after construction would silently mutate the "immutable" Value Object through the back door. **Prefer a comparable representation (a fixed-size array, a single sorted string, a small struct of primitives) over a slice/map field whenever the domain data permits it** — it is the difference between `==` working for free and every equality call site needing to remember to call `Equals` instead.

---

## Domain Events as Types

A Domain Event is a plain immutable value type implementing a tiny interface. Its exact shape is fixed: `AggregateID` (which instance), a tenant-scoping field where the domain is multi-tenant, business-specific fields describing what changed, and `OccurredAt time.Time` (when — always passed in, never `time.Now()` inside the event's own construction). The serialization contract for wire transport is owned by `event-schema-design`; the domain only defines this in-memory shape.

```go
// internal/domain/events.go
package domain

type DomainEvent interface{ EventType() string }

type DataAssetClassified struct {
    AggregateID  uuid.UUID
    TenantID     uuid.UUID
    Sensitivity  SensitivityLevel
    ClassifiedBy uuid.UUID
    OccurredAt   time.Time
}

func (DataAssetClassified) EventType() string { return "DataAssetClassified" }

// Compile-time assertion: forces the compiler to check DataAssetClassified's method set
// against DomainEvent right here, at the type that must satisfy it (go-project-structure's
// Minimalist Interfaces convention, applied to events). Add one beside every event type.
var _ DomainEvent = DataAssetClassified{}
```

### Past-Tense Naming Standard

| Rule | Good | Bad | Why |
|---|---|---|---|
| Past tense of the state change | `DataAssetClassified` | `ClassifyDataAsset` | The event reports a fact that already happened; the imperative form is the *Command* that caused it, a different concept with a different name in the application layer |
| Aggregate-qualified | `DataAssetClassified`, `DataAssetRegistered` | `Classified`, `Registered` | An unqualified past participle collides the moment a second Aggregate in the same Bounded Context has an analogous transition (`SourceRegistered` vs `DataAssetRegistered`) |
| One type per transition | A distinct struct for `Classified` vs `Registered` vs `Reclassified` | A single generic `DataAssetChanged{Field, OldValue, NewValue}` for every mutation | A generic event forces every consumer to switch on `Field` and type-assert `OldValue`/`NewValue`; a specific event gives consumers typed fields the same way a specific error type does (`references/aggregate-invariant-enforcement.md`) |

### Event-Emission Completeness Checklist

Run this check against **every** exported mutating method on the Aggregate, not just the ones that "obviously" need an event:

1. Does a successful call to this method record exactly one event? (Not zero — a silent successful mutation is invisible to every downstream consumer, including the outbox. Not two — a double-fire duplicates the fact for consumers expecting one occurrence per transition.)
2. Is the event recorded **after** every validation check has passed and **as part of** the same method body that performed the mutation — never constructed by a caller, never deferred to a later "event builder" step that could drift from the actual state change?
3. Does a rejected call to this method record **zero** events? (A validation failure that still appends an event reports a fact that never became true.)
4. Is the event's own field set derived from the method's actual parameters/resulting state, not recomputed independently in a way that could disagree with what was just written to the struct's fields?

A domain-model unit test (`SKILL.md`'s Domain-Model Unit-Test Standard) verifies points 1 and 3 directly via `PullEvents()` counts on both the success and failure branches of every table-driven case — this checklist is the design-time version of the same two checks, applied while writing the method rather than while testing it.
