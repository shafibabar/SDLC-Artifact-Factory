# Go Implementation Patterns

Self-contained — loadable without reading `SKILL.md` first.

This file is the full Go depth behind `SKILL.md`'s Identity Generation and Concurrency Strategy section: what the code actually looks like for both the current-state Aggregate this repo already implements (`go-domain-model`, `go-repository-pattern`) and the event-sourced alternative Khononov's research identified as the single largest concrete gap in this repo's Go skill set — nothing here contradicts those two skills; every pattern below either deepens code they already show or fills in a shape they don't cover at all. Grounded in `research/domain-driven-design/implementing-ddd-vernon.md` (identity generation, concurrency strategy) and `research/domain-driven-design/learning-ddd-khononov.md` (the event-sourced Aggregate shape, snapshotting, upcasting).

**A naming note before the code:** `go-domain-model`'s actual `DataAsset` struct uses plain `uuid.UUID` fields (`id uuid.UUID`, `sourceID uuid.UUID`) — no typed ID wrappers. `SKILL.md`'s own illustrative Rule 3 sketch and `references/entities-value-objects-and-domain-primitives.md`'s Rule-3-one-level-deeper example both write `DataAssetID`/`StorageSourceID` as if they were distinct types. This file resolves the tension rather than silently picking one: it uses plain `uuid.UUID` throughout, matching the actual implemented code in `go-domain-model`, because that is what exists today and this file's job is to deepen it, not redesign it. A typed-ID wrapper (`type DataAssetID uuid.UUID`) is a legitimate, compatible refinement — genuinely a Domain Primitive in the sense `references/entities-value-objects-and-domain-primitives.md` describes, since it prevents a `StorageSourceID` being passed where a `DataAssetID` is expected — worth adopting once a service has enough distinct Aggregate types in play that ID mix-ups become a real risk. It is not adopted here so this file's code samples paste directly into the existing `internal/domain` package without a rename.

---

## Aggregate Root in Go — Current-State Persistence

The full shape, deepened past `go-domain-model`'s already-correct sketch: unexported fields, a constructor/reconstitution split, an internal event buffer, and mutation methods that validate, then mutate, then record — never in a different order, and never split across two methods.

```go
// internal/domain/dataasset.go
package domain

import (
    "fmt"
    "time"

    "github.com/google/uuid"
)

// DataAsset is the Aggregate Root. Every field is unexported — the only way
// to reach any of them is through a method that enforces an invariant first.
type DataAsset struct {
    id           uuid.UUID
    tenantID     uuid.UUID
    sourceID     uuid.UUID          // reference to StorageSource — ID only (Rule 3)
    ruleID       uuid.UUID          // reference to ClassificationRule — ID only; see
                                    // references/worked-examples.md's Worked Example 3
                                    // for why this is a separate Aggregate, not embedded
    sensitivity  SensitivityLevel   // Value Object; zero value = "unclassified"
    classifiedBy uuid.UUID
    classifiedAt time.Time
    archivedAt   *time.Time         // nil while active
    version      int64              // optimistic concurrency — current-state CAS

    events          []DomainEvent    // uncommitted Domain Events; drained on save
    pendingEntities []ExtractedEntity // uncommitted child Entities recorded this
                                      // transaction; drained on save, same shape as
                                      // events — see "A Worked Child Entity Example"
                                      // below for why DataAsset never holds its FULL
                                      // ExtractedEntity collection in memory
}

// Classify enforces the invariant and records the event — the only way to
// set sensitivity. Precondition/postcondition pair (an Assertion, per
// references/invariants-and-consistency-boundaries.md): before this runs,
// level must be valid and must not silently downgrade; after it returns
// without error, a.Sensitivity() == level and exactly one DataAssetClassified
// event is recorded.
func (a *DataAsset) Classify(level SensitivityLevel, by uuid.UUID, ruleID uuid.UUID, now time.Time) error {
    if !level.IsValid() {
        return fmt.Errorf("classify data asset %s: %w", a.id, ErrInvalidSensitivity)
    }
    if a.sensitivity.IsHigherThan(level) {
        return fmt.Errorf("classify data asset %s: %w", a.id, ErrCannotDowngradeSilently)
    }
    previous := a.sensitivity
    a.sensitivity = level
    a.classifiedBy = by
    a.ruleID = ruleID
    a.classifiedAt = now
    a.recordEvent(DataAssetClassified{
        AggregateID: a.id, TenantID: a.tenantID,
        Sensitivity: level, PreviousLevel: previous,
        ClassifiedBy: by, RuleID: ruleID, OccurredAt: now,
    })
    return nil
}

// Archive is a second mutation method on the same root, shown to make the
// "root controls all mutations" discipline concrete beyond a single method.
func (a *DataAsset) Archive(reason string, now time.Time) error {
    if a.archivedAt != nil {
        return fmt.Errorf("archive data asset %s: %w", a.id, ErrAlreadyArchived)
    }
    a.archivedAt = &now
    a.recordEvent(DataAssetArchived{AggregateID: a.id, TenantID: a.tenantID, Reason: reason, OccurredAt: now})
    return nil
}

func (a *DataAsset) recordEvent(e DomainEvent) { a.events = append(a.events, e) }

// PullEvents returns and clears uncommitted events — the repository drains
// these into the outbox in the same transaction as the state change.
func (a *DataAsset) PullEvents() []DomainEvent {
    e := a.events
    a.events = nil
    return e
}

// PullPendingEntities returns and clears newly-recorded ExtractedEntity rows
// this transaction — the repository inserts these as new child rows, never
// as a full-collection rewrite. See "A Worked Child Entity Example."
func (a *DataAsset) PullPendingEntities() []ExtractedEntity {
    e := a.pendingEntities
    a.pendingEntities = nil
    return e
}

// Accessors expose state read-only, by value — never a pointer, never the
// live events/pendingEntities slices themselves (per SKILL.md's "Leaking
// internal collections" anti-pattern).
func (a *DataAsset) ID() uuid.UUID               { return a.id }
func (a *DataAsset) TenantID() uuid.UUID         { return a.tenantID }
func (a *DataAsset) Sensitivity() SensitivityLevel { return a.sensitivity }
func (a *DataAsset) Version() int64              { return a.version }
```

