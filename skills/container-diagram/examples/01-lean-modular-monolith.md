# Example 1 — Lean: A Modular Monolith

Self-contained. **Curtain Call** runs the box office and volunteer rota for one community theatre: patrons buy tickets online, volunteers sell at the door and sign up for front-of-house shifts. About 40 volunteers and a few thousand patrons a season. **Lean** profile. The approved system context diagram has persons **Patron** and **Box Office Volunteer**, and external systems **Stripe** and **Postmark**. The Context Map has two contexts: **Ticketing** and **Volunteer Rota**. No tenancy (one theatre).

## Input

> **User:** "Make Ticketing and Volunteer Rota two services with their own databases and Redpanda between them, so we're ready to grow. And put '×2 replicas' on the ticketing box so people know it's highly available."

## Working it

- **Decomposition.** Lean starts as one modular monolith. Disintegrators: none with evidence (both change at the same pace, neither needs separate scaling, a 40-volunteer theatre has no isolation need). Integrator: selling a ticket at the door and the volunteer's shift are read together on one screen. So: **one deployable**, `curtain-call`, with Ticketing and Volunteer Rota as modules, each with its own schema in one PostgreSQL database. No broker: the modules call each other in-process.
- **Declined:** two services and Redpanda (no disintegrator; every split adds a network hop, a deployment and a failure mode). The replicas go to the **deployment view**, not the container picture.
- **Gateway:** none. The ingress routes to the one application, which validates sessions itself.
- **Deployment view:** a single deployment; production as a table; staging is the same at one instance each.

## Output: `artifacts/curtain-call/design/architecture/container-diagram.md`

````markdown
---
name: container-diagram
product: curtain-call
version: 1.0.0
phase: design
owner: enterprise-architect
created: 2026-03-14
summary: Curtain Call as one modular monolith (Ticketing and Volunteer Rota modules), a React web app and one PostgreSQL database, run as a single deployment.
traces-to: [design/architecture/system-context.md, design/context-map.md, ideate/nfr-specification.md]
---

# Container diagram for Curtain Call

**Readers:** the product owner, the engineers, platform-engineer
**Question it answers:** what runnable units make up Curtain Call, what technology each uses, how they talk, and where they run.

## Decomposition

- **Profile:** lean

| Deployable | Containers | Contexts | Forces |
|---|---|---|---|
| curtain-call | Web App, Box Office App, Box Office DB | Ticketing, Volunteer Rota (modules) | modular monolith (lean); integrator: door sales and shifts are read together; no disintegrator with evidence |

## Diagram

```
 +-----------------------+        +-----------------------+
 | [Person]              |        | [Person]              |
 | Patron                |        | Box Office Volunteer  |
 +-----------+-----------+        +-----------+-----------+
             | Buys tickets in                | Sells at the door, takes
             | [HTTPS]                        | shifts in [HTTPS]
             v                                v
+--------------------------- Curtain Call ------------------------------+
|  +------------------------------+                                    |
|  | [Container: Web App]         |                                    |
|  | Web App                      |                                    |
|  | React + TypeScript           |                                    |
|  | Booking and rota screens     |                                    |
|  +---------------+--------------+                                    |
|                  | Sends bookings and shift sign-ups to [HTTPS/JSON]  |
|                  v                                                    |
|  +------------------------------+     +---------------------------+  |
|  | [Container: Application]     |     | [Container: Database]     |  |
|  | Box Office App               |---->| Box Office DB             |  |
|  | Go, net/http + chi           |     | PostgreSQL                |  |
|  | Ticketing and Volunteer Rota |     | One schema per module     |  |
|  | modules                      |     +---------------------------+  |
|  +------+-----------------+-----+  Reads and writes module rows [SQL] |
+---------|-----------------|-------------------------------------------+
          | Takes card      | Sends tickets and
          | payments in     | shift reminders to
          | [HTTPS]         | [HTTPS]
          v                 v
 +-------------------+  +-------------------+
 | [External System] |  | [External System] |
 | Stripe            |  | Postmark          |
 +-------------------+  +-------------------+
```

## Key

- `[Container: <type>]` a runnable or deployable unit of Curtain Call; `[Person]` / `[External System]` from the system context diagram
- `---->` synchronous call; all calls here are synchronous
- Arrows point from the caller; labels say what flows, then the protocol. No asynchronous messages: the modules call each other in-process.
- Clients enter once, north-south, through the ingress. Where things run: Deployment View.

## Element Catalog

### Containers

| Container | Type | Technology | Deployable | Responsibility |
|---|---|---|---|---|
| Web App | Web App | React + TypeScript | curtain-call | Booking and rota screens |
| Box Office App | Application | Go, net/http + chi | curtain-call | Ticketing and Volunteer Rota modules; serves the web app |
| Box Office DB | Database | PostgreSQL, pgx | curtain-call | Schemas `ticketing` and `rota`, one per module |

### Persons and External Systems

| Name | Kind | Uses or used by |
|---|---|---|
| Patron | Person | Web App |
| Box Office Volunteer | Person | Web App |
| Stripe | External System | Box Office App |
| Postmark | External System | Box Office App |

### Communication Matrix

| From | To | What flows | Protocol | Sync/Async |
|---|---|---|---|---|
| Patron | Web App | Buys tickets in | HTTPS | sync |
| Box Office Volunteer | Web App | Sells at the door, takes shifts in | HTTPS | sync |
| Web App | Box Office App | Sends bookings and shift sign-ups to | HTTPS/JSON | sync |
| Box Office App | Box Office DB | Reads and writes module rows in | SQL | sync |
| Box Office App | Stripe | Takes card payments in | HTTPS | sync |
| Box Office App | Postmark | Sends tickets and shift reminders to | HTTPS | sync |

## Gateway

- **Gateway:** none: the ingress routes to the Box Office App
- **Holds:** —
- **Identity:** the Box Office App verifies every session itself
- **Planes:** north-south: clients → ingress → Box Office App; east-west: none (one application and its database)
- **Configuration:** platform-engineer at Deploy (`api-gateway-design`)

## Rationale

One deployable because no disintegrator applies and door sales and shifts are read together. The modules keep the context boundary: separate schemas, no cross-module queries, so Volunteer Rota can move out later without changing the model.

## Fitness Functions

| Rule | Automated check |
|---|---|
| Modules don't import each other's internals | Import test in CI fails on `ticketing` → `rota` internal imports and back |
| One schema per module | Each module's database role has grants on its own schema only |

## Deployment View

- **Tenancy:** single deployment, no tenancy (one theatre)

### Environment: production

| Container | Deployment node | Instances | Notes |
|---|---|---|---|
| Web App | served by the Box Office App | — | static files in the same image |
| Box Office App | Kubernetes cluster, namespace `curtain-call` | 2 | behind the ingress |
| Box Office DB | managed PostgreSQL | 1 | daily backup |

- **Variability:** staging is production with one Box Office App instance and a smaller database.

## Open Questions

- none
````

## Why this is right

- One application and one database: the contexts are modules, each owning its schema, with an import test that keeps them apart.
- Both requests were declined with reasons: no disintegrator for the split; replicas live in the deployment view, where the table records two instances.
- No gateway, and the gateway section says so and who verifies identity.
- `validate-container-diagram.sh` exits clean on the artifact.
