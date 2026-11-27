# Event Contracts: Schema Checks

Self-contained. Read when setting up, changing or explaining contract checks for events. Events are checked by schema on every pull request. They are **not** covered by Pact: no message pact is written. Results marked "run" were observed with the schema registry of Redpanda v26.2.7 (JSON Schema) and `jsonschema/v6` v6.0.3. Confluent's and Apicurio's registries were not run.

## Contents

The three checks; why two registry passes; what each mode lets through; what nothing detects; baseline rules; engines.

## The three checks

| Check | Proves | Where |
|---|---|---|
| Producer test | The bytes the real code emits match the schema version its `dataschema` names, formats included, with no undeclared field | `make ci` |
| Consumer test | The real handler reads a valid sample of **every** published version, ignoring unknown fields | `make ci` |
| `./scripts/check-event-compatibility.sh` | Each new schema version is compatible with all deployed ones | Pull-request gate |

Templates: `./templates/event-contract-tests.md`. These replace hand-written compatibility checkers.

## Why the gate makes two passes

`event-schema-design` says schemas change by **adding only**: renaming, retyping, removing a field or making one required is a new event type. It also requires published JSON Schemas to stay open (`additionalProperties` not `false`) so readers tolerate additions. Those two rules meet badly in a registry (run):

| Change, open schema | BACKWARD | FORWARD | FULL |
|---|---|---|---|
| Remove an optional field | **pass** | pass | **pass** |
| Remove a required field | **pass** | fail | fail |
| Rename an optional field | **pass** | **pass** | **pass** |
| Rename a required field; change a type | fail | fail | fail |
| Add a required field; make an optional one required | fail | pass | fail |
| Add an enum value | **pass** | fail | fail |
| Remove an enum value | fail | pass | fail |
| Change only the description (meaning, unit) | pass | pass | pass |

So the declared mode alone accepts removals and renames that the event design forbids. The script therefore runs both:

1. **Declared pass.** Each version against the earlier ones under the mode the event design sets for that event, read from `schemas/events/modes.txt`. A hard-coded `BACKWARD` is wrong for any event whose design says otherwise.
2. **Add-only pass.** The same versions as copies with `additionalProperties: false` written into every object that lists properties, under `BACKWARD_TRANSITIVE`. A removed or renamed field then fails (`PROPERTY_REMOVED_FROM_CLOSED_CONTENT_MODEL`), at the top level, nested, in array items and under `$defs` (run). Adding an optional field still passes. The published files are not changed.

Neither pass replaces the other: under `FULL` the declared pass is the one that fails an added enum value.

## What nothing here detects

State these whenever the gate is described; review and the event design's own protocol have to catch them.

- A change of **meaning or unit** with the same name and type: passes every mode.
- An **enum value added** under `BACKWARD`: passes both passes. The event design treats it as additive **with notice**: announce it and wait, because a consumer matching every value breaks.
- A `format` change (`date` to `date-time`) and a changed default: pass `BACKWARD` and `FULL`.
- Mode `NONE` reports everything compatible. The script refuses it.

## Baseline rules the script enforces before asking the registry

- Every event folder has a mode line; `NONE` or an unknown mode fails.
- The baseline is the schema folder **as deployed**. A deployed event or version file that is missing fails (a published schema is never deleted); one whose content changed fails (add a new version file; never edit in place).
- Versions are numbered `1..n` without gaps.
- A mode that differs from the deployed one is printed as a warning: it must match the event design.
- `--first-release` states that nothing is deployed yet.

## Engines

The script talks to a schema registry it may write throwaway subjects to, and accepts only a loopback address. In a pipeline that is a Redpanda container started for the job, which is not a registry the product operates: a lean product with schema files in the repository still runs the gate this way. A product that operates its own registry may run the declared-mode check there (its compatibility endpoint, or the registration itself); the add-only pass still needs the throwaway one.

Registry calls used (run): `PUT /config/{subject}` with `{"compatibility": MODE}`; `POST /subjects/{subject}/versions`; `POST /compatibility/subjects/{subject}/versions/latest?verbose=true`; content type `application/vnd.schemaregistry.v1+json`. Under a `_TRANSITIVE` mode the `latest` check compares with every earlier version.

## Validating one event

- Compile with `AssertFormat()`: without it a malformed `uuid` or `date-time` passes (run).
- Validate the encoded bytes (`jsonschema.UnmarshalJSON`), not a Go struct (run: `invalid jsonType`).
- A renamed optional field passes validation against an open schema; the helper's closed copy is what catches a producer emitting a field it never published.