---

## Identity Generation in Go

Three shapes, in the order Vernon prefers them, from most- to least-favored:

**1. Client-generated identity — the default.** `uuid.New()` is called by application code at construction time, before any persistence I/O. A fully valid instance, ID included, exists the instant the constructor returns.

```go
// The caller — an application service, never the Aggregate itself —
// generates the ID and passes it in. This is already what go-domain-model's
// NewDataAsset does; shown here with the generation call made explicit at
// the actual call site, one layer up from the constructor.
func (s *RegisterDataAssetService) Handle(ctx context.Context, cmd RegisterDataAssetCommand) (uuid.UUID, error) {
    id := uuid.New() // generated here, BEFORE any database call
    asset, err := domain.NewDataAsset(id, cmd.TenantID, cmd.SourceID, s.clock.Now())
    if err != nil {
        return uuid.Nil, fmt.Errorf("registering data asset: %w", err)
    }
    if err := s.repo.Save(ctx, asset); err != nil {
        return uuid.Nil, fmt.Errorf("saving new data asset %s: %w", id, err)
    }
    return id, nil
}
```

Why this is the default, restated precisely (Vernon's own reasoning, not a style preference): a `DataAssetRegistered` event fired inside `NewDataAsset` can correctly carry `id` — it already exists. A unit test constructs a fully valid `DataAsset` with zero database dependency: `domain.NewDataAsset(uuid.New(), tenantID, sourceID, fixedClock.Now())`, no `Save` call required to get an ID. Vernon's own diagnostic applies directly: if constructing a valid instance for a test requires a database round trip to obtain an ID, that friction is evidence of a wrong identity-generation choice, not a testing inconvenience to route around with more test helpers.

**2. Persistence-generated identity — disfavored, shown only to make the contrast concrete.**

```go
// Disfavored: the ID does not exist until INSERT returns. A DataAssetRegistered
// event fired "at construction" literally cannot carry a real ID yet — it
// would have to be fired after the INSERT, coupling the domain event's timing
// to a specific persistence round trip. A unit test wanting a valid instance
// must either fake an ID (silently untested against the real generation path)
// or accept a database dependency purely to get an integer back.
func (r *DataAssetRepo) Insert(ctx context.Context, tenantID, sourceID uuid.UUID) (int64, error) {
    var id int64
    err := r.pool.QueryRow(ctx, `
        INSERT INTO data_assets (tenant_id, source_id) VALUES ($1, $2)
        RETURNING id`, // SERIAL / GENERATED ALWAYS AS IDENTITY
        tenantID, sourceID,
    ).Scan(&id)
    return id, err
}
```

Never use this shape for a new Aggregate Root in this repo without a specific, documented reason (the closest legitimate reason would be interop with a legacy system that already expects sequential integer IDs — not a case this repo currently has).

**3. `Repository.NextIdentity()` — for business-meaningful (not opaque) identifiers.** Reserved for the case an opaque UUID doesn't fit — a human-readable, sequential, or externally-visible identifier the business itself refers to. Vernon's guidance: keep this domain-facing (owned by the Repository, which the domain layer already talks to) rather than hidden inside infrastructure the domain never sees.

```go
// internal/domain/ports.go — the port lives with the consumer, per go-repository-pattern
type ComplianceGapRepository interface {
    NextIdentity(ctx context.Context) (ComplianceGapReference, error) // e.g. "CG-2026-000431"
    FindByID(ctx context.Context, ref ComplianceGapReference) (*ComplianceGap, error)
    Save(ctx context.Context, g *ComplianceGap) error
}

// internal/infrastructure/postgres/compliancegap_repo.go
func (r *ComplianceGapRepo) NextIdentity(ctx context.Context) (domain.ComplianceGapReference, error) {
    var seq int64
    // A dedicated sequence, queried BEFORE construction — the constructor
    // still only ever accepts an already-generated identifier, exactly like
    // NewDataAsset does. This is the only difference from the client-generated
    // case: WHERE the generation happens, not whether the constructor takes
    // a pre-built ID.
    if err := r.pool.QueryRow(ctx, `SELECT nextval('compliance_gap_seq')`).Scan(&seq); err != nil {
        return domain.ComplianceGapReference{}, fmt.Errorf("reserving next compliance gap identity: %w", err)
    }
    return domain.NewComplianceGapReference(fmt.Sprintf("CG-%d-%06d", time.Now().Year(), seq))
}
```

This repo has no current Aggregate that needs this — every existing Aggregate Root uses an opaque UUID — but it is the correct escape hatch the day one does (a compliance case number a regulator refers to directly, for instance), rather than reaching for persistence-generated identity out of familiarity.

---

## Concurrency Strategy in Go

**Default — optimistic concurrency, compare-and-swap on `version`.** Already fully implemented in `go-repository-pattern`'s `Save` (`UPDATE ... WHERE id = $N AND tenant_id = $M AND version = $K`, `0` rows affected → `ErrConcurrentModification`) — not re-derived here. Use it for every interactive, user-facing write path where per-instance contention is low and a retry is cheap, per `references/sizing-contention-and-concurrency.md`'s full decision tree.

**The narrow, documented exception — pessimistic locking with `SELECT ... FOR UPDATE`.** Reserved for the two conditions Vernon names: a batch/administrative job processing rows sequentially with no interactive user waiting, or an interactive path where a failed optimistic attempt is unacceptably costly to redo. A concrete worked case for the first condition — a nightly reclassification sweep that must re-evaluate every `DataAsset` under a newly-published `ClassificationRule`, one row at a time, with no concurrent interactive writer expected to be racing it:

```go
// internal/infrastructure/postgres/dataasset_repo.go

// ReclassifySweepBatch is used ONLY by the nightly batch job (scripts/jobs,
// not the request path) — this is the documented exception, not a second
// default. Holding a short row lock here is simpler and safer than designing
// a retry loop for a process that isn't latency-sensitive and processes rows
// one at a time, per references/sizing-contention-and-concurrency.md's
// Decision Tree.
func (r *DataAssetRepo) ReclassifySweepBatch(ctx context.Context, ruleID uuid.UUID, limit int) error {
    tx, err := r.pool.Begin(ctx)
    if err != nil {
        return fmt.Errorf("begin sweep tx: %w", err)
    }
    defer func() {
        if rbErr := tx.Rollback(ctx); rbErr != nil && !errors.Is(rbErr, pgx.ErrTxClosed) {
            err = errors.Join(err, fmt.Errorf("rollback: %w", rbErr))
        }
    }()

    // FOR UPDATE SKIP LOCKED lets concurrent sweep workers each claim a
    // disjoint batch without blocking on each other — a lock held only for
    // the duration of this one transaction, never across the whole sweep.
    rows, err := tx.Query(ctx, `
        SELECT id, tenant_id, source_id, sensitivity_level, version
          FROM data_assets
         WHERE needs_reclassification = true
         ORDER BY id
         LIMIT $1
         FOR UPDATE SKIP LOCKED`, limit)
    if err != nil {
        return fmt.Errorf("selecting sweep batch: %w", err)
    }
    defer rows.Close()

    for rows.Next() {
        var (
            id, tid, sid uuid.UUID
            level        string
            version      int64
        )
        if err := rows.Scan(&id, &tid, &sid, &level, &version); err != nil {
            return fmt.Errorf("scanning sweep row: %w", err)
        }
        asset := domain.Reconstitute(id, tid, sid, domain.SensitivityLevel(level), version)
        newLevel := s.engine.Evaluate(ctx, asset, ruleID) // pure classification logic
        if err := asset.Classify(newLevel, systemActorID, ruleID, s.clock.Now()); err != nil {
            return fmt.Errorf("reclassifying data asset %s: %w", id, err)
        }
        // Still writes through the ordinary CAS UPDATE + outbox insert below,
        // inside the SAME transaction that holds the row lock — the lock and
        // the CAS are not competing mechanisms here, the lock just removes
        // the need to retry on conflict within this one sweep transaction.
        if err := r.saveWithinTx(ctx, tx, asset); err != nil {
            return fmt.Errorf("saving reclassified data asset %s: %w", id, err)
        }
    }
    return tx.Commit(ctx)
}
```

**Why this isn't a competing philosophy, just a different tool for a different condition:** the CAS pattern still runs inside this same transaction (`saveWithinTx`) — `FOR UPDATE SKIP LOCKED` only removes the *need* for the CAS to ever reject here (no other writer can touch a row this transaction has already locked), it doesn't replace the CAS as a correctness backstop. Never reach for `FOR UPDATE` on an ordinary interactive `Classify` request handler — that would hold a lock for the duration of a request-response round trip, including any client "think time," which is exactly the throughput cost Vernon's default exists to avoid.

---

## Factory Methods and the Construction/Reconstitution Split

`go-domain-model`'s `NewDataAsset`/`Reconstitute` pair, deepened with the reasoning `references/entities-value-objects-and-domain-primitives.md` already names as an unlabeled Factory-method pair satisfying Evans' third Factory criterion (a materially different path for reconstitution vs. creation):

```go
// NewDataAsset — construction. A real domain event: this asset came into
// existence. Emits DataAssetRegistered exactly once.
func NewDataAsset(id, tenantID, sourceID uuid.UUID, now time.Time) (*DataAsset, error) {
    if id == uuid.Nil || tenantID == uuid.Nil || sourceID == uuid.Nil {
        return nil, ErrMissingIdentity
    }
    a := &DataAsset{id: id, tenantID: tenantID, sourceID: sourceID, version: 1}
    a.recordEvent(DataAssetRegistered{AggregateID: id, TenantID: tenantID, OccurredAt: now})
    return a, nil
}

// Reconstitute — rebuilds an EXISTING asset from storage. Never re-validates
// (the data was valid under the rules in force when it was stored) and never
// emits events (it already exists; nothing "happened" by loading it).
func Reconstitute(id, tenantID, sourceID uuid.UUID, level SensitivityLevel, version int64) *DataAsset {
    return &DataAsset{id: id, tenantID: tenantID, sourceID: sourceID, sensitivity: level, version: version}
}
```

**A genuinely complex Factory case, escalating past a plain constructor function** — illustrative, no such requirement is currently specified elsewhere in this repo, but a plausible shape given this domain: registering a `DataAsset` must, based on the file's detected MIME type, construct one of two different concrete Aggregate Root shapes (`StructuredDataAsset` carrying a `SchemaID`, or `UnstructuredDataAsset` carrying only asset-level classification) — and must simultaneously confirm the referenced `StorageSource` is active before either concrete type is allowed to exist at all. This is the same worked case `references/entities-value-objects-and-domain-primitives.md` already introduces (satisfying Evans' criteria 1 and 2 together — a cross-object invariant at construction time, plus choosing among concrete implementations); reproduced here with the piece that file didn't need to show: how the Factory's read-only lookup fits into the surrounding transaction boundary.

