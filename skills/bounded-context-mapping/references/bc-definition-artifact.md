# BC Definition Artifact
## Template, Worked Example, and Versioning Guide

Self-contained reference for the `bounded-context-mapping` skill. Use this to produce or review
a Bounded Context definition document.

---

## BC Definition Template

Each Bounded Context discovered in the discovery workshop must be documented using this template
before any service-decomposition or architecture decision is made.

```markdown
---
name: [BC name — a domain noun from the Ubiquitous Language, not a technical name]
version: 1.0.0
phase: design
owner: domain-modeler
product: [product name]
created: [ISO date]
---

# [BC Name] — Bounded Context Definition

## Identity

| Field | Value |
|---|---|
| **Name** | [Ubiquitous Language name — e.g. "DataAsset Management"] |
| **Responsibility** | [One sentence: what this context is responsible for in the domain] |
| **Strategic classification** | [Core / Supporting / Generic — from subdomain-distillation output] |
| **Boundary justification** | [Which discovery signals justify this boundary: linguistic fracture, team ownership, data ownership, deployment independence] |

---

## Ubiquitous Language Excerpt

The following terms have specific, bounded meanings **inside this context**. The same words may
carry different meanings in adjacent contexts — that divergence is what justifies the boundary.

| Term | Definition within this context |
|---|---|
| [Term 1] | [One-sentence definition as used inside this BC] |
| [Term 2] | [One-sentence definition as used inside this BC] |
| ... | ... |

Minimum 5 terms. Maximum 15 terms in the excerpt (the full glossary lives in glossary-management).

---

## Owned Aggregates

These Aggregate Roots are defined, maintained, and exclusively written by this context. No other
context may write to the master record of these Aggregates.

| Aggregate Root | Key Invariants | Primary Commands |
|---|---|---|
| [AggregateName] | [The business rule(s) the Aggregate enforces atomically] | [Commands that drive state changes] |

---

## Owned Domain Events

These Domain Events are emitted by Aggregates inside this context and published for consumption
by other contexts. Each event is an immutable fact — something that happened, past tense.

| Event Name | Emitted by | What it signals | Primary consumers |
|---|---|---|---|
| [EventName] | [AggregateName] | [What business fact occurred] | [Other BCs that consume this] |

---

## Consumed Domain Events / Read Models

This context consumes the following from other contexts. It does not own these — it reads them
as events or via Read Models, never writes to the source.

| Source context | What is consumed | Consumed as |
|---|---|---|
| [ContextName] | [Data or event] | Event / Read Model |

---

## Integration Relationships

| Adjacent context | This context's role | Pattern | Implementation |
|---|---|---|---|
| [ContextName] | Upstream / Downstream | [ACL / OHS / PL / Customer / Supplier / Conformist] | [Brief note on mechanism] |

---

## Team / Service Owner

| Field | Value |
|---|---|
| **Owning team** | [Team name or "domain-modeler agent" for this platform] |
| **Deployable service** | [Service name — the microservice that embodies this BC] |
| **Repository / module** | [e.g., `services/dataasset-management/`] |
```

---

## Worked Example: DataAsset Management BC

This example uses the Data Estate Mapping & Compliance Intelligence product.

