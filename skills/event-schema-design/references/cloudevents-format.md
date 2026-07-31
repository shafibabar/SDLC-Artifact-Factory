# CloudEvents 1.0 Format Reference

This file is self-contained: it can be read without the parent SKILL.md in
context. It defines the complete CloudEvents 1.0 attribute specification as
applied to this platform, the event type and source naming conventions, and
the Go struct mapping. Use it whenever defining a new Domain or Integration
Event.

---

## CloudEvents 1.0 Attribute Specification

CloudEvents separates event *context* (envelope attributes) from event *data*
(the payload). Every event this platform produces or consumes follows
CloudEvents 1.0 exactly — no extensions to the envelope structure without an
explicit ADR.

### Required Attributes

| Attribute | Type | Constraint | This Platform's Convention |
|---|---|---|---|
| `specversion` | string | Must be `"1.0"` | Hard-coded in the Go event factory; never set by callers |
| `id` | string | Must be globally unique per event | A `uuid.UUID` generated at construction time by the producer |
| `source` | URI-reference | Identifies the producing service | `/<service-name>/<semver>` — e.g., `/data-asset-management/v1.2.0` |
| `type` | string | Reverse-domain notation | `com.sdlc-factory.<bounded-context>.<aggregate>.<past-tense-verb>` |
| `datacontenttype` | string | Media type of `data` | Always `"application/json"` on this platform |

### Optional Attributes Used on This Platform

| Attribute | Type | When to set |
|---|---|---|
| `subject` | string | Aggregate root ID when the event concerns a specific instance — e.g., the `DataAsset` UUID |
| `time` | RFC 3339 timestamp | Always set — the instant the domain event occurred (wall-clock on the producing node) |
| `dataschema` | URI | The Apicurio Registry URL for the event's JSON Schema — set automatically by the Go event factory |

### Reserved Optional Attributes (Do Not Use Without ADR)

`dataref` — a pointer to event data held externally rather than inline. Not
used on this platform; all event data is inline in `data`.

---

## Event Type Naming Convention

Every event type follows the reverse-domain convention:

```
com.sdlc-factory.<bounded-context>.<aggregate>.<past-tense-verb>
```

Rules:
- All segments are **lowercase**, hyphen-separated (`data-asset`, not
  `DataAsset` or `dataasset`).
- `<bounded-context>` maps to the Bounded Context name as used in the Context
  Map — e.g., `data-asset-management`, `compliance-intelligence`.
- `<aggregate>` is the Aggregate Root type name, lowercased and hyphenated —
  e.g., `data-asset`, `storage-source`.
- `<past-tense-verb>` is a single past-tense verb in the Ubiquitous Language
  describing what happened — `classified`, `registered`, `archived`,
  `activated`, `deactivated`. Never a noun; never a command verb in present
  tense.

**Examples from this domain:**

| Event | Type string |
|---|---|
| A DataAsset is classified by a reviewer | `com.sdlc-factory.data-asset-management.data-asset.classified` |
| A StorageSource is confirmed active | `com.sdlc-factory.data-asset-management.storage-source.activated` |
| A DataAsset is registered for the first time | `com.sdlc-factory.data-asset-management.data-asset.registered` |
| A compliance gap is detected | `com.sdlc-factory.compliance-intelligence.compliance-gap.detected` |

**Why reverse-domain, not CamelCase?** Reverse-domain types are globally
unambiguous, sort lexicographically by context, and never collide across
organisations if this platform's events are ever federated with an external
event mesh.

**Why not version in the type name?** A type like
`com.sdlc-factory.data-asset-management.data-asset.classified.v2` forces
every consumer to enumerate versions explicitly. When a breaking change is
necessary, the correct resolution is a new, semantically distinct type name —
see `references/schema-versioning.md`.

---

## Source Attribute Convention

```
/<service-name>/<semver>
```

The `source` attribute identifies the service instance that produced the event.

| Segment | Example | Notes |
|---|---|---|
| `service-name` | `data-asset-management` | Kebab-case; matches the Kubernetes `Deployment` name |
| `semver` | `v1.2.0` | The deployed service version — injected at build time via `ldflags` |

A fully formed source: `/data-asset-management/v1.2.0`

The source is used by consumers to correlate events with the version of the
producing service, which helps debug compatibility issues when multiple versions
of a producer are running during a rolling deploy.

---

## Worked Example: DataAssetClassified

A complete CloudEvents 1.0 envelope for a `DataAssetClassified` domain event:

```json
{
  "specversion": "1.0",
  "id": "7f3a2b1c-4d5e-6f7a-8b9c-0d1e2f3a4b5c",
  "source": "/data-asset-management/v1.2.0",
  "type": "com.sdlc-factory.data-asset-management.data-asset.classified",
  "datacontenttype": "application/json",
  "subject": "3c4d5e6f-7a8b-9c0d-1e2f-3a4b5c6d7e8f",
  "time": "2026-07-31T14:23:45.678Z",
  "dataschema": "https://registry.internal/apis/registry/v2/groups/events/artifacts/data-asset-classified",
  "data": {
    "aggregateId": "3c4d5e6f-7a8b-9c0d-1e2f-3a4b5c6d7e8f",
    "tenantId":    "a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d",
    "sensitivityLevel": "Confidential",
    "classifiedBy":     "b2c3d4e5-f6a7-8b9c-0d1e-2f3a4b5c6d7e",
    "classifiedAt":     "2026-07-31T14:23:45.678Z",
    "previousLevel":    "Internal"
  }
}
```

**Payload field justification:**

| Field | Reason included |
|---|---|
| `aggregateId` | Primary reference — lets consumers fetch full state if needed |
| `tenantId` | Required for physical multi-tenancy routing in every consumer |
| `sensitivityLevel` | The fact that changed — the whole reason for the event |
| `classifiedBy` | The actor — audit trail without a separate query |
| `classifiedAt` | When the domain event occurred — distinct from `time` (event produced) |
| `previousLevel` | Allows consumers to handle transitions (e.g., alert only on Restricted) |

**Payload fields deliberately absent:**

| Field | Why excluded |
|---|---|
| `assetName` | Derived attribute; can drift from the authoritative record |
| `storageSourceDetails` | Full Aggregate state — fat payload anti-pattern |
| Raw file content | Violates data retention; immutable in the event log |

---

## Go Struct Mapping

See `references/go-event-structs.md` for the complete Go struct layout, factory
function, and JSON serialisation conventions. The attribute names above map
directly to exported Go struct fields tagged with `json:"<attribute>"`.

The Go `CloudEvent` envelope struct embeds the five required attributes as
value fields; the `Data` field is `json.RawMessage` so payload structs remain
strongly typed in the producer/consumer without the envelope struct knowing
about them.