```go
type DataAssetFactory struct {
    sourceRepo StorageSourceRepository // read-only; the SAME pre-transaction
                                       // read pattern references/invariants-and-
                                       // consistency-boundaries.md describes for
                                       // the Classify() Restricted-check — this
                                       // Factory's lookup happens BEFORE the new
                                       // DataAsset's own Save transaction begins,
                                       // never joined into it.
}

func (f *DataAssetFactory) NewFromDetectedFile(
    ctx context.Context, id, tenantID, sourceID uuid.UUID, mimeType string, now time.Time,
) (DataAsset, error) {
    source, err := f.sourceRepo.FindByID(ctx, sourceID)
    if err != nil {
        return nil, fmt.Errorf("resolving storage source %s: %w", sourceID, err)
    }
    if !source.IsActive() {
        return nil, fmt.Errorf("cannot register asset against inactive source %s: %w", sourceID, ErrSourceInactive)
    }
    if isStructuredMIMEType(mimeType) {
        return NewStructuredDataAsset(id, tenantID, sourceID, now)
    }
    return NewUnstructuredDataAsset(id, tenantID, sourceID, now)
}
```

The escalation rule stated plainly: a plain constructor function (`NewDataAsset`) suffices whenever construction validates only the new object's own fields. A dedicated Factory type is warranted only once construction needs a read against another Aggregate's Repository, a choice between concrete types, or both together — never adopted by default "for consistency" when a plain constructor would do.

