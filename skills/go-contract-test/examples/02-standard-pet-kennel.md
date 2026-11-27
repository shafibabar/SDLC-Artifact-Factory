# Standard: a Pet Boarding Kennel with Events

Three Go services in one repository: `bookings` confirms a stay and publishes `booking.confirmed`; `reminders` consumes it; `bookings` also calls `kennels` over HTTP to check a kennel is free. The event design sets `BACKWARD_TRANSITIVE` for `booking.confirmed`, because the topic is retained and replayed. This example works the event checks; the HTTP call is listed at the end.

Run on 2026-11-28: Go 1.27.4 (darwin/arm64), `github.com/santhosh-tekuri/jsonschema/v6` v6.0.3, `check-event-compatibility.sh` against the schema registry of `redpandadata/redpanda:v26.2.7` started for the run on 127.0.0.1.

## Plan

| Boundary | Every pull request | Daily |
|---|---|---|
| `booking.confirmed` schema | `check-event-compatibility.sh`: the declared mode, then the add-only pass | |
| `bookings` as producer | Emitted bytes validated against the schema `dataschema` names; no undeclared field | |
| `reminders` as consumer | Real handler reads a sample of every published version | |
| `bookings` → `kennels` (HTTP) | API description gate, conformance, consumer test | Pact |

Events are not covered by Pact. No message pact is written.

## Files

`internal/test/contract/events.go` and both tests are the files in `../templates/event-contract-tests.md`, unchanged: that template was cut from this example.

### `schemas/events/modes.txt`

```text
bookings/booking-confirmed BACKWARD_TRANSITIVE
```

### `schemas/events/bookings/booking-confirmed/1.json`

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["bookingId", "kennelId", "nights"],
  "properties": {
    "bookingId": { "type": "string", "format": "uuid" },
    "kennelId": { "type": "string" },
    "nights": { "type": "integer", "minimum": 1 },
    "diet": { "type": "string" }
  }
}
```

Version 2 adds the optional `pickupWindow` and is otherwise identical.

### `internal/bookings/events.go`

```go
// Package bookings confirms kennel bookings and publishes what happened.
package bookings

import (
	"encoding/json"
	"time"
)

// BookingConfirmed is the data of the booking.confirmed event, schema version 2.
type BookingConfirmed struct {
	BookingID    string `json:"bookingId"`
	KennelID     string `json:"kennelId"`
	Nights       int    `json:"nights"`
	Diet         string `json:"diet,omitempty"`
	PickupWindow string `json:"pickupWindow,omitempty"`
}

// Envelope builds the CloudEvents JSON the service puts in its outbox.
func (b BookingConfirmed) Envelope(eventID string, at time.Time) ([]byte, error) {
	return json.Marshal(map[string]any{
		"specversion":     "1.0",
		"id":              eventID,
		"source":          "https://kennel.example/bookings",
		"type":            "booking.confirmed",
		"subject":         b.BookingID,
		"time":            at.UTC().Format(time.RFC3339),
		"datacontenttype": "application/json",
		"dataschema":      "https://schemas.kennel.example/bookings/booking-confirmed/2",
		"data":            b,
	})
}
```

### `internal/reminders/handler.go`

```go
// Package reminders sends the owner a reminder before pick-up.
package reminders

import (
	"encoding/json"
	"errors"
	"fmt"
)

// Reminder is what this consumer derives from a confirmed booking.
type Reminder struct {
	BookingID string
	Nights    int
}

