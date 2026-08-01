---
name: event-schema-design
description: >
  Teaches the domain-modeler and backend-engineer to design event schemas that
  are correct, evolvable, and consumer-safe — covering the CloudEvents 1.0
  envelope as the mandatory wrapper, required and optional attribute fields,
  the event data payload design (what to include in the payload vs. the
  envelope), schema versioning strategy (additive-only changes, breaking change
  protocol), schema registry integration (Apicurio or Confluent Schema Registry
  in this platform), backward and forward compatibility rules, and the Go struct
  conventions for events. Used during Design and Implement whenever a new Domain
  or Integration Event is being defined.
version: 2.0.0
phase: design
owner: domain-modeler
created: 2026-06-25
related:
  - domain-event-catalog
  - go-domain-model
  - data-retention-policy
  - cqrs-pattern
tags:
  - design
  - domain-modeling
  - event-schema
  - cloudevents
  - schema-versioning
  - schema-registry
  - backward-compatibility
produces: event-schema
domain: domain-modeling
status: stable
---

# Event Schema Design

## CloudEvents 1.0 — The Mandatory Envelope

Every Domain Event and Integration Event in this platform is wrapped in a
**CloudEvents 1.0** envelope. This is not optional. CloudEvents is a CNCF
standard that gives every event a predictable structure so any consumer can
parse the envelope without knowing the event type in advance.

The five **required** CloudEvents attributes on every event:

| Attribute | Type | Meaning |
|---|---|---|
| `specversion` | string | Always `"1.0"` |
| `id` | string (UUID) | Unique event ID — used for idempotency deduplication |
| `source` | string (URI) | Identifies the service that produced the event |
| `type` | string | Reverse-domain name identifying the event (see `references/cloudevents-format.md`) |
| `datacontenttype` | string | Always `"application/json"` for this platform |

Full attribute specifications, the event type naming convention for this repo
(`com.sdlc-factory.<bounded-context>.<aggregate>.<past-tense-verb>`), worked
examples, and the Go struct mapping are in
`skills/event-schema-design/references/cloudevents-format.md`.

---

## Payload Design Principles

The CloudEvents envelope holds metadata. The `data` field holds the payload.

**An event is a fact about something that happened, not a command or a
notification.** This has direct consequences for what belongs in the payload:

- **Include:** the identifiers, levels, and metadata that let a consumer act
  without querying back. A `DataAssetClassified` event carries `aggregateId`,
  `tenantId`, `sensitivityLevel`, and `classifiedBy` — everything the
  Compliance Intelligence context needs to update its read model.
- **Exclude:** derived or computed values that could become stale. A consumer
  that needs a human-readable asset name should query the Data Asset Management
  context, not receive the name in the event payload (where it could drift from
  the authoritative record).
- **Never embed raw sensitive content.** The event log is immutable and
  replicated. A raw PII value in a payload can only be erased by
  crypto-shredding the topic — an operational catastrophe. Carry identifiers
  and classification levels; let consumers query the source for the actual data
  under the classification.

**Payload minimalism is a data retention constraint, not a style preference.**
See `data-retention-policy` for the full retention and erasure model.

---

## Schema Change Classification

Every proposed change to a published event schema falls into one of four classes:

| Class | Examples | Safe? |
|---|---|---|
| **Additive** | Add an optional field with a default; add a new enum value | Safe — backward compatible if consumers use tolerant reading |
| **Rename** | Rename an existing field, even with an alias | Breaking — any consumer reading the old name silently gets `null` |
| **Type change** | Change a field from `string` to `int`; narrow an enum | Breaking — consumers parsing the old type get a decode error |
| **Remove** | Delete a field consumers depend on | Breaking — consumers reading the old field get `null` or an error |

The rename, type-change, and remove classes are **always breaking** — there is
no "soft" version. They require the breaking change protocol.

---

## Evolution Strategy

### Additive-only (default)

Add an optional field with a default value or a new enum value. Consumers
that do not recognise the new field ignore it (tolerant reading). No version
bump is needed; the existing event type continues.

### Breaking change protocol

A breaking change is **never made in place**. Instead:

1. Define a **new event type**. Do not increment a version suffix on the old
   type — `DataAssetClassified.v2` forces every consumer to enumerate versions
   rather than just subscribing to the type they understand.
2. Producers publish **both** the old and new event types during the transition
   window.
3. Consumers migrate to the new event type at their own pace.
4. The old event type is retired only after telemetry confirms no consumer
   group is still reading it.

Why a new type rather than a new version of the old type: Khononov's Event
Upcasting pattern (see `references/schema-versioning.md`) offers an
alternative for permanently-stored internal events in an event-sourced
Aggregate — it is not the right tool for integration events, which can be
genuinely deprecated and retired.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| CloudEvents envelope present | Every event has all five required attributes | Events lacking `specversion`, `id`, `source`, `type`, or `datacontenttype` |
| Event type naming follows convention | `com.sdlc-factory.<bc>.<aggregate>.<verb>` | Free-form or CamelCase type names |
| Payload carries references not values | IDs, levels, and metadata only | Raw sensitive values or full Aggregate state in the payload |
| Additive-only in-place changes | New fields are optional with defaults | Required fields added in place; enum values removed in place |
| Breaking changes use new event type | Separate event type published in parallel | Breaking change made by modifying the existing type in-place |
| Schema registered before first publish | Schema in Apicurio Registry before the producer deploys | Unregistered schemas reaching the broker |
| Compatibility mode is BACKWARD | Every subject registered in BACKWARD mode | Subjects with NONE or no explicit mode |
| CI gate enforces compatibility | Schema compatibility checked in the pipeline | Compatibility relying on reviewer discipline |

---

## Anti-Patterns

- **Version suffix in the event type name.** `DataAssetClassified.v2` is not a
  type — it is an implementation detail wearing a type name. Consumers must now
  subscribe to each version explicitly rather than subscribing to a stable
  semantic event. Use a new, distinct type name when the semantics genuinely
  change.
- **Fat payload.** Serialising the whole Aggregate state into the event payload
  "so consumers have everything." Every consumer now couples to the Aggregate's
  write model, every internal field change becomes a contract negotiation, and
  sensitive fields accumulate. An event carries what changed and the IDs to
  fetch the rest.
- **Raw PII in the payload.** Immutable, replicated, multi-consumer topics are
  the worst possible location for data that may need erasure. Always carry the
  identifier; let the consumer retrieve the value under access control.
- **Breaking change in place.** Removing or renaming a field on an existing
  event type and calling it "just a schema update." Any consumer still reading
  the old field receives `null` or a decode error, silently, until a page fires.
- **Skipping schema registration.** A producer serialising from its current Go
  struct, with registry registration deferred. The registry only protects
  consumers if the registered schema *is* the wire truth at the moment the event
  is produced.
- **`NONE` compatibility mode.** Disabling compatibility enforcement to get a
  change through. Once disabled, every subsequent deploy can silently break
  consumers.

---

## References

For implementation depth, go to:

- `references/cloudevents-format.md` — complete attribute spec, event type
  naming convention, source attribute convention, worked `DataAssetClassified`
  example, Go struct layout.
- `references/schema-versioning.md` — additive change examples, breaking change
  protocol step-by-step, Event Upcasting for internally-stored events,
  deprecation timeline guidance.
- `references/schema-registry.md` — Apicurio Registry setup, schema
  registration flow, Go client pattern, Flux CRD reconciliation, compatibility
  mode configuration.
- `references/go-event-structs.md` — canonical Go struct shape for a CloudEvents
  event, JSON serialisation discipline, parse-don't-validate approach, factory
  function pattern, test helper.
