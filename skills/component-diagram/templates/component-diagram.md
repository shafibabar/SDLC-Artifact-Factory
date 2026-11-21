---
name: component-diagram
product: [product slug]
service: [container name, as on the container diagram]
bounded-context: [Bounded Context name]
version: 1.0.0
phase: design
owner: enterprise-architect
created: [YYYY-MM-DD]
summary: [One sentence, ≤ 200 chars: the container, its components, and what departs from the default skeleton]
traces-to: [design/architecture/container-diagram.md, design/<bc>/aggregates.md]
---

# Component diagram for [Service]

<!-- Path: artifacts/<product>/design/<service>/component-diagram.md.
     Only for a service whose insides differ from the default skeleton. A default service gets one line
     in the service's record instead ("<service>: default skeleton (<skill>), no component diagram").
     A static module view: no numbered steps, no runtime flow, no deployment placement. -->

**Readers:** [backend-engineer, security-engineer, reviewers]
**Question it answers:** what are the building blocks inside [Service], what does each do, and which way do the dependencies point?

## Container Context

[One line: the container, its technology, and its Level 2 neighbours: its database, the topics it publishes and consumes, the containers and external systems it calls.]

## Departures from the Default

- [each way this service differs from the default skeleton, e.g. "anti-corruption adapter around <system>", "read-model projector", "saga coordinator with its own state"]

## Diagram

```
[ASCII. One boundary box: "<Service> [Container: <type>, <technology>]".
 Inside: one box per component: name, [Component: <role>, <package or module>], one-line responsibility.
 Arrows between components: labelled verb phrases, pointing inward, no protocol, never two-way, no step numbers.
 Arrows leaving the boundary: to the database, broker or other containers, labelled with what flows and [protocol].]
```

## Key

- `[Component: <role>]` a grouping of related code behind an interface, inside [Service]
- `────▶` depends on (calls, uses); `- - -▶` implements a port declared in the domain
- Arrows point from the dependent component to the one it depends on, inward toward the domain
- Protocols appear only on arrows leaving the boundary

## Element Catalog

### Components

| Component | Role | Package or module | Interface presented | Responsibility |
|---|---|---|---|---|
| [name] | [entry point / use cases / domain / adapter / anti-corruption adapter / projector / coordinator] | [path] | [the port or API it presents] | [in full] |

### Relationships

| From | To | Nature | Direction rationale |
|---|---|---|---|
| [component] | [component or external container] | [calls / implements / uses via port / SQL / Kafka protocol / HTTPS] | [why it points this way] |

## Dependency Rule

[Where each port is declared (in the domain), which adapter implements it, and that the domain imports only the standard library.]

## Fitness Function

- **Check:** [the automated check that fails the build when the domain imports outside the standard library, e.g. the `arch` target's import check]

## Variability

[What differs per deployment, from the container diagram's deployment view and multi-tenancy-design; the component structure itself is the same everywhere. Tenancy not decided: "tenancy pending multi-tenancy-design; tenant placement belongs to the deployment view".]

## Rationale

- [one or two sentences per departure listed above]

## Open Questions

- [an assumption or missing input — who answers it | none]
