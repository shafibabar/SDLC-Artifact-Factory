# Approval Records: Exceptions and Endpoint Retirements

Self-contained. Copy both files into the product's `api/` folder when the API breaking-change gate is set up. They start with only their comment lines. `./scripts/check-openapi-breaking.sh` reads both on every run and fails on a line without its approval fields. Both formats were run against oasdiff 1.39.0.

## `api/contract-exceptions.txt`

One approved exception per line: the change exactly as oasdiff prints it (endpoint, then the description), followed by the reason and the approval. The gate prints every line on every run, so an exception never becomes invisible.

```text
# Approved exceptions to the API breaking-change check. One oasdiff change per line.
# <METHOD> <path> <change text as printed by oasdiff> | reason: <why no caller breaks> | approved-by: <product owner> | approved-on: YYYY-MM-DD
GET /v1/sailings/{id} added the new `delayed` enum value to the `status` response property for the response status `200` | reason: harbour-travel confirmed in writing on 2026-11-24 that it shows unknown statuses as "check with the operator" | approved-by: R. Okafor (product owner) | approved-on: 2026-11-26
```

- A new enum value in a response fails the gate by default. Each case is approved separately by the product owner; there is no blanket rule and no wildcard line.
- A line without `approved-by:` and `approved-on:` fails the gate (exit 1).
- Remove a line once the change is deployed: the deployed description then contains it.

## `api/endpoint-retirements.txt`

One line per endpoint removed. Without it the gate fails, even when the sunset date has passed and oasdiff itself reports nothing.

```text
# Endpoints removed after their sunset date.
# <METHOD or *> <path> | sunset: YYYY-MM-DD | no-caller-evidence: <what was checked, over which period> | approved-by: <product owner> | approved-on: YYYY-MM-DD
GET /v1/timetable | sunset: 2026-09-30 | no-caller-evidence: gateway access logs 2026-10-01 to 2026-11-20 show 0 requests; consumer registry lists no caller | approved-by: R. Okafor (product owner) | approved-on: 2026-11-21
```

- The gate checks that the line exists, that the sunset date has passed, that evidence is written down and that the approval is dated. It cannot check that the evidence is true; that is what the product owner signs.
- `*` as the method covers every method of the path.
- Removal before the sunset date, or of an endpoint never marked deprecated, fails in oasdiff itself and no record changes that.
