# Worked Examples

Self-contained — loadable without reading `SKILL.md` first.

Four full worked Aggregate designs for the data-estate-mapping product, each carrying the expanded worksheet (`references/decision-trees-and-worksheets.md` owns the blank template; this file shows it filled in), a Go type sketch (full code lives in `references/go-implementation-patterns.md`; this file cross-references rather than repeating it verbatim), and a written rationale trail — including a genuinely hard boundary case with a documented alternative considered and rejected, modeled on Vernon's own "one big Aggregate, then correctly split it" SaaSOvation narrative. Grounded in all three `research/domain-driven-design/` files and consistent with `go-domain-model`, `go-repository-pattern`, and `domain-event-catalog`'s existing conventions.

**A labeling note that applies to every example below:** this repo's actual specified requirements (per `sdlc-context.json` and the product context) do not yet include a ratified list of business rules at this level of detail. Every invariant, rule, and numeric estimate below is **illustrative** — a plausible instance of this domain's shape, in the same spirit `references/entities-value-objects-and-domain-primitives.md` and `references/invariants-and-consistency-boundaries.md` already flag their own illustrative content. Where a design choice rests on something already established elsewhere in this repo (a glossary term, an existing skill's code, a decision in `sdlc-context.json`), that grounding is named explicitly; where it doesn't, it's flagged as a judgment call for Shafi to validate before treating it as settled.

---

## Worked Example 1: DataAsset

**The Aggregate Design Worksheet**

| Field | Value |
|---|---|
| **Aggregate name** | `DataAsset` |
| **Root Entity** | `DataAsset` |
| **Invariants** | (1) A `DataAsset`'s `SensitivityLevel` may never silently downgrade — a de-escalation must be an explicit, audited act, not an accidental overwrite (already enforced in `go-domain-model`'s `Classify`). (2) A `DataAsset` may only be marked `Restricted` if its `StorageSource` is confirmed active — the canonical True Invariant worked in `references/invariants-and-consistency-boundaries.md`. |
| **Entities** | `ExtractedEntity` — locally-identified child; see `references/go-implementation-patterns.md`'s "A Worked Child Entity Example" for the full identity decision and justification. |
| **Value Objects** | `SensitivityLevel` (already in `go-domain-model`); `EntityType`, `TextSpan` (fields of `ExtractedEntity`); `FilePath` (`references/entities-value-objects-and-domain-primitives.md`'s worked Domain Primitive example, illustrating a validated source-file reference). |
| **Commands/Events** | `RegisterDataAsset` → `DataAssetRegistered`; `ClassifyDataAsset` → `DataAssetClassified`; `RecordExtractedEntity` → internal `entityExtractedInternal` (never published as-is — see below); `ArchiveDataAsset` → `DataAssetArchived`. |
| **Cross-Aggregate References** | `storageSourceID` (→ `StorageSource`, Worked Example 2); `ruleID` (→ `ClassificationRule`, Worked Example 3) — both by ID only, per Rule 3. `classifiedBy` (→ a `User`, by ID). |
| **Business Logic Pattern chosen** | **Domain Model.** `DataAsset` sits in this product's Core Domain (data-estate mapping and sensitivity classification is the differentiating capability, per this repo's product context) and its invariants are genuinely cross-object (the `Restricted`/active-source rule) — Khononov's prior gate (`SKILL.md`'s "Before You Reach for an Aggregate at All") is satisfied, not skipped by default. |
| **Identity generation strategy** | Client-generated UUID, assigned by the application service at `RegisterDataAsset` command-handling time, before any persistence I/O — matches `go-domain-model`'s actual `NewDataAsset(id, ...)` signature exactly; no redesign. |
| **Concurrency strategy** | Optimistic CAS (default) for the interactive `Classify`/`Archive` paths. The narrow, documented exception: a nightly reclassification sweep (`references/go-implementation-patterns.md`'s `ReclassifySweepBatch`) uses `SELECT ... FOR UPDATE SKIP LOCKED` — a batch/administrative context, not a default reached for out of convenience. |
| **Contention estimate** | Low-to-medium, per instance. A single asset is classified relatively infrequently (once at ingestion, occasionally re-evaluated). `RecordExtractedEntity` can be bursty during an active extraction pass on a large file — this is exactly why `pendingEntities` batches rather than CAS-ing per-entity-row, keeping the write count (and hence contention) to one `Save` per extraction batch, not one per entity. |

**Go type sketch** (full code, including `Classify`, `Archive`, `RecordExtractedEntity`, and the repository, is in `references/go-implementation-patterns.md`'s first and fifth sections):

```go
type DataAsset struct {
    id, tenantID, sourceID, ruleID uuid.UUID
    sensitivity                    SensitivityLevel
    classifiedBy                   uuid.UUID
    classifiedAt                   time.Time
    archivedAt                     *time.Time
    version                        int64
    events                         []DomainEvent
    pendingEntities                []ExtractedEntity
}
```

**Rationale trail.** `DataAsset` is this product's most central Aggregate — it's the thing a compliance reviewer ultimately cares about ("is this file sensitive, and do we know where it is"). The two invariants above are the only two that earned a place inside its consistency boundary after running Vernon's three-question test (both worked in full in `references/invariants-and-consistency-boundaries.md`); a third candidate — keeping `entityCount` in lockstep with the real `ExtracedEntity` row count — was tested and correctly rejected in that same file's worked counter-example. The boundary stops exactly at `DataAsset` and its locally-identified `ExtractedEntity` children; `StorageSource` and `ClassificationRule` are referenced by ID only, never embedded, because neither passes the must-be-atomic-with half of the has-a/must-be-atomic-with test (Worked Example 3 works through the `ClassificationRule` half of that decision in full).

---

## Worked Example 2: StorageSource

**The Aggregate Design Worksheet**

| Field | Value |
|---|---|
| **Aggregate name** | `StorageSource` |
| **Root Entity** | `StorageSource` |
| **Invariants** | (1) A `StorageSource` may not transition to `Active` until its connection credentials have passed a successful test connection — activating an unverified connection would let the scan pipeline attempt to read a source that may not actually be reachable, silently producing incomplete data-estate coverage rather than a clear failure. (2) A `StorageSource` may not be reconnected with new credentials while a scan is in progress against it — swapping credentials mid-scan risks a partial scan silently mixing results from two different underlying accounts/permission sets. *(Both illustrative — no such requirement is currently ratified in this repo's artifacts; flagged as a plausible shape of this domain's connection-lifecycle concerns, not a claim of settled fact.)* |
| **Entities** | None. A `StorageSource` has no locally-identified children in this design — its connection state is fully captured by Value Objects. |
| **Value Objects** | `SourceType` (enum: `GoogleDrive`, `S3`, ...); `ConnectionEndpoint` (a Domain Primitive, same self-validating-construction discipline as `FilePath` — rejects a malformed URI at construction, never a runtime check a caller might skip); `CredentialReference` (a reference *into* Secrets Management — never the raw secret itself, per `CLAUDE.md`'s `Secrets Management` glossary term and this product's SOC 2 posture). |
| **Commands/Events** | `ConnectStorageSource` → `StorageSourceConnected`; `ValidateConnection` → `StorageSourceValidated`; `Decommission` → `StorageSourceDecommissioned`; `Reactivate` → `StorageSourceReactivated` (the compensating-action shape `references/cross-aggregate-coordination-and-sagas.md` already names as a legitimate root method, not a raw setter). |
| **Cross-Aggregate References** | None owned by `StorageSource` itself — it is referenced *from* `DataAsset` (Worked Example 1) and, by ID, from any Saga step that needs to compensate against it (`references/cross-aggregate-coordination-and-sagas.md`'s worked Decommission-with-Restricted-assets Saga). `StorageSource` never holds a live or ID reference back to the `DataAsset`s connected to it — doing so would recreate exactly the eager-loading/unbounded-collection hazard `references/sizing-contention-and-concurrency.md`'s "Unbounded Collections" section names, this time on the `StorageSource` side of the relationship instead of the `DataAsset` side. |
| **Business Logic Pattern chosen** | **Domain Model.** The credential-validation-before-activation invariant is genuinely cross-step (it depends on the result of a `ValidateConnection` command that must have already succeeded), which is enough intricacy to clear Khononov's prior gate — a plain Active Record (an object per row with no enforced sequencing) could not guarantee "never `Active` without a prior successful validation" the way a root method can. |
| **Identity generation strategy** | Client-generated UUID, same shape as `DataAsset` — no reason to deviate; a `StorageSource` is fully valid, ID included, before any persistence I/O, and `StorageSourceConnected` can correctly carry the real ID from the moment it's recorded. |
| **Concurrency strategy** | Optimistic CAS (default). Contention is low: a `StorageSource` is administered by a small number of compliance/platform administrators, and simultaneous edits to the *same* source are a genuine edge case, not routine traffic — exactly the "healthy" retry profile `references/sizing-contention-and-concurrency.md`'s "Retry-on-Conflict" section describes, not a boundary smell. |
| **Contention estimate** | Low. Unlike `DataAsset` (many concurrent classification/extraction writes across a large asset population), each `StorageSource` instance is written to rarely — connect, validate, occasional reactivation — by a small population of administrators. |

**Go type sketch:**

```go
type StorageSource struct {
    id, tenantID       uuid.UUID
    sourceType         SourceType
    endpoint           ConnectionEndpoint
    credentialRef      CredentialReference
    status             SourceStatus // Value Object: Pending, Active, Decommissioned
    lastValidatedAt    *time.Time
    version            int64
    events             []DomainEvent
}

func (s *StorageSource) Activate(now time.Time) error {
    if s.lastValidatedAt == nil {
        return fmt.Errorf("activate storage source %s: %w", s.id, ErrConnectionNotValidated)
    }
    s.status = SourceStatusActive
    s.recordEvent(StorageSourceConnected{AggregateID: s.id, TenantID: s.tenantID, OccurredAt: now})
    return nil
}
```

**Rationale trail.** `StorageSource` is deliberately kept free of any reference to the `DataAsset`s connected to it — the temptation to add a `dataAssetIDs []uuid.UUID` field "so a source can report how many assets it has" was considered and rejected using the same reasoning `references/invariants-and-consistency-boundaries.md`'s `entityCount` counter-example already applies to `DataAsset`: that question is answerable by a targeted query (`SELECT COUNT(*) FROM data_assets WHERE source_id = $1`) or a Read Model, never by a root field the Aggregate's own transaction has to keep current. Keeping `StorageSource` this narrow is also what keeps its contention low — if it held a live or ID collection of every connected asset, every classification write anywhere in the system would eventually touch this one Aggregate's write path, recreating exactly the Scalability hazard `references/sizing-contention-and-concurrency.md`'s three sizing angles warn against.

---

## Worked Example 3: A Genuinely Hard Boundary Case

**The question:** should `ClassificationRule` — the configuration that determines how the classification engine assigns a `SensitivityLevel` to a `DataAsset` — be its own Aggregate, referenced by ID from `DataAsset`, or folded directly into `DataAsset` itself?

**The first design considered — and why it was tempting.** A first-pass modeler, looking at the Ubiquitous Language, notices that a `DataAsset` is always classified *according to* some rule, and that the rule and the classification decision feel like one continuous business action — "classify this asset" *is*, in the moment it happens, "apply this rule to this asset." The tempting design: embed the active `ClassificationRule`'s criteria directly as a field on `DataAsset` itself (or, in a more extreme version of the same mistake, model a single `ClassificationEngine` Aggregate that holds every rule *and* every asset together, so that "the engine" can always guarantee every asset is classified consistently with the current rule set in one atomic place). This is structurally the same mistake Vernon's own SaaSOvation `Product`-contains-`BacklogItem`s-contains-`Task`s narrative works through: reasoning from "these feel like they belong together" straight to "therefore one Aggregate," without separately testing the has-a question against the must-be-atomic-with question.

**Running the has-a vs. must-be-atomic-with test, in writing, against this specific candidate relationship:**

- **Has-a:** Yes, unambiguously. A domain expert would say, unprompted, that a `DataAsset`'s classification is *governed by* a `ClassificationRule` — this is a real, meaningful conceptual relationship, not a fabricated one.
- **Must-be-atomic-with:** **No.** Nothing in this domain requires that classifying `DataAsset` A be atomically consistent, at the database-transaction level, with every other asset's classification, or with the rule's own definition being edited. When a compliance administrator publishes a new version of a `ClassificationRule`, it is entirely acceptable — expected, even — that assets already classified under the previous version stay as they are until the next scheduled reclassification sweep re-evaluates them (`references/go-implementation-patterns.md`'s `ReclassifySweepBatch`). A brief window where some assets reflect the old rule and some reflect the new one is not a compliance incident; it's the normal, expected shape of a rollout. Running Vernon's own three-question test against the specific candidate rule ("a `DataAsset`'s classification must always reflect the currently-published `ClassificationRule`, atomically, at every instant") makes this concrete: **Q1** (real harm from momentary staleness)? No — a brief lag before the sweep catches up causes no compliance harm; the sweep exists precisely because eventual, not instantaneous, re-evaluation is acceptable. **Q2** (correction needs more than a reasonable compensating action)? No — the nightly sweep *is* the reasonable compensating action, already designed for exactly this. **Q3** (already enforced elsewhere)? Effectively yes, in spirit — the sweep is the enforcement mechanism, and it's designed to run outside any single classification transaction on purpose. **No/No/Yes-in-effect** — this fails to justify a shared consistency boundary on every axis.

**Why the has-a/must-be-atomic-with mismatch is the tell, not a coincidence.** This is precisely Vernon's named root cause of oversized Aggregates: the domain language's "governed by" relationship is real, but it is a *configuration* relationship, not a *transactional* one. Evans' Knowledge Level concept (`research/domain-driven-design/domain-driven-design-evans.md`) names this shape directly: `ClassificationRule` is not a peer business object alongside `DataAsset` in the same layer of the model — it is a **Knowledge Level object**, a distinct set of rules that configure the behavior of a separate "base level" set of objects (`DataAsset`), and Evans' own guidance is that a Knowledge Level concept complex and independently-changing enough to deserve its own explicit model should get one, rather than being folded into the base-level object it governs.

**What the merged, rejected design would have cost, run against all three sizing angles from `references/sizing-contention-and-concurrency.md`:**

- **Performance.** Every single `DataAsset` load would need to hydrate the full `ClassificationRule` criteria (potentially a nontrivial ruleset — keyword lists, regex patterns, ML model thresholds) even for operations that have no use for it at all, like a simple `Archive()` call.
- **Scalability.** If a single `ClassificationEngine` Aggregate held every rule and every asset together, every classification write across the *entire tenant* would contend for one Aggregate instance's version/lock — collapsing what should be thousands of independent, parallelizable per-asset writes into serialized contention on one hot row.
- **Collaboration.** A compliance administrator publishing a new rule version and the classification engine continuously classifying incoming assets are two entirely legitimate, unrelated activities that would collide constantly if forced to share one Aggregate's write path — administrators editing rules would routinely conflict with (or block) the classification pipeline's own throughput, a textbook instance of the Collaboration sizing angle's failure mode, not a performance problem at all.

**The design actually adopted:** `ClassificationRule` is its **own Aggregate Root**, with its own global identity, its own Repository, and its own lifecycle (`DraftRule` → `PublishRule` → `RetireRule`, each a real command against `ClassificationRule`'s own root, invariant-checked independently of any `DataAsset`). `DataAsset` holds only `ruleID uuid.UUID` — a reference by identity, recorded into the `DataAssetClassified` event at the moment classification happens (see `references/go-implementation-patterns.md`'s `Classify` signature, which already takes `ruleID` as a parameter for exactly this reason) so the audit record captures *which version* of the rule produced a given classification, without `DataAsset` needing to hold a live reference to the rule itself.

| | Rejected: folded into `DataAsset` / a shared `ClassificationEngine` | Adopted: `ClassificationRule` as its own Aggregate |
|---|---|---|
| Has-a | Yes | Yes (unchanged — the conceptual relationship is real either way) |
| Must-be-atomic-with | No | No (confirmed by the design, not contradicted) |
| Contention | High — every classification write and every rule edit share one lock | Low on each side — `DataAsset` writes contend only with other `DataAsset` writes; `ClassificationRule` edits (rare, administrator-driven) contend only with each other |
| Consistent-with-Knowledge-Level test | Fails — collapses a distinct configuring concept into the object it configures | Passes — the configuring concept gets its own explicit model, referenced by ID |

---

## Worked Example 4 (if warranted): An Event-Sourced Aggregate

**The candidate: `ComplianceGap`.** This repo's own product context is compliance/audit-heavy — `Audit Trail` and `Non-Repudiation` are canonical glossary terms, and the first product targets a SOC 2 posture. A `ComplianceGap` represents a detected non-conformance (e.g., a `Restricted` asset found somewhere it shouldn't be) tracked through a real multi-step lifecycle: detected → acknowledged → remediation plan proposed → remediated → verified, with the possibility of being reopened if verification fails. Full Go pattern (the `Apply`/command-method shape, the conditional-append repository, snapshotting, and upcasting) is in `references/go-implementation-patterns.md`; this worked example's job is the *design decision itself* — why this specific Aggregate justifies Event Sourcing where `DataAsset` (Worked Example 1) correctly does not.

**Running Khononov's three-question justification test, in writing, against this specific Aggregate:**

1. **Temporal query need — does the business genuinely need to reconstruct state at an arbitrary past point in time?** Yes. A SOC 2 auditor's own working method is exactly this: "show me what this gap's status was as of the date of the prior audit period," not merely "what is it now." A current-state table with only a `status` column and an `updated_at` timestamp cannot answer that question at all — it has already overwritten whatever the prior status was.
2. **Retroactive projection need — will new Read Models need to be built from history that already happened, before that Read Model was designed?** Plausible, though secondary to (1) and (3) for this specific case — a future "mean time to remediation, broken down by gap category" dashboard would need to derive duration-in-each-status from history that predates the dashboard's own design, which current-state persistence has already discarded by the time anyone thinks to build it.
3. **Audit-as-record — must the event stream itself, not a bolted-on log, be the authoritative compliance record?** Yes, and this is the decisive answer for this specific Aggregate. `domain-event-catalog`'s own worked example already gestures at exactly this need without resolving it: `DataAssetClassified`'s own catalog entry states `Retention: 90 days on the broker; indefinitely in the audit store` — naming an "audit store" as a requirement without ever designing what it is. For `ComplianceGap` specifically, the regulatory posture is that the full remediation narrative *is* the compliance evidence a SOC 2 auditor reviews — not a summary derived from it after the fact.

**Yes/Plausible/Yes** — at least one clear "yes" (in fact two) is enough to justify the escalation past current-state, per `SKILL.md`'s own quality criterion ("Event Sourcing justified... against Khononov's three-question test"), which requires only that a specific, named need actually applies — not that all three apply.

**Why current-state was rejected for this specific case — the contrast that matters.** `DataAsset` (Worked Example 1) has the *same* general shape (a lifecycle, multiple state-changing commands, Domain Events already fired at each transition) and was correctly kept current-state. The difference is not that `ComplianceGap` is "more Core Domain" — Khononov's research explicitly names "adopted because the subdomain is Core, and deserves the best patterns" as the specific premature-adoption failure mode to avoid, and this worked example does not fall into it. The difference is that `DataAsset`'s own audit need is already fully satisfied by its existing `DataAssetClassified`/`DataAssetArchived` events flowing through the ordinary outbox into whatever downstream audit store eventually consumes them — current-state persistence plus an event trail is sufficient, because nothing in `DataAsset`'s own design requires the event stream *itself*, rather than a copy of it, to be the authoritative record a regulator points to. `ComplianceGap`'s specific difference is answer (3) above: the regulatory requirement is that the record of the remediation process itself — not a projection built from a log that could theoretically drift from a separately-maintained current-state row — is what an auditor is shown. A design that kept `ComplianceGap` current-state and bolted on a separate `compliance_gap_audit_log` table (mirroring every transition into a second, hand-maintained table) was considered and rejected for the reason Khononov's own research names directly: two representations of the same history (a current-state row plus a hand-maintained log) can drift apart the first time a code path updates one and not the other, and at that point the "audit log" is no longer trustworthy as the authoritative record — it is a second, unverified claim about what happened, not a source of truth. Making the event stream itself the only thing that ever gets written removes the drift risk structurally, rather than policing it by discipline.

**Costs accepted, named explicitly rather than left implicit** (per `SKILL.md`'s Anti-Patterns table entry on premature Event Sourcing, applied here in the opposite direction — an honest costing of a *justified* adoption, not a warning against one): `ComplianceGap` now requires an upcasting chain maintained forever for every event type it can experience (`references/go-implementation-patterns.md`'s `upcastComplianceGapAcknowledged` worked example already shows one real schema correction this cost was paid for); a snapshotting cadence to bound replay cost as gaps accumulate a long history; and replay-based testing (constructing a test fixture means building a plausible event sequence, not just calling one constructor) rather than `DataAsset`'s simpler table-driven invariant tests. These costs are accepted here specifically because answer (3) is a genuine, named regulatory need — not paid by default because the subdomain sounds important.

**The Aggregate Design Worksheet**

| Field | Value |
|---|---|
| **Aggregate name** | `ComplianceGap` |
| **Root Entity** | `ComplianceGap` |
| **Invariants** | A gap cannot be `Acknowledged` except from `Open`; cannot be `Remediated` except from `Acknowledged`; cannot be `Verified` except from `Remediated`; `Reopen` is valid from `Verified` only (a failed re-check). Each is enforced by the corresponding command method's precondition, exactly like `DataAsset.Classify`'s Assertion discipline — the event-sourced shape changes *how* state is derived, not the requirement that every mutation still validate before it applies. |
| **Entities** | None — no locally-identified children needed for this Aggregate's scope. |
| **Value Objects** | `GapStatus` (a closed value set, same shape as `SensitivityLevel`). |
| **Commands/Events** | `DetectGap` → `ComplianceGapDetected`; `Acknowledge` → `ComplianceGapAcknowledged`; `ProposeRemediationPlan` → `RemediationPlanProposed`; `MarkRemediated` → `ComplianceGapRemediated`; `Verify` → `ComplianceGapVerified`; `Reopen` → `ComplianceGapReopened`. Published externally as the coarser `ComplianceGapDetectedPublished`/`ComplianceGapStatusChanged` pair — see `references/go-implementation-patterns.md`'s translation step. |
| **Cross-Aggregate References** | `dataAssetID` (→ `DataAsset`, by ID). |
| **Business Logic Pattern chosen** | **Event-Sourced Domain Model** — Domain Model's invariants and command structure, plus Event Sourcing as the persistence strategy, justified above against Khononov's three-question test. |
| **Identity generation strategy** | Client-generated UUID, same default as every other Aggregate in this file — Event Sourcing changes the persistence shape, not the identity-generation preference. |
| **Concurrency strategy** | Optimistic — conditional append on expected stream version (`references/go-implementation-patterns.md`'s "Event-Sourced Repository: Conditional Append"), the same underlying principle as `DataAsset`'s CAS, restated for an append-only store. |
| **Contention estimate** | Low. A given `ComplianceGap` instance is written to only at real lifecycle transitions — a handful of writes over its lifetime, driven by human compliance-review action, not high-frequency automated traffic. |