```markdown
---
name: DataAsset Management
version: 1.0.0
phase: design
owner: domain-modeler
product: Data Estate Mapping & Compliance Intelligence
created: 2026-07-31
---

# DataAsset Management — Bounded Context Definition

## Identity

| Field | Value |
|---|---|
| **Name** | DataAsset Management |
| **Responsibility** | Discovers, ingests, and classifies data assets from external storage sources; produces the canonical DataAsset record that is the authoritative reference for everything downstream |
| **Strategic classification** | Core — this is the differentiating capability of the product |
| **Boundary justification** | Linguistic fracture (a "File" in Google Drive is a raw object; a "DataAsset" here is an enriched, classified domain entity — distinct meanings); data ownership (only this context writes the authoritative DataAsset record); deployment independence (classification workloads must scale independently) |

---

## Ubiquitous Language Excerpt

| Term | Definition within DataAsset Management |
|---|---|
| **DataAsset** | A discovered, ingested, and at least partially classified unit of data originating from an external storage source. Has identity, a sensitivity level, a schema fingerprint, and a lifecycle. Not the same as a raw "file" or "object" in external storage. |
| **StorageSource** | An external system (Google Drive workspace, S3 bucket, SharePoint site) from which DataAssets are discovered. Has a connectivity status and a discovery schedule. |
| **SensitivityLevel** | A classification decision attached to a DataAsset — one of: Unclassified, Internal, Confidential, Restricted. This is a domain-specific assessment, not the storage provider's own access control label. |
| **ExtractionJob** | A unit of work that ingests a StorageSource, discovers DataAssets, and extracts structural metadata. Has a run status and a result summary. |
| **ExtractedEntity** | A typed, named data element found inside a DataAsset's content (e.g., a column name, a named field, a detected PII pattern). Locally identified within its owning DataAsset. |
| **DataAssetClassified** | The fact that a DataAsset's SensitivityLevel was set or changed by a classification action. An immutable past-tense event. |

---

## Owned Aggregates

| Aggregate Root | Key Invariants | Primary Commands |
|---|---|---|
| **DataAsset** | A DataAsset may only be marked Restricted if its StorageSource is confirmed Active at the time of classification; SensitivityLevel changes emit a DataAssetClassified event; version must increment on every state change | RegisterDataAsset, ClassifyDataAsset, ArchiveDataAsset |
| **StorageSource** | A StorageSource may not be deleted while it has Active DataAssets; connectivity status is derived from the most recent probe result | RegisterStorageSource, ProbeConnectivity, DeactivateStorageSource |
| **ExtractionJob** | A job may only transition from Pending → Running → Completed or Failed; retries are bounded by a configured maximum | ScheduleExtraction, StartExtraction, CompleteExtraction, FailExtraction |

---

## Owned Domain Events

| Event Name | Emitted by | What it signals | Primary consumers |
|---|---|---|---|
| `DataAssetRegistered` | DataAsset | A new DataAsset was discovered and persisted | Compliance Intelligence, Reporting |
| `DataAssetClassified` | DataAsset | A DataAsset's SensitivityLevel was set or changed | Compliance Intelligence, Graph, Reporting |
| `DataAssetArchived` | DataAsset | A DataAsset is no longer active in any StorageSource | Compliance Intelligence |
| `StorageSourceRegistered` | StorageSource | A new external storage source was connected | Reporting |
| `StorageSourceDeactivated` | StorageSource | A StorageSource is no longer reachable or was removed | Compliance Intelligence, Graph |
| `ExtractionCompleted` | ExtractionJob | A full scan of a StorageSource completed | DataAsset Management (self — triggers classification pipeline) |

---

## Consumed Domain Events / Read Models

| Source context | What is consumed | Consumed as |
|---|---|---|
| Identity & Access | Tenant configuration (which storage sources are permitted) | Read Model — via tenant-settings projection |
| Compliance Intelligence | Classification rule updates (new sensitivity policies) | Event — `ClassificationRuleUpdated` |

---

## Integration Relationships

| Adjacent context | This context's role | Pattern | Implementation |
|---|---|---|---|
| Google Drive API | Downstream (consumer) | ACL — Google Drive Adapter | `internal/infrastructure/gdrive/` translates Drive `File` objects into `StorageSourceItem` Value Objects; the domain never sees Drive types |
| AWS S3 API | Downstream (consumer) | ACL — S3 Adapter | Same pattern; `internal/infrastructure/s3/` translates S3 `Object` into `StorageSourceItem` |
| Compliance Intelligence | Upstream (producer) | OHS + PL | Emits events over Redpanda topics; event schemas registered in schema registry |
| Graph Context | Upstream (producer) | PL | Emits `DataAssetClassified` events consumed by Graph to update the knowledge graph |
| Identity & Access | Downstream (consumer) | Customer/Supplier | Consumes tenant and user records; enforced by Consumer-Driven Contract test |

---

## Team / Service Owner

| Field | Value |
|---|---|
| **Owning team** | domain-modeler agent (design phase); backend-engineer agent (implementation phase) |
| **Deployable service** | `dataasset-management` |
| **Repository / module** | `services/dataasset-management/` |
```

---

## Versioning a BC Definition

A BC definition is a design artifact that evolves as the domain is better understood. Version
the document using semantic versioning with this interpretation:

| Change type | Version bump | When |
|---|---|---|
| New Aggregate or Domain Event added | MINOR (1.0.0 → 1.1.0) | The boundary grew to cover more responsibility |
| Ubiquitous Language term redefined | MINOR | A better definition was found; no structural change |
| Boundary moved (Aggregate transferred to another BC) | MAJOR (1.x.x → 2.0.0) | The boundary changed — any downstream service-decomposition decisions based on v1.x must be reviewed |
| Integration pattern changed | MAJOR | A pattern change (e.g., Conformist → ACL) implies an architectural change |
| Typos, formatting | PATCH (1.0.0 → 1.0.1) | No semantic change |

**When a MAJOR version is issued:** review the Context Map to check whether any relationship
pattern is now incorrect, review the service-decomposition decisions in
`references/service-decomposition.md`, and re-run the "one BC or two?" decision tree from
`references/bc-discovery-guide.md` to confirm the new boundary is stable.

### Go struct for tracking BC identity across versions

When the service embodying a BC needs to communicate its own BC identity to other services
(e.g., in a health endpoint or a manifest API), use this shape:

```go
// BoundedContextIdentity describes the BC this service embodies.
// Used in health endpoints and deployment manifests.
type BoundedContextIdentity struct {
    Name    string `json:"name"`    // e.g. "DataAsset Management"
    Version string `json:"version"` // semver of the BC definition, e.g. "1.1.0"
    Phase   string `json:"phase"`   // design | implement | production
}
```

This is documentation metadata, not domain logic. It belongs in the service's `internal/config`
package alongside its service-version constant, not in the domain layer.
