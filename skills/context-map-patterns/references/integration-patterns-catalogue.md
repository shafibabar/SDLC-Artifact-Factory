# Integration Patterns Catalogue
## Full per-pattern reference for context-map-patterns

This file is the comprehensive per-pattern reference. It is self-contained — usable without the
parent SKILL.md in context. All nine Context Map patterns are covered with formal definition,
precise use/do-not-use criteria, political dynamics, and implementation shape for this platform's
Go + Redpanda + OpenAPI stack.

Sources: Evans, *Domain-Driven Design* (2003), Ch. 14 "Maintaining Model Integrity"; Vernon,
*Implementing Domain-Driven Design* (2013), Ch. 3 "Context Maps"; Khononov, *Learning DDD* (2021),
Ch. 4 "Integrating Bounded Contexts".

---

## Pattern 1: Partnership

### Formal Definition
Two teams commit to succeed or fail together. They synchronize planning and release cycles; each
team has effective veto power over the other's interface changes. Evans names this pattern for
relationships where neither team is upstream or downstream — the dependency is mutual (Ch. 14).

### When to Use
- Two Bounded Contexts share a delivery milestone that neither can ship independently
- Both teams have genuine mutual influence over the integration contract
- The dependency is acknowledged to be temporary — the goal is to stabilize into a
  Customer/Supplier relationship as the interface matures

### When NOT to Use
- The dependency is permanent; if it cannot be resolved into a clear upstream/downstream, use
  Shared Kernel instead
- One team is significantly more powerful or indifferent — that dynamic makes Partnership
  governance hollow; use Customer/Supplier or Conformist instead
- Remote teams across time zones with infrequent sync — Partnership requires continuous, low-latency
  communication to function

### Political/Team Dynamic
Partnership cannot be mandated from above. Both teams must genuinely agree. The coordination cost
is high: joint planning meetings, unified release gates, architecture review for every change to
shared interfaces. Treat this pattern as a time-boxed transitional state with an explicit exit plan
— indefinite Partnership without a sunset date is an anti-pattern (see SKILL.md).

### Implementation in This Platform
No special code mechanism. The integration contract is maintained by:
- Shared interface documentation committed to a jointly-owned repository path
- Both teams listed as required reviewers on PRs that touch the shared interface
- A joint release gate in CI: neither service's deployment pipeline proceeds without the other's
  integration tests passing
- An explicit "exit date" by which the relationship must mature to Customer/Supplier

### Worked Example (This Repo)
In the early stage of integrating Classification Engine with a new Compliance Intelligence service,
before either team's API is stable, Partnership may apply for one release cycle — both teams
jointly own the `DataAssetClassified` event schema and neither can change it unilaterally. This
is transitional: once the schema stabilizes, the relationship becomes Customer/Supplier with
Classification Engine as upstream.

---

## Pattern 2: Shared Kernel

### Formal Definition
Two Bounded Contexts share a small, explicitly agreed-upon subset of the domain model. The shared
code is jointly owned: any change requires agreement from both teams, testing in both contexts, and
coordinated release (Evans, Ch. 14).

### When to Use
- Both contexts genuinely depend on the same immutable concept — a canonical identifier type, a
  cross-cutting reference data schema, or a Published Language envelope format
