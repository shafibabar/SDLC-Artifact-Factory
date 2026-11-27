---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It says the consumer test in `reminders` must not import the `bookings` app: it runs the consumer's real httpx client against a double (canned responses), and that double is checked against the provider's API description. Which library provides the double or the check does not matter.
2. It says a contract job that selects or collects zero tests must fail, and rejects allowing exit code 5; "0 selected" means CI ran nothing. Adding the marker to the contract tests is the expected remedy, but naming it is not required.
3. It says `format` keywords such as `uuid` and `date-time` are not enforced by jsonschema by default, so the current check proves neither, and a format checker must be supplied (or a validator that enforces formats used).
4. It says provider conformance sends real requests through the real FastAPI app and checks the responses against the authored `openapi.yaml`, not against the description the app generates about itself.
5. It says the pull-request gate is `oasdiff breaking --fail-on WARN` (not `ERR`), and that removing the optional response field `notes` is a failure of that gate rather than a change that goes straight through.
Fail if any of the 5 is missing.