---

## A Worked Child Entity Example

**The decision, stated first:** `ExtractedEntity` is a **locally-identified child Entity of `DataAsset`** — not its own Aggregate. This resolves the question `references/entities-value-objects-and-domain-primitives.md` deliberately left open, using that file's own test.

**Applying the test:** would any code outside `DataAsset` ever legitimately need to fetch one specific `ExtractedEntity` directly, by its own ID, independent of loading the `DataAsset` that produced it first? Working through this repo's actual domain rather than a hypothetical: a compliance reviewer's question is always "what did this asset extract, and how sensitive is it" — a question that starts at the asset. There is no plausible UI deep-link to "extraction result #4821" independent of the asset it belongs to; no downstream Bounded Context in this repo's domain (Compliance Intelligence, the Graph Context, per `domain-event-catalog`'s worked example) reacts to an individual `ExtractedEntity` as its own unit of integration — they react to `DataAssetClassified`, a fact about the asset as a whole. Contrast this with why `StorageSource` and `ClassificationRule` (`references/worked-examples.md`'s Worked Example 3) *do* need global identity: both are independently administered, independently referenced from multiple `DataAsset`s, and independently queryable ("show me every asset connected to this source," "show me every asset classified under this rule") — exactly the shape of a "yes" answer the test is built to catch. Nothing about `ExtractedEntity` matches that shape. The answer is **no**, and per the test, that settles it: a locally-identified child Entity, unique within its parent `DataAsset`, found only by loading the asset and looking inside.

**What this buys, concretely, tying together two other files' open threads:** because `ExtractedEntity` is local, `DataAsset` never needs its own Repository for it (`SKILL.md`'s "Repository per Entity" anti-pattern stays avoided by construction, not by discipline) and the entity-count question `references/invariants-and-consistency-boundaries.md`'s worked counter-example already resolved (never a root field kept in lockstep) applies unmodified. The one thing local identity does **not** grant permission to do is eagerly load the full collection — that's `references/sizing-contention-and-concurrency.md`'s Eager-Loading Trap, and the `pendingEntities` field shown above in this file's first section is the resolution: `DataAsset` only ever holds *newly recorded, not-yet-persisted* entities in memory, drained on save exactly like Domain Events, never the historical collection.

