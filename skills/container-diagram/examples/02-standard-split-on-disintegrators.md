# Example 2 — Standard: Splitting on Named Forces

Self-contained. **Pawsbook** is a SaaS for veterinary practice groups: pet owners book visits, front-desk staff check animals in, vets record visit notes and prescriptions, and each practice bills owners by card. About 60 practice groups. **Standard** profile. The approved system context diagram has persons **Pet Owner**, **Front Desk** and **Vet**, and external systems **Postmark** and **Stripe**. The Context Map has four contexts: **Appointments**, **Reminders**, **Clinical Records** and **Billing**. `multi-tenancy-design` chose a **pooled** model: one deployment, every row scoped by practice group.

## Input

> **User:** "Four contexts, so four services. Put the loyalty discount rules in the gateway so every service gets them for free, and let Billing read the appointments database directly so invoices are quick. The gateway checks the login, so the services can trust the user header."

## Working it

- **Decomposition** with both checklists:
  - **Appointments + Reminders stay together.** Integrator: every booking change reschedules its reminders (chatty workflow). Reminders runs as a worker container of the same deployable.
  - **Clinical Records split off.** Disintegrator: security. Clinical notes and prescriptions are regulated records with stricter access and audit than bookings.
  - **Billing split off.** Disintegrators: fault tolerance, since a Stripe outage must not stop bookings, and code volatility, since pricing and loyalty rules change monthly. The integrator it overrides: an invoice needs visit details, which arrive by event.
  - Result: **three deployables** from four contexts.
- **Declined:**
  - *Discount rules in the gateway:* a gateway with business rules becomes an unowned service every context depends on; the rules live in Billing.
  - *Billing reading the appointments database:* that is a shared database; Billing keeps its own copy of what it needs from `appointment-booked` and `visit-recorded` events.
  - *Trusting the user header:* every service validates the token itself; the gateway is the first check, not the only one.
- **Broker:** one Redpanda; each topic's publisher and consumers in the Topics table, so the pairs stay readable.
- **Deployment view:** pooled tenancy, so one deployment; production and staging differ in shape (staging shares one database server), so both are drawn.

## Output: `artifacts/pawsbook/design/architecture/container-diagram.md`

````markdown
---
name: container-diagram
product: pawsbook
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-04-20
summary: Pawsbook as three deployables (appointments, clinical-records, billing) behind one edge gateway, with Redpanda topics and a pooled production deployment.
traces-to: [design/architecture/system-context.md, design/context-map.md, design/architecture/cqrs-decisions.md, ideate/nfr-specification.md, design/architecture/multi-tenancy-design.md]
---

# Container diagram for Pawsbook

**Readers:** the engineers, platform-engineer, security-architect, the product owner
**Question it answers:** what runnable units make up Pawsbook, what technology each uses, how they talk, and where they run.

## Decomposition

- **Profile:** standard

| Deployable | Containers | Contexts | Forces |
|---|---|---|---|
| appointments | Appointments API, Reminders Worker, Appointments DB | Appointments, Reminders | integrator: chatty workflow, every booking change reschedules reminders |
| clinical-records | Clinical Records API, Clinical Records DB | Clinical Records | disintegrator: security, regulated records with stricter access and audit |
| billing | Billing API, Billing DB | Billing | disintegrators: fault tolerance (Stripe outages), volatility (monthly pricing changes); overrides the data-relationship integrator by events |
| edge | Web App, Edge Gateway, Event Broker | — | scope: the shared entry and event transport for all three; holds no context |

## Diagram

