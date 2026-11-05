---
name: event-schema-design
description: >
  Design the wire contract of Domain and Integration Events: the CloudEvents
  1.0 envelope (the four required attributes, the attributes this plugin
  always sets, the correlationid / causationid / tenantid extensions, type
  and source naming, Kafka binary versus structured mode), what goes in the
  payload, how a schema evolves (an additive change in place versus a
  breaking change as a new event type, never a .v2 suffix), upcasting for
  stored events, compatibility modes, and whether a product needs a schema
  registry and a CI gate. Use when defining or changing an event's schema,
  renaming, retyping or removing a field, adding an enum value, choosing
  BACKWARD, FORWARD or FULL, retiring an old event type, or checking an
  envelope against the CloudEvents spec. What an event means is
  domain-event-catalog; publishing code is go-event-publisher. Used by
  data-architect.
version: 3.0.0
phase: design
owner: data-architect
created: 2026-06-25
tags: [design, data, event-schema, cloudevents, schema-evolution, schema-registry, compatibility, upcasting]
produces: event-schema
domain: data
status: stable
related: [domain-event-catalog, aggregate-design, event-driven-patterns, go-event-publisher, go-event-consumer, go-contract-test, data-retention-policy, distributed-tracing-design, canonical-data-model]
sources:
  - research/software-architecture/cloudevents-spec.md
  - research/domain-driven-design/versioning-event-sourced-system-young.md
  - research/software-architecture/designing-data-intensive-applications-kleppmann.md
  - research/software-architecture/building-microservices-newman.md
  - research/domain-driven-design/learning-ddd-khononov.md
---

# Event Schema Design

## Purpose

An event schema is a published contract with consumers you don't control. Once one consumer reads a type, its shape can't change unilaterally. This skill fixes the envelope every event wears, what goes in its payload, and how the payload changes without breaking anyone. What an event *means* (its business fact, when it fires, who reacts) is `domain-event-catalog`'s. This skill owns the wire shape, the versioning rule and the registry choice (D047-1, D047-2). Stack-neutral: the Go envelope, factories and dual publishing are `go-event-publisher` (its CloudEvents event-structs reference).

## 1. The Envelope: CloudEvents 1.0

**The spec requires exactly four attributes:** `specversion` (`"1.0"`), `id` (unique within its `source`), `source` and `type`. Everything else is optional in the spec, `datacontenttype` included. **This plugin additionally always sets** `datacontenttype`, `dataschema` (a versioned schema URI), `subject` (the Aggregate ID) and `time` (when the occurrence happened). Never present a house rule as the spec.

- **`type`:** `<reverse-dns>.<context>.<aggregate>.<past-tense-verb>`, lower-case and hyphenated, e.g. `com.fernpost.lockers.parcel.deposited`. **No version in the type.**
- **`source`:** a stable URI per Bounded Context (`/lockers`). A deploy version inside it changes it every release.
- **House extensions (D047-1):** `correlationid`, `causationid`, `tenantid` (multi-tenant products only), as top-level Strings. Extension names are lower-case letters and digits only, so `correlationId` and `correlation_id` are invalid. No CloudEvents document defines these three, so the artifact states what each means and who sets it. Adopt `partitionkey` and `traceparent` from the spec's documented extensions when needed.
- **On Kafka / Redpanda,** choose one content mode per product. **Structured:** the whole event is the value. **Binary:** `data` is the value and attributes are `ce_` headers (HTTP uses `ce-`), so every forwarder must copy the headers.

Attribute table, naming, extensions, bindings, a worked event in both modes: `./references/envelope.md`.

**What goes in `data`:** what a consumer needs to react without calling back (identifiers, the values that changed, the prior value where transitions matter, the actor). Not envelope facts (event ID, type, occurrence time, version, tenant), not derived values that can drift, not the whole Aggregate (*stamp coupling*), never raw sensitive values on a retained, replicated topic.

## 2. Evolving a Schema

**Classify the change first** (Young): if every field of the new shape can be derived from the old one, it is the same fact in a new shape; if the meaning changed, it is a different event with a new business name.

| Change | Class | Action |
|---|---|---|
| Add an optional field with a default **true for old events**; add a new type | additive | in place; a new schema version |
| Add an enum value | additive **with notice** | announce, wait out a window: exhaustive matchers break |
| Rename; change type or unit; remove; make optional required | **breaking** | a **new event type**, published alongside the old one |
| The business meaning changed | a different event | a new event with its own name |

**The breaking-change protocol (published events):** name a new type that says what differs (`charge.captured-in-minor-units`), never `.v2`. Register its schema first. Publish both from the same transaction. Set a deprecation date. Retire the old type only when telemetry shows no consumer group reads it. Keep its schema registered forever. A `.vN` suffix makes every consumer enumerate versions and says nothing about what changed.

**Stored events are different.** An event-sourced Aggregate's own events can't be retired. Change them by weak schema for additions, **upcasting** on read for convertible changes, and copy-and-replace for a stream's structure. Never edit them in place: correct a wrong fact with a correcting event. Upcasting is never used for published events, because it hides the contract change from consumers. Detail and Young's rules for defaults: `./references/evolution.md`.