```go
// internal/domain/extractedentity.go
package domain

// ExtractedEntity is a locally-identified child Entity: it has identity
// (localID is stable across the extraction pipeline's retries) but that
// identity is scoped to its parent DataAsset — never independently queried,
// never independently repository-backed.
type ExtractedEntity struct {
    localID    int64            // unique WITHIN this DataAsset only — a
                                 // per-asset sequence, not a global UUID;
                                 // this is itself part of the local-identity
                                 // signal: a global UUID here would invite
                                 // exactly the "maybe this deserves its own
                                 // Repository" temptation the test above
                                 // already answered "no" to.
    entityType EntityType        // Value Object: SSN, ACCOUNT_NUMBER, EMAIL, ...
    confidence float64
    span       TextSpan          // Value Object: offset/length within the source file
}

// RecordExtractedEntity is DataAsset's own method — the ONLY way an
// ExtractedEntity comes into existence. There is no NewExtractedEntity
// exported from this package for external callers to construct directly;
// construction is entirely owned by the root, per SKILL.md's "Root controls
// mutations" criterion applied to a child Entity, not just the root's own fields.
func (a *DataAsset) RecordExtractedEntity(entityType EntityType, confidence float64, span TextSpan, now time.Time) error {
    if a.archivedAt != nil {
        return fmt.Errorf("record extracted entity on data asset %s: %w", a.id, ErrAssetArchived)
    }
    e := ExtractedEntity{
        localID:    a.nextLocalEntityID(), // a monotonic in-memory/DB-backed
                                            // counter scoped to this asset —
                                            // never a global UUID generator
        entityType: entityType,
        confidence: confidence,
        span:       span,
    }
    a.pendingEntities = append(a.pendingEntities, e)
    // Internal event — see "Distinguishing Internal Events from Published
    // Domain Events" below for why this is NOT published externally as-is.
    a.recordEvent(entityExtractedInternal{AggregateID: a.id, EntityType: entityType, OccurredAt: now})
    return nil
}
```

The repository's job for this shape: `PullPendingEntities()` inserts new rows into an `extracted_entities` table keyed by `(data_asset_id, local_id)` — never a full-collection replace, and `local_id` is only ever unique per `data_asset_id`, enforced by a composite unique constraint rather than a global one, which is the schema-level expression of "local, not global" identity.

---

## Event-Sourced Aggregates in Go

The alternative persistence shape — genuinely new to this repo's Go skill set, per Khononov's research finding. Worked here against `ComplianceGap`, the candidate `references/worked-examples.md`'s Worked Example 4 justifies in full against Khononov's audit-as-record test; this section shows only the Go pattern, not the justification (that belongs in the worked example).

**The core idea, stated precisely:** an event-sourced Aggregate's fields are never set directly by a command handler — they are always *derived* by folding every event in the Aggregate's own history through an `Apply` method, one per event type. The exact same `Apply` method runs whether the Aggregate is being rebuilt from storage (replay the whole stream) or updated in memory immediately after a new command succeeds (apply the one new event so the in-memory instance reflects it without a second read).

```go
// internal/domain/compliancegap.go
package domain

type GapStatus string

const (
    GapStatusOpen        GapStatus = "Open"
    GapStatusAcknowledged GapStatus = "Acknowledged"
    GapStatusRemediated  GapStatus = "Remediated"
    GapStatusVerified    GapStatus = "Verified"
)

// ComplianceGap is event-sourced. Every field below is DERIVED — none of
// them is ever assigned outside an Apply method, including by the command
// methods themselves. This is the one structural difference from DataAsset:
// DataAsset's Classify() assigns a.sensitivity directly and separately
// records an event; ComplianceGap's Acknowledge() records an event and lets
// Apply be the ONLY code path that ever changes a field.
type ComplianceGap struct {
    id              uuid.UUID
    tenantID        uuid.UUID
    dataAssetID     uuid.UUID
    status          GapStatus
    detectedAt      time.Time
    acknowledgedBy  uuid.UUID
    remediationPlan string
    verifiedBy      uuid.UUID
    streamVersion   int64 // the event-sourced equivalent of DataAsset's `version` —
                          // the sequence number of the last event applied

    uncommitted []DomainEvent // events recorded, not yet appended to the store
}

// Apply is the single mutation path — the one thing every event type has in
// common. Replay and in-memory post-command update both call this, and
// nothing else in this type ever assigns a.status, a.detectedAt, etc.
func (g *ComplianceGap) apply(e DomainEvent) {
    switch ev := e.(type) {
    case ComplianceGapDetected:
        g.id, g.tenantID, g.dataAssetID = ev.AggregateID, ev.TenantID, ev.DataAssetID
        g.status, g.detectedAt = GapStatusOpen, ev.OccurredAt
    case ComplianceGapAcknowledged:
        g.status, g.acknowledgedBy = GapStatusAcknowledged, ev.AcknowledgedBy
    case RemediationPlanProposed:
        g.remediationPlan = ev.Plan
    case ComplianceGapRemediated:
        g.status = GapStatusRemediated
    case ComplianceGapVerified:
        g.status, g.verifiedBy = GapStatusVerified, ev.VerifiedBy
    case ComplianceGapReopened:
        g.status = GapStatusOpen
    }
    g.streamVersion++
}

// applyNew is the command-side entry point: apply the event to update
// in-memory state immediately AND stage it for append. Every command method
// below calls this, never a.apply directly and never a.uncommitted append directly —
// one chokepoint keeps the two lists (derived state, staged events) impossible
// to drift apart.
func (g *ComplianceGap) applyNew(e DomainEvent) {
    g.apply(e)
    g.uncommitted = append(g.uncommitted, e)
}

// DetectGap is this Aggregate's construction path — a Factory method, same
// shape as NewDataAsset, except "construction" here means "record the first
// event," not "assign fields directly."
func DetectGap(id, tenantID, dataAssetID uuid.UUID, now time.Time) *ComplianceGap {
    g := &ComplianceGap{}
    g.applyNew(ComplianceGapDetected{AggregateID: id, TenantID: tenantID, DataAssetID: dataAssetID, OccurredAt: now})
    return g
}

// Acknowledge — a command method. Precondition/postcondition, same
// Assertion discipline as DataAsset.Classify: before this runs, status must
// be Open; after it returns without error, status is Acknowledged and
// exactly one ComplianceGapAcknowledged event is staged.
func (g *ComplianceGap) Acknowledge(by uuid.UUID, now time.Time) error {
    if g.status != GapStatusOpen {
        return fmt.Errorf("acknowledge compliance gap %s: %w", g.id, ErrGapNotOpen)
    }
    g.applyNew(ComplianceGapAcknowledged{AggregateID: g.id, TenantID: g.tenantID, AcknowledgedBy: by, OccurredAt: now})
    return nil
}

// PullEvents — identical contract to DataAsset.PullEvents: drain and clear
// what's staged, for the repository to append.
func (g *ComplianceGap) PullEvents() []DomainEvent {
    e := g.uncommitted
    g.uncommitted = nil
    return e
}

// ReconstituteComplianceGap — replay. This is Reconstitute's event-sourced
// counterpart: it folds history through the SAME apply method the command
// path uses, and stages nothing (streamVersion ends up equal to len(history),
// uncommitted stays empty) — reconstitution never re-fires events here
// either, for exactly the reason go-domain-model's Reconstitute doesn't.
func ReconstituteComplianceGap(history []DomainEvent) *ComplianceGap {
    g := &ComplianceGap{}
    for _, e := range history {
        g.apply(e)
    }
    return g
}
```

