# CloudEvents 1.0 Specification
**Authors:** CNCF Serverless Working Group / CloudEvents project (*CloudEvents* specification v1.0, with patch releases 1.0.1 and 1.0.2; plus the JSON Event Format, the Kafka and HTTP Protocol Bindings, the documented extensions and the Primer; free, Apache 2.0, github.com/cloudevents/spec)
**Domain:** Software Architecture — event envelope standard (context attributes, event formats, protocol bindings)

This file grounds the event envelope rule that the Wave 2 audit found contradicting itself and the spec (W2-4, W2-5). Decision D047-1 sets the house rule: the envelope is CloudEvents 1.0 with three extensions (`correlationid`, `causationid`, `tenantid`); a breaking change is a new event type, never a `.vN` suffix; `event-schema-design` owns the rule and `domain-event-catalog` points to it. Versioning approaches themselves (weak schema, upcasting, copy-and-replace) are in `research/domain-driven-design/versioning-event-sourced-system-young.md`; this file covers only what CloudEvents says about where a version goes.

## Core Concepts

- **CloudEvents standardises the envelope, not the event.** It defines a small set of *context attributes* (metadata any router or consumer can read without knowing the event) and leaves *data* (the payload) to the producer. Formats (JSON, Avro, Protobuf) say how an event is serialised; protocol bindings (HTTP, Kafka, AMQP, MQTT, NATS) say how it rides a transport.
- **Exactly four attributes are REQUIRED.** `id`, `source`, `specversion` and `type`. Nothing else is mandatory in the spec, `datacontenttype` included.
  - **`id`:** a non-empty String. It only has to be unique *within the scope of its `source`*: `source` + `id` identifies one event, and a consumer may treat two events with the same pair as duplicates (the basis for Idempotency). A UUID satisfies this but is not required.
  - **`source`:** a non-empty URI-reference identifying the context in which the event happened (a service, a Bounded Context, a device). Absolute URIs are recommended for events that leave an organisation; a relative path like `/data-asset-management` is valid.
  - **`specversion`:** the String `"1.0"`. It stays `"1.0"` for every 1.0.x patch release.
  - **`type`:** a non-empty String naming the kind of occurrence, used for routing, filtering and policy. The spec says it SHOULD be prefixed with a reverse-DNS name (the organisation that defines the type's meaning), e.g. `com.example.orders.order.placed`. The spec does not fix the rest of the string.
- **Four core attributes are OPTIONAL, each with one job.**
  - **`datacontenttype`:** the RFC 2046 media type of `data` (e.g. `application/json`). When absent, `data` follows the event format's own encoding; in the JSON format that means JSON.
  - **`dataschema`:** a URI of the schema `data` adheres to. The spec text says incompatible changes to the schema SHOULD be reflected by a different URI.
  - **`subject`:** the thing the event is about, within the producer's context (e.g. the Aggregate ID). It lets an intermediary filter on the instance without decoding `data`.
  - **`time`:** a Timestamp (RFC 3339) of when the *occurrence* happened. If it cannot be known, all producers for the same `source` must use the same rule for setting it.
- **Extension context attributes are allowed, flat and named strictly.** Names MUST use only lower-case ASCII letters a–z and digits 0–9 (no hyphens, underscores or camelCase), SHOULD be descriptive and terse, and SHOULD NOT exceed 20 characters. Extensions sit at the top level beside the core attributes (1.0 removed the nested `extensions` bag). A consumer that does not know an extension must ignore it, not reject the event.
- **The spec repo documents a set of extensions, but they are optional.** These include Distributed Tracing (`traceparent`, `tracestate`, W3C Trace Context), Partitioning (`partitionkey`), Sequence (`sequence`), and Dataref (`dataref`, the claim-check pointer to data held elsewhere), along with others such as auth context, expiry time and severity. `correlationid`, `causationid` and `tenantid` are **not** spec-defined anywhere: they are custom extensions, valid because they follow the naming rules, and the house must document their meaning itself.
- **Attribute values use a closed type system.** Boolean, Integer (32-bit signed), String, Binary, URI, URI-reference and Timestamp. No maps, arrays or null as values: an attribute is present with a valid value or absent. Every type has a canonical string form, which is what lets attributes travel as transport headers.
- **The JSON format puts data in `data` or `data_base64`, never both.** The event's media type is `application/cloudevents+json` (`application/cloudevents-batch+json` for a batch). If `datacontenttype` is JSON (`application/json` or a `+json` suffix), `data` holds the JSON value directly, not an escaped string. Binary payloads go Base64-encoded in `data_base64`.
- **Every binding offers two content modes.**
  - **Binary mode:** `data` is the raw message body; each attribute becomes a transport header. HTTP prefixes headers with `ce-` (`ce-id`, `ce-type`); Kafka prefixes them with `ce_` (`ce_id`, `ce_type`). In both, `datacontenttype` maps to the plain `content-type` header, not a prefixed one.
  - **Structured mode:** the whole event (attributes plus `data`) is serialised into the body in an event format, with `content-type: application/cloudevents+json`. Headers carry nothing CloudEvents-specific.
- **The Kafka binding maps `partitionkey` to the message key.** The 1.0.x Kafka binding describes key mapping: when the Partitioning extension is used, the Kafka record key is set from `partitionkey` (and read back into it on consume), so per-key ordering is visible at the envelope level.
- **The spec deliberately leaves out payload schema, versioning policy and routing.** It does not define what goes in `data`, how a schema evolves, delivery guarantees, or subscription and routing (those are separate CNCF specs: Subscriptions, Discovery, CloudEvents SQL). Versioning appears only as the `dataschema` sentence above.
- **The Primer (non-normative) gives the versioning advice.** As recalled, it says a backward-compatible change to the data should generally show up as a new `dataschema` value, and an incompatible change should generally show up as a new `type`, with the producer encouraged to emit both old and new events for a period. This is advice, not spec text, but it matches D047-1 exactly.

## Actionable Techniques

- **Validate against four required attributes, then add house rules separately.** Say "the spec requires `id`, `source`, `specversion`, `type`; this platform also always sets `time`, `datacontenttype`, `dataschema`, `subject`, `correlationid`, `causationid`, `tenantid`". Never present a house rule as spec.
- **Keep `source` stable per context.** A deploy version inside `source` changes it on every release, breaks filters on `source`, and widens the `id` uniqueness scope for no gain.
- **Make `dataschema` version-specific.** Point it at the registry's versioned schema URI, so a schema change gives a different URI as the spec asks; a breaking change gets a new `type` (Primer, D047-1).
- **Declare the three custom extensions once, with types.** `correlationid`, `causationid`, `tenantid`: String, meaning, who sets each, and how they propagate. Optionally adopt `partitionkey` (set to the tenant ID where tenants are the ordering unit) and `traceparent`.
- **Choose one Kafka content mode per platform and write it down.** Structured mode keeps the whole event in the value, so a byte-for-byte DLQ forward and Debezium outbox relay carry everything. Binary mode lets consumers and brokers filter on `ce_` headers without decoding, but every forwarder must copy headers too.

## Applies To

| Skill file (lines) | What it says now | What this research changes |
|---|---|---|
| `event-schema-design/SKILL.md:44-52` | Five required attributes, including `datacontenttype` | Four required (`id`, `source`, `specversion`, `type`). Move `datacontenttype` to a "house-required optional" list with `time`, `dataschema`, `subject` and the three D047-1 extensions |
| `event-schema-design/SKILL.md:136` | Quality criterion fails events missing any of the five | Split: spec-required four (fail = invalid CloudEvent) and house-required set (fail = house rule) |
| `event-schema-design/references/cloudevents-format.md:13-16` | "No extensions to the envelope structure without an explicit ADR" | Contradicts D047-1. Add an Extensions section: naming rules, the three custom extensions as Strings with meaning and propagation, and which documented extensions (`partitionkey`, `traceparent`) are adopted |
| `event-schema-design/references/cloudevents-format.md:23-24, 85-102` | `id` "globally unique"; `source` = `/<service-name>/<semver>` | `id` unique within `source` (spec). Drop the version from `source`; use a stable context URI such as `/data-asset-management` |
| `event-schema-design/references/cloudevents-format.md:26` | `datacontenttype` in the Required table | Move to optional; keep "always `application/json`" as a house rule |
| `event-schema-design/references/cloudevents-format.md:33` vs `:139` | `time` = when the domain event occurred; later `time` = "event produced" beside a payload `classifiedAt` | The spec defines `time` as the occurrence time. Fix line 139 and drop `classifiedAt` from the payload, or say why both exist |
| `event-schema-design/references/cloudevents-format.md:36-39` | `dataref` as a "reserved optional attribute" | `dataref` is a documented extension (claim check), not a core attribute. Reword |
| `event-schema-design/references/cloudevents-format.md:119, 136` | Unversioned registry URL in `dataschema`; `tenantId` in `data` "for physical multi-tenancy" | Versioned schema URI in `dataschema`. Carry tenant as the `tenantid` extension (D047-1) and drop the physical-tenancy claim (D047-7) |
| `event-schema-design/references/cloudevents-format.md` (new section) | No content mode or binding named anywhere | Add Kafka binding: binary (`ce_` headers, `content-type`) vs structured (`application/cloudevents+json`), the chosen default, and `partitionkey` → record key |
| `event-schema-design/references/go-event-structs.md:16-72, 173, 226-233` | Go envelope with five required fields and no extensions; `Time` with `omitempty` | Move to the `go-*` skills (D047-10). There: required four, extension fields, and note that `omitempty` never omits a zero `time.Time` in `encoding/json`. Or use the CNCF Go SDK rather than a hand-rolled struct Also: the test helper `MustNewClassifiedEvent` (`:276-299`) declares a `dataasset.ClassifiedPayload` return type but returns the `cloudevents.Event`, so it does not compile; fix it when the code moves. |
| `domain-event-catalog/SKILL.md:7, 71-89` | House "canonical envelope" (`eventId`, `eventType`, `version`, `occurredAt`, `aggregateType`, `boundedContext`, `payload`) | Replace with a pointer to `event-schema-design`. Mapping: `eventId`→`id`, `eventType`→`type`, `occurredAt`→`time`, `aggregateId`→`subject`, `boundedContext`→`source`, `aggregateType`→part of `type`, `version`→dropped (`dataschema`), `payload`→`data`, the three IDs→extensions |
| `domain-event-catalog/SKILL.md:159` | Fails events missing `eventId`, `correlationId`, `tenantId`, `version` | Fail on missing `id`, `correlationid`, `tenantid`; drop `version` |
| `domain-event-catalog/references/event-format.md:9-24, 27-104, 128-153` | House field table, Go struct, worked JSON in the house shape | Rewrite the worked example as a CloudEvent; move the Go code to `go-*` (D047-10); keep the per-event definition block (`:162-195`) minus `Version` |
| `domain-event-catalog/references/event-format.md:110, 115, 119` | "Not a formal CloudEvents implementation"; type `com.caizin.classification-engine.DataAssetClassified`; source `https://caizin.com/...` | Delete the disclaimer: the envelope *is* CloudEvents (D047-1). Use the single house type scheme from `event-schema-design` and a neutral example domain, not a company name |
| `domain-event-catalog/references/event-format.md:120-122` | `correlationid`, `causationid`, `tenantid` as extension attributes "not in the core spec" | Correct per spec. Keep, and add that no CloudEvents extension document defines them, so the house defines them |
| `domain-event-catalog/references/event-format.md:124` | "Set the `ce-specversion: 1.0` header" when publishing to Redpanda | `ce-` is the HTTP prefix; Kafka uses `ce_`. Binary mode needs every attribute as a header (`ce_id`, `ce_source`, `ce_type`, ...), not only `specversion` |
| `domain-event-catalog/references/catalog-template.md:113-114, 171` | camelCase `correlationId` / `causationId` in envelope JSON | Lower-case extension names, top-level in the event |
| `go-event-publisher/SKILL.md:61-86` | Envelope with `EventType`, `SchemaVersion: 1`, `Payload`, claimed as `event-schema-design`'s standard; key = tenant ID | A third envelope shape; replace with the CloudEvents envelope. Express the tenant key as `partitionkey`. OTel's `traceparent` record header is protocol-level tracing and can stay |
| `python-event-publisher/SKILL.md:60, 137` | Points to `domain-event-catalog`'s envelope shape | Point to `event-schema-design` |
| `go-event-consumer/SKILL.md:83`; `references/dead-letter-queue-standard.md:51` | DLQ forwards envelope bytes unchanged, failure metadata in headers | True only in structured mode. In binary mode the `ce_` headers are part of the event and must be copied to the DLQ record |
| `event-driven-patterns/SKILL.md:83`; `references/go-implementation.md:194` | Envelope `causationId` / `correlationId` | Rename to the extension names `causationid` / `correlationid` |

## Candidate New Skills/Agents

- **No new skill or agent.** `event-schema-design` owns the envelope (D047-1, data-architect per D047-2).
- **Split `event-schema-design/references/cloudevents-format.md`** into the attribute rules (spec vs house), an `extensions.md` (the three custom extensions plus adopted documented ones), and a `protocol-bindings.md` (Kafka content modes, key mapping, header names). Add `examples/` with one event in JSON structured mode and the same event as Kafka binary-mode headers.

## Key Terminology

- **Context attribute** — envelope metadata (`id`, `type`, ...), as opposed to `data`.
- **Extension context attribute** — any attribute beyond the core ones; documented (`partitionkey`) or custom (`tenantid`).
- **Event format** — a serialisation of a whole event (JSON, Avro, Protobuf).
- **Protocol binding** — how an event maps onto a transport (HTTP, Kafka).
- **Binary content mode** — attributes in transport headers, data as the body.
- **Structured content mode** — the whole event serialised in the body.
- **Primer** — the non-normative companion document explaining design choices and advice.

## Caveats

- **Certain from the spec:** the four required and four optional core attributes and their types; `id` unique within `source`; `type` reverse-DNS SHOULD; the extension naming character set; the type system; `data` vs `data_base64`; binary vs structured modes; the `ce-` (HTTP) and `ce_` (Kafka) header prefixes; `datacontenttype` → `content-type`; the `dataschema` sentence on incompatible changes.
- **Recalled with less confidence:** the exact wording of the Primer's versioning advice (paraphrased above, not quoted); the 20-character length guideline (it has been reworded across versions); the exact Kafka key-mapping wording; whether `time` is RFC 3339 with or without stricter profile notes in 1.0.2.
- **May have changed:** the spec repo evolves. The extension list (names, which are deprecated, e.g. `sequencetype` was dropped from Sequence) and the current patch number (1.0.2 as of this writing) should be checked against github.com/cloudevents/spec before quoting. Work on a CloudEvents 1.1 or 2.0 would not change a `"1.0"` producer, but it may add attributes.
- **No quotations or section numbers.** Everything is paraphrase from working knowledge of the spec documents; attribute names and header prefixes are exact.
- **House rules are not spec.** Always setting `datacontenttype`, `time` and `dataschema`, the type naming scheme, the three custom extensions, and "breaking change = new type, never `.vN`" are house choices (D047-1). The last one follows the Primer's advice but the spec itself does not require it.
