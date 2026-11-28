# Standard: a Car-Share Fleet with Events

Three Python services in one repository: `trips` ends a trip and publishes `trip.ended`; `invoicing` consumes it; `trips` also calls `vehicles` over HTTP to check a car is free. The event design sets `BACKWARD_TRANSITIVE` for `trip.ended`, because the topic is retained and replayed. This example works the event checks; the HTTP call is listed at the end.

Run on 2026-11-28: Python 3.15.2 (macOS arm64), pytest 9.2.0, jsonschema 4.26.0 with rfc3339-validator 0.1.4, `check-event-compatibility.sh` against the schema registry of `redpandadata/redpanda:v26.2.7` started for the run on 127.0.0.1.

## Plan

| Boundary | Every pull request | Daily |
|---|---|---|
| `trip.ended` schema | `make event-gate`: the declared mode, then the add-only pass | |
| `trips` as producer | Emitted bytes validated against the schema `dataschema` names; no undeclared field | |
| `invoicing` as consumer | Real handler reads a sample of every published version | |
| `trips` → `vehicles` (HTTP) | API description gate, conformance, consumer test | Pact |

Events are not covered by Pact. No message pact is written.

## Files

`tests/contract/events.py` and both tests are the files in `../templates/event-contract-tests.md`, unchanged: that template was cut from this example.

### `schemas/events/modes.txt`

```text
trips/trip-ended BACKWARD_TRANSITIVE
```

### `schemas/events/trips/trip-ended/1.json`

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "required": ["tripId", "vehicleId", "startedAt", "distanceMetres"],
  "properties": {
    "tripId": { "type": "string", "format": "uuid" },
    "vehicleId": { "type": "string" },
    "startedAt": { "type": "string", "format": "date-time" },
    "distanceMetres": { "type": "integer", "minimum": 0 },
    "cleaningNote": { "type": "string" }
  }
}
```

Version 2 adds the optional `parkingZone` and is otherwise identical. The schemas are open (`additionalProperties` is not set), as the event design requires.

### `src/trips/adapters/messaging.py`

```python
"""The trips service publishes what happened to a trip."""

from __future__ import annotations

import json
import uuid
from dataclasses import dataclass
from datetime import datetime, timezone

SCHEMA_BASE = "https://schemas.carshare.example/trips/trip-ended/"
SCHEMA_VERSION = 2


@dataclass(frozen=True)
class Trip:
    id: str
    vehicle_id: str
    started_at: datetime
    distance_metres: int
    cleaning_note: str | None = None
    parking_zone: str | None = None


def build_trip_ended(trip: Trip, *, now: datetime) -> bytes:
    """The bytes the publisher sends as the record value (structured mode)."""
    data: dict[str, object] = {
        "tripId": trip.id,
        "vehicleId": trip.vehicle_id,
        "startedAt": trip.started_at.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
        "distanceMetres": trip.distance_metres,
    }
    if trip.cleaning_note is not None:
        data["cleaningNote"] = trip.cleaning_note
    if trip.parking_zone is not None:
        data["parkingZone"] = trip.parking_zone
    event = {
        "specversion": "1.0",
        "id": str(uuid.uuid4()),
        "source": "https://carshare.example/trips",
        "type": "trip.ended",
        "subject": trip.id,
        "time": now.astimezone(timezone.utc).isoformat().replace("+00:00", "Z"),
        "datacontenttype": "application/json",
        "dataschema": f"{SCHEMA_BASE}{SCHEMA_VERSION}",
        "data": data,
    }
    return json.dumps(event).encode()
```

### `src/invoicing/entrypoints/event_consumer.py`

```python
"""The invoicing service turns an ended trip into an invoice line."""

from __future__ import annotations

import json
from dataclasses import dataclass

PENCE_PER_KILOMETRE = 45


class UnreadableEvent(Exception):
    pass


@dataclass(frozen=True)
class InvoiceLine:
    trip_id: str
    amount_pence: int