**The load-bearing discipline this pattern depends on:** every command method funnels through `applyNew`, never through `apply` directly and never appending to `uncommitted` directly. A command method that mutated a field by hand (`g.status = GapStatusAcknowledged`) instead of calling `applyNew` would silently desynchronize replayed state from command-path state — the exact bug class this pattern exists to make structurally impossible, provided the chokepoint is never bypassed.

---

## The Event-Sourced Repository: Conditional Append

**Framed explicitly, per this file's own opening claim: this is the same optimistic-concurrency principle as the current-state CAS pattern, not a different philosophy** — applied to an append-only store instead of a mutable row. Where the current-state repository's `UPDATE ... WHERE version = $N` rejects a write if the row's version has moved, the event-sourced repository's append rejects a write if the stream has grown since it was last read. `0` rows affected and "append rejected" are the identical signal wearing two storage shapes.

```go
-- migrations/0000N_create_compliance_gap_events.sql (per go-migration's conventions)
CREATE TABLE compliance_gap_events (
    aggregate_id    UUID NOT NULL,
    tenant_id       UUID NOT NULL,
    sequence_number BIGINT NOT NULL,
    event_type      TEXT NOT NULL,
    event_version   INT NOT NULL DEFAULT 1,  -- for upcasting, see below
    payload         JSONB NOT NULL,
    occurred_at     TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (aggregate_id, sequence_number)
);
```

```go
// internal/infrastructure/postgres/compliancegap_repo.go

// Load replays the full stream (snapshotting below adds a shortcut, not a
// replacement, for this).
func (r *ComplianceGapRepo) Load(ctx context.Context, id uuid.UUID) (*domain.ComplianceGap, error) {
    rows, err := r.pool.Query(ctx, `
        SELECT event_type, event_version, payload, occurred_at
          FROM compliance_gap_events
         WHERE aggregate_id = $1 AND tenant_id = $2
         ORDER BY sequence_number ASC`, id, tenantID(ctx))
    if err != nil {
        return nil, fmt.Errorf("loading compliance gap %s event stream: %w", id, err)
    }
    defer rows.Close()

    var history []domain.DomainEvent
    for rows.Next() {
        var eventType string
        var eventVersion int
        var payload []byte
        var occurredAt time.Time
        if err := rows.Scan(&eventType, &eventVersion, &payload, &occurredAt); err != nil {
            return nil, fmt.Errorf("scanning event row: %w", err)
        }
        // upcast() is Event Upcasting, below — every row passes through it,
        // even ones already at the current version (a no-op in that case).
        e, err := upcast(eventType, eventVersion, payload)
        if err != nil {
            return nil, fmt.Errorf("upcasting %s v%d: %w", eventType, eventVersion, err)
        }
        history = append(history, e)
    }
    if len(history) == 0 {
        return nil, fmt.Errorf("compliance gap %s: %w", id, domain.ErrNotFound)
    }
    return domain.ReconstituteComplianceGap(history), nil
}

// Save appends new events CONDITIONALLY on the stream's expected next
// sequence number — the event-sourced equivalent of the current-state CAS.
func (r *ComplianceGapRepo) Save(ctx context.Context, g *domain.ComplianceGap) (err error) {
    tx, err := r.pool.Begin(ctx)
    if err != nil {
        return fmt.Errorf("begin tx: %w", err)
    }
    defer func() {
        if rbErr := tx.Rollback(ctx); rbErr != nil && !errors.Is(rbErr, pgx.ErrTxClosed) {
            err = errors.Join(err, fmt.Errorf("rollback: %w", rbErr))
        }
    }()

    var currentMax int64
    if scanErr := tx.QueryRow(ctx, `
        SELECT COALESCE(MAX(sequence_number), 0) FROM compliance_gap_events
         WHERE aggregate_id = $1 AND tenant_id = $2 FOR UPDATE`,
        g.ID(), tenantID(ctx),
    ).Scan(&currentMax); scanErr != nil {
        return fmt.Errorf("checking current stream position for %s: %w", g.ID(), scanErr)
    }
    if currentMax != g.ExpectedStreamVersion() {
        // The append-if-expected-version check — this IS the CAS, restated:
        // "the stream moved since I read it" is the identical signal as
        // "0 rows affected" in the current-state case.
        return fmt.Errorf("compliance gap %s: %w", g.ID(), domain.ErrConcurrentModification)
    }

    for i, e := range g.PullEvents() {
        payload, mErr := json.Marshal(e)
        if mErr != nil {
            return fmt.Errorf("marshalling %s: %w", e.EventType(), mErr)
        }
        if _, err = tx.Exec(ctx, `
            INSERT INTO compliance_gap_events
                (aggregate_id, tenant_id, sequence_number, event_type, event_version, payload, occurred_at)
            VALUES ($1,$2,$3,$4,$5,$6, now())`,
            g.ID(), tenantID(ctx), currentMax+int64(i)+1, e.EventType(), currentEventVersion(e), payload,
        ); err != nil {
            return fmt.Errorf("appending %s: %w", e.EventType(), err)
        }
        // The outbox insert for the PUBLISHED (translated) event happens
        // here too, same transaction — see "Distinguishing Internal Events
        // from Published Domain Events" below for what actually gets written.
    }
    return tx.Commit(ctx)
}
```

