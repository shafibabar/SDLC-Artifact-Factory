# Example 1 — Lean: JSON, No Registry, Contract Tests

Self-contained. **Crumbline** takes pre-orders for a two-shop bakery, at the **lean** profile, as one modular monolith. Two contexts publish events: **Ordering** (`OrderPlaced`, `OrderCollected`) and **Baking** (`BakePlanPublished`). The consumers are the bake planner and a reminder sender, all in the same codebase. The phase plan skips `event-schemas.md` at lean; the product owner asked for it directly.

## Input

> **User:** "Set up Apicurio for our events, and list the five required CloudEvents attributes in the doc. Also put eventId and occurredAt in each payload so the reminder sender has them."

## Working it

- **Registry:** three event types, two consumers, one codebase, one team. A registry adds a service to run and buys little here. Schema files live in the repo beside Ordering. The bake planner and reminder sender each have a consumer contract test, and CI runs a schema diff that fails on a rename or removal (Young: lean products can run JSON weak schema with contract tests). Revisit when an outside consumer appears.
- **Required attributes:** the spec requires four (`specversion`, `id`, `source`, `type`). `datacontenttype` is a house rule.
- **`eventId` / `occurredAt` in the payload:** these are `id` and `time` in the envelope. Copying them into `data` creates two answers that can drift. The reminder sender reads the envelope.
- **Mode:** structured JSON, so one value carries everything. **Compatibility:** BACKWARD semantics, held by tolerant readers and the CI diff.

## Output: `design/data/event-schemas.md` (excerpt)

```markdown
---
name: event-schema
product: crumbline
version: 1.0.0
phase: design
owner: data-architect
created: 2026-11-05
summary: Crumbline's three event types use CloudEvents JSON in structured mode, schema files in the repo and consumer contract tests instead of a registry.
profile: lean
traces-to: [design/domain-model.md, design/context-map.md]
---

# Event Schemas: Crumbline

## Conventions

| Convention | Value |
|---|---|
| **Envelope** | CloudEvents 1.0 — spec-required: specversion, id, source, type; house-required: datacontenttype, dataschema, subject, time |
| **Extensions** | correlationid, causationid — set by the producer from the Command being handled |
| **Type naming** | com.crumbline.<context>.<aggregate>.<past-tense-verb>, lower-case, no version suffix |
| **Source** | /ordering, /baking (stable) |
| **Format** | JSON with tolerant readers — few consumers, readable topics |
| **Content mode** | structured — one value carries the whole event |
| **Registry** | none: schema files in the repo + consumer contract tests — 3 types, 2 consumers, one codebase; revisit at the first outside consumer |
| **Default compatibility** | BACKWARD — held by tolerant readers and the CI schema diff |
| **CI gate** | schema diff on schemas/events fails on a removed, renamed or retyped field; consumer contract tests run on every build |

## Event: com.crumbline.ordering.order.placed

| Field | Value |
|---|---|
| **Domain Event** | OrderPlaced — design/domain-model.md |
| **Kind** | published |
| **source** | /ordering |
| **subject** | orderId |
| **dataschema** | schemas/events/ordering/order-placed/1.json |
| **Compatibility** | BACKWARD |
| **Consumers** | bake planner, reminder sender |

### Payload (data)

| Field | Type | Required | Default for old events | Why included |
|---|---|---|---|---|
| orderId | string | yes | — | the order to plan and remind about |
| shop | enum(high-street, station) | yes | — | which shop bakes it |
| collectOn | date | yes | — | the bake planner's day |
| items | array of {product, quantity} | yes | — | what to bake |

### Deliberately excluded

| Field | Why excluded |
|---|---|
| eventId, occurredAt | envelope attributes (id, time) |
| customerPhone | sensitive; the reminder sender fetches it from Ordering under access control |
| orderTotal | derived from items and the price list; can drift |
```

## Why this is right

- The registry request is declined with its reason: at this size, schema files, contract tests and a CI diff protect consumers as well as a registry would.
- Four spec-required attributes, with the house rules labelled as house rules.
- Envelope facts stay in the envelope; the payload carries only what the consumers act on.
