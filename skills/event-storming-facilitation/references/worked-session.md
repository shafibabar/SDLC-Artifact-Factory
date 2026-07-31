# Worked Event Storming — DataAsset Ingestion → Classification → Compliance

A full worked session for this repo's flagship domain, showing the sticky-note
sequence exactly as it lands on the wall, the pivotal events and vertical
dividers, and the Aggregates and Bounded Contexts the session discovers. This is
an illustrative model for the domain-modeler agent to pattern-match against — not
a spec; a real session with real Data Stewards and Compliance Officers will
differ.

Domain in scope: a Data Steward connects a storage source (Google Drive, Amazon
S3), the platform scans it, discovers and catalogues DataAssets, classifies
their sensitivity, and drives compliance actions (access review, retention).
Personas on the wall: **Data Steward**, **Compliance Officer**.

---

## Big Picture — the orange timeline (after passes 1–3)

Read left to right, past tense, business-meaningful:

```
StorageSourceConnected → SourceScanScheduled → SourceScanStarted →
DataAssetDiscovered → DataAssetCatalogued → EntitiesExtracted →
DataAssetClassified → SensitivityElevated → AccessReviewRequested →
AccessReviewCompleted → RetentionPolicyApplied → RetentionPeriodExpired →
DataAssetPurged
```

Unhappy-path events provoked in pass 5 ("what goes wrong?"):

```
SourceScanFailed → SourceCredentialsExpired → ClassificationRejected →
ManualClassificationOverridden → AccessReviewOverdue → PurgeBlockedByLegalHold
```

---

## Pivotal events and vertical dividers (pass 7)

Three events change the phase of the narrative. A vertical line is drawn across
the whole timeline at each — the first cue of where boundaries fall:

| Pivotal event | Phase change it marks | Language shift across the line |
|---|---|---|
| `DataAssetCatalogued` | discovery/scanning → cataloguing | "source/scan" language → "asset/catalogue" language |
| `DataAssetClassified` | cataloguing → compliance | "asset/entity" language → "sensitivity/review/retention" language |
| `RetentionPolicyApplied` | active compliance → lifecycle disposal | "review" language → "retention/purge/legal-hold" language |

The vertical lines sort the timeline into three candidate subdomain areas:
**Ingestion**, **Cataloguing**, and **Compliance**.

---

## Process Level — the classification process

Zoom into the span between `DataAssetCatalogued` and `AccessReviewCompleted`.
Working right-to-left off each orange Event yields:

```
[Read Model: Unclassified Assets Queue]
   → (Actor: Compliance Officer)
   → [Command: ClassifyDataAsset]
   → {Aggregate: DataAsset}
   → <Domain Event: DataAssetClassified>
   → «Policy: Whenever DataAssetClassified with SensitivityLevel = Restricted,
              then RequestAccessReview»
   → [Command: RequestAccessReview]
   → {Aggregate: AccessReview}
   → <Domain Event: AccessReviewRequested>
   → (External System: Google Drive — sharing/ACL settings inspected)
   → «Policy: Whenever AccessReviewRequested, then NotifyAssignedReviewer»
```

The scanning process (left of `DataAssetCatalogued`) yields a second chain:

```
[Read Model: Connected Sources] → (Actor: Data Steward)
   → [Command: ScheduleSourceScan] → {Aggregate: SourceScan}
   → <Domain Event: SourceScanScheduled> → «Policy: Whenever SourceScanStarted,
      then discovered assets are catalogued» → {Aggregate: DataAsset}
   → <Domain Event: DataAssetCatalogued>
   → (External System: Amazon S3 — object listing via connector)
```

What this fragment demonstrates:
- Every `<Domain Event>` traces to a `[Command]` issued by an `(Actor)` or a
  «Policy» — no orphan events.