`FOR UPDATE` on the `MAX(sequence_number)` read inside the same transaction as the appends is what makes the expected-version check race-free — without it, two concurrent appenders could both read the same `currentMax` and both proceed to insert, defeating the whole point. This is the event-sourced repository's one legitimate use of row locking, and it is scoped to this single transaction, not held across a request.

---

## Snapshotting

A snapshot is never authoritative — purely a load-time optimization, always regeneratable from the stream. Cadence: every *N* events (a tunable constant, not a business rule), persist the derived current state alongside the stream.

```go
-- migrations/0000N_create_compliance_gap_snapshots.sql
CREATE TABLE compliance_gap_snapshots (
    aggregate_id     UUID PRIMARY KEY,
    tenant_id        UUID NOT NULL,
    stream_version   BIGINT NOT NULL,   -- the sequence_number this snapshot reflects
    state            JSONB NOT NULL,    -- the Aggregate's derived fields, serialized
    snapshotted_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

```go
const snapshotEveryNEvents = 50

// snapshotIfDue runs after a successful Save, in the SAME transaction —
// never a separate, best-effort background job that could drift from the
// stream it's meant to summarize.
func (r *ComplianceGapRepo) snapshotIfDue(ctx context.Context, tx pgx.Tx, g *domain.ComplianceGap) error {
    if g.StreamVersion()%snapshotEveryNEvents != 0 {
        return nil
    }
    state, err := json.Marshal(g.SnapshotState()) // a plain DTO of the derived fields
    if err != nil {
        return fmt.Errorf("marshalling snapshot for %s: %w", g.ID(), err)
    }
    _, err = tx.Exec(ctx, `
        INSERT INTO compliance_gap_snapshots (aggregate_id, tenant_id, stream_version, state)
        VALUES ($1,$2,$3,$4)
        ON CONFLICT (aggregate_id) DO UPDATE
          SET stream_version = EXCLUDED.stream_version, state = EXCLUDED.state, snapshotted_at = now()`,
        g.ID(), tenantID(ctx), g.StreamVersion(), state,
    )
    return err
}

// Load, rewritten to use a snapshot as a shortcut, never a substitute:
func (r *ComplianceGapRepo) Load(ctx context.Context, id uuid.UUID) (*domain.ComplianceGap, error) {
    var (
        snapshotVersion int64
        snapshotState   []byte
    )
    err := r.pool.QueryRow(ctx, `
        SELECT stream_version, state FROM compliance_gap_snapshots
         WHERE aggregate_id = $1 AND tenant_id = $2`, id, tenantID(ctx),
    ).Scan(&snapshotVersion, &snapshotState)

    g := domain.NewComplianceGapFromNothing() // empty, pre-replay instance
    if err == nil {
        if restoreErr := g.RestoreFromSnapshot(snapshotState, snapshotVersion); restoreErr != nil {
            return nil, fmt.Errorf("restoring snapshot for %s: %w", id, restoreErr)
        }
    } else if !errors.Is(err, pgx.ErrNoRows) {
        return nil, fmt.Errorf("querying snapshot for %s: %w", id, err)
    }
    // Replay only events AFTER the snapshot — the whole performance point.
    // If no snapshot existed, snapshotVersion is 0 and this replays everything,
    // which is exactly correct: a missing snapshot is not an error, just an
    // unoptimized (but still fully correct) load.
    return r.replayFrom(ctx, id, g, snapshotVersion)
}
```

A snapshot with a bad or stale `state` blob is never a data-loss event — deleting the row and re-running `Load` simply replays from the beginning and produces the identical result, slower. That regeneratability is the entire justification for treating snapshotting as safe to add, remove, or re-tune the cadence of, without a migration plan for the underlying data.

---

## Event Upcasting

A versioned, load-time transformation — never a rewrite of the stored bytes. Distinguished sharply from `domain-event-catalog`'s additive/breaking-version strategy: that strategy works because integration events are transient messages that can run two versions in parallel on the wire until every consumer migrates. A stored, already-persisted internal event has no such luxury — it must remain loadable *forever*, because it is the permanent system of record for that Aggregate, not a message with a retention window.

```go
// internal/domain/upcast.go

