---
name: event-schema
product: [product slug]
version: 1.0.0
phase: design
owner: data-architect
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: how many event types, the format and registry choice, and any breaking change in flight]
profile: [lean | standard | enterprise]
traces-to: [design/<context>/domain-event-catalog.md, design/context-map.md, design/data/data-model.md, …]
---

# Event Schemas: [Product]

Version rule: MINOR when a type is added or a field added in place; MAJOR when a breaking change starts (a new type and dual publishing) or a convention changes.

<!-- The wire contract only. What each event means is in domain-event-catalog; publishing code is go-event-publisher.
     No code (D047-10). A sample event in JSON is fine. -->

## Conventions

| Convention | Value |
|---|---|
| **Envelope** | CloudEvents 1.0 — spec-required: specversion, id, source, type; house-required: datacontenttype, dataschema, subject, time |
| **Extensions** | correlationid, causationid[, tenantid][, partitionkey][, traceparent] — [who sets each] |
| **Type naming** | [reverse-dns].<context>.<aggregate>.<past-tense-verb>, lower-case, no version suffix |
| **Source** | /<context>, stable (no deploy version) |
| **Format** | [JSON with tolerant readers | Avro | Protobuf] — [why] |
| **Content mode** | [structured | binary] — [why] |
| **Registry** | [none: schema files in the repo + consumer contract tests | registry name] — [why, from consumers and profile] |
| **Default compatibility** | [BACKWARD | FORWARD | FULL][_TRANSITIVE] — [deploy order and retention] |
| **CI gate** | [registration attempt or schema diff that fails the build on an incompatible change] |

## Event: [type string]

| Field | Value |
|---|---|
| **Domain Event** | [PastTenseName] — [design/<context>/domain-event-catalog.md] |
| **Kind** | [published | stored (event-sourced, internal)] |
| **source** | [/context] |
| **subject** | [the Aggregate ID field] |
| **dataschema** | [versioned URI or path] |
| **Compatibility** | [mode] — [why, if not the default] |
| **Consumers** | [named consumers, or "none yet"] |

### Payload (data)

| Field | Type | Required | Default for old events | Why included |
|---|---|---|---|---|
| [field] | [string | integer | timestamp | enum(…) | …] | [yes | no] | [— if required; else the default and what it means] | [what a consumer does with it] |

### Deliberately excluded

| Field | Why excluded |
|---|---|
| [field] | [envelope attribute | derived value | sensitive | whole-Aggregate state] |

### Change log

| Date | Change | Class | Action |
|---|---|---|---|
| [YYYY-MM-DD] | [what changed] | [additive | additive with notice | breaking | new event] | [in place | new type <type>, dual publish until <date>, retire on telemetry | upcaster v1→v2 (stored only)] |

## Open questions

- [question for the product owner or a consumer team]
