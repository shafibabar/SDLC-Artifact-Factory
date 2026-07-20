---
name: event-schema-design
description: >
  Teaches how to design the serialization contract for Domain Events — the wire
  format, the schema registry, compatibility modes, and CI enforcement of schema
  evolution. This is the operational contract layer beneath the domain-modeler's
  event catalog: the catalog defines what events mean; this skill defines how they
  are encoded on Redpanda topics, registered, versioned, and validated so producers
  and consumers never break each other. Produced by the data-architect during the
  Design phase.
version: 1.1.0
phase: design
owner: data-architect
created: 2026-06-25
tags: [design, data-architecture, event-schema, schema-registry, redpanda, compatibility, avro]
---

# Event Schema Design

## Purpose

The domain-modeler's `domain-event-catalog` defines *which* Domain Events exist, their business meaning, and the standard envelope. This skill defines the layer beneath that: how those events are serialized onto Redpanda topics, how their schemas are registered and versioned, and how compatibility is enforced so that a producer change can never silently break a consumer.

An event schema is a published contract. Once an event has been consumed by another service, its schema cannot change freely — it can only evolve within compatibility rules. This skill makes those rules explicit and machine-enforced.

---

## Division of Responsibility

| Concern | Owner | Artifact |
|---|---|---|
| What events exist, business meaning, envelope fields | domain-modeler | `domain-event-catalog` |
| Serialization format, registry, compatibility, CI enforcement | data-architect | this skill |
| Producing/consuming code (outbox, idempotent consumer) | backend-engineer | implementation |

Keep these aligned: every event in the catalog has exactly one registered schema here.

---

## Serialization Format

| Format | Strengths | Weaknesses | Verdict |
|---|---|---|---|
| **JSON Schema** | Human-readable, debuggable, no codegen needed, plays well with `jsonb` storage and PostgreSQL | Larger payloads, weaker typing | **Default.** Compliance-grade transparency: a reviewer can read the event |
| **Avro** | Compact, strong typing, built-in evolution rules, native registry support | Binary (not human-readable), requires schema to decode | Use when payload volume makes JSON cost material |
| **Protobuf** | Compact, strong typing, cross-language | Binary, separate IDL toolchain | Use only if a polyglot consumer demands it |

**Default: JSON Schema.** It matches the project's frugality and transparency posture — events are reviewable by a PM without tooling, and integrate directly with PostgreSQL `jsonb` and the outbox. Revisit per topic only when volume justifies Avro; record the choice as an ADR.

---

## Schema Registry

Every event schema is registered in a schema registry (the Redpanda Schema Registry, Apache-2.0, bundled with Redpanda — no extra system). The registry is the single source of truth for the wire contract.

| Registry concept | Meaning |
|---|---|
| Subject | A named schema lineage, one per topic + record type — convention: `<topic>-value` |
| Version | An immutable registered schema under a subject; new compatible schemas add a version |
| Compatibility mode | The rule the registry enforces before accepting a new version |

A producer registers (or validates against) its schema at build time. A schema that violates the subject's compatibility mode is rejected by CI before it ever reaches a topic.

---

## Compatibility Modes

The compatibility mode defines what evolution is allowed. Choose per subject based on whether producers or consumers upgrade first.

| Mode | Allows | Use when |
|---|---|---|
| **BACKWARD** | Delete fields, add optional fields *(Avro semantics — see the JSON Schema caveat below)* | Consumers upgrade *before* producers (most common) — new consumer reads old events |
| **FORWARD** | Add fields, delete optional fields | Producers upgrade *before* consumers |
| **FULL** | Add/delete optional fields only | Strict bidirectional safety needed |
| **NONE** | Anything | Never for a published event — only for a topic with a single owner and no external consumers |

**Default: `BACKWARD`.** Combined with the additive-change rule below, it keeps consumers safe through producer deployments.

**The JSON Schema caveat:** the "BACKWARD allows deleting fields" folklore comes from Avro, where a reader schema silently ignores unknown fields during resolution. It does not transfer to this project's defaults. With JSON Schema payloads that set `additionalProperties: false`, deleting a field is **not** backward compatible: events already on the topic still carry the field, and the new, closed schema *rejects* them as invalid. Under JSON Schema + closed payloads + `BACKWARD`, the only safe in-place change is **adding an optional field** (old events simply lack it and still validate). Treat every removal, rename, or type change as breaking and version it — and expect the registry's JSON Schema compatibility checker to enforce exactly this, not Avro's rules.

---

## The Evolution Rules

These map the domain-event-catalog's "additive vs breaking" guidance onto registry-enforced mechanics:

### Additive (safe — same major version)

