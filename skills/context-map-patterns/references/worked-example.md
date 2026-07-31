# Worked Example: Complete Context Map for the Data Estate Platform
## Three-BC example with full pattern annotation

This file is self-contained — usable without the parent SKILL.md in context. It shows a complete
Context Map for this repo's first product (Data Estate Mapping and Compliance Intelligence) with
every relationship annotated with the chosen pattern, the alternatives considered, and the rationale
for the selection.

---

## The Three Bounded Contexts

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  External Systems                                                            │
│  ┌─────────────────┐   ┌─────────────────┐                                  │
│  │  Google Drive   │   │    AWS S3       │                                  │
│  │  API            │   │    API          │                                  │
│  └────────┬────────┘   └────────┬────────┘                                  │
│           │  ACL                │  ACL                                       │
└───────────┼─────────────────────┼───────────────────────────────────────────┘
            │                     │
            ▼                     ▼
┌────────────────────────────────────────────────────────────────────────────┐
│  Storage Integration BC                                                     │
│  (discovers DataAsset candidates from external storage sources)             │
│                                                                             │
│  Core domain concepts: StorageSource, DataAssetCandidate, DiscoveryJob     │
└──────────────────────────────────────────┬─────────────────────────────────┘
                                           │  OHS + PL
                                           │  (DataAssetDiscovered event)
                                           ▼
┌────────────────────────────────────────────────────────────────────────────┐
│  Classification Engine BC                                                   │
│  (classifies DataAsset candidates; assigns SensitivityLevel)               │
│                                                                             │
│  Core domain concepts: DataAsset, SensitivityLevel, ClassificationRule,   │
│  Classifier, ClassificationAuditEntry                                      │
└──────────┬─────────────────────────────────────────────┬───────────────────┘
           │  Customer/Supplier                          │  Customer/Supplier
           │  (DataAssetClassified event)                │  (entity graph queries)
           ▼                                             ▼
┌──────────────────────┐                   ┌────────────────────────────────┐
│  Compliance          │                   │  Graph Context BC               │
│  Intelligence BC     │◄──────────────────│  (entity relationship graph;   │
│  (gap analysis;      │  Customer/Supplier │   identifies PII entity links)  │
│   compliance reports)│  (entity queries) │                                 │
└──────────────────────┘                   └────────────────────────────────┘
```

---

## Pattern Selection Rationale

| Relationship | Pattern selected | Rationale | CDC required? |
|---|---|---|---|
| Google Drive API → Storage Integration | **ACL** | Third-party vendor API — rule applies unconditionally. Google Drive's `File` resource (fields: `mimeType`, `parents[]`, `capabilities`, `permissions[]`) uses vocabulary incompatible with the downstream's domain. `File` in Google Drive means any cloud storage object; `DataAsset` in Storage Integration means a governed asset subject to classification. The Ubiquitous Language collision makes Conformist structurally wrong. ACL translates `drive.File` → `DataAssetCandidate` in `internal/acl/translators/googledrive_translator.go`. | No (vendor will not run downstream's tests; ACL integration tests instead) |
| AWS S3 API → Storage Integration | **ACL** | Same reasoning as Google Drive. S3 exposes `Object` and `Bucket` vocabulary; neither maps to the downstream's Ubiquitous Language without translation. The `Object` key naming scheme and metadata model differs entirely from `DataAssetCandidate`'s required fields. | No (same vendor-ACL rationale) |
| Storage Integration → Classification Engine | **OHS + Published Language** | Classification Engine is consumer #1 today; a future Indexing service and a future Governance Dashboard are planned consumers within 6 months. The upstream exceeds the 2-consumer threshold at which private Customer/Supplier contracts become unmanageable. Storage Integration publishes `DataAssetDiscovered` events to a Redpanda topic; the event schema is the Published Language, registered in the schema registry and versioned. Classification Engine and future consumers register Consumer-Driven Contracts against the OHS endpoint. | Yes — one contract per consumer of the OHS |
| Classification Engine → Compliance Intelligence | **Customer/Supplier** | Compliance Intelligence depends on `DataAssetClassified` events (carrying `dataAssetID`, `tenantID`, `sensitivityLevel`, `classifiedAt`). Compliance is the single downstream; Classification Engine has organizational obligation to not break Compliance's integration. Consumer-Driven Contract: Compliance writes the contract specifying exactly which fields it reads; Classification Engine's CI runs this contract before every deployment. **Rejected: Conformist** — Classification Engine is an internal team that can and should honor obligations. Conformist here would permanently cede the Compliance domain's model to a team that owes it nothing, which is the "Conformist by inertia" anti-pattern. | Yes |
| Graph Context → Compliance Intelligence | **Customer/Supplier** | Compliance queries entity relationship data for gap analysis (e.g., which data assets are linked to PII entities without a classification). Graph Context has obligation to Compliance as the single structured consumer of entity graph queries. Consumer-Driven Contract: Compliance specifies the graph query shapes it uses; Graph Context's CI runs the contract. | Yes |
| Graph Context → Classification Engine | **Customer/Supplier** | Classification Engine uses entity relationship data to enrich classification context (a `DataAsset` linked to a PII entity gets a higher initial sensitivity score). Graph Context is upstream; Classification Engine is a single structured downstream consumer. | Yes |
| Classification Engine ↔ Future Billing BC | **Separate Ways** | Usage metering for billing can be derived from Redpanda consumer-group offsets and Prometheus metrics — no direct integration between Classification Engine and any billing service is warranted. Validated via Event Storming: no `DataAssetClassified` event carries information that a billing domain would need to process directly; billing metrics are observability-derived, not integration-derived. **Exit condition**: if the billing model changes to require per-classification pricing data that cannot be derived from metrics, re-evaluate this decision. | No |

---

## What Is Absent From This Map — and Why

**No Shared Kernel**: The platform has a single engineering team (one PM, one agent engineer). All
three BCs are independently deployable but share the same codebase and deployment pipeline.
Shared Kernel governance (two-owner approval, joint release) has no practical benefit in this
organizational structure; it adds process overhead with no corresponding risk reduction. The
`DataAssetID` and `TenantID` canonical types are shared only via the Published Language schema,
not as shared Go types, so each BC keeps its own copy of those type aliases and validates them
at the event boundary.

**No Partnership**: No relationship exists where neither BC can be clearly upstream. The dependency
graph is acyclic. If future work creates a cycle (e.g., Classification Engine feeding results back
to Storage Integration's next-run prioritization), that would be the signal to consider Partnership
as a transitional state while the dependency is refactored into a unidirectional shape.

**No Conformist**: Every external integration is behind an ACL (vendor APIs cannot be negotiated
with); every internal integration is Customer/Supplier (internal teams have and honor obligations).
No integration exists where an internal upstream is truly non-cooperative, and no upstream model
is coherent enough in the downstream's domain sense to make Conformist acceptable. This is the
correctly rare use of Conformist — it should appear on a Context Map only when the upstream is
genuinely non-negotiable *and* the upstream model passes the Ubiquitous Language collision check.

---

## Implementation Inventory

### ACL Packages

```
internal/acl/
├── ports/
│   └── storage_source_port.go      # type StorageSourcePort interface
├── adapters/
│   ├── googledrive/
│   │   └── client.go               # Google Drive API client (upstream)
│   └── s3/
│       └── client.go               # AWS S3 client (upstream)
└── translators/
    ├── googledrive_translator.go   # drive.File → DataAssetCandidate
    └── s3_translator.go            # s3.Object → DataAssetCandidate