- The shared subset is small and stable; the two teams have a negotiated governance process
- The shared kernel is enumerated (the list of what's in it is finite and agreed)

### When NOT to Use
- The shared subset is growing — a Shared Kernel that grows is a coupling accumulator; dissolve
  it into a Published Language or per-context code
- No governance process exists for joint approval — without joint ownership, this is just coupling
  wearing a pattern's name
- Three or more contexts need the same thing — at that scale, prefer Open Host Service +
  Published Language over a kernel shared across many teams simultaneously

### Political/Team Dynamic
Both teams are co-owners. Changes require a PR approved by both. The governance cost is
proportional to the kernel's size — keep it minimal. Khononov (Ch. 4) notes that Shared Kernel
is increasingly rare in microservices architectures, superseded by Published Language for
cross-context schemas because PL eliminates co-ownership of code while maintaining schema alignment.

### Implementation in This Platform
A Go module (not a package inside a single service) versioned independently:
```
shared-kernel/
├── go.mod                    # module: github.com/org/product-shared
├── ids/                      # canonical ID types only
│   └── ids.go                # type DataAssetID = uuid.UUID; type TenantID = uuid.UUID
└── events/                   # shared event envelope (not payloads — those are per-PL)
    └── envelope.go           # type EventEnvelope struct { ID, Type, OccurredAt, TenantID }
```
Both services declare the shared module as a dependency. Changes to this module require PRs
approved by both owning teams before merging.

### Worked Example (This Repo)
If `DataAssetID` and `TenantID` canonical types must be used identically in both Classification
Engine and Compliance Intelligence — typed aliases that enforce no confusion at compile time —
a shared-kernel module carrying only those two type aliases is a legitimate use. The module must
declare: "This module contains `DataAssetID` and `TenantID`. Nothing else will be added without
both teams' approval."

---

## Pattern 3: Customer/Supplier

### Formal Definition
A clear upstream (Supplier) / downstream (Customer) dependency, with the Supplier carrying explicit
obligations to the Customer: no breaking changes without consultation, and Customer requirements
have a place on the Supplier's roadmap (Evans, Ch. 14; Vernon, Ch. 3).

### When to Use
- Two internal teams with a clear directional dependency
- The downstream can negotiate — it has organizational standing to demand a stable contract
- The upstream has the capacity to maintain that stability
- This is the **default pattern for all internal upstream/downstream relationships** in a
  well-governed microservices system

### When NOT to Use
- The upstream team is indifferent and has no organizational incentive to honor obligations —
  that is Conformist territory, not Customer/Supplier
- The upstream serves three or more consumers and a private per-consumer contract is unmanageable
  — escalate to Open Host Service

### Political/Team Dynamic
The upstream has power over the downstream. The Customer/Supplier pattern rebalances this through
Consumer-Driven Contracts: the downstream writes the contract (what it expects from the upstream),
and the upstream's CI must pass the downstream's tests before any deployment. This gives the
downstream a technical veto over breaking changes — the contract is the mechanism of obligation.

Without Consumer-Driven Contracts, this relationship degrades to Conformist by default. The
contracts are not optional — they are the enforcement mechanism (Vernon, Ch. 3).

### Implementation in This Platform
```
# DataAsset → Classification Engine relationship
# Consumer (Classification Engine) declares what it reads from DataAsset:
tests/
└── contracts/
    └── classification-engine-consumes-data-asset.json   # Pact or schema-based contract

# In Classification Engine's CI pipeline:
- run: go test ./tests/contracts/...   # verifies DataAsset still satisfies the contract

# In DataAsset Management's CI pipeline:
- run: pact-provider-verifier \        # runs all consumers' contracts against DataAsset
    --provider-base-url $BASE_URL \
    --pact-urls s3://contracts/...
```

### Worked Example (This Repo)
**Classification Engine → Compliance Intelligence**: Compliance depends on `DataAssetClassified`
(carrying `SensitivityLevel`) and can negotiate with the upstream team. The contract specifies
exactly which fields Compliance reads (`dataAssetID`, `tenantID`, `sensitivityLevel`,
`classifiedAt`) — the upstream cannot rename or remove these fields without a coordinated version
bump and migration.

---

## Pattern 4: Conformist

### Formal Definition
The downstream context adopts the upstream model as-is, without translation. The upstream has no
obligation to the downstream and no incentive to negotiate. The downstream simply conforms to
whatever the upstream provides (Evans, Ch. 14).

### When to Use
- The upstream team is indifferent to the downstream's needs (e.g., a large internal platform
  team with dozens of consumers, or a vendor-owned API that has no SLA for customization)
- The upstream model is coherent in the downstream's domain sense — see the **Ubiquitous Language
  collision check** below before deciding
- The relationship is low-risk: the upstream model is stable and unlikely to change frequently
  in ways that break the downstream's core domain invariants

### When NOT to Use
- The upstream is an internal team that *can* be negotiated with — escalate to Customer/Supplier
  instead; Conformist permanently cedes the downstream's model to a team that owes it nothing
- The **Ubiquitous Language collision check** fails (see below) — if adopting the upstream model
  would introduce vocabulary that conflicts with the downstream's own model, Conformist is wrong
  and ACL is required

### The Ubiquitous Language Collision Check
This is the decisive test for choosing between Conformist and Anti-Corruption Layer:

