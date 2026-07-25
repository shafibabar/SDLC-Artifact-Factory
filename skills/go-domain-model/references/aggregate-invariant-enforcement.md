# Aggregate Invariant Enforcement — Worked Examples

Full worked material referenced from `SKILL.md`'s "Aggregate Root: The Invariant-Enforcement Standard", "Receiver-Type Standard", and "Invariant-Violation Error Standard" sections. Self-contained — reads without the parent body already in context.

---

## The Failing-Constructor Pattern, and the Anti-Pattern It Replaces

**Wrong** — a constructor that always succeeds, pushing invariant enforcement onto every caller:

```go
// ANTI-PATTERN: no error path, invariant checking left to whoever remembers.
func NewDataAsset(id, tenantID, sourceID uuid.UUID) *DataAsset {
    return &DataAsset{id: id, tenantID: tenantID, sourceID: sourceID, version: 1}
}
```

Nothing stops `NewDataAsset(uuid.Nil, uuid.Nil, uuid.Nil)` from compiling and running. The zero-`uuid.UUID` asset is now live in memory, indistinguishable from a valid one until something downstream happens to check `id != uuid.Nil` — if anything ever does.

**Right** — the constructor is itself an invariant-checked operation, exactly like any mutating method:

```go
func NewDataAsset(id, tenantID, sourceID uuid.UUID, now time.Time) (*DataAsset, error) {
    if id == uuid.Nil || tenantID == uuid.Nil {
        return nil, ErrMissingIdentity // nil *DataAsset — nothing half-built escapes
    }
    a := &DataAsset{id: id, tenantID: tenantID, sourceID: sourceID, version: 1}
    a.recordEvent(DataAssetRegistered{AggregateID: id, TenantID: tenantID, OccurredAt: now})
    return a, nil
}
```

The caller cannot obtain a `*DataAsset` without either a valid one or an explicit error — there is no third outcome. This is the same discipline `go-error-handling`'s nil-interface-footgun guidance protects from the opposite direction (never return a typed-nil through an `error`-typed result); here the rule runs the other way: never return a non-nil `*T` alongside a non-nil `error`, and never a nil `*T` alongside a nil `error`. Exactly one of the pair is non-nil, always.

### Table-Driven Test Proving the Invariant Is Actually Enforced

Per `SKILL.md`'s Domain-Model Unit-Test Standard, this table asserts all three axes — invariant match, immutability-on-reject, event-count-both-ways — for `Classify`:

```go
func TestDataAsset_Classify(t *testing.T) {
    fixedNow := time.Date(2026, 7, 24, 0, 0, 0, 0, time.UTC)

    tests := []struct {
        name       string
        start      SensitivityLevel
        target     SensitivityLevel
        wantErr    error   // nil means success expected
        wantAsErr  bool    // true: assert with errors.As instead of errors.Is
    }{
        {name: "unclassified to public succeeds", start: SensitivityUnclassified, target: SensitivityPublic},
        {name: "invalid level rejected", start: SensitivityPublic, target: SensitivityLevel("bogus"), wantErr: ErrInvalidSensitivity},
        {name: "downgrade rejected", start: SensitivityRestricted, target: SensitivityPublic, wantAsErr: true},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            a, err := NewDataAsset(uuid.New(), uuid.New(), uuid.New(), fixedNow)
            if err != nil {
                t.Fatalf("fixture setup: %v", err)
            }
            a.sensitivity = tt.start // test-only direct field set; production code never does this
            _ = a.PullEvents()       // drain the NewDataAsset registration event before the assertion

            err = a.Classify(tt.target, uuid.New(), fixedNow)

            switch {
            case tt.wantErr == nil && !tt.wantAsErr:
                if err != nil {
                    t.Fatalf("got error %v, want success", err)
                }
                events := a.PullEvents()
                if len(events) != 1 {
                    t.Fatalf("got %d events, want exactly 1", len(events)) // event-emission completeness
                }
                if _, ok := events[0].(DataAssetClassified); !ok {
                    t.Fatalf("got event type %T, want DataAssetClassified", events[0])
                }
            case tt.wantAsErr:
                var dg *ErrSensitivityDowngrade
                if !errors.As(err, &dg) {
                    t.Fatalf("got %v, want *ErrSensitivityDowngrade", err)
                }
                if a.sensitivity != tt.start {
                    t.Fatalf("sensitivity mutated on rejected call: got %v, want unchanged %v", a.sensitivity, tt.start) // immutability-on-reject
                }
                if events := a.PullEvents(); len(events) != 0 {
                    t.Fatalf("got %d events on rejected call, want 0", len(events))
                }
            default:
                if !errors.Is(err, tt.wantErr) {
                    t.Fatalf("got %v, want %v", err, tt.wantErr)
                }
                if a.sensitivity != tt.start {
                    t.Fatalf("sensitivity mutated on rejected call: got %v, want unchanged %v", a.sensitivity, tt.start)
                }
                if events := a.PullEvents(); len(events) != 0 {
                    t.Fatalf("got %d events on rejected call, want 0", len(events))
                }
            }
        })
    }
}
```

