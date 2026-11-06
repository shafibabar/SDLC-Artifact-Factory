# Ownership and Order

The detail behind `SKILL.md` § 1. Self-contained: it assumes only that the matrix in `SKILL.md` is the lookup for who owns a concern. Grounded in Khononov (*Learning Domain-Driven Design*: subdomain, Bounded Context, Aggregate and service boundaries are drawn by different forces, and nothing forces them to align), summarised in `research/domain-driven-design/learning-ddd-khononov.md`, and in the Wave 2 decisions (D047).

## 1. The Design phase, in order

```
domain-modeler                                  enterprise-architect / data-architect
 1 Domain Storytelling (optional by profile)
 2 Event Storming Big Picture
 3 Subdomain classification
 4-5 Process Modelling, Software Design (by profile)
 6 Ubiquitous Language per context
 7 Context Map
 8 Aggregates   9 Domain Event catalog   10 Command catalog
          ──hand-over──▶                        read side per context (cqrs-pattern)
                                                event envelope and registry (event-schema-design, data-architect)
          ◀──read-side decision──
11 Read Models
          ──hand-over──▶                        system context → tenancy → containers and deployment view
                                                → components (non-default services) → integration, events,
                                                orchestration, broker → API and gRPC contracts → ADRs
                                                → architecture evaluation
                                                physical and canonical data model (data-architect)
```

Each agent's own *Execution Sequence* is the authority for its steps; this picture shows where they meet.

## 2. Edge cases of ownership

| Situation | Owner | Why |
|---|---|---|
| What an event *means*, its name, payload fields and their meaning, who reacts | domain-modeler (`domain-event-catalog`) | the business fact belongs to the domain |
| The event's envelope (CloudEvents attributes and extensions), encoding, compatibility, schema registry, a breaking change as a new event type | data-architect (`event-schema-design`) | D047-1, D047-2 |
| Whether a context projects its Read Models; queries across services | enterprise-architect (`cqrs-pattern`) | D047-4; decided before Read Models |
| A Read Model's shape, events, rebuild | domain-modeler (`read-model-design`) | follows the read-side decision |
| Which contexts share a deployable; modular monolith at lean | enterprise-architect (`container-diagram`) | D047-6 |
| Where the gateway sits | enterprise-architect (`container-diagram`) | D047-11; Design |
| The gateway's routes, limits and policies | platform-engineer (`api-gateway-design`) | D047-11; Deploy |
| Services still verify identity behind the gateway | security-architect, then each service | D047-12 |
| Tenant isolation model | enterprise-architect (`multi-tenancy-design`), from NFR and compliance input | D047-7; no default |
| A product's per-context terms | domain-modeler, in the product's artifacts (`ubiquitous-language`) | D047-9 |
| The plugin's own vocabulary | `glossary-management` | D047-9 |
| Stack-neutral files (a Dockerfile, a migration) | the agent whose stack the instance belongs to | claimed per instance |
| An Aggregate rule that touches access policy | domain-modeler owns the rule; security-architect owns the policy; joint review | each owns its half |

## 3. Definition of Done per stage

A hand-over starts only when the producer's stage meets its Definition of Done.

| Stage | Producer | Definition of Done |
|---|---|---|
| Discovery and language | domain-modeler | Event Storming levels the plan requires, marked agent-run or workshop; subdomain classification; Ubiquitous Language per context; validators clean |
| Strategic design | domain-modeler | Context Map with a named pattern for every relationship referenced downstream |
| Tactical design | domain-modeler | Aggregates (pattern per use case, true invariants), event and Command catalogs per context; validators clean |
| Read side | enterprise-architect | `cqrs-decisions.md` (standard and enterprise): a rung per context, staleness and read-your-writes per projected view |
| Read Models | domain-modeler | `read-models.md` per context with queries; `validate-read-models.sh` clean |
| Architecture | enterprise-architect, data-architect | every service, contract and data decision traces to a named Bounded Context and Aggregate; no orphan decisions |
| Implementation | backend-engineer, frontend-engineer, platform-engineer | code implements the designed contracts; any deviation is a flag back, not a silent change |
| Verification | test-strategist, security-engineer | tests bind to Aggregates and Domain Events, not incidental details; compliance checks cover every context with regulated data |

## 4. When an earlier decision is missing

The later agent does not make it. It records an open question naming the owner, carries on with what does not depend on it, and labels any assumption it had to make (`read-model-design`: a staleness proposed and marked for enterprise-architect to confirm). The owner settles it; the dependent artifact is then checked against the decision.