```
  +--------------------------------+      +--------------------------------+      +--------------------------------+
  | [Person]                       |      | [Person]                       |      | [Person]                       |
  | Pet Owner                      |      | Front Desk                     |      | Vet                            |
  +--------------------------------+      +--------------------------------+      +--------------------------------+
                   | Books visits in [HTTPS]               | Books, checks in [HTTPS]              | Records visits in
                   |                                       |                                       |  [HTTPS]
                   v                                       v                                       v
  ================================================== Pawsbook ======================================================
                                          +--------------------------------+
                                          | [Container: Web App]           |
                                          | Web App                        |
                                          | React + TypeScript             |
                                          | All screens                    |
                                          +--------------------------------+
                                                           | Sends every request to
                                                           | [HTTPS/JSON]
                                                           v
                                          +--------------------------------+
                                          | [Container: Gateway]           |
                                          | Edge Gateway                   |
                                          | chosen in api-gateway-design   |
                                          | Routes, checks tokens, limits  |
                                          +--------------------------------+
                   +---------------------------------------+---------------------------------------+
                   | Routes bookings to                    | Routes visits to                      | Routes invoices to
                   | [HTTPS/JSON]                          | [HTTPS/JSON]                          | [HTTPS/JSON]
                   v                                       v                                       v
  +--------------------------------+      +--------------------------------+      +--------------------------------+
  | [Container: API]               |      | [Container: API]               |      | [Container: API]               |
  | Appointments API               |      | Clinical Records API           |      | Billing API                    |
  | Go, net/http + chi             |      | Go, net/http + chi             |      | Go, net/http + chi             |
  | Books and moves visits         |      | Visit notes, prescriptions     |      | Invoices and payments          |
  +--------------------------------+      +--------------------------------+      +--------------------------------+
                   | Reads and writes rows in              | Reads and writes rows in              | Reads and writes rows in
                   | [SQL]                                 | [SQL]                                 | [SQL]
                   v                                       v                                       v
  +--------------------------------+      +--------------------------------+      +--------------------------------+
  | [Container: Database]          |      | [Container: Database]          |      | [Container: Database]          |
  | Appointments DB                |      | Clinical Records DB            |      | Billing DB                     |
  | PostgreSQL, pgx                |      | PostgreSQL, pgx                |      | PostgreSQL, pgx                |
  +--------------------------------+      +--------------------------------+      +--------------------------------+

  - - - Each API publishes its events to the Event Broker and consumes others' [Kafka protocol]; - - -
  - - - who publishes and who consumes each topic: the Topics table.                              - - -

  +--------------------------------+      +--------------------------------+
  | [Container: Worker]            |      | [Container: Broker]            |
  | Reminders Worker               |      | Event Broker                   |
  | Go                             |      | Redpanda                       |
  | Sends visit reminders          |      | Carries Domain Events          |
  +--------------------------------+      +--------------------------------+
  ==================================================================================================================
                   | Sends reminders to                                                            | Takes card payments in
                   | [HTTPS]                                                                       | [HTTPS] (from Billing API)
                   v                                                                               v
  +--------------------------------+                                              +--------------------------------+
  | [External System]              |                                              | [External System]              |
  | Postmark                       |                                              | Stripe                         |
  +--------------------------------+                                              +--------------------------------+
```

## Key

- `[Container: <type>]` a runnable or deployable unit of Pawsbook; `[Person]` / `[External System]` from the system context diagram
- `|` then `v` synchronous call, from the caller; `- - -` asynchronous messages through the Event Broker, from the publisher; pairs in the Topics table
- Arrows point from the party that starts the exchange; labels say what flows, then the protocol.
- Clients enter once, north-south, at the Edge Gateway; container-to-container calls run east-west over the mesh. Where things run: Deployment View.

## Element Catalog

### Containers

| Container | Type | Technology | Deployable | Responsibility |
|---|---|---|---|---|
| Web App | Web App | React + TypeScript | edge | All screens |
| Edge Gateway | Gateway | chosen in api-gateway-design | edge | Routes, validates tokens, limits rates |
| Appointments API | API | Go, net/http + chi | appointments | Books and moves visits |
| Reminders Worker | Worker | Go | appointments | Sends visit reminders |
| Appointments DB | Database | PostgreSQL, pgx | appointments | Appointments and reminder schedule |
| Clinical Records API | API | Go, net/http + chi | clinical-records | Visit notes and prescriptions |
| Clinical Records DB | Database | PostgreSQL, pgx | clinical-records | Clinical records, encrypted at rest |
| Billing API | API | Go, net/http + chi | billing | Invoices, loyalty discounts, payments |
| Billing DB | Database | PostgreSQL, pgx | billing | Invoices and the visit copies it needs |
| Event Broker | Broker | Redpanda | edge | Carries Domain Events |

### Persons and External Systems

| Name | Kind | Uses or used by |
|---|---|---|
| Pet Owner | Person | Web App |
| Front Desk | Person | Web App |
| Vet | Person | Web App |
| Postmark | External System | Reminders Worker |
| Stripe | External System | Billing API |

### Communication Matrix

| From | To | What flows | Protocol | Sync/Async |
|---|---|---|---|---|
| Pet Owner | Web App | Books visits in | HTTPS | sync |
| Front Desk | Web App | Books and checks in animals in | HTTPS | sync |
| Vet | Web App | Records visits in | HTTPS | sync |
| Web App | Edge Gateway | Sends every request to | HTTPS/JSON | sync |
| Edge Gateway | Appointments API | Routes bookings to | HTTPS/JSON | sync |
| Edge Gateway | Clinical Records API | Routes visits to | HTTPS/JSON | sync |
| Edge Gateway | Billing API | Routes invoices to | HTTPS/JSON | sync |
| Appointments API | Appointments DB | Reads and writes appointment rows in | SQL | sync |
| Reminders Worker | Appointments DB | Reads the reminder schedule from | SQL | sync |
| Clinical Records API | Clinical Records DB | Reads and writes clinical rows in | SQL | sync |
| Billing API | Billing DB | Reads and writes invoice rows in | SQL | sync |
| Appointments API | Event Broker | Publishes `appointment-booked` to | Kafka protocol | async |
| Clinical Records API | Event Broker | Publishes `visit-recorded` to | Kafka protocol | async |
| Billing API | Event Broker | Publishes `invoice-paid` to | Kafka protocol | async |
| Event Broker | Reminders Worker | Delivers `appointment-booked` to | Kafka protocol | async |
| Event Broker | Billing API | Delivers `appointment-booked` and `visit-recorded` to | Kafka protocol | async |
| Event Broker | Appointments API | Delivers `invoice-paid` to | Kafka protocol | async |
| Reminders Worker | Postmark | Sends reminders to | HTTPS | sync |
| Billing API | Stripe | Takes card payments in | HTTPS | sync |