def handle_trip_ended(raw: bytes) -> InvoiceLine:
    """Reads only tripId and distanceMetres; any other field is ignored."""
    data = json.loads(raw)["data"]
    try:
        trip_id, distance = data["tripId"], data["distanceMetres"]
    except KeyError as missing:
        raise UnreadableEvent(f"trip.ended without {missing}") from None
    return InvoiceLine(trip_id=trip_id, amount_pence=distance * PENCE_PER_KILOMETRE // 1000)
```

### `tests/contract/samples/trip-ended.1.json`

```json
{"specversion":"1.0","id":"5d1c1e0e-51a5-4b8e-9d7c-0f6f2f3f8a01","source":"https://carshare.example/trips","type":"trip.ended","subject":"0b9f4c7e-3f0a-4d0e-8a43-5c2f7d1e9a10","time":"2026-11-28T09:00:00Z","datacontenttype":"application/json","dataschema":"https://schemas.carshare.example/trips/trip-ended/1","data":{"tripId":"0b9f4c7e-3f0a-4d0e-8a43-5c2f7d1e9a10","vehicleId":"V-12","startedAt":"2026-11-28T08:10:00Z","distanceMetres":18400,"cleaningNote":"sand on the back seat"}}
```

`trip-ended.2.json` is the same event with `dataschema` ending in `/2` and `"parkingZone":"north-3"` added.

## Every pull request

```text
$ uv run pytest tests                                 # in the product: part of make test
5 passed

$ make event-gate
ok trips/trip-ended [declared, BACKWARD_TRANSITIVE]: 2 version(s)
ok trips/trip-ended [add-only, BACKWARD_TRANSITIVE]: 2 version(s)
checked 1 event(s): 0 FAIL
RESULT: PASS (shape only: meaning, unit and format changes are not detected)
```

## A removal the declared mode lets through

A developer adds `3.json` without the optional field `cleaningNote`. The event design calls removing a field breaking: it needs a new event type published beside the old one, not a new version.

```text
$ make event-gate
ok trips/trip-ended [declared, BACKWARD_TRANSITIVE]: 3 version(s)
FAIL trips/trip-ended/3.json [add-only, BACKWARD_TRANSITIVE]: not compatible with the earlier versions:
  {errorType:"PROPERTY_REMOVED_FROM_CLOSED_CONTENT_MODEL", description:"The new has a closed content model and is missing
  a property or item present at path '#/properties/cleaningNote' in the old schema"}
checked 1 event(s): 1 FAIL
RESULT: FAIL
make: *** [event-gate] Error 1                        # make exits 2; the registry container is removed all the same
```

The registry accepted the removal under the declared mode, because the published schema is open. Only the second pass, on closed copies, failed it. Both passes run on every pull request; neither replaces the other.

Other results from the same registry, one change each to a version 3 (the script called directly):

| Change | Declared mode | Add-only pass |
|---|---|---|
| Add an optional field | pass (`BACKWARD_TRANSITIVE`) | pass |
| Remove the optional field, declared mode `FULL_TRANSITIVE` | pass | **fail** |
| Rename the optional field | pass (`BACKWARD`) | **fail** |
| Remove a required field | pass (`BACKWARD`) | **fail** |
| Change a field's type | fail (`BACKWARD`) | fail |
| Add a required field | fail (`BACKWARD`); pass (`FORWARD`) | fail |
| Add an enum value | pass (`BACKWARD`); fail (`FULL_TRANSITIVE`) | pass |
| Change only the description (the meaning); change `date-time` to `date` | pass (`BACKWARD`) | pass |
| Edit `1.json` in place | fail before the registry is asked | |
| Mode `NONE` in `modes.txt` | fail before the registry is asked | |

An added enum value and a change of meaning, unit or format pass both passes under `BACKWARD`. The event design's rule still applies to them (announce an enum value and wait; a unit change is a new event type), and review has to catch them.

## Test failures seen

Listed in `../templates/event-contract-tests.md`: an undeclared field, a malformed `tripId`, a `startedAt` without a zone, a consumer reading a renamed field with a default.

## The HTTP call

`trips` → `vehicles` gets the four HTTP checks of `./01-lean-garden-plots.md`, Pact included, with `trips` and `vehicles` in `PACT_SERVICES`. They were not run again for this example.

## For the product owner

- The mode per event comes from the event design. A changed line in `modes.txt` is printed as a warning on every run until it is deployed.
- Whether the registry used in the pull-request job is this throwaway container or the product's own registry is recorded in the test strategy.
