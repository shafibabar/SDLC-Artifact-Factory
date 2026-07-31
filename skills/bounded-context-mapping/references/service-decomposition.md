# Service Decomposition
## How Bounded Context Boundaries Translate to Service Boundaries

Self-contained reference for the `bounded-context-mapping` skill. Use this after the Context Map
is agreed and BC definition artifacts are complete, to produce the service inventory for this
platform.

---

## The Default Rule: One BC → One Deployable Service

The default in this platform is **one Bounded Context equals one deployable microservice**.

This default derives from three reinforcing principles:

1. **Ubiquitous Language consistency** — a service embodies one language. Mixing two BCs into one
   service means the service codebase holds two vocabularies that do not agree on term meanings,
   which is the root cause of the "anemic domain model" anti-pattern at the service level.

2. **Independent deployability** — if a BC's capability must scale, deploy, or version
   independently, it needs its own deployment unit. One service per BC makes this possible by
   default without requiring up-front knowledge of *which* BCs will need independence later.

3. **Data ownership clarity** — each service owns its own PostgreSQL schema. No service reads
   or writes another service's database directly. This is an operational enforcement of the
   data-ownership discovery signal from `references/bc-discovery-guide.md`.

Newman (*Building Microservices*) articulates the same principle from the team-ownership angle:
size a service around what one team can own end-to-end. Since team ownership is one of the four
BC discovery signals, a correctly-drawn BC already respects this constraint.

---

## Service Boundary Checklist

Before finalising that a BC becomes a standalone service, confirm all of:

| Check | Pass condition |
|---|---|
| BC has a name from the Ubiquitous Language | The service name matches the BC name (e.g., `dataasset-management`, not `asset-svc`) |
| BC has at least one owned Aggregate | A service with no owned Aggregates is a pure consumer — may not need its own service |
| BC has a distinct deployment or scaling need | OR is a Core subdomain — Core subdomains always get their own service |
| BC has at least one owned Domain Event | A service with no emitted events can be a module inside its consumer's service |
| Team ownership is clear | One team (or one agent in this platform) owns this service end to end |

If a candidate BC fails more than one check, consider whether it should be a module inside
a larger service rather than a standalone deployment unit.

---

## Service Inventory for the Data Estate Platform

The following service inventory derives directly from the Context Map in
`references/context-map-template.md`.

| Service name | BC name | Classification | Owns | Exposed interface |
|---|---|---|---|---|
| `dataasset-management` | DataAsset Management | Core | DataAsset, StorageSource, ExtractionJob | OHS/PL: Redpanda topics; REST API for ingestion triggers |
| `compliance-intelligence` | Compliance Intelligence | Core | ComplianceGap, AuditRecord, ClassificationRule | OHS/PL: Redpanda topics; REST API for gap queries |
| `graph-context` | Graph Context | Supporting | EntityRelationship, KnowledgeGraph | OHS/PL: Redpanda topics; GraphQL API |
| `reporting` | Reporting | Supporting | ReportDefinition | REST API for report generation; no events emitted |
| `identity-access` | Identity & Access | Supporting (buy/build) | Tenant, User | REST API; OHS/PL for user events |

Each row in this table corresponds to one deployable Helm chart, one PostgreSQL schema, one
Redpanda consumer group prefix, and one GitHub repository (or top-level module in a monorepo).

---

## When to Merge Two BCs Into One Service

Merging two distinct BCs into a single deployable service is a deployment decision, not a
domain-model decision. The domain model — the Ubiquitous Language, the Aggregate boundaries,
the Context Map patterns — does not change when two BCs share a service. The translation layer
that would normally be a network call becomes an in-process call, but the model boundary still
exists as a package/module boundary inside the service.

**Valid reasons to merge two BCs into one service:**

| Reason | When it applies |
|---|---|
| Operational immaturity | The team cannot yet operate N independent services; start with merged services and extract later as operational capability grows |
| Both BCs are in the same Supporting/Generic classification with minimal domain-model complexity | The overhead of service coordination exceeds the benefit of independence |
| The two BCs are accessed synchronously at every operation, with no latency tolerance between them | Merging eliminates the network call; but first verify the sync coupling is not a model-design smell |
| Team is small and cannot own N separate on-call rotations | Conway's Law applies: team size constrains service count, not the other way around |

**When merging, preserve the internal model boundary as a Go package boundary:**

