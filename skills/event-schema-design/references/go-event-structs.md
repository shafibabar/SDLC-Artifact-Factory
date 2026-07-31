# Go Event Struct Conventions Reference

This file is self-contained. It defines the canonical Go struct pattern for
CloudEvents events produced and consumed on this platform, covering:
1. The CloudEvents envelope struct (mandatory wrapper)
2. Payload struct conventions
3. JSON serialisation discipline
4. The parse-don't-validate approach for consumers
5. Event factory function pattern
6. Test helper for constructing valid events in tests

---

## 1. The CloudEvents Envelope Struct

The envelope carries the five required CloudEvents attributes and the optional
attributes this platform uses. The `Data` field is `json.RawMessage` — the
envelope struct does not know the shape of the payload, keeping the producer
and consumer domain code free to work with strongly-typed payload structs.

```go
// Package cloudevents provides the canonical CloudEvents 1.0 envelope for
// this platform. Import this package from any service that produces or
// consumes events.
package cloudevents

import (
    "encoding/json"
    "time"

    "github.com/google/uuid"
)

// Event is the CloudEvents 1.0 envelope. All fields except DataSchema are
// required; omitempty is absent on required fields to make serialisation
// failures visible as explicit zero values rather than silent omissions.
type Event struct {
    SpecVersion     string          `json:"specversion"`
    ID              uuid.UUID       `json:"id"`
    Source          string          `json:"source"`
    Type            string          `json:"type"`
    DataContentType string          `json:"datacontenttype"`

    // Optional attributes used by this platform
    Subject    string          `json:"subject,omitempty"`
    Time       time.Time       `json:"time,omitempty"`
    DataSchema string          `json:"dataschema,omitempty"`

    // Data holds the event payload as raw JSON. The producing package
    // marshals its payload struct into Data; the consuming package
    // unmarshals Data into its own payload struct.
    Data json.RawMessage `json:"data"`
}
```

**Why `json.RawMessage` for `Data`?**

If the envelope used `interface{}` or `any`, callers would need to type-assert
after unmarshalling the outer envelope, losing type safety. With
`json.RawMessage`, the producer marshals a strongly-typed payload struct once
(`json.Marshal(payload)` → `Data`) and the consumer unmarshals `Data` once
(`json.Unmarshal(evt.Data, &payload)` → strongly-typed payload struct). The
envelope struct itself never touches the payload's fields.

**`omitempty` discipline:**

Required CloudEvents attributes (`specversion`, `id`, `source`, `type`,
`datacontenttype`) do **not** carry `omitempty`. If any of these fields is the
zero value when the event is serialised, the resulting JSON is a schema
violation — an explicit zero value in the output makes the bug visible
immediately. Optional attributes (`subject`, `time`, `dataschema`) carry
`omitempty` so they serialise cleanly when absent.

---

## 2. Payload Structs

Each event type gets its own payload struct in the package that owns the
Bounded Context. The struct is separate from the envelope to keep the domain
package independent from the `cloudevents` package.

```go
// Package dataasset is the domain package for the Data Asset Management
// Bounded Context.
package dataasset

import (
    "time"
    "github.com/google/uuid"
)

// ClassifiedPayload is the data payload for the DataAssetClassified event.
// All fields carry json tags; omitempty is used ONLY for genuinely optional
// fields whose absence conveys meaningful information (previousLevel may be
// absent if the asset has no prior classification).
type ClassifiedPayload struct {
    AggregateID      uuid.UUID  `json:"aggregateId"`
    TenantID         uuid.UUID  `json:"tenantId"`
    SensitivityLevel string     `json:"sensitivityLevel"`
    ClassifiedBy     uuid.UUID  `json:"classifiedBy"`
    ClassifiedAt     time.Time  `json:"classifiedAt"`
    PreviousLevel    *string    `json:"previousLevel,omitempty"`
}
```

**Payload struct rules:**

- All fields are exported (uppercase). Unexported fields silently omit from
  serialisation — a hard-to-diagnose bug.
- Use concrete types (`uuid.UUID`, `time.Time`) rather than `string` for
  fields that have a defined format. `uuid.UUID` serialises to the standard
  hyphenated string and deserialises with format validation — free validation
  at parse time without explicit guards.
