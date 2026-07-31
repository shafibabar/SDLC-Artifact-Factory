# C4 Level 2 (Container) Notation

The complete notation catalogue for a C4 Container Diagram as produced in this repo. Everything here
describes a **component-and-connector (C&C) view**: boxes are runtime containers, arrows are runtime
communication paths. Nothing in this notation encodes *where* a container runs — placement notation
belongs to the deployment (allocation) view, not here. See `viewtype-distinction.md`.

The five element/relation kinds on a Container Diagram are: the **container box**, the **synchronous
connector**, the **asynchronous connector**, the **system boundary**, and the **persons/external
systems** carried down from Level 1.

---

## 1. The container box

A container is an independently deployable/runnable unit that hosts code or stores state. Every
container box carries three things — and only these three:

```
┌─────────────────────────────┐
│  DataAsset API              │   ← 1. Name (the container's role, in Ubiquitous Language)
│  [Go, net/http + chi]       │   ← 2. Technology (the agreed stack, in brackets)
│  Handles asset-discovery    │   ← 3. Responsibility (one line, what it is for)
│  commands & queries         │
└─────────────────────────────┘
```

1. **Name** — the container's role, drawn from the domain's Ubiquitous Language (e.g. `Compliance
   API`, `DataAsset Worker`, `Reporting DB`). Not a generic "service".
2. **Technology** — the concrete stack, in brackets, from `sdlc-config.json` / the agreed defaults:
   `Go, net/http + chi`, `PostgreSQL 16, pgx`, `React 18, TypeScript`, `Redpanda (Kafka API)`,
   `Apache AGE (PostgreSQL ext.)`. A container with no technology label is an incomplete artifact.
3. **Responsibility** — one line describing what the container is for. Not its internal structure
   (that is L3), not where it runs (that is the deployment view).

### Container shape conventions used in this repo

| Element kind | Shape / label convention | Example |
|---|---|---|
| API / service (stateless) | Rounded box, technology in brackets | `DataAsset API [Go, chi]` |
| Background worker | Rounded box, note "consumes ..." | `DataAsset Worker [Go, franz-go]` |
| Relational datastore | Cylinder, `[PostgreSQL 16, pgx]` | `dataasset_db` |
| Graph datastore | Cylinder, `[Apache AGE]` | `lineage graph` |
| Message broker | Cylinder or box, `[Redpanda (Kafka API)]` | `Redpanda` |
| Front-end / SPA | Box, `[React 18, TypeScript]` | `Web Shell` |
| Object store | Cylinder, `[S3-compatible]` | `evidence-bucket` |

Ports, replica counts, node/pod placement, and namespace grouping are **not** container-box
properties on a C&C view — they are deployment-view properties.

## 2. Synchronous connector (solid arrow)

A synchronous connector is a runtime call where the caller waits for a response. Draw it as a
**solid arrow** from caller to callee, labelled with **protocol + payload**:

```
Web Shell ──HTTP/JSON──▶ API Gateway ──HTTP/JSON──▶ Compliance API
```

Label format: `<protocol>[/<format>]: <what flows>`, e.g.:
- `HTTP/JSON: submit assessment`
- `gRPC: GetAssetClassification`
- `SQL/pgx: read/write aggregate rows` (API → its own DB)

Direction of the arrow is the **direction of initiation** — who calls whom — not the direction of
data. A query that returns data still points from caller to callee.

Every synchronous cross-service call is a coupling point: it must carry an integration contract
(timeout, retry, circuit breaker) documented via `integration-design`. Keep synchronous chains
shallow — at most one hop past the gateway; deeper chains are the "distributed monolith"
anti-pattern.

## 3. Asynchronous connector (dashed arrow via the broker)

An asynchronous connector is a runtime interaction mediated by the message broker: a producer
publishes a Domain Event to a topic; consumers subscribe. Draw **two dashed arrows** — producer to
broker, broker to consumer — each labelled with the **topic and event**:

```
DataAsset API ┈┈publishes┈┈▶ Redpanda ┈┈subscribes┈┈▶ Compliance Worker
              (Kafka/Redpanda:                (Kafka/Redpanda:
               dataasset.discovered)           dataasset.discovered)
```

Label format: `Kafka/Redpanda: <topic>` plus the event name, e.g.
`Kafka/Redpanda: dataasset.discovered`. Cross-context topics carry **Published Language** schemas
only; a context's internal topics are private and are not consumed across boundaries (the
"broker as shared database" anti-pattern).

Async connectors are the default for cross-Bounded-Context communication in this repo: they decouple
producer and consumer lifecycles and remove the availability multiplication of synchronous chains.

## 4. The system boundary

A single labelled box (or dashed frame) encloses **everything that is a container of this system**.
The label is the system name (matching the System Context view). Its purpose:

- Everything *inside* is a container this team builds, deploys, and owns.
- Everything *outside* is a person or an external system.
- No container from a *different* system may appear inside the boundary.

```
┌── Data Estate Mapping & Compliance Intelligence ──────────────┐
│                                                               │
│   [ Web Shell ]  [ API Gateway ]  [ DataAsset API ] ...       │
│                                                               │
└───────────────────────────────────────────────────────────────┘
```

## 5. Persons and external systems — carried down from Level 1

The Container Diagram does not re-invent its external context; it **inherits** the persons and
external systems already fixed on the System Context (L1) diagram. They appear unchanged:

- **Person** — a human role interacting with the system (e.g. `Compliance Officer`, `CISO`). Drawn
  outside the boundary, with a solid arrow into the container they use (usually the front-end).
- **External system** — a system this team does not own (e.g. `Google Drive API`, `AWS S3 API`,
  `Identity Provider`). Drawn outside the boundary; the arrow names the protocol
  (`HTTPS/OAuth2`, `S3 API`).

**Consistency rule:** the set of persons and external systems on the Container Diagram must match
the System Context view exactly. A new external system appearing for the first time at L2 is a
defect — it means the L1 context was incomplete and must be corrected there first.

```
[Compliance Officer] ──uses──▶ (boundary) ... [DataAsset Worker] ──HTTPS/OAuth2──▶ [Google Drive API]
[CISO]                                          [DataAsset Worker] ──S3 API──▶       [AWS S3 API]
```

## Element catalog: the table the picture cannot carry

The primary presentation (the drawing) cannot show every property. Accompany it with an element
catalog — one row per container and one row per connector:

**Containers**

| Container | Type | Technology | Bounded Context | Responsibility |
|---|---|---|---|---|
| DataAsset API | API service | Go, chi | DataAsset Management | Asset discovery commands/queries |
| DataAsset DB | Relational store | PostgreSQL 16, pgx | DataAsset Management | Aggregate + outbox + read-model tables |
| Redpanda | Broker | Redpanda (Kafka API) | (shared) | Domain Event transport |

**Connectors (Communication Matrix — pure C&C)**

| From | To | Protocol | Data / Event | Sync/Async |
|---|---|---|---|---|
| Web Shell | API Gateway | HTTP/JSON | user requests | Sync |
| DataAsset API | Redpanda | Kafka/Redpanda | dataasset.discovered | Async |
| Compliance Worker | Redpanda | Kafka/Redpanda | dataasset.discovered (subscribe) | Async |

Note there is **no "node" or "replica" column** — those are deployment-view (allocation) properties,
documented separately.

## Notation don'ts (all are C&C-view violations)

- No node/pod/cluster boxes, no replica counts, no region labels — allocation view.
- No internal layers/packages of a container — that is the L3 Component diagram.
- No class or function boxes — that is L4 Code.
- No unlabelled arrows — every connector states protocol and sync/async.
- No aspirational technology — labels come from the agreed stack; deviations need an ADR first.
