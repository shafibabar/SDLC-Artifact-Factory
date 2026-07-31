# Runtime Topology, Technology Annotation, and the Container Diagram Template

This reference gives the technology-annotation conventions, the full artifact template, and a
**fully worked, deployment-free** Container Diagram for this repo's system. Everything here is a
**component-and-connector (C&C) view** — runtime containers and their communication. It contains
**no** node/pod/replica/region placement; that lives in the deployment (allocation) view, and this
reference ends with a pointer to where. See `viewtype-distinction.md` for why the separation is a
correctness rule, and `c4-container-notation.md` for the notation.

---

## Technology-annotation conventions

Every container is labelled with the concrete technology from `sdlc-config.json` (or the agreed
defaults when a product has not overridden them). Use the canonical spellings:

| Container role | Canonical annotation |
|---|---|
| Synchronous API / command handler | `Go, net/http + chi` |
| Background / event worker | `Go, franz-go consumer` |
| Relational state store | `PostgreSQL 16, pgx` |
| Graph / lineage store | `Apache AGE (PostgreSQL ext.)` |
| Message broker | `Redpanda (Kafka API)` |
| Front-end shell / micro-frontend | `React 18, TypeScript` |
| Object / evidence store | `S3-compatible object store` |
| Edge / gateway | `Go, chi (routing, auth, rate-limit)` |

Rules:
- **From the agreed stack only.** A label naming a technology never agreed silently overrides
  `sdlc-config.json`. Any deviation requires an ADR (`adr-authoring`) *before* it appears here.
- **One technology per container.** If a box needs two technology labels, it is probably two
  containers.
- **Observability is cross-cutting, not a container.** OpenTelemetry / Prometheus / Tempo / Grafana
  instrument every Go container; note them once in the diagram key, do not draw a per-service arrow
  to a "metrics" box unless the collector is genuinely a container in the topology.

## The Container Diagram artifact template

```markdown
---
name: container-diagram
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: enterprise-architect
---

# Container Diagram: [Product Name]

> View type: **Component-and-Connector (C&C)** — runtime containers and their communication.
> Deployment placement (nodes, pods, replicas, tenant stamps) lives in the deployment view: [link].

## Primary Presentation
[Mermaid C4 or textual C4 diagram — pure C&C, no placement]

## Containers (Element Catalog)
| Container | Type | Technology | Bounded Context | Responsibility |
|---|---|---|---|---|

## Communication Matrix (Connectors — pure C&C)
| From | To | Protocol | Data / Event | Sync / Async |
|---|---|---|---|---|

## Bounded Context → Container Mapping
| Bounded Context | API Container | Database | Worker | Topics |
|---|---|---|---|---|

## Rationale (view-shape)
[Why this decomposition of containers and this set of connectors — 2-3 sentences.
 Not an ADR; this explains why *this diagram* looks the way it does.]

## Mapping to Deployment View
[Pointer: each container above is allocated to nodes/pods in deployment-diagram: [link].
 Placement, replica counts, per-tenant stamps are documented there, not here.]
```

## Worked example — Data Estate Mapping & Compliance Intelligence (pure C&C)

Three Bounded Contexts — **DataAsset Management**, **Compliance**, **Reporting** — each an API +
its own Postgres, communicating cross-context asynchronously over Redpanda, fronted by a React shell
through a gateway. This is a *pure* C&C view: no pods, nodes, replicas, ports, or tenant stamps.

### Mermaid (C4-style, C&C)

