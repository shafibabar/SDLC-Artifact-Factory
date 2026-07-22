---
name: ddd-agent-handoff
description: >
  Cross-cutting reference for how Domain-Driven Design work is divided across
  this plugin's agents — domain-modeler, enterprise-architect, data-architect,
  data-engineer, backend-engineer, security-architect, security-engineer,
  platform-engineer, ux-architect, frontend-engineer, and test-strategist —
  and the handoff protocol between them: interaction modes, mode selection,
  Definition of Done, mode/roster changes mid-session, conflict resolution,
  and resumption after an interrupted session. Points to the existing DDD
  pattern skills (bounded-context-mapping, context-map-patterns,
  aggregate-design, ubiquitous-language, domain-event-catalog,
  read-model-design, cqrs-pattern, event-driven-patterns, event-schema-design,
  canonical-data-model, adr-authoring, subdomain-distillation) rather than
  duplicating them. Use when a task touches more than one agent's DDD
  responsibility and the correct owner, mode, or sequencing is unclear.
version: 2.0.0
phase: cross-cutting
owner: factory-governance
created: 2026-07-22
tags: [design, ddd, cross-cutting, governance, handoff, agents]
---

# DDD Agent Handoff

## Purpose

This skill is a boundary and handoff entry point, not a routing engine and
not a place to explain DDD concepts — every concept below is a pointer to
where it's actually taught. Consult this skill when a task spans more than
one agent's DDD responsibility and it's unclear which agent owns which part,
what interaction mode to use, or how to resume work after an interruption.

## Agent Boundary Matrix

| Concern | Owning agent | Load |
|---|---|---|
| Strategic subdomain classification (Core/Supporting/Generic) | **domain-modeler** | `subdomain-distillation` |
| Bounded Context boundaries, Context Map, Ubiquitous Language elicitation, Aggregate design, Domain Event catalog, Read Model design | **domain-modeler** | `bounded-context-mapping`, `context-map-patterns`, `aggregate-design`, `ubiquitous-language`, `domain-event-catalog`, `read-model-design` |
| Service decomposition, architecture-level CQRS, event-driven patterns (Saga, choreography vs. orchestration), ADRs | **enterprise-architect** | `cqrs-pattern`, `event-driven-patterns`, `adr-authoring` |
| Physical data model, canonical data model, event serialization/schema registry | **data-architect** | `event-schema-design`, `canonical-data-model`, `data-model-design` |
| Data pipeline implementation, product analytics and reporting content | **data-engineer** | `data-pipeline-implementation`, `analytics-requirements` |
| Go implementation of Aggregates, CQRS, event publishers/consumers | **backend-engineer** | `go-domain-model`, `go-event-consumer`, `go-event-publisher` |
| Threat model, ABAC, privacy and compliance design | **security-architect** | `access-control-model`, `compliance-design`, `privacy-design` |
| Security control implementation, compliance verification | **security-engineer** | `security-implementation`, `compliance-verification` |
| CI/CD, service mesh, container topology per Bounded Context | **platform-engineer** | `ci-pipeline`, `cd-pipeline`, `kubernetes-manifest` |
| Task UI flows aligned to the Ubiquitous Language | **ux-architect** | `ux-flow-design`, `information-architecture` |
| Component/UI implementation per Bounded Context | **frontend-engineer** | `react-component-design`, `react-project-structure` |
| Binding tests to Aggregates and Domain Events | **test-strategist** | `test-pyramid`, `bdd-feature-file` |

Two rows sharing an agent (e.g. Security and Compliance both routing to
security-architect/security-engineer) are not a duplicate entry — they are two
distinct concerns the same agent owns at different points (design vs.
verification).

## Handoff Protocol

Full protocol — the handoff record schema, the three Team Topologies
interaction modes (Collaboration, X-as-a-Service, Facilitating), Mode
Selection Criteria (subdomain classification as the primary signal),
Definition of Done per stage, the Mode Transition and Roster Change
protocols, conflict resolution for genuine ownership disputes, and a
Pass/Defect handoff-quality checklist — lives in
`references/handoff-protocol.md`. Load it whenever a handoff needs more
than the boundary lookup above.

Two rules stay here since every agent must know them regardless of which
mode or stage applies:

- An agent never edits another agent's artifact directly. If a gap is found
  in another agent's domain, flag it back to that agent rather than
  patching it.
- Vocabulary is owned per Bounded Context via `ubiquitous-language`, not per
  agent. If two agents' terms for the same concept conflict,
  `glossary-management` is the tiebreaker — this skill has no authority
  over terminology.

## Recording a Handoff

Every handoff is recorded using `assets/handoff-record-template.md` —
one record per concern changing hands, not one per agent pairing in
general. The template encodes which fields are required per interaction
mode and how to mark an interrupted handoff's `resumption_type` correctly.

## Worked Examples

`references/handoff-worked-examples.md` has seven filled-in examples: two
straightforward successful handoffs (one per non-Facilitating mode), a mode
escalation mid-session, a new-agent addition mid-session, and three
resumption scenarios — including the distinction between an ordinary
operational pause and a breakthrough that should route back to
domain-modeler for model revision rather than resume forward.

## When Nothing Matches

If a task's DDD ownership isn't clear from the matrix above, ask a single
clarifying question naming the two closest-matching agents rather than
guessing — a misrouted handoff compounds quickly across phases.
