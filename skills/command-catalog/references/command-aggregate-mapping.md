# Command-to-Aggregate Mapping Reference

Self-contained reference for the Command-to-Aggregate mapping table format, Vernon's
one-command-one-aggregate rule, how to identify the correct Aggregate for a Command,
the "command storm" anti-pattern, and a worked mapping table for the DataAsset
Bounded Context. Read alongside `SKILL.md`'s Command-to-Aggregate Mapping section.

---

## Vernon's Rule: One Command, One Aggregate

From *Implementing Domain-Driven Design* (Vernon, Ch. 10 — Effective Aggregate Design):

> A single use case should, ideally, modify exactly one Aggregate instance within
> its own transaction.

This is not a stylistic preference. It is a structural consequence of the Aggregate's
purpose: an Aggregate boundary is a consistency boundary. A transaction that modifies
two Aggregate instances must enforce consistency across two separate boundaries
simultaneously — requiring either a distributed transaction (prohibitively expensive)
or a relaxed, best-effort consistency guarantee that is rarely what the business actually
intended when it asked for "one operation."

**The enforcement chain:**

```
Command → one Aggregate type → one Repository → one transaction
```

Any Command that appears to require two Aggregates in the same transaction is a signal
that one of these is true:

1. The two "Aggregates" share a true invariant and should be **merged** into one
   (revisit Aggregate boundary using Vernon's three-question test: real harm if
   momentarily violated? No easy compensation? Not already enforced externally?)
2. The second Aggregate update is a **consequence** that can tolerate eventual
   consistency — publish a Domain Event from the first transaction; a consumer
   updates the second Aggregate asynchronously.
3. A **Saga** or Process Manager is warranted — a named, persistent coordination
   object that sequences multiple Commands across multiple Aggregates over time
   with explicit compensation steps.

---

## Mapping Table Format

The Command Catalog mapping section uses this table format for each Bounded Context:

| Command | Actor | Aggregate Type | Aggregate Method | Success Event | API Endpoint |
|---|---|---|---|---|---|
| `ClassifyDataAsset` | Compliance Analyst | `DataAsset` | `Classify(cmd)` | `DataAssetClassified` | `PATCH /v1/data-assets/{id}/classification` |
| `ArchiveDataAsset` | Data Steward | `DataAsset` | `Archive(cmd)` | `DataAssetArchived` | `DELETE /v1/data-assets/{id}` |
| `ConnectStorageSource` | Platform Engineer | `StorageSource` | `Connect(cmd)` | `StorageSourceConnected` | `POST /v1/storage-sources` |
| `DetachStorageSource` | Platform Engineer | `StorageSource` | `Detach(cmd)` | `StorageSourceDetached` | `DELETE /v1/storage-sources/{id}` |
| `TriggerEstateScan` | Automated Policy | `StorageSource` | `TriggerScan(cmd)` | `EstateScanTriggered` | `POST /v1/storage-sources/{id}/scans` |

**Column definitions:**

- **Command** — the Command name, PascalCase, imperative verb + Aggregate noun
- **Actor** — the human role or automated policy that issues this Command; required because guards and audit trails reference it
- **Aggregate Type** — the Aggregate Root type this Command targets; establishes which Repository the handler uses
- **Aggregate Method** — the specific method on the Aggregate Root that applies the Command; method signature is `MethodName(cmd CommandType) error`
- **Success Event** — the Domain Event emitted when the Command succeeds; past-tense fact, PascalCase noun phrase
- **API Endpoint** — the HTTP method and path this Command maps to; documented in the Command Catalog and used as input to API contract design

---

## Finding the Right Aggregate for a Command

When a new Command is being defined, use this decision process to identify which
Aggregate it should target.

### Step 1: Identify the True Invariant

What state constraint must hold atomically as a result of this Command? Which object
*owns* that state?

> "A DataAsset can only be classified if its storage source is active."

The state being changed is the `DataAsset`'s `sensitivityLevel`. The invariant
references `StorageSource` status as a cross-Aggregate check — but the *state being
changed* belongs to `DataAsset`. The Command targets `DataAsset`.

### Step 2: Apply the "Has-a vs. Must-Be-Atomic-With" Test (Vernon)

The Ubiquitous Language may say "A StorageSource *has* DataAssets" — but does the
domain require `StorageSource` and `DataAsset` to be **atomically consistent** with
each other at every instant? Usually not. Linguistic ownership does not imply
transactional consistency.

If the answer is "yes, they must be atomically consistent," revisit whether they
should be one Aggregate. If "no, eventual consistency is acceptable," they are
separate Aggregates, and the Command targets only one.

### Step 3: Check the Repository

Each Aggregate type has exactly one Repository. The Repository is queryable only by
the Aggregate Root's own identity. If your Command cannot be routed to a Repository
using only the fields the client supplies, the Aggregate boundary is wrong — not the
Command.