```

### Published Language Schema Registry

```
schemas/
└── events/
    ├── data-asset-discovered/
    │   ├── v1.json                 # JSON Schema for DataAssetDiscovered v1
    │   └── v2.json                 # Additive: added mediaType field (minor bump)
    └── data-asset-classified/
        └── v1.json                 # JSON Schema for DataAssetClassified v1
```

### Consumer-Driven Contracts

```
tests/
└── contracts/
    ├── compliance-consumes-classification.json     # Compliance → Classification CDC
    ├── classification-consumes-graph-entities.json # Classification → Graph CDC
    └── compliance-consumes-graph-entities.json     # Compliance → Graph CDC
```

Each contract file is committed by the consumer team. The supplier's CI pipeline runs
`pact-provider-verifier` (or schema-based equivalent) against all contracts for that supplier
before any deployment proceeds.

### OHS OpenAPI Specification

```
openapi/
└── storage-integration/
    └── v1/
        └── openapi.yaml            # Classification Engine and future consumers use this spec
```

---

## Quality Criteria for This Context Map

| Criterion | Status | Evidence |
|---|---|---|
| Every relationship carries exactly one pattern | Pass | Six relationships, six patterns, none unnamed |
| Each ACL covers every external vendor integration | Pass | Google Drive and S3 both behind ACL |
| No Conformist for internal negotiable teams | Pass | All internal relationships are Customer/Supplier |
| Consumer-Driven Contracts for all C/S and OHS relationships | Pass | 3 C/S contracts + OHS consumer contracts |
| Shared Kernel enumerated (or explicitly absent) | Pass | Explicitly absent; rationale stated |
| Temporary patterns time-boxed | Pass | No Partnership or dual-schema state is open-ended |
| Separate Ways validated by Event Storming | Pass | Billing separation validated (no shared event flows) |
| Every pattern selection names an alternative considered | Pass | Each rationale includes at least one rejected alternative |

---

## Evolving This Context Map

### When a New Consumer Appears for Classification Engine

If a third service (e.g., an Audit Dashboard) needs to consume `DataAssetClassified` events:
- The relationship remains Customer/Supplier if three or fewer total consumers
- At the fourth consumer, evaluate escalating Classification Engine's output interface to OHS +
  Published Language (consistent with the Storage Integration decision)
- The Consumer-Driven Contract for the new consumer is added by that team before their service
  goes to production

### When the Billing BC Becomes Real

If a billing system is introduced that needs per-asset classification counts:
- Re-run the pattern selection guide from Step 1
- If billing derives counts from metrics (Prometheus) — Separate Ways holds
- If billing needs the actual `DataAssetClassified` event stream — the relationship becomes
  Customer/Supplier or OHS depending on consumer count; the Separate Ways decision is superseded
  by an ADR documenting the change in rationale

### When a Legacy System Must Be Integrated

If a client's existing data catalog must be integrated:
- Name it Big Ball of Mud on the Context Map if it has no clear API or owner
- Build a single ACL as the entry point — never integrate new BCs directly with the legacy system
- Plan Strangler Fig extraction: which capabilities will be extracted, in what order, on what
  timeline, into which BC — see `subdomain-distillation`'s legacy transformation guidance
