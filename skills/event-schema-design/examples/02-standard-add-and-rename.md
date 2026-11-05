# Example 2 — Standard: An Additive Change and a Rename

Self-contained. **Fernpost** runs parcel lockers in railway stations, at the **standard** profile. Three teams consume `com.fernpost.billing.charge.captured` from the **Billing** context: Finance Reporting, Partner Payouts and the customer Receipts service. Events are JSON on Redpanda, with an Apicurio registry in BACKWARD mode, chosen because three teams deploy independently.

## Input

> **User:** "Two changes to ChargeCaptured. Add `lockerSize` so Finance can report by size. And rename `amount` to `amountMinor`: it's going from a decimal string in pounds to an integer in pence. Bump it to `charge.captured.v2` and we're done. Old events can default `lockerSize` to `medium`."

## Working it

- **`lockerSize`, classified (Young):** an optional field is additive, so it goes in place on the same type with a new schema version. But defaulting old events to `medium` misstates history: old events never recorded a size. The default is **unknown** (the field absent), and Finance reports pre-change charges as "size unknown".
- **`amount` → `amountMinor`:** a rename *and* a type *and* a unit change. All three are breaking. In JSON Schema the registry might even accept a new optional `amountMinor` with `amount` dropped; that is exactly why the mode isn't the test.
- **`.v2`:** declined (D047-1). Consumers would have to enumerate versions, and the name wouldn't say what changed. A new descriptive type, `charge.captured-in-minor-units`, is published beside the old one. Each of the three consumer teams is told, with a deprecation date. The old type retires when consumer-group offsets show nobody reads it.
- **Plan → validate → execute:** the plan names the new schema (registered first), the dual-publish window (6 weeks), the three consumers, and the telemetry check. It is reviewed before Billing publishes anything new.

## Output: `design/data/event-schemas.md` (excerpt)

```markdown
---
name: event-schema
product: fernpost
version: 2.0.0
phase: design
owner: data-architect
created: 2026-11-05
summary: ChargeCaptured gains an optional lockerSize in place; the pounds-to-pence change ships as a new type, charge.captured-in-minor-units, dual-published for six weeks.
profile: standard
traces-to: [design/billing/domain-event-catalog.md, design/context-map.md]
---

# Event Schemas: Fernpost

## Conventions

| Convention | Value |
|---|---|
| **Envelope** | CloudEvents 1.0 — spec-required: specversion, id, source, type; house-required: datacontenttype, dataschema, subject, time |
| **Extensions** | correlationid, causationid, partitionkey — producer sets all three; partitionkey is the charge's locker |
| **Type naming** | com.fernpost.<context>.<aggregate>.<past-tense-verb>, lower-case, no version suffix |
| **Source** | /billing, /lockers (stable) |
| **Format** | JSON with tolerant readers — three consumer teams, readable topics |
| **Content mode** | structured — the DLQ forwards values byte for byte |
| **Registry** | Apicurio Registry — three teams deploy independently |
| **Default compatibility** | BACKWARD_TRANSITIVE — consumers upgrade first; the topic is retained 90 days and replayed |
| **CI gate** | the pipeline registers the schema; a 409 from the registry fails the build |

## Event: com.fernpost.billing.charge.captured

| Field | Value |
|---|---|
| **Domain Event** | ChargeCaptured — design/billing/domain-event-catalog.md |
| **Kind** | published |
| **source** | /billing |
| **subject** | chargeId |
| **dataschema** | https://registry.fernpost.example/events/charge-captured/4 |
| **Compatibility** | BACKWARD_TRANSITIVE |
| **Consumers** | Finance Reporting, Partner Payouts, Receipts |

### Payload (data)

| Field | Type | Required | Default for old events | Why included |
|---|---|---|---|---|
| chargeId | string | yes | — | the charge |
| rentalId | string | yes | — | links to the rental for receipts |
| amount | string (decimal pounds) | yes | — | what was charged |
| lockerSize | enum(small, medium, large) | no | absent = size unknown (not recorded before 2026-11) | Finance reports by size |

### Change log

| Date | Change | Class | Action |
|---|---|---|---|
| 2026-11-05 | add optional lockerSize | additive | in place, schema version 4 |
| 2026-11-05 | rename amount to amountMinor as integer pence | breaking | new type com.fernpost.billing.charge.captured-in-minor-units, dual publish until 2026-12-17, retire when telemetry shows no consumer group reads this type |

## Event: com.fernpost.billing.charge.captured-in-minor-units

| Field | Value |
|---|---|
| **Domain Event** | ChargeCaptured — design/billing/domain-event-catalog.md |
| **Kind** | published |
| **source** | /billing |
| **subject** | chargeId |
| **dataschema** | https://registry.fernpost.example/events/charge-captured-in-minor-units/1 |
| **Compatibility** | BACKWARD_TRANSITIVE |
| **Consumers** | Finance Reporting, Partner Payouts, Receipts (migrating by 2026-12-17) |

### Payload (data)

| Field | Type | Required | Default for old events | Why included |
|---|---|---|---|---|
| chargeId | string | yes | — | the charge |
| rentalId | string | yes | — | links to the rental |
| amountMinor | integer (pence) | yes | — | what was charged, without decimal rounding |
| currency | string (ISO 4217) | yes | — | the unit, stated rather than assumed |
| lockerSize | enum(small, medium, large) | no | absent = size unknown | Finance reports by size |
```

## Why this is right

- The additive change went in place, with a default that tells the truth about old events.
- The rename was recognised as breaking three ways. It became a new type with a window, named consumers and a telemetry exit.
- The `.v2` request and the `medium` default were both declined, each with its reason.