### Topics

| Topic | Publisher | Consumers |
|---|---|---|
| appointment-booked | Appointments API | Reminders Worker, Billing API |
| visit-recorded | Clinical Records API | Billing API |
| invoice-paid | Billing API | Appointments API |

## Gateway

- **Gateway:** Edge Gateway, the one north-south entry
- **Holds:** routing, TLS, token validation, rate limits per practice group; no business rules (loyalty discounts live in Billing)
- **Identity:** every API verifies the token itself; the gateway's user header is never trusted on its own
- **Planes:** north-south: clients → Edge Gateway; east-west: API to API and API to broker over the mesh (Linkerd, mutual TLS)
- **Configuration:** platform-engineer at Deploy (`api-gateway-design`)

## Rationale

Three deployables because two disintegrators have evidence (regulated clinical records; Stripe outages and monthly pricing changes) and the Reminders workflow is too chatty to split from Appointments. Billing keeps copies of visit details from events, so no deployable reaches another's database. The broker is shown once, with the producer-consumer pairs in the Topics table.

## Fitness Functions

| Rule | Automated check |
|---|---|
| No deployable reaches another's database | Each deployable's database role exists only in its own database |
| One writer per topic | Broker ACLs give produce rights on each topic to its publisher only |
| The gateway holds no business rules | Review check: gateway configuration contains routes, auth and limits only |

## Deployment View

- **Tenancy:** pooled (multi-tenancy-design): one deployment, every row scoped by practice group

### Environment: production

```
Production
+-- Region: eu-west ----------------------------------------------------------+
|  [Infrastructure] Load balancer --> [Infrastructure] Ingress                |
|  +-- Kubernetes cluster --------------------------------------------------+ |
|  |  namespace: pawsbook-edge      Edge Gateway x2, Web App x2             | |
|  |  namespace: appointments       Appointments API x3, Reminders Worker x1| |
|  |  namespace: clinical-records   Clinical Records API x2                 | |
|  |  namespace: billing            Billing API x2                          | |
|  |  namespace: broker             Event Broker x3                         | |
|  +------------------------------------------------------------------------+ |
|  [Managed PostgreSQL] Appointments DB, Clinical Records DB, Billing DB      |
|                       (separate instances, each primary + standby)          |
+-----------------------------------------------------------------------------+
```

| Container | Deployment node | Instances | Notes |
|---|---|---|---|
| Web App | namespace pawsbook-edge | 2 | static files behind the gateway |
| Edge Gateway | namespace pawsbook-edge | 2 | behind the ingress |
| Appointments API | namespace appointments | 3 | scales on requests |
| Reminders Worker | namespace appointments | 1 | one consumer group |
| Appointments DB | managed PostgreSQL instance | 1 + standby | |
| Clinical Records API | namespace clinical-records | 2 | stricter network policy |
| Clinical Records DB | managed PostgreSQL instance | 1 + standby | encrypted at rest, audit log on |
| Billing API | namespace billing | 2 | |
| Billing DB | managed PostgreSQL instance | 1 + standby | |
| Event Broker | namespace broker | 3 | |

### Environment: staging

| Container | Deployment node | Instances | Notes |
|---|---|---|---|
| Web App | namespace pawsbook-edge | 1 | |
| Edge Gateway | namespace pawsbook-edge | 1 | |
| Appointments API | namespace appointments | 1 | |
| Reminders Worker | namespace appointments | 1 | |
| Appointments DB | one shared PostgreSQL server, own database | 1 | |
| Clinical Records API | namespace clinical-records | 1 | |
| Clinical Records DB | one shared PostgreSQL server, own database | 1 | synthetic records only |
| Billing API | namespace billing | 1 | Stripe test mode |
| Billing DB | one shared PostgreSQL server, own database | 1 | |
| Event Broker | namespace broker | 1 | |

- **Variability:** production runs separate managed database instances and three brokers; staging shares one database server (separate databases) and runs one of each. Practice groups vary only as data, never as copies.

## Open Questions

- none
````

## Why this is right

- Four contexts became three deployables, each split justified by a named disintegrator and the kept-together pair by an integrator.
- The three requests were declined with reasons: no business rules in the gateway, no shared database, and services verify identity.
- The broker is drawn once and the Topics table keeps every producer-consumer pair readable.
- Replicas, namespaces and regions live only in the deployment view; staging is drawn because its shape differs.
- `validate-container-diagram.sh` exits clean on the artifact.
