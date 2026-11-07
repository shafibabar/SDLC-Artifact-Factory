# Example 3 — Enterprise: Regions and Stamps in the Deployment View Only

Self-contained. **Cargoline** books and tracks ocean freight for about 40 shipping customers in the EU and the US: shippers book and track shipments, operations agents clear holds, customers' transport management systems (TMS) send bookings by API, a vessel position feed streams positions, and customs declarations go to the customs authority. **Enterprise** profile. The approved system context diagram has persons **Shipper** and **Operations Agent**, and external systems **Shipper TMS**, **Vessel Position Feed** and **Customs Authority**. The Context Map has **Bookings**, **Invoicing**, **Tracking** and **Customs Documents**. `multi-tenancy-design` chose: **one pooled stamp per region** (EU data stays in the EU), plus **dedicated stamps for two customers** whose contracts require isolation, each in its home region.

## Input

> **User:** "Put the EU and US copies and the two dedicated stamps on the container diagram, with '×40 customers' on the APIs so the board sees the scale. And run one Kafka cluster shared by all regions so every event is available everywhere."

## Working it

- **Decomposition:**
  - **Bookings + Invoicing together.** Integrator: a booking's rate lock and its invoice line commit in one transaction.
  - **Tracking alone.** Disintegrator: throughput. The position stream bursts to tens of thousands of messages a minute; it runs as an API and an ingest worker of one deployable.
  - **Customs Documents alone.** Disintegrators: fault tolerance (customs authority outages must not block bookings) and security (regulated declarations).
- **Declined:**
  - *Regions, stamps and "×40" on the picture:* they change where things run, not what talks to what, so they belong in the deployment view.
  - *One global broker:* multi-tenancy-design keeps EU data in the EU, so every stamp has its own broker and databases. No event crosses a region.
- **Gateway:** one Edge Gateway is the north-south entry for both the web app and the customers' TMS. It enforces API keys and per-customer rate limits; services still verify identity.
- **Deployment view:** one stamp drawn once, with its mapping table. The variability guide lists the four stamps and what differs between them.

## Output: `artifacts/cargoline/design/architecture/container-diagram.md`

````markdown
---
name: container-diagram
product: cargoline
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-05-27
summary: Cargoline as three deployables behind one edge gateway, deployed as a stamp per region plus two dedicated customer stamps, each with its own broker and databases.
traces-to: [design/architecture/system-context.md, design/context-map.md, design/architecture/cqrs-decisions.md, ideate/nfr-specification.md, design/architecture/multi-tenancy-design.md]
---

# Container diagram for Cargoline

**Readers:** the engineers, platform-engineer, security-architect, the product owner and the board
**Question it answers:** what runnable units make up Cargoline, what technology each uses, how they talk, and where they run.

## Decomposition

- **Profile:** enterprise

| Deployable | Containers | Contexts | Forces |
|---|---|---|---|
| bookings | Bookings API, Bookings DB | Bookings, Invoicing | integrator: a booking's rate lock and its invoice line commit in one transaction |
| tracking | Tracking API, Tracking Ingest, Tracking DB | Tracking | disintegrator: throughput, position bursts of tens of thousands a minute |
| customs | Customs API, Customs DB | Customs Documents | disintegrators: fault tolerance (customs authority outages), security (regulated declarations) |
| edge | Web App, Edge Gateway, Event Broker | — | scope: the shared entry and event transport of a stamp; holds no context |

## Diagram