// FromBookingConfirmed reads only the fields reminders need and ignores the
// rest, so a field added by the producer changes nothing here.
func FromBookingConfirmed(event []byte) (Reminder, error) {
	var envelope struct {
		Type string `json:"type"`
		Data struct {
			BookingID string `json:"bookingId"`
			Nights    int    `json:"nights"`
		} `json:"data"`
	}
	if err := json.Unmarshal(event, &envelope); err != nil {
		return Reminder{}, fmt.Errorf("decode event: %w", err)
	}
	if envelope.Type != "booking.confirmed" {
		return Reminder{}, fmt.Errorf("unexpected event type %q", envelope.Type)
	}
	// A missing field decodes to zero without an error, so required values
	// are checked here rather than trusted.
	if envelope.Data.BookingID == "" || envelope.Data.Nights < 1 {
		return Reminder{}, errors.New("booking.confirmed without bookingId or nights")
	}
	return Reminder{BookingID: envelope.Data.BookingID, Nights: envelope.Data.Nights}, nil
}
```

### `internal/reminders/testdata/booking-confirmed.1.json`

```json
{"specversion":"1.0","id":"5d1c1e0e-51a5-4b8e-9d7c-0f6f2f3f8a01","source":"https://kennel.example/bookings","type":"booking.confirmed","subject":"0b9f4c7e-3f0a-4d0e-8a43-5c2f7d1e9a10","time":"2026-11-28T09:00:00Z","datacontenttype":"application/json","dataschema":"https://schemas.kennel.example/bookings/booking-confirmed/1","data":{"bookingId":"0b9f4c7e-3f0a-4d0e-8a43-5c2f7d1e9a10","kennelId":"K-12","nights":3,"diet":"grain free"}}
```

## Every pull request

```text
$ go test -race -shuffle=on -count=1 ./...
ok      example.com/kennel/internal/bookings
ok      example.com/kennel/internal/reminders

$ ./scripts/check-event-compatibility.sh --schemas schemas/events --baseline deployed/schemas/events --registry http://127.0.0.1:18081
ok bookings/booking-confirmed [declared, BACKWARD_TRANSITIVE]: 2 version(s)
ok bookings/booking-confirmed [add-only, BACKWARD_TRANSITIVE]: 2 version(s)
checked 1 event(s): 0 FAIL
RESULT: PASS (shape only: meaning, unit and format changes are not detected)
```

## A removal the declared mode lets through

A developer adds `3.json` without the optional field `diet`. The event design calls removing a field breaking: it needs a new event type published beside the old one, not a new version.

```text
$ ./scripts/check-event-compatibility.sh --schemas schemas/events --baseline deployed/schemas/events --registry http://127.0.0.1:18081
ok bookings/booking-confirmed [declared, BACKWARD_TRANSITIVE]: 3 version(s)
FAIL bookings/booking-confirmed/3.json [add-only, BACKWARD_TRANSITIVE]: not compatible with the earlier versions:
  {errorType:"PROPERTY_REMOVED_FROM_CLOSED_CONTENT_MODEL", description:"The new has a closed content model and is missing
  a property or item present at path '#/properties/diet' in the old schema"}
checked 1 event(s): 1 FAIL
RESULT: FAIL                                                                    # exit 1
```

The registry accepted the removal under the declared mode, because the published schema is open (`additionalProperties` not set, as the event design requires for tolerant readers). Only the second pass, on closed copies, failed it. Both passes run on every pull request; neither replaces the other.

Other results from the same registry, one change each to version 2:

| Change | Declared mode (`BACKWARD`) | Add-only pass |
|---|---|---|
| Add an optional field | pass | pass |
| Remove or rename an optional field, top level or nested | pass | **fail** |
| Change a field's type | fail | fail |
| Add an enum value | pass | pass (under `FULL` the declared mode fails it) |
| Change only the description (the meaning) | pass | pass |
| Edit `1.json` in place | fail before the registry is asked | |
| Mode `NONE` in `modes.txt` | fail before the registry is asked | |

An added enum value and a change of meaning or unit pass both passes. The event design's rule still applies to them (announce an enum value and wait; a unit change is a new event type), and review has to catch them.

## Test failures seen

Listed in `../templates/event-contract-tests.md`: an undeclared field, a malformed `bookingId`, a consumer reading a renamed field.

## The HTTP call

`bookings` → `kennels` gets the four HTTP checks of `./01-lean-dance-studio.md`, Pact included, with `bookings` and `kennels` added to the two loops of the daily workflow. They were not run again for this example.

## For the product owner

- The mode per event comes from the event design. A changed line in `modes.txt` is printed as a warning on every run until it is deployed.
- Whether the registry used in the pull-request job is this throwaway container or the product's own registry is recorded in the test strategy.