## 3. Registry, Compatibility, Gate

- **Format and registry are decided before the first event is stored**, and recorded per product. The tech-stack defaults name no registry. **Lean, or a few consumers in one codebase:** schema files in the repo, consumer contract tests (`go-contract-test`), a schema-diff check in CI. **Several independently deployed consumers, Avro or Protobuf, or several teams:** a registry, preferably open source (Apicurio Registry).
- **Compatibility mode per event:** BACKWARD by default (new readers read old events); FORWARD when producers deploy first; FULL with many consumers and no deploy order; `_TRANSITIVE` for retained, replayable topics; **never NONE** on a published event. A mode checks shape, not meaning: a unit change with the same field name passes every mode and is still breaking.
- **The gate:** register before the first publish; CI fails on an incompatible version; never delete a registered schema.

Modes, JSON Schema traps, the lean alternative: `./references/registry-and-compatibility.md`.

## Producing the Schemas

Standard and enterprise: `design/data/event-schemas.md` (`./templates/event-schemas.md`). At lean the artifact is skipped by the phase plan. The same rules still apply when events are defined in `design/domain-model.md`, and a user may ask for the document directly. No code (D047-10); a sample event in JSON is fine.

1. **Read** each context's `domain-event-catalog` (what each event means, who consumes it), the context map (which events cross which lines and with what contract), `aggregate-design` (which events are stored internal events of an event-sourced Aggregate), and the NFR specification (tenancy, retention, regulated data).
2. **Fix the conventions once:** format, content mode, registry or contract tests, default compatibility, CI gate, the extensions and who sets them.
3. **Per event,** write its type, source, subject and versioned `dataschema`. Mark it published or stored. List its payload fields with type, required or not, the default for old events, and why each is there. List what was deliberately left out.
4. **For a change to an existing event,** classify it (§ 2) and record it in the change log with its action. Plan → validate → execute: a published contract is costly to undo, so validate the plan (new type, dual-publish window, retirement condition, named consumers told) before anything is published.
5. **Validate, then loop.** Run `./scripts/validate-event-schemas.sh design/data/event-schemas.md`. Fix every FAIL and run it again until it exits clean, then go through `./resources/schema-checklist.md`.
6. **Present** the conventions and each change with its class and action, and for every request you declined, its reason in full (§ Gotchas).

Examples: `./examples/01-lean-json-contract-tests.md`, `./examples/02-standard-add-and-rename.md`, `./examples/03-enterprise-protobuf-registry.md`.

## Gotchas

Each trap comes with the reason to give in full.

- **"The five required CloudEvents attributes, including `datacontenttype`."** *Reason:* the spec requires four: `specversion`, `id`, `source`, `type`. `datacontenttype` is optional (absent means the format's own encoding). This plugin always sets it, but that is a house rule. *Instead:* list the four as spec-required and the house set separately.
- **"Bump it to `.v2`."** *Reason:* a version suffix makes every consumer enumerate versions and change code even when its fields are untouched, drifts from the registry's own version count, and says nothing about what changed (D047-1; the CloudEvents Primer puts an incompatible change in a new `type`). *Instead:* a new, descriptive type published alongside the old one, retired on telemetry.
- **"It's only a rename; keep the old name as an alias."** *Reason:* a reader of the old name silently gets nothing; renames, type and unit changes, and removals are always breaking. *Instead:* the breaking-change protocol.
- **"Old events default `isExpress` to false."** *Reason:* a default is how old events will be read; a default that misstates history is a silent data error (Young). *Instead:* an explicit unknown (an absent optional field or an `UNKNOWN` value).
- **"Put `eventId`, `occurredAt`, `tenantId` and `version` in the payload."** *Reason:* those are envelope attributes (`id`, `time`, the `tenantid` extension, `dataschema`); duplicating them creates two answers that drift. *Instead:* keep `data` for the fact itself.
- **"Upcast the published event so consumers needn't change."** *Reason:* upcasting is a read-time translation for an event-sourced Aggregate's own stored events, which can't be retired; on a published event it hides a contract change consumers can't see (Khononov, Young). *Instead:* a new type for published events; upcasting only inside the store.
- **"Set the registry's compatibility mode to NONE to get this change through."** *Reason:* NONE disables the check for every later change too, and consumers break silently. *Instead:* run the breaking-change protocol.
- **"Put the service version in `source`."** *Reason:* `source` then changes every release, breaking filters and widening the scope in which `id` must be unique. *Instead:* a stable context URI; the schema version lives in `dataschema`.
- **"Every product needs a schema registry."** *Reason:* the defaults name none, and a lean product with a few consumers in one codebase is protected as well by schema files, consumer contract tests and a CI diff (Young). *Instead:* decide per product from consumers, format and teams, and record it.

## References

| Question | File |
|---|---|
| Which attributes? Extensions? Naming? Kafka modes? What goes in `data`? | `./references/envelope.md` |
| Is this change breaking? The protocol? Defaults? Stored events? | `./references/evolution.md` |
| Registry or not? Which compatibility mode? The CI gate? | `./references/registry-and-compatibility.md` |
| Checking before hand-off | `./resources/schema-checklist.md` |