```
services/
  compliance-core/          ← merged service: Compliance Intelligence + Graph Context
    internal/
      complianceintelligence/   ← ComplianceGap, AuditRecord model — one language
        domain/
        ports/
        application/
      graphcontext/             ← EntityRelationship, KnowledgeGraph model — different language
        domain/
        ports/
        application/
      infrastructure/           ← shared database, shared Redpanda setup
    cmd/
      server/
        main.go
```

The two domain packages never import each other. If `complianceintelligence` needs data from
`graphcontext`, it goes through an in-process port/adapter, not a direct import. This preserves
the ability to extract `graphcontext` into its own service later without changing the domain
model.

---

## When to Split One BC Across Multiple Services

Splitting a single BC across more than one deployable service is a rare, justified exception.
It applies when one BC has two distinct scaling or deployment profiles that cannot coexist.

**Valid reasons to split one BC across services:**

| Reason | Example |
|---|---|
| Ingestion and query have radically different scaling characteristics | DataAsset ingestion (burst, I/O-bound, horizontal) vs. DataAsset queries (steady, CPU-bound for classification) — same BC, different scaling profiles |
| Security or compliance isolation | A portion of the BC handles regulated data subject to stricter network isolation or audit requirements |
| A long-running background process vs. a synchronous API | ExtractionJob processing (long-running, async, high-CPU) vs. DataAsset registration (synchronous, low-latency) |

**Constraint:** when splitting a BC across services, one service must be designated the
**write authority** for the BC's Aggregates. The other service(s) are readers or workers —
they do not write to the authoritative Aggregate table. No split may result in two services
both writing to the same Aggregate's master record.

```
dataasset-management-api/     ← handles registration, classification commands
  internal/
    domain/                   ← the authoritative DataAsset domain model
    infrastructure/
      postgres/               ← writes to dataasset schema
      outbox/                 ← publishes events

dataasset-management-worker/  ← handles ExtractionJob processing
  internal/
    domain/                   ← only ExtractionJob model; DataAsset accessed read-only
    infrastructure/
      postgres/               ← writes to extraction_jobs table only
                              ← reads DataAsset via Read Model, not via direct write table
```

---

## Service Naming Conventions

Services in this platform follow these naming rules derived from BC naming:

| Rule | Example |
|---|---|
| Service name = BC name, lower-kebab-case | "DataAsset Management" → `dataasset-management` |
| No generic suffixes (`-service`, `-svc`, `-api`) unless the BC name itself is a noun that would be ambiguous without a qualifier | "Reporting" → `reporting` (not `reporting-service`); only add `-api` if the same BC also has a `-worker` |
| Helm chart name matches service name | chart: `dataasset-management`, image: `org/dataasset-management:tag` |
| PostgreSQL schema name matches service name, underscore-separated | schema: `dataasset_management` |
| Redpanda topic prefix matches service name | topic: `dataasset-management.dataasset.classified.v1` |
| Go module path encodes the service name | `github.com/org/product/services/dataasset-management` |

---

## Service Decomposition Anti-Patterns

### "One Service Per Aggregate"
Aggregates are a transactional-consistency mechanism *within* a Bounded Context. Creating a
separate service per Aggregate produces a distributed system where every use case requires
orchestrating multiple services — the distributed monolith pattern. A BC with three Aggregates
should normally be one service whose domain layer contains three Aggregate types.

### "Database-Per-Table Service"
Deriving service boundaries from table names rather than BC names produces services without
a coherent Ubiquitous Language. "UserTable service," "AssetTable service," and "AuditTable
service" do not correspond to any bounded language — they are an accidental decomposition of
the database schema, not a deliberate decomposition of the domain model.

### "Shared Database Across Services"
Two services that both write to the same PostgreSQL schema or table are not independently
deployable, regardless of whether they have separate deployable units. The shared schema is a
de-facto shared model — an unnamed, unmanaged Shared Kernel whose schema becomes a migration
risk for every team. Enforce one schema per service by convention and by code review.

### "Nano-Service Per Use Case"
Splitting a service for every application-level use case (one service for "classify a DataAsset,"
one for "ingest from S3," one for "query DataAssets") collapses the BC model entirely — each
use case gets its own deployment unit, its own network boundary, and its own failure mode, with
no language boundary justifying any of the splits. The result is a fine-grained RPC mesh that
is operationally indistinguishable from a monolith in terms of coupling, but with all the
operational overhead of microservices.