- A `*string` (pointer to string) for an optional field whose absence is
  semantically meaningful (`PreviousLevel` is `nil` when there is no prior
  classification, distinct from an empty string "").
- No derived or computed fields. `AssetName` does not appear in the payload —
  it is derivable from the aggregate ID via a query and would become stale.

---

## 3. Parse-Don't-Validate for Consumers

A consumer that receives a raw CloudEvents envelope does not check individual
field values with `if` statements after unmarshalling into a map. Instead, it
unmarshals directly into a strongly-typed struct — the struct definition
*is* the validation contract.

**Anti-pattern — map-based validation:**
```go
// Do NOT do this
var raw map[string]interface{}
json.Unmarshal(evt.Data, &raw)
if v, ok := raw["sensitivityLevel"]; !ok || v == "" {
    return errors.New("missing sensitivityLevel")
}
level := raw["sensitivityLevel"].(string) // type assertion can panic
```

**Correct — parse-don't-validate:**
```go
// Consumer in the Compliance Intelligence Bounded Context
func (h *ClassificationEventHandler) Handle(ctx context.Context, evt cloudevents.Event) error {
    var payload dataasset.ClassifiedPayload
    if err := json.Unmarshal(evt.Data, &payload); err != nil {
        // A well-formed event that fails to unmarshal into the expected struct
        // is a schema violation — route to the Dead Letter Queue, do not retry
        return fmt.Errorf("malformed DataAssetClassified payload: %w", err)
    }
    // payload.AggregateID, payload.SensitivityLevel etc. are now strongly typed
    // and guaranteed non-zero by the uuid.UUID and string types respectively
    return h.projector.Project(ctx, payload)
}
```

By unmarshalling into `ClassifiedPayload`, the Go runtime validates:
- `aggregateId` and `classifiedBy` are valid UUIDs (or the unmarshal fails)
- `classifiedAt` is a valid RFC 3339 timestamp (or the unmarshal fails)
- All exported fields without `omitempty` are present (or the unmarshal sets
  them to zero values — a second reason to avoid `omitempty` on required fields)

Unknown fields in the incoming JSON are silently ignored (`json.Decoder`'s
default behaviour), implementing the Tolerant Reader pattern automatically.

---

## 4. Event Factory Function Pattern

Each event type has a factory function in its Bounded Context's domain package.
The factory function:
- Accepts only domain-typed arguments (no raw strings for UUIDs)
- Generates the envelope ID from `uuid.New()` (never from a caller parameter)
- Sets `specversion`, `source`, `type`, and `datacontenttype` as constants
- Marshals the payload struct into `json.RawMessage`

```go
package dataasset

import (
    "encoding/json"
    "fmt"
    "time"

    "github.com/google/uuid"
    "github.com/your-org/sdlc-factory/pkg/cloudevents"
)

const (
    // ServiceSource identifies this service in the CloudEvents source attribute.
    // Version is injected at build time via ldflags:
    //   -ldflags="-X github.com/your-org/.../dataasset.ServiceVersion=v1.2.0"
    ServiceVersion = "dev"
    serviceSource  = "/data-asset-management/" + ServiceVersion

    // EventTypeClassified is the CloudEvents type for a DataAssetClassified event.
    EventTypeClassified = "com.sdlc-factory.data-asset-management.data-asset.classified"

    // RegistryURL is the Apicurio Registry base URL; set via environment variable.
    registryGroupURL = "http://apicurio-registry.platform.svc.cluster.local:8080" +
        "/apis/registry/v2/groups/events/artifacts/"
)

// NewDataAssetClassifiedEvent constructs a validated CloudEvents envelope for
// a DataAssetClassified domain event.
func NewDataAssetClassifiedEvent(
    aggregateID uuid.UUID,
    tenantID uuid.UUID,
    level string,
    classifiedBy uuid.UUID,
    classifiedAt time.Time,
    previousLevel *string,
) (cloudevents.Event, error) {
    payload := ClassifiedPayload{
        AggregateID:      aggregateID,
        TenantID:         tenantID,
        SensitivityLevel: level,
        ClassifiedBy:     classifiedBy,
        ClassifiedAt:     classifiedAt,
        PreviousLevel:    previousLevel,
    }
    data, err := json.Marshal(payload)
    if err != nil {
        return cloudevents.Event{}, fmt.Errorf("marshal ClassifiedPayload: %w", err)
    }
    return cloudevents.Event{
        SpecVersion:     "1.0",
        ID:              uuid.New(),      // Always generated — never caller-supplied
        Source:          serviceSource,
        Type:            EventTypeClassified,
        DataContentType: "application/json",
        Subject:         aggregateID.String(),
        Time:            classifiedAt,
        DataSchema:      registryGroupURL + EventTypeClassified,
        Data:            data,
    }, nil
}
```