```mermaid
flowchart TB
    officer([Compliance Officer<br/>person])
    ciso([CISO<br/>person])

    subgraph SYS[Data Estate Mapping & Compliance Intelligence]
        shell["Web Shell<br/>[React 18, TypeScript]<br/>Dashboards & assessment UI"]
        gw["API Gateway<br/>[Go, chi]<br/>Routing, auth, rate-limit"]

        daAPI["DataAsset API<br/>[Go, chi]<br/>Asset discovery & classification"]
        daDB[("dataasset_db<br/>[PostgreSQL 16, pgx]")]
        daWorker["DataAsset Worker<br/>[Go, franz-go]<br/>Scans Drive/S3 sources"]

        compAPI["Compliance API<br/>[Go, chi]<br/>Controls & assessments"]
        compDB[("compliance_db<br/>[PostgreSQL 16, pgx]")]
        compWorker["Compliance Worker<br/>[Go, franz-go]<br/>Reacts to asset events"]

        repAPI["Reporting API<br/>[Go, chi]<br/>Read models & exports"]
        repDB[("reporting_db<br/>[PostgreSQL 16, pgx]")]

        graph[("Lineage Graph<br/>[Apache AGE]")]
        broker[("Redpanda<br/>[Kafka API]")]
    end

    gdrive([Google Drive API<br/>external])
    s3([AWS S3 API<br/>external])
    idp([Identity Provider<br/>external])

    officer -->|HTTPS| shell
    ciso -->|HTTPS| shell
    shell -->|HTTP/JSON| gw
    gw -->|HTTP/JSON| daAPI
    gw -->|HTTP/JSON| compAPI
    gw -->|HTTP/JSON| repAPI
    gw -.->|OIDC| idp

    daAPI -->|SQL/pgx| daDB
    compAPI -->|SQL/pgx| compDB
    repAPI -->|SQL/pgx| repDB
    daAPI -->|Cypher/AGE| graph

    daWorker -.->|HTTPS/OAuth2| gdrive
    daWorker -.->|S3 API| s3

    daAPI -.->|"publish: dataasset.discovered"| broker
    broker -.->|"subscribe: dataasset.discovered"| compWorker
    broker -.->|"subscribe: dataasset.discovered"| daWorker
    compAPI -.->|"publish: assessment.completed"| broker
    broker -.->|"subscribe: assessment.completed"| repAPI
```

### Communication Matrix (pure C&C)

| From | To | Protocol | Data / Event | Sync/Async |
|---|---|---|---|---|
| Compliance Officer | Web Shell | HTTPS | UI interaction | Sync |
| Web Shell | API Gateway | HTTP/JSON | user requests | Sync |
| API Gateway | DataAsset API | HTTP/JSON | asset commands/queries | Sync |
| API Gateway | Identity Provider | OIDC | token validation | Sync |
| DataAsset API | dataasset_db | SQL/pgx | aggregate + outbox rows | Sync |
| DataAsset API | Lineage Graph | Cypher/AGE | lineage upserts/queries | Sync |
| DataAsset Worker | Google Drive API | HTTPS/OAuth2 | file & ACL scan | Sync |
| DataAsset Worker | AWS S3 API | S3 API | object & ACL scan | Sync |
| DataAsset API | Redpanda | Kafka/Redpanda | dataasset.discovered | Async |
| Compliance Worker | Redpanda | Kafka/Redpanda | dataasset.discovered (sub) | Async |
| Compliance API | Redpanda | Kafka/Redpanda | assessment.completed | Async |
| Reporting API | Redpanda | Kafka/Redpanda | assessment.completed (sub) | Async |

### Bounded Context → Container Mapping

| Bounded Context | API Container | Database | Worker | Topics |
|---|---|---|---|---|
| DataAsset Management | DataAsset API | dataasset_db (+ AGE) | DataAsset Worker | dataasset.* |
| Compliance | Compliance API | compliance_db | Compliance Worker | assessment.* |
| Reporting | Reporting API | reporting_db | — (read-side only) | (subscribes) |

### Rationale (view-shape)

DataAsset Management owns the graph store because lineage is intrinsic to its aggregate; Compliance
and Reporting never touch it directly, only reacting to its Domain Events — this keeps the
one-DB-per-service rule intact. Reporting is API-only (a read-side projection) because it holds no
write model of its own. The gateway carries auth and rate-limiting so no downstream service repeats
that concern.

## What is deliberately NOT on this diagram (and where it lives)

The following are **allocation (deployment) concerns** and are documented in the deployment view
(`deployment-diagram`, owned by `platform-engineer`), not here:

- **Physical multi-tenancy** — each tenant gets a physically isolated stamp (namespace + dedicated
  Postgres). That multiplies the *deployment* of every container per tenant; it does not change the
  logical C&C topology above (DataAsset API still calls its DB; Compliance still subscribes to
  `dataasset.discovered`). The per-tenant multiplication and its variability guide live in the
  deployment view.
- **Replica counts and autoscaling** — e.g. DataAsset Worker scaled on scan backlog.
- **Node pools, regions, availability zones** — data-residency placement per tenant/jurisdiction.
- **Helm releases, namespaces, ports/Services** — packaging and network binding.

The mapping between the two views: each container box above → one Deployment/StatefulSet in the
deployment view. Documented as a table there, so the C&C view stays a clean answer to "what talks
to what, and how."