```
  +--------------------------------+      +--------------------------------+      +--------------------------------+
  | [Person]                       |      | [Person]                       |      | [External System]              |
  | Shipper                        |      | Operations Agent               |      | Shipper TMS                    |
  +--------------------------------+      +--------------------------------+      +--------------------------------+
                   | Books and tracks                      | Clears holds, fixes                   | Sends bookings to
                   | shipments in [HTTPS]                  | bookings in [HTTPS]                   | [HTTPS/JSON, API key]
                   +---------------------------------------+                                       |
                                                           v                                       |
  ================================================== Cargoline =====================================================
                                          +--------------------------------+                       |
                                          | [Container: Web App]           |                       |
                                          | Web App                        |                       |
                                          | React + TypeScript             |                       |
                                          | Shipper and agent screens      |                       |
                                          +--------------------------------+                       |
                                                           | Sends requests to                     |
                                                           | [HTTPS/JSON]                          |
                                                           +---------------------------------------+
                                                           v
                                          +--------------------------------+
                                          | [Container: Gateway]           |
                                          | Edge Gateway                   |
                                          | chosen in api-gateway-design   |
                                          | Routes, checks tokens, limits  |
                                          +--------------------------------+
                   +---------------------------------------+---------------------------------------+
                   | Routes bookings to                    | Routes tracking                       | Routes customs
                   | [HTTPS/JSON]                          | queries to [HTTPS/JSON]               | documents to [HTTPS/JSON]
                   v                                       v                                       v
  +--------------------------------+      +--------------------------------+      +--------------------------------+
  | [Container: API]               |      | [Container: API]               |      | [Container: API]               |
  | Bookings API                   |      | Tracking API                   |      | Customs API                    |--+
  | Go, net/http + chi             |      | Go, net/http + chi             |      | Go, net/http + chi             |  |
  | Bookings, rates, invoices      |      | Where each shipment is         |      | Customs declarations           |  |
  +--------------------------------+      +--------------------------------+      +--------------------------------+  |
                   | Reads and writes rows in              | Reads positions from                  | Reads and writes |ows in
                   | [SQL]                                 | [SQL]                                 | [SQL]            |
                   v                                       v                                       v                  |
  +--------------------------------+      +--------------------------------+      +--------------------------------+  |
  | [Container: Database]          |      | [Container: Database]          |      | [Container: Database]          |  |
  | Bookings DB                    |      | Tracking DB                    |      | Customs DB                     |  |
  | PostgreSQL, pgx                |      | PostgreSQL, pgx                |      | PostgreSQL, pgx                |  |
  +--------------------------------+      +--------------------------------+      +--------------------------------+  |
                                                           ^                                                          |
                                                           | Writes positions to [SQL]                                |
  +--------------------------------+      +--------------------------------+                                          |
  | [Container: Broker]            |      | [Container: Worker]            |                                          |
  | Event Broker                   |      | Tracking Ingest                |                                          |
  | Redpanda                       |      | Go                             |                                          |
  | Carries Domain Events          |      | Turns raw positions into       |                                          |
  |                                |      | shipment positions             |                                          |
  +--------------------------------+      +--------------------------------+                                          |
                                                                                                                      |
  - - - Each API publishes and consumes through the Event Broker [Kafka protocol];                                    |
  - - - who publishes and who consumes each topic: the Topics table.                                                  |
  ==================================================================================================================  |
                                                           ^                        Submits declarations to [HTTPS]   |
                                                           | Sends vessel positions to [HTTPS stream]         v-------+
                                          +--------------------------------+      +--------------------------------+
                                          | [External System]              |      | [External System]              |
                                          | Vessel Position Feed           |      | Customs Authority              |
                                          +--------------------------------+      +--------------------------------+
```

## Key

- `[Container: <type>]` a runnable or deployable unit of Cargoline; `[Person]` / `[External System]` from the system context diagram
- `|` then `v` (or `^`) synchronous call, the head at the callee; `- - -` asynchronous messages through the Event Broker, from the publisher; pairs in the Topics table
- Arrows point from the party that starts the exchange; labels say what flows, then the protocol.
- Clients and the Shipper TMS enter once, north-south, at the Edge Gateway; container-to-container calls run east-west over the mesh. Regions and stamps: Deployment View.

## Element Catalog

### Containers

| Container | Type | Technology | Deployable | Responsibility |
|---|---|---|---|---|
| Web App | Web App | React + TypeScript | edge | Shipper and agent screens |
| Edge Gateway | Gateway | chosen in api-gateway-design | edge | Routes, validates tokens and API keys, limits rates per customer |
| Bookings API | API | Go, net/http + chi | bookings | Bookings, rates, invoices |
| Bookings DB | Database | PostgreSQL, pgx | bookings | Bookings and invoices |
| Tracking API | API | Go, net/http + chi | tracking | Where each shipment is |
| Tracking Ingest | Worker | Go | tracking | Turns raw vessel positions into shipment positions |
| Tracking DB | Database | PostgreSQL, pgx | tracking | Shipment positions |
| Customs API | API | Go, net/http + chi | customs | Customs declarations |
| Customs DB | Database | PostgreSQL, pgx | customs | Declarations, encrypted at rest |
| Event Broker | Broker | Redpanda | edge | Carries Domain Events within a stamp |

### Persons and External Systems

| Name | Kind | Uses or used by |
|---|---|---|
| Shipper | Person | Web App |
| Operations Agent | Person | Web App |
| Shipper TMS | External System | Edge Gateway |
| Vessel Position Feed | External System | Tracking Ingest |
| Customs Authority | External System | Customs API |

### Communication Matrix