Compare the upstream's vocabulary to the downstream's Ubiquitous Language term-by-term. If
adopting the upstream model would require the downstream domain layer to use a term with a
different meaning than its own model assigns to that term — or to import concepts that do not
exist in the downstream's Ubiquitous Language at all — then **Conformist is wrong and ACL is
required**.

Example: if the upstream API uses `File` to mean any cloud storage object (a Google Drive API
concept), while the downstream uses `File` to mean a governed `DataAsset` subject to
classification and compliance tracking, that semantic collision means the downstream cannot safely
adopt the upstream model. The term `File` carries different invariants on each side. An ACL is
required to translate `File` (upstream) → `DataAsset` candidate (downstream).

If there is no collision — the upstream model is coherent in the downstream's domain sense, no
term conflicts arise, no invariants are violated — then Conformist is correct and the ACL's
translation overhead is wasteful.

### Political/Team Dynamic
This is the pattern for power imbalance: the upstream team has more organizational authority, or
is simply not reachable for negotiation. Attempting to impose Consumer-Driven Contracts on a
non-cooperative upstream will fail — that energy is better spent on building an ACL if the model
is poor, or simply conforming if the model is acceptable.

### Implementation in This Platform
No special mechanism. The downstream imports and uses the upstream's types directly:
```go
// In the downstream Classification Engine — Conformist to an internal platform's audit API
// The platform's AuditRecord type is used directly; no translation layer.
import auditplatform "github.com/org/audit-platform/api"

func recordClassification(a auditplatform.AuditRecord) {
    // Store audit record as-is — no translation to a domain type
}
```
Document the dependency explicitly: which upstream package is imported, its version, and the
upstream's release cadence, so the downstream can plan for drift.

---

## Pattern 5: Anti-Corruption Layer (ACL)

### Formal Definition
The downstream builds a translation layer that converts the upstream model into the downstream's
own Ubiquitous Language. Nothing inside the downstream ever sees the upstream model directly —
the ACL is the boundary. The domain layer imports only from the ACL's ports interface; the
adapters package is internal to the ACL (Evans, Ch. 14; Vernon, Ch. 3).

### When to Use
- **Always** for third-party APIs (Google Drive, AWS S3, Office 365) — without exception
- Integrating with a legacy system whose model is poor, undefined, or volatile
- When the **Ubiquitous Language collision check** (see Pattern 4) fails — when the upstream
  vocabulary would corrupt the downstream's own model if imported directly
- When the upstream is expected to change frequently and the downstream must be insulated

### When NOT to Use
- The upstream model is coherent in the downstream's domain sense (no UL collision) and the
  upstream is cooperative — use Conformist or Customer/Supplier instead; ACL adds maintenance cost
- The "translation" would be purely 1:1 field renaming — that is a pass-through ACL anti-pattern
  (see SKILL.md); if there is nothing to translate, the relationship is Conformist, not ACL

### Political/Team Dynamic
The downstream takes full control of its own model regardless of the upstream's cooperation.
The ACL is a unilateral decision — the downstream builds it, maintains it, and updates it when
the upstream changes. The upstream is never aware of the ACL's existence. This is the correct
pattern even when the upstream is cooperative — if the upstream's model is semantically different
from the downstream's, an ACL is more durable than a negotiated Conformist arrangement.

### Implementation in This Platform
```
internal/
└── acl/                          # ACL package — imported by application layer only
    ├── ports/                    # Interfaces the domain uses (the downstream's own vocabulary)
    │   └── storage_source.go     # type StorageSourcePort interface { ListAssets(...) }
    ├── adapters/                  # HTTP/SDK clients for the upstream API (never seen by domain)
    │   ├── googledrive/
    │   │   └── client.go         # calls Google Drive API; returns upstream types internally
    │   └── s3/
    │       └── client.go         # calls AWS S3 API; returns upstream types internally
    └── translators/              # Convert upstream types → downstream domain types
        ├── googledrive_translator.go   # maps drive.File → DataAssetCandidate
        └── s3_translator.go            # maps s3.Object → DataAssetCandidate
```

**The critical import rule**: the domain layer (`internal/domain/`) imports only from `ports/`.
It never imports from `adapters/` or `translators/`. The `adapters/` packages are imported only
by the `translators/`, and the `translators/` are wired at the application layer (`internal/app/`)
which satisfies the `ports/` interfaces with the concrete adapter+translator implementations.

