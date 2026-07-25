# Value Objects and Domain Events — Worked Examples

Full worked material referenced from `SKILL.md`'s "Value Objects" and "Domain Events as Types" sections.

---

## Value Objects

Value Objects are immutable, compared by value, and have no identity. Implement them as small value types (often a defined string/int) with behaviour attached.

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

func (s SensitivityLevel) IsValid() bool {
    switch s {
    case SensitivityPublic, SensitivityInternal, SensitivityConfidential, SensitivityRestricted:
        return true
    }
    return false
}

func (s SensitivityLevel) rank() int {
    return map[SensitivityLevel]int{
        SensitivityUnclassified: 0, SensitivityPublic: 1, SensitivityInternal: 2,
        SensitivityConfidential: 3, SensitivityRestricted: 4,
    }[s]
}

func (s SensitivityLevel) IsHigherThan(other SensitivityLevel) bool { return s.rank() > other.rank() }
```

A Value Object is never a pointer in the domain — passing it by value is cheap, prevents aliasing bugs, and keeps it immutable.

---

## Domain Events as Types

Domain Events are plain immutable value types implementing a tiny interface. The serialization contract is owned by `event-schema-design`; the domain only defines the in-memory shape.

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

// Compile-time assertion: forces the compiler to check DataAssetClassified's method set against
// DomainEvent right here, at the type that must satisfy it (see go-project-structure's Minimalist
// Interfaces). Add one next to every Domain Event type, not just this one.
var _ DomainEvent = DataAssetClassified{}
```