- Add a new **optional** field (with a default)
- Add a new event type (new subject)
- Widen a constraint (e.g., increase an enum's allowed set, if consumers tolerate unknown values)

### Breaking (requires a new event version, parallel publication)

- Remove or rename a field consumers rely on
- Change a field's type or semantics
- Make an optional field required
- Narrow a constraint (remove an enum value)

A breaking change is never made in place. Instead:

1. Define a new event version: `DataAssetClassified` → `DataAssetClassified` v2 (new subject `data-asset-classified-v2-value`, or a `schemaVersion` discriminator).
2. Producers publish **both** versions during a transition window.
3. Consumers migrate to v2 at their own pace.
4. v1 is retired only after telemetry confirms no consumer reads it.

---

## Schema Anatomy

Every event schema has two parts: the standard envelope (fixed across all events, from the catalog) and the event-specific payload.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://schemas.example.com/events/data-asset-classified/v1.json",
  "title": "DataAssetClassified",
  "type": "object",
  "required": ["eventId","eventType","schemaVersion","occurredAt","aggregateId","tenantId","payload"],
  "properties": {
    "eventId":       { "type": "string", "format": "uuid" },
    "eventType":     { "const": "DataAssetClassified" },
    "schemaVersion": { "type": "integer", "const": 1 },
    "occurredAt":    { "type": "string", "format": "date-time" },
    "aggregateId":   { "type": "string", "format": "uuid" },
    "correlationId": { "type": "string", "format": "uuid" },
    "causationId":   { "type": "string", "format": "uuid" },
    "tenantId":      { "type": "string", "format": "uuid" },
    "payload": {
      "type": "object",
      "required": ["sensitivityLevel","classifiedBy"],
      "properties": {
        "sensitivityLevel": { "enum": ["Public","Internal","Confidential","Restricted"] },
        "classifiedBy":     { "type": "string", "format": "uuid" }
      },
      "additionalProperties": false
    }
  },
  "additionalProperties": false
}
```

**`additionalProperties: false`** on the payload is deliberate: it forces every new field to be a conscious, registered schema change rather than an accidental untracked addition.

**Payload minimalism is a retention constraint, not a style preference.** The event log is immutable and replicated — a payload cannot be edited or row-deleted later. Payloads therefore carry identifiers, levels, and metadata (`sensitivityLevel`, `classifiedBy`, aggregate IDs), never raw sensitive content: a raw SSN in a `DataAssetClassified` payload could only ever be erased by crypto-shredding the whole topic's data (see `data-retention-policy`). Schema review explicitly checks new payload fields against the classification scheme — any field that would embed a Restricted raw value is rejected in favour of a reference.

---

## CI Enforcement

Schema compatibility is enforced in the pipeline, not by review discipline. The CI gate:

```yaml
# Validate every changed event schema against the registry's compatibility mode
- name: Validate event schemas
  run: |
    for schema in $(git diff --name-only origin/main HEAD | grep '^schemas/events/.*\.json$'); do
      subject=$(basename "$(dirname "$schema")")-value
      rpk registry schema check --subject "$subject" --schema "$schema"   # fails on incompatibility
    done
```

A pull request that introduces an incompatible schema fails the build. There is no path to deploy a breaking schema change without explicitly versioning it.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| One schema per catalog event | Every event in the domain-event-catalog has a registered schema | Catalog events with no wire contract |
| Compatibility mode set | Every subject has an explicit compatibility mode (default BACKWARD) | Subjects with NONE or unset mode for published events |
| Additive-by-default | New fields are optional with defaults | Required fields added in place |
| Breaking changes versioned | Breaking changes create a new version with parallel publication | Breaking change made in place on an existing subject |
| `additionalProperties` closed | Payloads set `additionalProperties: false` | Open payloads allowing untracked fields |
| CI-enforced | Schema compatibility checked in the pipeline | Compatibility relying on reviewer vigilance |
| Payloads carry references | IDs, levels, metadata only | Raw sensitive values embedded in immutable events |
| Format semantics respected | Evolution rules reasoned in JSON Schema terms (closed payloads) | Avro deletion folklore applied to JSON Schema subjects |

---

## Anti-Patterns

- **`NONE` on a published subject.** Disabling compatibility "temporarily" to get a change through. The registry is the only mechanical guarantee producers and consumers share; with `NONE`, the next deploy can strand every consumer with undecodable events.
- **Fixing a registered schema in place.** Editing version 3 because it "had a typo". Registered versions are immutable history — events encoded against them exist on topics. A wrong schema is superseded by a new version, never rewritten.
- **The open payload.** Omitting `additionalProperties: false` so producers can slip fields in without registering them. Every untracked field is an undocumented contract some consumer will start depending on — and its later removal is an unversioned breaking change nobody gated.
- **Avro reasoning on JSON Schema subjects.** Deleting a field because "BACKWARD allows deletion". Under closed JSON Schema payloads it does not — old events on the topic fail validation against the new schema. Evolution decisions are reasoned in the semantics of the registered format.
- **The fat event.** Serializing the entire Aggregate into every event "so consumers have everything". Consumers couple to the whole write model, every internal field change becomes a wire-contract negotiation, and payloads accrete sensitive attributes. An event carries what changed and the IDs to fetch the rest.
- **Registry bypass.** A producer serializing whatever its current Go struct happens to be, with the registered schema updated "when we get to it". The registry only protects consumers if the registered schema *is* the wire truth — codegen or validation ties the struct to the registered version in CI.
- **Raw PII in payloads.** Embedding extracted sensitive values in events for convenience. Immutable, replicated, multi-consumer topics are the single worst place for data that may need erasure (see `data-retention-policy`).

---

## Output Format

```markdown
---
name: event-schema-design
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: data-architect
---

# Event Schema Design

## Serialization Format Decision
[Format chosen, per topic if it varies, with ADR reference]

## Subject Registry
| Subject | Topic | Event type | Compatibility mode |
|---|---|---|---|

## Event Schemas
[JSON Schema per event — envelope + payload]

## Evolution Policy
[Additive rules; breaking-change versioning procedure]

## CI Enforcement
[The pipeline gate that validates compatibility]
```