// upcast converts a stored event, of whatever version it was written under,
// into the CURRENT shape the domain package's Apply methods expect. The
// stored row is never touched — only the in-memory value produced by this
// function changes.
func upcast(eventType string, storedVersion int, payload []byte) (DomainEvent, error) {
    switch eventType {
    case "ComplianceGapAcknowledged":
        return upcastComplianceGapAcknowledged(storedVersion, payload)
    // ... one case per event type this Aggregate can experience
    default:
        return nil, fmt.Errorf("unknown event type %q: %w", eventType, ErrUnknownEventType)
    }
}

// A concrete upcast chain: v1 of ComplianceGapAcknowledged stored the
// acknowledging user only as a free-text name (an early, since-corrected
// design mistake). v2 replaced it with a proper uuid.UUID actor reference.
// Events written under v1 must still load correctly, forever.
func upcastComplianceGapAcknowledged(storedVersion int, payload []byte) (DomainEvent, error) {
    switch storedVersion {
    case 1:
        var v1 struct {
            AggregateID      uuid.UUID `json:"aggregateId"`
            TenantID         uuid.UUID `json:"tenantId"`
            AcknowledgedByName string  `json:"acknowledgedByName"` // the old, free-text shape
            OccurredAt       time.Time `json:"occurredAt"`
        }
        if err := json.Unmarshal(payload, &v1); err != nil {
            return nil, fmt.Errorf("unmarshalling v1 ComplianceGapAcknowledged: %w", err)
        }
        // The transformation: resolve the historical free-text name to a
        // best-effort sentinel actor ID rather than silently inventing a
        // fake UUID — an honest upcast, not a fabrication.
        return ComplianceGapAcknowledged{
            AggregateID: v1.AggregateID, TenantID: v1.TenantID,
            AcknowledgedBy: resolveHistoricalActor(v1.AcknowledgedByName),
            OccurredAt:     v1.OccurredAt,
        }, nil
    case 2:
        var v2 ComplianceGapAcknowledged
        if err := json.Unmarshal(payload, &v2); err != nil {
            return nil, fmt.Errorf("unmarshalling v2 ComplianceGapAcknowledged: %w", err)
        }
        return v2, nil
    default:
        return nil, fmt.Errorf("unknown ComplianceGapAcknowledged version %d: %w", storedVersion, ErrUnknownEventVersion)
    }
}
```

Every event type this Aggregate can ever experience needs its own upcast chain, however small — the discipline that matters is that a chain is added the moment a shape changes, never retrofitted after the fact once an old-shape row is already unreadable. `event_version` in the schema above exists specifically to make this dispatch possible; a table with no per-row version column has no way to know which upcast function to apply.

---

## Distinguishing Internal Events from Published Domain Events

`ComplianceGap`'s own internal event stream is exactly the granularity its own state-reconstruction needs — `RemediationPlanProposed`, `ComplianceGapReopened`, and the rest are all real, individually-meaningful transitions worth keeping distinct internally. But Compliance Intelligence and the Graph Context (`domain-event-catalog`'s existing consumers) do not need to know about every one of them individually — they need to know the gap's *status* changed, and to what, and when. Publishing every internal transition as-is would couple those consumers to this Aggregate's internal state machine shape — precisely the hidden-coupling hazard Khononov's research names.

```go
// internal/infrastructure/outbox/compliancegap_translator.go

// translateForPublication is the coarsening step — every internal event
// from ComplianceGap passes through here before an outbox row is written.
// Some internal events are dropped entirely (never published); some are
// translated into a coarser external shape.
func translateForPublication(internal domain.DomainEvent) (published domain.DomainEvent, publish bool) {
    switch e := internal.(type) {
    case domain.ComplianceGapDetected:
        return ComplianceGapDetectedPublished{
            GapID: e.AggregateID, TenantID: e.TenantID, DataAssetID: e.DataAssetID, OccurredAt: e.OccurredAt,
        }, true
    case domain.ComplianceGapAcknowledged, domain.RemediationPlanProposed,
        domain.ComplianceGapRemediated, domain.ComplianceGapVerified, domain.ComplianceGapReopened:
        // Coarsened: every one of these internal transitions collapses into
        // the SAME external shape — "the gap's status changed" — because no
        // external consumer needs to distinguish "reopened" from "detected"
        // versus knowing the CURRENT status and when it last changed.
        return ComplianceGapStatusChanged{
            GapID: internal.(interface{ GapID() uuid.UUID }).GapID(),
            NewStatus: statusAfter(internal),
            OccurredAt: internal.(interface{ When() time.Time }).When(),
        }, true
    default:
        // Any future purely-internal bookkeeping event (e.g. a housekeeping
        // event recording that a snapshot was taken) is never published at
        // all — publish=false, no outbox row written for it.
        return nil, false
    }
}
```

The repository's `Save` (shown above) calls this translator once per pulled event, writes the *internal* event to `compliance_gap_events` unconditionally (that's the permanent record this Aggregate exists to keep), and writes an outbox row only for events where `publish` is true, using the *translated*, coarser payload — never the internal one. This is the concrete instance of `domain-event-catalog`'s existing "event as state dump" anti-pattern, extended one layer deeper: the risk here isn't the payload being too large, it's the payload being too *granular*, exposing a storage implementation detail (that this Aggregate happens to use event sourcing, and exactly how many intermediate states it happens to model) to Bounded Contexts that have no business knowing either fact.
