# Example 3 — Enterprise: Protobuf, a Registry, Binary Mode and Stored Events

Self-contained. **Coastline Energy** reads 4 million smart meters across three regions, at the **enterprise** profile. **Metering** publishes `meter.reading-recorded` at high volume to about a dozen consumers: Billing, Network Planning, a regulator feed, and analytics teams, which deploy on no fixed order. **Tariffs** is an event-sourced Aggregate; its stored events are internal. Readings are personal data under the regulator's rules.

## Input

> **User:** "Use Protobuf and the registry in BACKWARD. Put the meter's address in each reading so analytics don't have to join. And the Tariff events changed shape last quarter. Publish a new type for them like we do for readings, and migrate the store by editing the old rows."

## Working it

- **Format and mode:** Protobuf, for volume and typed contracts across languages. The registry is required, since readers need the writer's schema. **Binary mode** carries the bytes as the value with `ce_` headers, so routers filter on `ce_type` and `ce_tenantid` without decoding. Every forwarder, the Dead Letter Queue included, must copy the headers.
- **Compatibility:** consumers deploy in no fixed order, the topic is retained for 13 months, and Network Planning replays it. So the mode is **FULL_TRANSITIVE**, not BACKWARD: old readers must read new events and new readers must read every old one. Protobuf rules: add fields with new numbers only, never reuse or renumber.
- **The meter's address in every reading:** declined. It is personal data on a retained, replicated topic, where erasure means crypto-shredding. It is also derived from the meter register and can drift. Analytics joins on `meterId` against a Read Model under access control.
- **Tariff events are stored events.** They can't be retired, so the published-event protocol doesn't apply. The change was convertible (a `rate` split into `rate` and `standingCharge`), so it gets an **upcaster** on read. **Editing old rows is declined:** it destroys the audit trail and can't be undone (Young). Tariffs publishes a coarser `tariff.changed` for other contexts, translated from the stream (`aggregate-design`).
- **`tenantid`:** Coastline is multi-tenant: it meters for three regional distribution companies, and the regulator requires separation. So `tenantid` is set on every event, and `partitionkey` is the meter.

## Output: `design/data/event-schemas.md` (excerpt)

```markdown
---
name: event-schema
product: coastline-energy
version: 1.0.0
phase: design
owner: data-architect
created: 2026-11-05
summary: Meter readings use Protobuf in binary mode with a FULL_TRANSITIVE registry subject; Tariff's stored events evolve by upcasting, never by editing rows.
profile: enterprise
traces-to: [design/metering/domain-event-catalog.md, design/tariffs/aggregates.md, design/context-map.md, requirements/nfr-specification.md]
---

# Event Schemas: Coastline Energy

## Conventions

| Convention | Value |
|---|---|
| **Envelope** | CloudEvents 1.0 — spec-required: specversion, id, source, type; house-required: datacontenttype, dataschema, subject, time |
| **Extensions** | correlationid, causationid, tenantid, partitionkey, traceparent — producer sets all; tenantid is the distribution company; partitionkey is the meter |
| **Type naming** | com.coastline-energy.<context>.<aggregate>.<past-tense-verb>, lower-case, no version suffix |
| **Source** | /metering, /tariffs (stable) |
| **Format** | Protobuf — 4 million meters, a dozen consumers in several languages |
| **Content mode** | binary — routers filter on ce_type and ce_tenantid; the DLQ copies all ce_ headers |
| **Registry** | Apicurio Registry, one per region, replicated from the central one — Protobuf readers need the writer's schema |
| **Default compatibility** | FULL_TRANSITIVE — no deploy order across a dozen consumers; 13-month retention with replays |
| **CI gate** | the pipeline registers the schema against the central registry; an incompatible version fails the build before any region deploys |

## Event: com.coastline-energy.metering.meter.reading-recorded

| Field | Value |
|---|---|
| **Domain Event** | MeterReadingRecorded — design/metering/domain-event-catalog.md |
| **Kind** | published |
| **source** | /metering |
| **subject** | meterId |
| **dataschema** | https://registry.coastline-energy.example/metering/meter-reading-recorded/7 |
| **Compatibility** | FULL_TRANSITIVE |
| **Consumers** | Billing, Network Planning, regulator feed, analytics (9 teams) |

### Payload (data)

| Field | Type | Required | Default for old events | Why included |
|---|---|---|---|---|
| meterId | string (field 1) | yes | — | the meter |
| registerId | string (field 2) | yes | — | which register on a multi-rate meter |
| readingKwh | int64 watt-hours (field 3) | yes | — | the reading, without decimal rounding |
| readingQuality | enum(ACTUAL, ESTIMATED, UNKNOWN) (field 4) | no | UNKNOWN (quality not recorded before schema 5) | Billing must not bill estimates as actual |

### Deliberately excluded

| Field | Why excluded |
|---|---|
| supplyAddress | personal data on a retained topic; derived from the meter register; join on meterId via a Read Model |
| customerName | personal data; not needed to react to a reading |
| readAt | the envelope's time attribute |

## Event: com.coastline-energy.tariffs.tariff.rate-set

| Field | Value |
|---|---|
| **Domain Event** | TariffRateSet — design/tariffs/aggregates.md |
| **Kind** | stored (event-sourced, internal) |
| **source** | /tariffs |
| **subject** | tariffId |
| **dataschema** | https://registry.coastline-energy.example/tariffs/tariff-rate-set/3 |
| **Compatibility** | BACKWARD_TRANSITIVE — only Tariffs reads its own stream, and every stored shape must stay readable |
| **Consumers** | none outside Tariffs (others consume the translated tariff.changed) |

### Payload (data)

| Field | Type | Required | Default for old events | Why included |
|---|---|---|---|---|
| tariffId | string | yes | — | the tariff |
| unitRatePencePerKwh | int32 tenths of a penny | yes | — | the energy rate |
| standingChargePencePerDay | int32 tenths of a penny | no | derived by the upcaster from the old combined rate's published split | the daily charge, split from the rate in schema 3 |

### Change log

| Date | Change | Class | Action |
|---|---|---|---|
| 2026-08-01 | split rate into unit rate and standing charge | breaking | upcaster v2→v3 on read; stored rows never edited; fixtures of every old shape in the test suite |
```

## Why this is right

- The compatibility mode follows from deploy order and retention, so it is FULL_TRANSITIVE, not the default BACKWARD.
- Binary mode was chosen for header routing, with the forwarding cost stated.
- The address request was declined on two grounds: personal data on a retained topic, and a derived value that can drift.
- Stored events evolve by upcasting. Editing rows and a "new type like readings" were both declined, with their reasons.
- `tenantid` is set because this product's NFRs make it multi-tenant, not by default.
