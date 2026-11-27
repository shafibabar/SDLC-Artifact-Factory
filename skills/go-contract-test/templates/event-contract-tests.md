# Event Contract Tests: Helper and Skeletons

Self-contained. Copy when a Go service publishes or consumes events. These tests have no build tag and run in `make ci`. Compiled and run on Go 1.27.4 with `github.com/santhosh-tekuri/jsonschema/v6` v6.0.3 (the code is the standard example's; replace the names).

Layout the tests and `./scripts/check-event-compatibility.sh` share:

```text
schemas/events/<context>/<event>/1.json, 2.json, ...   one file per published version, never edited
schemas/events/modes.txt                               "<context>/<event> <MODE>", from the event design
```

## Helper: copy unchanged into `internal/test/contract/`

### `internal/test/contract/events.go`

```go
// Package contract is test support for contract tests. It must never be
// imported by code that ships.
package contract

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/santhosh-tekuri/jsonschema/v6"
)

// ValidateEvent checks one CloudEvents JSON event against the schema file its
// dataschema attribute names: <schemaRoot>/<context>/<event>/<version>.json,
// taken from the last three segments of the URI. Formats are asserted, and a
// field the schema does not declare is an error, so a producer cannot emit
// what it has not published.
func ValidateEvent(schemaRoot string, event []byte) error {
	var envelope struct {
		DataSchema string          `json:"dataschema"`
		Data       json.RawMessage `json:"data"`
	}
	if err := json.Unmarshal(event, &envelope); err != nil {
		return fmt.Errorf("event is not JSON: %w", err)
	}
	segments := strings.Split(strings.TrimRight(envelope.DataSchema, "/"), "/")
	if len(segments) < 3 {
		return fmt.Errorf("dataschema %q does not end in <context>/<event>/<version>", envelope.DataSchema)
	}
	tail := segments[len(segments)-3:]
	file := filepath.Join(schemaRoot, tail[0], tail[1], tail[2]+".json")
	raw, err := os.ReadFile(file)
	if err != nil {
		return fmt.Errorf("dataschema %q names no schema file: %w", envelope.DataSchema, err)
	}
	var schema any
	if err := json.Unmarshal(raw, &schema); err != nil {
		return fmt.Errorf("%s is not JSON: %w", file, err)
	}
	// Validate the bytes as sent, not the Go value they were built from.
	data, err := jsonschema.UnmarshalJSON(bytes.NewReader(envelope.Data))
	if err != nil {
		return fmt.Errorf("event data is not JSON: %w", err)
	}
	for name, doc := range map[string]any{"published": schema, "closed": closed(schema)} {
		compiler := jsonschema.NewCompiler()
		compiler.AssertFormat() // without this a bad uuid or date-time passes
		if err := compiler.AddResource(name+".json", doc); err != nil {
			return fmt.Errorf("%s: %w", file, err)
		}
		compiled, err := compiler.Compile(name + ".json")
		if err != nil {
			return fmt.Errorf("%s: %w", file, err)
		}
		if err := compiled.Validate(data); err != nil {
			return fmt.Errorf("event does not match %s (%s copy): %w", file, name, err)
		}
	}
	return nil
}

// closed returns a copy with additionalProperties:false in every object
// schema that lists properties. The published file stays open for readers.
func closed(schema any) any {
	object, ok := schema.(map[string]any)
	if !ok {
		return schema
	}
	out := make(map[string]any, len(object)+1)
	for key, value := range object {
		switch key {
		case "properties", "patternProperties", "$defs", "definitions", "dependentSchemas":
			if members, ok := value.(map[string]any); ok {
				copied := make(map[string]any, len(members))
				for name, member := range members {
					copied[name] = closed(member)
				}
				value = copied
			}
		case "allOf", "anyOf", "oneOf", "prefixItems":
			if members, ok := value.([]any); ok {
				copied := make([]any, len(members))
				for i, member := range members {
					copied[i] = closed(member)
				}
				value = copied
			}
		case "items", "not", "if", "then", "else", "contains":
			value = closed(value)
		}
		out[key] = value
	}
	if _, has := object["properties"].(map[string]any); has {
		if _, isSchema := object["additionalProperties"].(map[string]any); !isSchema {
			out["additionalProperties"] = false
		}
	}
	return out
}
```

## Producer test: adapt

It validates the bytes the real code emits, against the schema file the event's own `dataschema` names.

### `internal/bookings/events_contract_test.go`

```go
package bookings_test

import (
	"testing"
	"time"

	"example.com/kennel/internal/bookings"
	"example.com/kennel/internal/test/contract"
)

const schemaRoot = "../../schemas/events"

func TestBookingConfirmedMatchesItsPublishedSchema(t *testing.T) {
	cases := map[string]bookings.BookingConfirmed{
		"every field": {BookingID: "0b9f4c7e-3f0a-4d0e-8a43-5c2f7d1e9a10", KennelID: "K-12", Nights: 3,
			Diet: "grain free", PickupWindow: "16:00-18:00"},
		"required fields only": {BookingID: "0b9f4c7e-3f0a-4d0e-8a43-5c2f7d1e9a10", KennelID: "K-12", Nights: 1},
	}
	for name, booking := range cases {
		t.Run(name, func(t *testing.T) {
			event, err := booking.Envelope("5d1c1e0e-51a5-4b8e-9d7c-0f6f2f3f8a01", time.Date(2026, 11, 28, 9, 0, 0, 0, time.UTC))
			if err != nil {
				t.Fatalf("Envelope: %v", err)
			}
			if err := contract.ValidateEvent(schemaRoot, event); err != nil {
				t.Error(err)
			}
		})
	}
}
```

## Consumer test: adapt

The **real handler** reads one sample for every published version, old ones included. Each sample is validated against its schema first, so a sample cannot drift from what the producer may send. Samples live in the consumer's `testdata/`, named `<event>.<version>.json`.

### `internal/reminders/handler_contract_test.go`

```go
package reminders_test

import (
	"os"
	"path/filepath"
	"testing"

	"example.com/kennel/internal/reminders"
	"example.com/kennel/internal/test/contract"
)

const schemaRoot = "../../schemas/events"

// One sample per published schema version, old ones included: retained
// events of every version can still arrive.
func TestRemindersReadEveryPublishedVersion(t *testing.T) {
	versions, err := filepath.Glob(filepath.Join(schemaRoot, "bookings", "booking-confirmed", "*.json"))
	if err != nil || len(versions) == 0 {
		t.Fatalf("no schema versions found: %v", err)
	}
	samples, err := filepath.Glob("testdata/booking-confirmed.*.json")
	if err != nil {
		t.Fatal(err)
	}
	if len(samples) != len(versions) {
		t.Fatalf("%d sample(s) for %d published version(s); add a sample for each version", len(samples), len(versions))
	}
	for _, sample := range samples {
		t.Run(filepath.Base(sample), func(t *testing.T) {
			event, err := os.ReadFile(sample)
			if err != nil {
				t.Fatal(err)
			}
			// The sample must be an event the producer may really send.
			if err := contract.ValidateEvent(schemaRoot, event); err != nil {
				t.Fatalf("sample is not a valid published event: %v", err)
			}
			got, err := reminders.FromBookingConfirmed(event)
			if err != nil {
				t.Fatalf("FromBookingConfirmed: %v", err)
			}
			want := reminders.Reminder{BookingID: "0b9f4c7e-3f0a-4d0e-8a43-5c2f7d1e9a10", Nights: 3}
			if got != want {
				t.Errorf("reminder = %+v, want %+v", got, want)
			}
		})
	}
}

func TestRemindersRefuseAnEventWithoutNights(t *testing.T) {
	event := []byte(`{"type":"booking.confirmed","data":{"bookingId":"0b9f4c7e-3f0a-4d0e-8a43-5c2f7d1e9a10"}}`)
	if _, err := reminders.FromBookingConfirmed(event); err == nil {
		t.Error("an event without nights was accepted as zero nights")
	}
}
```

## What was seen to fail

| Change | Result |
|---|---|
| Producer emits `pickup`, which the schema does not declare | Producer test: `additional properties 'pickup' not allowed` (closed copy) |
| Producer emits `B-1` as `bookingId` | Producer test: `'B-1' is not valid uuid` |
| Consumer reads `days` instead of `nights` | Consumer test: the handler refuses the event; without the handler's own required-value check it would have read zero nights |
| A third schema version without a third sample | Consumer test: `2 sample(s) for 3 published version(s)` (by construction of the test; this line was not run) |

## Limits to state

- Without `AssertFormat()` a bad `uuid` or `date-time` passes (run).
- Passing a Go struct to `Validate` is an error (`invalid jsonType`); validate the encoded bytes through `jsonschema.UnmarshalJSON` (run).
- These tests prove one event against one schema version. Whether version 2 is compatible with version 1 is the gate script's job, not theirs.