```go
// internal/domain/service.go — domain imports only the port
import "github.com/org/product/internal/acl/ports"

type ClassificationService struct {
    storage ports.StorageSourcePort  // the domain only knows the port interface
}
```

```go
// internal/acl/translators/googledrive_translator.go — translates upstream types
import (
    drive "google.golang.org/api/drive/v3"           // upstream type
    "github.com/org/product/internal/domain"         // downstream domain type
)

func TranslateFile(f *drive.File) (domain.DataAssetCandidate, error) {
    return domain.DataAssetCandidate{
        ExternalID:  f.Id,
        Name:        f.Name,
        StorageKind: domain.GoogleDriveStorage,
        MimeType:    f.MimeType,
    }, nil
}
```

### Worked Example (This Repo)
**Google Drive API → Storage Integration BC**: The Google Drive API exposes `File` resources with
fields like `mimeType`, `parents[]`, `capabilities`, and `permissions[]`. None of these field
names or concepts appear in the downstream's Ubiquitous Language — the domain has `DataAsset`,
`StorageSource`, and `DataAssetCandidate`. The ACL in `internal/acl/adapters/googledrive/` calls
the Drive API; the translator in `internal/acl/translators/googledrive_translator.go` maps
`drive.File` → `domain.DataAssetCandidate`. The domain layer has zero knowledge of the Drive API.

---

## Pattern 6: Open Host Service (OHS)

### Formal Definition
The upstream context defines a well-documented, versioned protocol that any downstream can consume.
The protocol (not the implementation) is the contract. The upstream takes on public API discipline:
versioning, backward compatibility commitments, and change communication (Evans, Ch. 14).

### When to Use
- One upstream context must serve two or more downstream consumers
- Negotiating a private Customer/Supplier contract per consumer is unmanageable at scale
- The upstream team can commit to API versioning discipline and a deprecation sunset policy

### When NOT to Use
- Only one consumer currently exists — start with Customer/Supplier; escalate to OHS only when the
  second consumer arrives and the Consumer/Supplier model becomes unwieldy
- The upstream team cannot maintain versioning discipline — OHS without versioning commitments
  degrades into an undocumented, breaking API that is worse than Conformist

### Political/Team Dynamic
The upstream takes on the responsibility of a public API owner: versioning, documentation,
deprecation windows. This is a heavier organizational commitment than Customer/Supplier. The
benefit is scale — one public contract serves N consumers instead of N private contracts. The
risk is the "union-of-wishes" anti-pattern: if the OHS accumulates every consumer's special
request, it becomes a lowest-common-denominator API that serves nobody and can never shed a field.

### Implementation in This Platform
The OHS protocol is an OpenAPI specification (for synchronous) or an Avro/JSON Schema event
schema (for event-driven). The OHS and Published Language patterns are frequently paired:
- The OHS defines the endpoint and versioning contract
- The Published Language defines the event/payload schema that the OHS produces and consumers read

```yaml
# openapi/classification-engine/v1/openapi.yaml
openapi: "3.1.0"
info:
  title: Classification Engine API
  version: "1.0.0"      # SemVer; MAJOR bump for breaking changes
paths:
  /v1/assets/{id}/classification:
    get:
      summary: Get classification result for a DataAsset
      # Breaking changes require /v2/ path; /v1/ maintained 6 months after /v2/ launch
```

Consumer-Driven Contracts for OHS: each known consumer registers a contract against the OHS
endpoint. A new version of the OHS must pass all consumers' contracts before deployment.

---

## Pattern 7: Published Language (PL)

### Formal Definition
A well-documented, versioned shared schema — event schemas, canonical data models — that multiple
Bounded Contexts use to communicate. Frequently paired with OHS: the OHS publishes using the
Published Language. The schema is the contract; it is registered in a schema registry and governed
(Evans, Ch. 14; Khononov, Ch. 4).

### When to Use
- Event-driven integration across Bounded Contexts — the event schema is the Published Language
- Multiple contexts must read each other's events without point-to-point negotiation
- Schema evolution must be tracked, versioned, and validated at publish/consume time

