# Schema Versioning Reference

This file is self-contained. It covers:
1. Additive changes — worked examples of safe in-place evolution
2. Breaking change protocol — step-by-step, with the full deprecation timeline
3. Khononov's Event Upcasting — the alternative for permanently-stored internal
   events in event-sourced Aggregates
4. Why version numbers in event type names are harmful

---

## 1. Additive Changes (Safe, No New Event Type)

An additive change leaves all existing consumers working without modification.
Three kinds of additive change are safe:

### Add an optional field with a default

Before:
```json
{
  "aggregateId": "...",
  "tenantId": "...",
  "sensitivityLevel": "Confidential",
  "classifiedBy": "..."
}
```

After (adding `previousLevel` as optional):
```json
{
  "aggregateId": "...",
  "tenantId": "...",
  "sensitivityLevel": "Confidential",
  "classifiedBy": "...",
  "previousLevel": "Internal"
}
```

Why it is safe: a consumer that does not read `previousLevel` ignores it
silently (tolerant reading). Old events without `previousLevel` still validate
against the new schema because the field is optional with a documented default
of `null` (meaning "classification history not available").

### Add a new enum value

Before: `sensitivityLevel` allowed `["Public","Internal","Confidential","Restricted"]`

After: adding `"TopSecret"` to the allowed set.

Why it is safe *with a caveat*: consumers that pattern-match exhaustively on the
enum and have no `default` branch will fail on `"TopSecret"`. Announce new enum
values in the schema changelog and give consumers a migration window before
producing events with the new value. This is the one additive change that
requires consumer coordination even though it does not break the schema
validator.

### Add a new event type (separate subject)

Defining `com.sdlc-factory.data-asset-management.data-asset.archived` is
purely additive. Consumers that subscribe only to `...classified` are
unaffected.

---

## 2. Breaking Change Protocol

A breaking change modifies or removes something an existing consumer depends
on. The three breaking classes are:

| Class | Example |
|---|---|
| **Rename** | `classifiedBy` → `reviewerId` |
| **Type change** | `sensitivityLevel` string → integer code |
| **Remove** | Drop `previousLevel` after deciding it was a mistake |

**None of these are ever made in place on a published event type.** The
protocol:

### Step 1 — Define the new event type

Give the new event type a distinct, semantically meaningful name. Do not append
a version suffix.

**Wrong:** `com.sdlc-factory.data-asset-management.data-asset.classified.v2`

**Right:** If the semantic of the event has shifted (e.g., classification is
now a two-step review process, and `classified` means the second review
passed), give it a new verb: `com.sdlc-factory.data-asset-management.data-asset.review-completed`

If the semantic is unchanged and only the payload shape changed (a field was
renamed), the new type name can stay close to the original but must be
explicitly distinct — add a qualifier that describes the distinction:
`com.sdlc-factory.data-asset-management.data-asset.classified-with-history`

### Step 2 — Register the new schema

Register the new event type in Apicurio Registry before any producer deploys.
The old subject and schema remain untouched. Two subjects coexist in the
registry.

### Step 3 — Dual publish

The producer publishes both event types for the same business fact, for the
duration of the transition window. Every consumer that has migrated to the new
type receives both; consumers that have not migrated receive only the old type.

The dual-publish producer:

```go
func (svc *ClassificationService) Classify(ctx context.Context, cmd ClassifyCmd) error {
    asset, err := svc.repo.FindByID(ctx, cmd.AssetID, cmd.TenantID)
    if err != nil {
        return err
    }
    if err := asset.Classify(cmd.Level, cmd.ReviewerID, cmd.Now); err != nil {
        return err
    }
    // Publish old event type for consumers not yet migrated
    oldEvt := newDataAssetClassifiedV1(asset)
    // Publish new event type for migrated consumers
    newEvt := newDataAssetReviewCompleted(asset)
    return svc.repo.Save(ctx, asset, []cloudevents.Event{oldEvt, newEvt})
}
```

### Step 4 — Consumer migration window

Announce the new event type via the team's API changelog. Give consumers a
concrete deadline — typically 4–8 weeks, documented in the schema registry as
a `deprecationDate` custom property on the old subject.

### Step 5 — Confirm zero consumers on the old type

Before retiring the old event type, verify via telemetry that no consumer
group has consumed the old event type within the deprecation window. Use
Redpanda's consumer group lag endpoint:

```bash
rpk group describe <consumer-group> --brokers $REDPANDA_BROKERS
```

A consumer group whose latest offset equals the high-water mark on the old
topic has migrated.

### Step 6 — Stop publishing the old type