- The «Policy» captures automation stated in domain language ("whenever
  something is Restricted, someone must review access"), not a technical trigger.
- Each `(External System)` marks where the model's authority ends and implies an
  Anti-Corruption Layer for `bounded-context-mapping`.
- A hotspot surfaced in the walk: *"Can the engine reclassify an asset a human
  manually overrode?"* — recorded red, not debated; resolved later as a
  `DataAsset` invariant question.

---

## Design Level — Aggregates discovered

Clustering Commands/Events that share one true invariant:

| Aggregate | Commands handled | Events emitted | Key invariant (justifies the boundary) |
|---|---|---|---|
| **SourceScan** | ScheduleSourceScan, StartScan, RecordScanResult | SourceScanScheduled, SourceScanStarted, SourceScanFailed | A scan cannot start unless its StorageSource's credentials are currently valid |
| **DataAsset** | CatalogueDataAsset, ClassifyDataAsset, OverrideClassification | DataAssetCatalogued, DataAssetClassified, ManualClassificationOverridden | A DataAsset may only be marked Restricted if its storage source is confirmed active; a machine reclassification may not overwrite a human override |
| **AccessReview** | RequestAccessReview, CompleteAccessReview | AccessReviewRequested, AccessReviewCompleted, AccessReviewOverdue | A review cannot be completed without a recorded reviewer decision |
| **RetentionSchedule** | ApplyRetentionPolicy, PurgeDataAsset, PlaceLegalHold | RetentionPolicyApplied, RetentionPeriodExpired, DataAssetPurged, PurgeBlockedByLegalHold | A DataAsset under legal hold can never be purged, regardless of retention expiry |

Note that `DataAsset` and `AccessReview` are **separate** Aggregates even though
a Policy links them — the classification invariant and the review invariant do
not need to hold atomically together, so eventual consistency (a published
`DataAssetClassified` event consumed by the AccessReview side) is correct, not a
compromise. Folding them into one Aggregate to "keep them consistent" would be
the God-Aggregate mistake.

---

## Design Level — Bounded Contexts discovered

Grouping Aggregates that share one Ubiquitous Language and one owner; boundaries
fall on the vertical dividers where the language changes:

| Bounded Context | Aggregates | Language-boundary justification |
|---|---|---|
| **Source Ingestion** | SourceScan | Speaks "source", "scan", "connector", "credentials" — nothing about sensitivity or compliance |
| **Asset Catalog** | DataAsset | Speaks "asset", "catalogue", "extracted entity", "classification" — the word "source" here means only a reference ID, not the scanning machinery |
| **Compliance** | AccessReview, RetentionSchedule | Speaks "review", "reviewer decision", "retention", "legal hold", "purge" — "asset" here is an ID it does not own |

`DataAsset` is the shared spine: it is *owned* by Asset Catalog (only that
context writes its master record — Data Ownership), while Source Ingestion and
Compliance reference it by ID and react to its published Domain Events. The seam
between Asset Catalog and Compliance is the `DataAssetClassified` event flowing
across a context boundary — a Customer/Supplier relationship for
`bounded-context-mapping` to formalize.

---

## Hotspots recorded

| ID | Description | Type | Resolution | Status |
|---|---|---|---|---|
| H1 | Can the engine reclassify a human-overridden asset? | Process uncertainty | Modeled as a DataAsset invariant (no) | Resolved |
| H2 | Does "source" in Compliance mean the connector or just an ID? | Language disagreement | Ubiquitous-language session — it is an ID reference only | Resolved |
| H3 | Who owns retention periods when a source spans tenants? | Scope dispute | Escalated to Shafi (product decision) | Deferred |

---

## Outputs this session hands off

- **Timeline →** `domain-event-catalog` (13 happy-path + 6 unhappy-path events).
- **Aggregates →** `aggregate-design` (SourceScan, DataAsset, AccessReview,
  RetentionSchedule, each with its stated invariant).
- **Bounded Contexts →** `bounded-context-mapping` (Source Ingestion, Asset
  Catalog, Compliance, plus the Customer/Supplier seam on `DataAssetClassified`).
- **Commands →** `command-catalog`; **Read Models →** `read-model-design`;
  **Policies →** `domain-event-catalog` reaction rules.
- **Ubiquitous Language candidates →** `ubiquitous-language`: SensitivityLevel,
  Restricted, Legal Hold, Retention Period, Access Review, Extracted Entity.