### When NOT to Use
- Only two contexts share the schema — start with Consumer-Driven Contracts on a Customer/Supplier
  relationship; a full Published Language governance process is overhead for a two-party contract
- The "shared language" is really a grab-bag of convenience types — that is a Shared Kernel
  candidate (if small and stable) or a coupling smell (if large and growing)

### Schema Registry and Governance
```
# Event schema: DataAssetClassified
# File: schemas/events/data-asset-classified/v1.json (JSON Schema)
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "data-asset-classified/v1",
  "type": "object",
  "required": ["dataAssetID", "tenantID", "sensitivityLevel", "classifiedAt", "classifiedBy"],
  "properties": {
    "dataAssetID":      { "type": "string", "format": "uuid" },
    "tenantID":         { "type": "string", "format": "uuid" },
    "sensitivityLevel": { "enum": ["public", "internal", "confidential", "restricted"] },
    "classifiedAt":     { "type": "string", "format": "date-time" },
    "classifiedBy":     { "type": "string" }
  },
  "additionalProperties": false
}
```

Schema evolution rules:
- **Additive change** (new optional field): minor version bump; existing consumers need not change
  (tolerant reader — ignore unknown fields)
- **Breaking change** (remove field, rename field, change type): major version bump; run both
  versions in parallel during consumer migration; no breaking change to an in-production schema
  without a named migration plan

---

## Pattern 8: Separate Ways

### Formal Definition
Two contexts have no integration; they operate completely independently. Named explicitly on the
Context Map to document the deliberate decision that integration cost exceeds its value (Evans,
Ch. 14).

### When to Use
- Two subdomains that appear related at the domain language level but share no data or process
  that would require synchronization
- Integration cost (team coordination, schema evolution, latency, failure modes) provably exceeds
  the benefit (data consistency, feature enablement)

### When NOT to Use
- The separation was assumed, not validated — always verify with Event Storming before committing;
  a false Separate Ways creates duplication and eventual inconsistency
- The contexts will need to share data in a future phase — defer separation until the integration
  need is confirmed absent, rather than engineering both integration and a future migration

### Implementation in This Platform
No code shared. No events exchanged. No shared database tables. The Separate Ways decision is
documented in the Context Map artifact and in an ADR that names the specific business rationale.

---

## Pattern 9: Big Ball of Mud

### Formal Definition
Not a design pattern — an honest recognition that an existing system has no clear boundaries,
no defined interfaces, and ad-hoc integration everywhere. Named on the Context Map to document
reality rather than pretend boundaries exist where they do not (Evans, Ch. 14; Newman, Ch. 2).

### When to Use
- Documenting a legacy system or an existing service with accumulated coupling
- The system cannot be refactored in the current engagement — naming "Big Ball of Mud" is more
  honest than inventing a clean boundary that doesn't exist

### Next Steps
Plan migration toward defined boundaries. The ACL is always the correct entry point into a Big
Ball of Mud — never design new services to integrate directly with it. The ACL isolates new
services from the mud's instability and provides a refactoring surface for future improvement.

Newman's Strangler Fig pattern (Branch by Abstraction or edge-level routing) is the execution
mechanic for gradually replacing a Big Ball of Mud while new services grow up around it — see
`strangler-fig-execution` if that skill exists, or `subdomain-distillation`'s legacy transformation
guidance.

---

## Quick Pattern Comparison: Conformist vs. ACL

This comparison is frequently needed — both patterns address a non-cooperative or inaccessible
upstream, but they make fundamentally different trade-offs:

| Dimension | Conformist | Anti-Corruption Layer |
|---|---|---|
| Upstream vocabulary in domain layer | Yes — upstream types appear in downstream code | No — domain layer sees only its own types |
| Translation cost | Zero | Ongoing maintenance as upstream changes |
| Model pollution risk | High — upstream concepts leak into domain | None — ACL is the boundary |
| When correct | Upstream model is coherent in downstream's domain sense; no UL collision | Upstream vocabulary conflicts with downstream's Ubiquitous Language |
| Decisive test | **Ubiquitous Language collision check** (see Pattern 4) | Same check, opposite result |

The **Ubiquitous Language collision check** is the single most important decision criterion
distinguishing these two patterns. It is not a subjective preference — it is a structural test
grounded in whether the upstream's vocabulary is safe to adopt as-is in the downstream's own
domain model.