**Rules for factory functions:**

- Return `(cloudevents.Event, error)` — the error surface covers marshal
  failure, which should be treated as a programming error (panicking is also
  acceptable here, since a correctly typed payload struct should never fail
  to marshal).
- The envelope `ID` is always `uuid.New()` inside the factory — it is not a
  parameter. Callers never supply the event ID; the factory owns uniqueness.
- `Time` in the envelope is the time the *domain event occurred* — passed in
  from the Aggregate's event emission, not from `time.Now()` inside the
  factory. The factory is a construction helper, not a clock.
- One factory function per event type — not a generic factory parameterised by
  event type, which would lose the compile-time guarantee that required payload
  fields are present.

---

## 5. Test Helper for Valid Events

Tests that need a valid event should use the factory function, not hand-build a
`cloudevents.Event` struct literal. A test that hand-builds the struct is not
testing the factory's output and will drift from it silently.

```go
// testdata_test.go — in the dataasset package, available only in tests
package dataasset_test

import (
    "testing"
    "time"

    "github.com/google/uuid"
    "github.com/your-org/sdlc-factory/internal/dataasset"
)

// MustNewClassifiedEvent constructs a DataAssetClassified event for use in
// tests. Fails the test immediately if construction fails.
func MustNewClassifiedEvent(t *testing.T, opts ...func(*classifiedEventOpts)) dataasset.ClassifiedPayload {
    t.Helper()
    o := &classifiedEventOpts{
        aggregateID:      uuid.New(),
        tenantID:         uuid.New(),
        sensitivityLevel: "Confidential",
        classifiedBy:     uuid.New(),
        classifiedAt:     time.Now(),
    }
    for _, opt := range opts {
        opt(o)
    }
    evt, err := dataasset.NewDataAssetClassifiedEvent(
        o.aggregateID,
        o.tenantID,
        o.sensitivityLevel,
        o.classifiedBy,
        o.classifiedAt,
        o.previousLevel,
    )
    if err != nil {
        t.Fatalf("MustNewClassifiedEvent: %v", err)
    }
    return evt
}

type classifiedEventOpts struct {
    aggregateID      uuid.UUID
    tenantID         uuid.UUID
    sensitivityLevel string
    classifiedBy     uuid.UUID
    classifiedAt     time.Time
    previousLevel    *string
}

// WithSensitivityLevel sets the sensitivity level on a test event.
func WithSensitivityLevel(level string) func(*classifiedEventOpts) {
    return func(o *classifiedEventOpts) { o.sensitivityLevel = level }
}

// WithPreviousLevel sets a non-nil previousLevel on a test event.
func WithPreviousLevel(level string) func(*classifiedEventOpts) {
    return func(o *classifiedEventOpts) { o.previousLevel = &level }
}
```

**Usage in a table-driven test:**

```go
func TestClassificationProjector(t *testing.T) {
    tests := []struct {
        name          string
        event         cloudevents.Event
        expectLevel   string
    }{
        {
            name:        "projects Restricted level",
            event:       MustNewClassifiedEvent(t, WithSensitivityLevel("Restricted")),
            expectLevel: "Restricted",
        },
        {
            name:        "projects transition from Internal to Confidential",
            event:       MustNewClassifiedEvent(t,
                WithSensitivityLevel("Confidential"),
                WithPreviousLevel("Internal"),
            ),
            expectLevel: "Confidential",
        },
    }
    for _, tc := range tests {
        t.Run(tc.name, func(t *testing.T) {
            // ... invoke projector, assert tc.expectLevel ...
        })
    }
}
```

The functional-options pattern (`WithSensitivityLevel`, `WithPreviousLevel`)
keeps the test helper extensible: adding a new option for a new field does not
break existing tests.