| From | To | What flows | Protocol | Sync/Async |
|---|---|---|---|---|
| Shipper | Web App | Books and tracks shipments in | HTTPS | sync |
| Operations Agent | Web App | Clears holds, fixes bookings in | HTTPS | sync |
| Shipper TMS | Edge Gateway | Sends bookings to | HTTPS/JSON, API key | sync |
| Web App | Edge Gateway | Sends requests to | HTTPS/JSON | sync |
| Edge Gateway | Bookings API | Routes bookings to | HTTPS/JSON | sync |
| Edge Gateway | Tracking API | Routes tracking queries to | HTTPS/JSON | sync |
| Edge Gateway | Customs API | Routes customs documents to | HTTPS/JSON | sync |
| Bookings API | Bookings DB | Reads and writes booking rows in | SQL | sync |
| Tracking API | Tracking DB | Reads positions from | SQL | sync |
| Tracking Ingest | Tracking DB | Writes positions to | SQL | sync |
| Customs API | Customs DB | Reads and writes declaration rows in | SQL | sync |
| Vessel Position Feed | Tracking Ingest | Sends vessel positions to | HTTPS stream | async |
| Customs API | Customs Authority | Submits declarations to | HTTPS | sync |
| Bookings API | Event Broker | Publishes `booking-confirmed` to | Kafka protocol | async |
| Tracking Ingest | Event Broker | Publishes `shipment-arrived` to | Kafka protocol | async |
| Customs API | Event Broker | Publishes `declaration-cleared` to | Kafka protocol | async |
| Event Broker | Tracking API | Delivers `booking-confirmed` to | Kafka protocol | async |
| Event Broker | Customs API | Delivers `booking-confirmed` and `shipment-arrived` to | Kafka protocol | async |
| Event Broker | Bookings API | Delivers `shipment-arrived` and `declaration-cleared` to | Kafka protocol | async |

### Topics

| Topic | Publisher | Consumers |
|---|---|---|
| booking-confirmed | Bookings API | Tracking API, Customs API |
| shipment-arrived | Tracking Ingest | Bookings API, Customs API |
| declaration-cleared | Customs API | Bookings API |

## Gateway

- **Gateway:** Edge Gateway, the one north-south entry for the web app and the customers' TMS
- **Holds:** routing, TLS, token and API-key validation, rate limits per customer; no business rules
- **Identity:** every API verifies the token or key itself; the gateway is the first check, not the only one
- **Planes:** north-south: clients and TMS → Edge Gateway; east-west: API to API and to the broker over the mesh (Linkerd, mutual TLS), never across regions
- **Configuration:** platform-engineer at Deploy (`api-gateway-design`)

## Rationale

Three deployables: tracking split for throughput, customs for fault and security isolation, bookings and invoicing kept together for their shared transaction. The container view is drawn once; regions and stamps change where it runs, not what talks to what, so they are in the deployment view. Each stamp is a complete copy with its own broker, so EU data never leaves the EU.

## Fitness Functions

| Rule | Automated check |
|---|---|
| No deployable reaches another's database | Database roles exist only in their own deployable's database |
| No event crosses a region | Broker configuration has no cross-region replication; a deployment check fails if one is added |
| One writer per topic | Broker ACLs give produce rights to the publisher only |

## Deployment View

- **Tenancy:** a pooled stamp per region (EU, US) plus dedicated stamps for two customers, as multi-tenancy-design chose

### Environment: production

```
Production — one stamp (every stamp has this shape)
+-- Region: <stamp's region> ----------------------------------------------+
|  [Infrastructure] DNS --> Load balancer --> Ingress                      |
|  +-- Kubernetes cluster -----------------------------------------------+ |
|  |  namespace: edge       Edge Gateway x3, Web App x2, Event Broker x3 | |
|  |  namespace: bookings   Bookings API x3                              | |
|  |  namespace: tracking   Tracking API x2, Tracking Ingest x4          | |
|  |  namespace: customs    Customs API x2                               | |
|  +---------------------------------------------------------------------+ |
|  [Managed PostgreSQL] Bookings DB, Tracking DB, Customs DB               |
|                       (separate instances, primary + standby in-region)  |
+--------------------------------------------------------------------------+
```

| Container | Deployment node | Instances | Notes |
|---|---|---|---|
| Web App | namespace edge | 2 | static files |
| Edge Gateway | namespace edge | 3 | API keys per customer |
| Event Broker | namespace edge | 3 | one per stamp, no cross-region replication |
| Bookings API | namespace bookings | 3 | |
| Bookings DB | managed PostgreSQL in the stamp's region | 1 + standby | |
| Tracking API | namespace tracking | 2 | |
| Tracking Ingest | namespace tracking | 4 | scales on stream lag |
| Tracking DB | managed PostgreSQL in the stamp's region | 1 + standby | partitioned by month |
| Customs API | namespace customs | 2 | stricter network policy |
| Customs DB | managed PostgreSQL in the stamp's region | 1 + standby | encrypted at rest, audit log on |

- **Variability:** four production stamps of this shape: EU pooled (EU customers), US pooled (US customers), EU dedicated for Halvorsen Lines, US dedicated for Baymark Freight. Dedicated stamps run half the instance counts. Customers are rows in a pooled stamp and a whole stamp when dedicated. Staging is one stamp in the EU at one instance each.

## Open Questions

- none
````

## Why this is right

- The container view is drawn once. Regions, stamps and counts appear only in the deployment view, so the board sees the scale in the variability guide without the picture lying about what talks to what.
- The tenancy is exactly what `multi-tenancy-design` chose; a broker per stamp follows from EU data staying in the EU, and the global broker request was declined with that reason.
- Every split names its force; bookings and invoicing stay together on a transaction integrator.
- `validate-container-diagram.sh` exits clean on the artifact.
