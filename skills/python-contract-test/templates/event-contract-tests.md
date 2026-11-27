# Event Contract Tests: Helper and Skeletons

Self-contained. Copy when a Python service publishes or consumes events. These tests live in `tests/contract/`, carry no marker and run in `make ci`. Run on Python 3.15.2 with pytest 9.2.0, jsonschema 4.26.0 and rfc3339-validator 0.1.4, type-checked with mypy 2.4.1 in strict mode (the code is the standard example's; replace the names). Other versions are unverified.

Layout the tests and `../scripts/check-event-compatibility.sh` share:

```text
schemas/events/<context>/<event>/1.json, 2.json, ...   one file per published version, never edited
schemas/events/modes.txt                               "<context>/<event> <MODE>", from the event design
```

## Dependencies

```toml
[dependency-groups]
dev = [
    "jsonschema==4.26.0",
    "types-jsonschema==4.26.0.20261006",
    "rfc3339-validator==0.1.4",   # without it jsonschema passes any "date-time" silently
]
```

## Helper: copy unchanged into `tests/contract/`

### `tests/contract/events.py`

```python
"""Test support for event contract tests: validates the bytes of one event
against the published schema version its own dataschema names. It must never
be imported by code that ships."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

from jsonschema import Draft202012Validator

SCHEMAS = Path(__file__).parents[2] / "schemas" / "events"
ENVELOPE = ("specversion", "id", "source", "type", "subject", "time", "datacontenttype", "dataschema")
_NESTED_ONE = ("items", "additionalProperties", "not", "if", "then", "else", "contains", "propertyNames")
_NESTED_MAP = ("properties", "patternProperties", "$defs", "definitions", "dependentSchemas")
_NESTED_LIST = ("allOf", "anyOf", "oneOf", "prefixItems")


def schema_file(dataschema: str) -> Path:
    """https://schemas.example/trips/trip-ended/2 -> schemas/events/trips/trip-ended/2.json"""
    context, event, version = urlsplit(dataschema).path.strip("/").split("/")[-3:]
    return SCHEMAS / context / event / f"{version}.json"


def published_versions(event: str) -> list[int]:
    """Every published version of "<context>/<event>", oldest first."""
    return sorted(int(path.stem) for path in (SCHEMAS / event).glob("*.json"))


def closed(schema: Any) -> Any:
    """A copy with additionalProperties: false in every object that lists
    properties. The published file stays open; only this copy is closed."""
    if not isinstance(schema, dict):
        return schema
    out = dict(schema)
    for key in _NESTED_ONE:
        if isinstance(out.get(key), dict):
            out[key] = closed(out[key])
    for key in _NESTED_MAP:
        if isinstance(out.get(key), dict):
            out[key] = {name: closed(sub) for name, sub in out[key].items()}
    for key in _NESTED_LIST:
        if isinstance(out.get(key), list):
            out[key] = [closed(sub) for sub in out[key]]
    if isinstance(schema.get("properties"), dict) and not isinstance(schema.get("additionalProperties"), dict):
        out["additionalProperties"] = False
    return out


def _formats(schema: Any) -> set[str]:
    if isinstance(schema, dict):
        own = {schema["format"]} if isinstance(schema.get("format"), str) else set()
        return own.union(*(_formats(value) for value in schema.values()))
    if isinstance(schema, list):
        return set().union(*(_formats(value) for value in schema))
    return set()


def check_event(raw: bytes, *, exact: bool) -> dict[str, Any]:
    """Fail unless the encoded event is valid for the schema version it names.
    exact=True is for the producer: an undeclared field also fails. A consumer's
    sample is checked with exact=False. Returns the decoded event."""
    event: dict[str, Any] = json.loads(raw)
    missing = [name for name in ENVELOPE if name not in event]
    assert not missing, f"envelope attributes missing: {missing}"
    path = schema_file(event["dataschema"])
    assert path.is_file(), f"dataschema {event['dataschema']} names no published schema ({path})"
    schema = json.loads(path.read_text(encoding="utf-8"))
    checker = Draft202012Validator.FORMAT_CHECKER
    # Without a checker jsonschema ignores "format"; with one it still ignores
    # a format it has no function for ("date-time" needs rfc3339-validator).
    unknown = sorted(_formats(schema) - set(checker.checkers))
    assert not unknown, f"formats nothing would check: {unknown}; install the validator for them"
    Draft202012Validator.check_schema(schema)
    validator = Draft202012Validator(closed(schema) if exact else schema, format_checker=checker)
    errors = sorted(error.message for error in validator.iter_errors(event["data"]))
    assert not errors, f"{path.parent.name}/{path.name}: " + "; ".join(errors)
    return event
```

## Producer test: adapt

It validates the bytes the real code emits, against the schema file the event's own `dataschema` names. Publishing to a real broker is `python-integration-test`'s subject, not this test's.

### `tests/contract/test_trip_ended_producer.py`

```python
"""Producer contract: the bytes trips really emits match the schema version
their own dataschema names, formats included, with no undeclared field."""

from __future__ import annotations

from datetime import datetime, timezone

from tests.contract.events import check_event
from trips.adapters.messaging import Trip, build_trip_ended

NOW = datetime(2026, 11, 28, 9, 0, tzinfo=timezone.utc)
TRIP = Trip(
    id="0b9f4c7e-3f0a-4d0e-8a43-5c2f7d1e9a10",
    vehicle_id="V-12",
    started_at=datetime(2026, 11, 28, 8, 10, tzinfo=timezone.utc),
    distance_metres=18400,
    cleaning_note="sand on the back seat",
    parking_zone="north-3",
)


def test_trip_ended_matches_its_published_schema() -> None:
    event = check_event(build_trip_ended(TRIP, now=NOW), exact=True)
    assert event["type"] == "trip.ended"
    assert event["subject"] == TRIP.id
    assert event["data"]["distanceMetres"] == 18400


def test_trip_ended_without_optional_fields_matches_too() -> None:
    bare = Trip(id=TRIP.id, vehicle_id="V-12", started_at=TRIP.started_at, distance_metres=0)
    check_event(build_trip_ended(bare, now=NOW), exact=True)
```

## Consumer test: adapt

The **real handler** reads one sample for every published version, old ones included. Each sample is validated against its schema first, so a sample cannot drift from what the producer may send. Samples live in `tests/contract/samples/`, named `<event>.<version>.json`. The test imports nothing of the producer's.

### `tests/contract/test_trip_ended_consumer.py`

```python
"""Consumer contract: the real invoicing handler reads a valid sample of every
published version of trip.ended, old ones included. Nothing here imports trips."""

from __future__ import annotations

from pathlib import Path

import pytest

from invoicing.entrypoints.event_consumer import InvoiceLine, handle_trip_ended
from tests.contract.events import check_event, published_versions

SAMPLES = Path(__file__).parent / "samples"
VERSIONS = published_versions("trips/trip-ended")


def test_there_is_a_sample_for_every_published_version() -> None:
    samples = sorted(int(path.suffixes[-2].lstrip(".")) for path in SAMPLES.glob("trip-ended.*.json"))
    assert samples == VERSIONS, f"samples {samples} for published versions {VERSIONS}"


@pytest.mark.parametrize("version", VERSIONS)
def test_invoicing_reads_every_published_version(version: int) -> None:
    raw = (SAMPLES / f"trip-ended.{version}.json").read_bytes()
    # The sample is checked first, so it cannot drift from what trips may send.
    event = check_event(raw, exact=False)
    assert event["dataschema"].endswith(f"/{version}")
    assert handle_trip_ended(raw) == InvoiceLine(trip_id="0b9f4c7e-3f0a-4d0e-8a43-5c2f7d1e9a10", amount_pence=828)
```

## What was seen to fail

| Change | Result |
|---|---|
| Producer emits `pickup`, which the schema does not declare | Producer test: `Additional properties are not allowed ('pickup' was unexpected)` (closed copy) |
| Producer emits `T-1` as `tripId` | Producer test: `'T-1' is not a 'uuid'` |
| Producer emits `2026-11-28 08:10` as `startedAt` | Producer test: `'2026-11-28 08:10' is not a 'date-time'` |
| Producer's `dataschema` names version 9 | Producer test: `names no published schema` |
| Consumer reads `data.get("distance", 0)` | Value assertion: `amount_pence=0`, wanted `828`. Reading the event raised nothing |
| Consumer's sample lacks a required field | Consumer test: `'vehicleId' is a required property` |
| A third schema version without a third sample | `samples [1, 2] for published versions [1, 2, 3]` |

## Limits to state

- `Draft202012Validator(schema)` with no `format_checker` ignores `format`: a bad `uuid` passed (run).
- With `FORMAT_CHECKER` and jsonschema alone installed, a bad `date-time` **still passed**: the checker has no function for it until `rfc3339-validator` is installed (run). The helper fails on any format the checker does not know.
- Validating one object of a larger document by itself (a schema cut out of an OpenAPI file) raises `PointerToNowhere` on the first `$ref` (run). Event schema files here are whole documents; OpenAPI responses are checked through openapi-core (`./http-contract-tests.md`).
- These tests prove one event against one schema version. Whether version 2 is compatible with version 1 is the gate script's job, not theirs; no compatibility checker is written by hand.