Remove the dual-publish code. The old event type is no longer produced. Keep
the schema registered in Apicurio indefinitely — events already on the topic
carry the old schema ID and must remain decodable if the topic is ever replayed.

---

## 3. Khononov's Event Upcasting

(Sourced from: *Learning Domain-Driven Design*, Vlad Khononov, Ch. on
Event-Sourced Domain Models)

**Event Upcasting applies to permanently-stored internal events in an
event-sourced Aggregate, not to integration events on the broker.**

An event-sourced Aggregate's event store is its source of truth. Every event
ever appended must remain loadable and interpretable forever, because replaying
the full stream reconstructs the Aggregate's current state. Unlike a transient
integration event on a Redpanda topic (which has a retention window and can be
superseded by a new event type), the internal event stream cannot be deleted or
re-emitted under a new version.

**The Upcasting pattern:** a versioned, load-time transformation function reads
an old-shape event from the store, converts it to the shape the current code
expects, and passes the result to the Aggregate's `Apply` method — without
rewriting the stored bytes.

```go
// Upcaster registry — registered at application startup
type Upcaster func(raw json.RawMessage) (json.RawMessage, error)

var upcasters = map[string]map[int]Upcaster{
    "DataAssetClassified": {
        1: upcastClassifiedV1toV2,
    },
}

// Applied at load time before Apply() sees the event
func upcastClassifiedV1toV2(raw json.RawMessage) (json.RawMessage, error) {
    var v1 struct {
        AggregateID      string `json:"aggregateId"`
        SensitivityLevel string `json:"sensitivityLevel"`
        ClassifiedBy     string `json:"classifiedBy"`
        // V1 had no previousLevel
    }
    if err := json.Unmarshal(raw, &v1); err != nil {
        return nil, err
    }
    v2 := struct {
        AggregateID      string  `json:"aggregateId"`
        SensitivityLevel string  `json:"sensitivityLevel"`
        ClassifiedBy     string  `json:"classifiedBy"`
        PreviousLevel    *string `json:"previousLevel"` // nil = history not available
    }{
        AggregateID:      v1.AggregateID,
        SensitivityLevel: v1.SensitivityLevel,
        ClassifiedBy:     v1.ClassifiedBy,
        PreviousLevel:    nil,
    }
    return json.Marshal(v2)
}
```

**Key rules for upcasters:**
- An upcaster is registered against a specific `(eventType, schemaVersion)`
  pair and transforms it to the current schema version.
- Upcasters are idempotent — applying the same upcaster twice to the same
  event must produce the same output.
- Upcasters are chained: if V1→V2 and V2→V3 upcasters both exist, the
  framework applies them in sequence at load time.
- The stored event bytes are **never rewritten**. The upcaster is a read-time
  translation layer only.

**When to use Event Upcasting vs. the new-event-type protocol:**

| Scenario | Correct approach |
|---|---|
| Integration event on a Redpanda topic (consumers can migrate and the old version can eventually stop being produced) | New event type + dual-publish + deprecation window |
| Internal persistence event in an event-sourced Aggregate's own event store (permanently stored, must remain replayable forever) | Event Upcasting |

Do not apply the new-event-type protocol to internal events — you cannot
"retire" an event type from a store you own. Do not apply Upcasting to
integration events — it introduces a hidden translation layer that hides the
wire contract from consumers.

---

## 4. Why Version Numbers in Event Type Names Are Harmful

`com.sdlc-factory.data-asset-management.data-asset.classified.v2` looks like
good hygiene but causes three concrete problems:

**Problem 1 — Consumers must enumerate versions.** A consumer subscribing to
`classified` events must now know about `.v1`, `.v2`, and eventually `.v3`.
Every version increment requires a consumer code change, even if the consumer's
use of the event is unaffected by the change.

**Problem 2 — The version in the type name and the schema version in the
registry diverge.** If the schema undergoes three additive changes and then one
breaking change, the registry might be on schema version 4 while the type name
says `v2`. Consumers cannot determine which is authoritative.

**Problem 3 — The version number carries no semantic meaning.** A consumer
reading `classified.v2` learns nothing about what changed relative to `v1`.
A semantically distinct type name (`review-completed`, `classified-with-history`)
communicates the change; a version suffix does not.

**The correct model:** the event type name is a stable semantic identifier. The
schema registry tracks the schema version internally. Consumers subscribe to
the stable type; the registry enforces compatibility of schema evolution within
that type. When the semantic changes enough to warrant a new subscriber
migration, the new semantic is expressed as a new type name, not a version
suffix on the old one.
