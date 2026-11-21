---
name: container-diagram
product: [product slug]
version: 1.0.0
phase: design
owner: enterprise-architect
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: the deployables, how they talk, and where they run]
traces-to: [design/architecture/system-context.md, design/context-map.md, design/architecture/cqrs-decisions.md, ideate/nfr-specification.md, design/architecture/multi-tenancy-design.md]
---

# Container diagram for [System]

<!-- Path: artifacts/<product>/design/architecture/container-diagram.md. One per product, every profile.
     Order: Decomposition → container view → Gateway → Deployment View (after multi-tenancy-design).
     Lean: one application container and its database; decomposition in two lines; one environment as a table; no Mermaid. -->

**Readers:** [engineers, platform-engineer, security-architect, the product owner]
**Question it answers:** what runnable units make up [System], what technology each uses, how they talk, and where they run.

## Decomposition

- **Profile:** [lean | standard | enterprise]

| Deployable | Containers | Contexts | Forces |
|---|---|---|---|
| [name] | [its containers] | [the Bounded Contexts it holds, as modules] | [lean: "modular monolith (lean)"; a split: the disintegrator with evidence, and the integrators it overrides; kept together: the integrator] |

## Diagram

```
[ASCII. A boundary frame named [System]; inside it each [Container: <type>] box with name, technology, responsibility.
 Persons and external systems outside, with the names from the system context diagram.
 Solid arrows for sync, dashed for async; each points from the caller or publisher and says what flows, then [protocol].
 No pods, replicas, ports, regions or tenant copies.]
```

## Key

- `[Container: <type>]` a runnable or deployable unit of [System]; `[Person]` / `[External System]` from the system context diagram
- `────▶` synchronous call, from the caller; `- - -▶` asynchronous message, from the publisher, label names the topic
- Arrows point from the party that starts the exchange; labels say what flows, then the protocol.
- Container-to-container calls run over the mesh (east-west); clients enter once, north-south. Where things run: Deployment View.

## Element Catalog

### Containers

| Container | Type | Technology | Deployable | Responsibility |
|---|---|---|---|---|
| [name] | [Web App / Mobile App / API / Worker / Application / Database / Broker / File Store / Gateway] | [from sdlc-config / defaults] | [deployable] | [one line] |

### Persons and External Systems

| Name | Kind | Uses or used by |
|---|---|---|
| [exactly as on the system context diagram] | [Person / External System] | [container] |

### Communication Matrix

| From | To | What flows | Protocol | Sync/Async |
|---|---|---|---|---|
| [caller or publisher] | [callee, broker or consumer] | [a phrase that reads start to end] | [HTTPS/JSON, SQL, Kafka protocol, …] | [sync / async] |

### Topics

<!-- Only if there is a broker. Keeps producer-consumer pairs readable. -->

| Topic | Publisher | Consumers |
|---|---|---|
| [topic] | [container] | [containers] |

## Gateway

- **Gateway:** [none: the ingress routes to <application> | <gateway container>]
- **Holds:** [routing, TLS, token validation, rate limits; never business rules]
- **Identity:** [services verify identity themselves; the gateway is the first check, not the only one]
- **Planes:** [north-south: clients → <gateway or ingress>; east-west: container to container over the mesh (Linkerd, mutual TLS)]
- **Configuration:** platform-engineer at Deploy (`api-gateway-design`)

## Rationale

[Why this shape: why these deployables (the forces), why the gateway sits where it does, how the broker is shown.]

## Fitness Functions

| Rule | Automated check |
|---|---|
| [modules don't import each other's internals / one schema per module / one writer per table] | [the test or check that fails the build] |

## Deployment View

- **Tenancy:** [the model multi-tenancy-design chose | single deployment, no tenancy | pending multi-tenancy-design]

### Environment: production

```
[ASCII nested deployment nodes: region → cluster → namespace, container instances with counts; infrastructure nodes (load balancer, ingress, CDN).]
```

| Container | Deployment node | Instances | Notes |
|---|---|---|---|
| [every container above] | [where it runs] | [count] | [—] |

- **Variability:** [what changes per environment, region or tenant; what stays fixed]

<!-- Add "### Environment: staging" only if its shape differs; otherwise one line under Variability. -->

## Open Questions

- [an assumption or missing input — who answers it | none]
