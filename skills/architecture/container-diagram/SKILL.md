---
name: container-diagram
description: >
  Teaches how to produce a C4 Level 2 Container Diagram — showing the deployable
  units (services, databases, message brokers, frontends) that make up the system,
  how they communicate, and which technology each uses. The Container Diagram is
  the primary input to service decomposition decisions and the blueprint that
  backend-engineer, frontend-engineer, data-architect, and platform-engineer
  work from. Used by the enterprise-architect agent after the System Context
  Diagram is approved.
version: 1.0.0
phase: design
owner: enterprise-architect
tags: [design, architecture, c4, container-diagram, service-decomposition, microservices]
---

# Container Diagram

## Purpose

The Container Diagram (C4 Level 2) zooms into the system and shows the high-level technical building blocks — the **containers**. A container is anything that must be separately deployed and run: a service, a database, a message broker, a frontend application, a background worker, a CLI tool.

The Container Diagram answers: **what are the independently deployable units of this system, what technology does each use, and how do they communicate?**

It is the most important architecture diagram for engineers: it establishes the service boundaries, the communication patterns, and the technology choices that all implementation work flows from.

---

## Container Types

| Container type | Examples |
|---|---|
| **Web application** | React + TypeScript SPA served as static assets |
| **API service** | Go service exposing HTTP endpoints (net/http + chi) |
| **Background worker** | Go service consuming from Redpanda, performing async processing |
| **Message broker** | Redpanda (Kafka-compatible) |
| **Relational database** | PostgreSQL (primary store per service) |
| **Document store** | MongoDB (variable-schema bounded contexts) |
| **Graph database** | Apache AGE (PostgreSQL extension) |
| **Search index** | Elasticsearch |
| **Cache** | Redis |
| **File store** | Object storage (S3-compatible) |
| **Identity provider** | External — shown as external system (from System Context) |

---

## Container Diagram Rules

### One database per service

Each service owns its own database. No two services share a database. Cross-service queries go through APIs or events — never through a shared database.

This is a hard rule. Shared databases create invisible coupling between services: one service's schema change breaks another service's queries without warning.

### Technology is explicit

Every container is labelled with its technology:
- API service: "Go, net/http + chi"
- Database: "PostgreSQL 16, pgx"
- Message broker: "Redpanda (Kafka-compatible)"
- Frontend: "React 18, TypeScript"

Technology labels make the diagram actionable for engineers. A diagram that says "service" without a technology is incomplete.

### Communication protocols are labelled

Every arrow between containers is labelled with:
- What flows (events, HTTP request, query result)
- The protocol (HTTP/JSON, gRPC, Kafka topic, AMQP)
- The direction of initiation

### Bounded Context → Container mapping

Each Bounded Context from the domain model maps to one or more containers. The mapping must be documented:
- Most Bounded Contexts map to: one API service + one database + (if async) event publishing to the message broker
- Some Bounded Contexts may share infrastructure (e.g., the same Redpanda cluster) while having separate logical topics

---

## Standard Container Set (Default Stack)

For each service that owns a Bounded Context, the default container set is:

```
┌─────────────────────────────────────────────────────────────────┐
│ [Bounded Context Name] Service                                  │
│                                                                 │
│  ┌──────────────────┐     ┌───────────────────────────────┐    │
│  │  [Name] API      │────▶│  PostgreSQL                   │    │
│  │  Go, chi         │     │  [name]_db                    │    │
│  │  Port: 8080      │     │  Aggregate tables             │    │
│  └──────────────────┘     │  Outbox table                 │    │
│           │               │  Read model tables            │    │
│           │ Publishes     └───────────────────────────────┘    │
│           ▼ events                                              │
│  ┌──────────────────┐                                          │
│  │  Redpanda        │  (shared cluster, dedicated topics)      │
│  │  Topic:          │                                          │
│  │  [bc-name].*     │                                          │
│  └──────────────────┘                                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Container Diagram Example (Data Estate Product)

```
┌─────────────────────────────────────────────────────────────────────┐
│ Data Estate Mapping & Compliance Intelligence                        │
│                                                                     │
│  [Compliance Officer]──────────────▶┌─────────────────────┐        │
│  [CISO]                             │  Web App             │        │
│                                     │  React 18+TypeScript │        │
│                                     │  Nginx / static      │        │
│                                     └──────────┬──────────┘        │
│                                                │ HTTPS/JSON         │
│  ┌──────────────────┐    ┌────────────────────▼──────────────┐     │
│  │  Storage         │    │  API Gateway / BFF                │     │
│  │  Integration     │    │  Go, chi — routing, auth, rate    │     │
│  │  Service         │    │  limiting, JWT validation         │     │
│  │  Go, chi         │◀───│                                   │     │
│  │  [Google Drive   │    └───────┬───────────┬──────────────┘     │
│  │   ACL, S3 ACL]   │           │ gRPC/HTTP  │                    │
│  └────────┬─────────┘           ▼            ▼                    │
│           │             ┌────────────┐ ┌──────────────┐           │
│           │             │ Classific- │ │ Compliance   │           │
│           │             │ ation Svc  │ │ Intelligence │           │
│           │ events      │ Go, chi    │ │ Svc Go, chi  │           │
│           │             │ PostgreSQL │ │ PostgreSQL   │           │
│           │             └────────────┘ └──────────────┘           │
│           │                    │               │                   │
│           └────────────────────▼───────────────▼                  │
│                          ┌───────────┐                             │
│                          │ Redpanda  │  Kafka-compatible           │
│                          │ Cluster   │  Topics per BC              │
│                          └───────────┘                             │
│                                │                                   │
│                          ┌─────▼──────┐                           │
│                          │ Graph Svc  │  Apache AGE                │
│                          │ Go, chi    │  (PostgreSQL ext.)         │
│                          └────────────┘                            │
└─────────────────────────────────────────────────────────────────────┘
         │                                      │
         ▼                                      ▼
 [Google Drive API]                        [AWS S3 API]
 (External)                                (External)
```

---

## Deciding Service Boundaries

Service boundaries follow Bounded Context boundaries from the domain model, subject to these additional constraints:

| Constraint | Effect on boundaries |
|---|---|
| Physical multi-tenancy | Tenant isolation may require separate deployment per tenant — the container boundary stays, but the deployment multiplies |
| Data residency NFR | Data that must not leave a jurisdiction may require a separate service boundary to enforce the constraint at the network level |
| Independent scaling | A container that must scale independently (e.g., the scanning worker) must be its own service — it cannot share a process with a request-response API |
| Team ownership | If different teams own different capabilities, those capabilities are in different containers — shared containers create coordination overhead |
| Change rate | A container that changes frequently should not be coupled to one that is stable — independent deployment requires independent containers |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Technology labelled | Every container states its technology | Containers labelled only with a name |
| One DB per service | No shared databases between services | Two services with the same database |
| Protocol labelled | Every inter-container arrow has a protocol label | Unlabelled arrows |
| BC → container map | Every Bounded Context maps to at least one container | Containers with no domain model origin |
| External systems consistent | External systems match the System Context Diagram | New external systems appearing for the first time |
| Bounded by the system | All containers shown are inside the system boundary | Containers from other systems inside the box |

---

## Output Format

```markdown
---
artifact: container-diagram
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: enterprise-architect
---

# Container Diagram: [Product Name]

## Diagram
[ASCII diagram]

## Containers

| Container | Type | Technology | Bounded Context | Port / Topic |
|---|---|---|---|---|

## Communication Matrix
| From | To | Protocol | Data / Event | Sync / Async |
|---|---|---|---|---|

## Bounded Context → Container Mapping
| Bounded Context | API Container | Database | Worker | Topics |
|---|---|---|---|---|

## Service Boundary Decisions
[For each non-obvious boundary: why this is a separate container, referencing the constraint that justifies it]
```