The two rejected-call branches each check three things, not one: the exact error (via `errors.Is` for the sentinel case, `errors.As` for the typed case), that `sensitivity` is byte-for-byte unchanged, and that `PullEvents()` drains zero events. A test that only asserts `err != nil` would pass even if `Classify` mutated state before returning the error — it is the immutability and event-count assertions that actually prove "validate before mutate" holds, not the error check alone.

---

## The Method-Set Rule, Precisely

Per the Go specification and Donovan & Kernighan (ch. 6.2): the method set of type `T` contains every method declared with receiver `T`. The method set of `*T` contains every method declared with receiver `T` **or** `*T` — the pointer type's method set is always a superset of the value type's. This is not a convention the compiler is lenient about; it is enforced at every interface-satisfaction check.

```go
type DataAsset struct{ /* ... */ }

func (a *DataAsset) Classify(level SensitivityLevel, by uuid.UUID, now time.Time) error { /* ... */ }

type Classifier interface {
    Classify(level SensitivityLevel, by uuid.UUID, now time.Time) error
}

var _ Classifier = (*DataAsset)(nil) // compiles: *DataAsset's method set includes Classify

var a DataAsset
var _ Classifier = a // does NOT compile:
// "cannot use a (variable of type DataAsset) as Classifier value:
//  DataAsset does not implement Classifier (method Classify has pointer receiver)"
```

The value `a` cannot satisfy `Classifier` no matter how the call site is written — the fix is never a cast, it is passing `&a` (or, for an Aggregate Root, never having a bare value in scope in the first place, since every constructor already returns `*T`). Harsanyi's functions-and-methods chapter (ch. 6) frames the practical consequence: **once any one method of a type needs a pointer receiver (because it mutates, or the type must not be copied), every method on that type should use a pointer receiver, even ones that technically wouldn't need to** — a mixed method set is a standing trap for the next person who writes `var a DataAsset` expecting the full API to be available and discovers, only at a call site far from the type definition, that half of it isn't.

**When would a value receiver still be correct even on a largish struct?** Only when the type is a genuine Value Object: no method mutates, copying it is the entire point (immutability, safe concurrent sharing, map-key usability), and its size is small enough that copying isn't a measurable cost (`SensitivityLevel`, a defined `string`, is the cheapest possible case). A large *immutable* Value Object is the one case worth checking with a benchmark before deciding — see `go-performance-optimization` — but the receiver-type decision itself is still binary and still governed by mutability first, size second.

---

## One Error Type Per Invariant — the Full Contrast

**Wrong** — every invariant funneled through one bucket type, or through `errors.New` with no attached data:

```go
// ANTI-PATTERN A: stringly-typed, no structured data recoverable.
if a.sensitivity.IsHigherThan(level) {
    return errors.New("cannot downgrade sensitivity")
}

// ANTI-PATTERN B: a generic bucket "solves" the missing-data problem by
// trading static field access for a map a caller has to know the keys of.
type InvariantViolationError struct {
    Rule    string
    Details map[string]any
}
if a.sensitivity.IsHigherThan(level) {
    return &InvariantViolationError{Rule: "no-silent-downgrade", Details: map[string]any{"from": a.sensitivity, "to": level}}
}
// caller: details, ok := err.(*InvariantViolationError); from, ok := details.Details["from"].(SensitivityLevel)
// — two type assertions deep, no compiler help if a key is renamed.
```

**Right** — a named type per invariant that carries its own violating values as real fields:

```go
// internal/domain/errors.go
type ErrSensitivityDowngrade struct {
    AssetID  uuid.UUID
    From, To SensitivityLevel
}

func (e *ErrSensitivityDowngrade) Error() string {
    return fmt.Sprintf("data asset %s: cannot downgrade sensitivity %s → %s without explicit reclassification",
        e.AssetID, e.From, e.To)
}

// caller — one type-safe extraction, no map, no second assertion:
var dg *ErrSensitivityDowngrade
if errors.As(err, &dg) {
    audit.Log("sensitivity-downgrade-blocked", "asset", dg.AssetID, "from", dg.From, "to", dg.To)
}
```

### Classifying the `DataAsset` Error Roster

| Invariant | Carries data? | Standard |
|---|---|---|
| Missing identity (`id`/`tenantID` nil) | No — the fact alone is the whole message | Sentinel: `ErrMissingIdentity` |
| Invalid sensitivity level | No — any invalid input produces the same fact | Sentinel: `ErrInvalidSensitivity` |
| Silent downgrade attempted | Yes — `From`/`To` are needed by the caller (audit log, 409 body) | Typed: `*ErrSensitivityDowngrade{AssetID, From, To}` |
| (Hypothetical) classification by a user outside the asset's tenant | Yes — the offending `by` and the asset's `tenantID` both matter | Typed: `*ErrCrossTenantClassification{AssetID, TenantID, ActorID}` |

The dividing line is mechanical, not judgment-based: **if a caller could plausibly want to read a specific value out of the failure, it is a typed error with that value as a field — never a sentinel, and never a shared generic-bucket type.** `go-error-handling`'s sentinel-vs-typed guidance states the general rule (`references/worked-example.md` there); this table is the domain-specific application of it to one Aggregate's full invariant roster, not a duplicate of the general rule itself.