### Step 4: Name the Aggregate Method

The Command should map to a single, named method on the Aggregate Root. The method
name must use Ubiquitous Language — a domain expert should understand it from the
name alone. If you cannot name a clean, single method on one Aggregate that applies
this Command, the Aggregate boundary is probably wrong.

---

## Worked Mapping: DataAsset Bounded Context

Complete mapping for the DataAsset Management Bounded Context, including all
Commands and their Aggregate method signatures.

### DataAsset Aggregate

| Command | Actor | Method Signature | Success Event | Guard Summary |
|---|---|---|---|---|
| `ClassifyDataAsset` | Compliance Analyst | `(a *DataAsset) Classify(cmd ClassifyDataAsset) error` | `DataAssetClassified` | Not archived; SensitivityLevel changed; StorageSource active (denormalized check) |
| `ArchiveDataAsset` | Data Steward | `(a *DataAsset) Archive(cmd ArchiveDataAsset) error` | `DataAssetArchived` | Not already archived; no active compliance holds |
| `TagDataAsset` | Any authenticated user | `(a *DataAsset) Tag(cmd TagDataAsset) error` | `DataAssetTagged` | Tag does not duplicate an existing tag; tag name within length limit |
| `RemoveDataAssetTag` | Any authenticated user | `(a *DataAsset) RemoveTag(cmd RemoveDataAssetTag) error` | `DataAssetTagRemoved` | Tag exists on this asset |
| `RegisterDataAsset` | Automated Policy (EstateScan) | `NewDataAsset(cmd RegisterDataAsset) (*DataAsset, error)` | `DataAssetRegistered` | AggregateID is unique in this tenant; StorageSource exists |

### StorageSource Aggregate

| Command | Actor | Method Signature | Success Event | Guard Summary |
|---|---|---|---|---|
| `ConnectStorageSource` | Platform Engineer | `NewStorageSource(cmd ConnectStorageSource) (*StorageSource, error)` | `StorageSourceConnected` | AggregateID unique; connector type supported; credentials shape valid |
| `DetachStorageSource` | Platform Engineer | `(s *StorageSource) Detach(cmd DetachStorageSource) error` | `StorageSourceDetached` | Not already detached; no active scans in progress |
| `TriggerEstateScan` | Automated Policy | `(s *StorageSource) TriggerScan(cmd TriggerEstateScan) error` | `EstateScanTriggered` | Source is active; no scan currently running for this source |
| `PauseEstateScan` | Platform Engineer | `(s *StorageSource) PauseScan(cmd PauseEstateScan) error` | `EstateScanPaused` | An active scan exists for this source |
| `UpdateStorageCredentials` | Platform Engineer | `(s *StorageSource) UpdateCredentials(cmd UpdateStorageCredentials) error` | `StorageCredentialsUpdated` | Source is not detached; credential shape passes structural validation |

---

## The "Command Storm" Anti-Pattern

A **command storm** is a design where a single user action results in the client
issuing multiple Commands in rapid succession to satisfy one business intent.

**Example of a command storm:**
A "Bulk Reclassify" feature issues 50 individual `ClassifyDataAsset` Commands,
one per asset, inside a client-side loop.

**Why it fails:**

1. **No transactional atomicity.** If the 30th Command fails, the first 29 are already
   committed. The system is in a partially-applied state with no clean rollback.
2. **No business invariant.** "Classify 50 assets together" is a UI-layer batch
   operation, not a domain invariant that requires atomic consistency.
3. **Network amplification.** N Commands = N HTTP round trips = N latency windows
   for failure.

**The resolution:**

Model "Bulk Reclassify" as a **Process Manager** that:
1. Accepts one `BulkClassifyDataAssets` request
2. Persists a process record listing all target asset IDs and the target classification
3. Issues individual `ClassifyDataAsset` Commands asynchronously, one per asset
4. Tracks progress; retries failures; marks the process complete or partially-failed
5. Reports summary status to the requesting user

The Process Manager tolerates partial failure by design. The individual `ClassifyDataAsset`
Commands remain simple, single-Aggregate operations. No distributed transaction is required.

---

## Mapping Table in the Catalog Artifact

The Command Catalog artifact (see `references/catalog-template.md`) contains a
**Command Summary** table at the top that mirrors the mapping table format above — it
is the quick-reference index to the full Command Catalog and the authoritative input
to the API contract design step.

Every Command definition in the Catalog body cross-references:
- Its Aggregate type and method
- Its success Domain Event
- Its API endpoint (also recorded in the API contract design artifact)

This traceability chain — Command → Aggregate → Domain Event → API Endpoint — is
verified by the `pre-phase-advance` hook's methodology-compliance check before a
Bounded Context advances from Design to Implement.
