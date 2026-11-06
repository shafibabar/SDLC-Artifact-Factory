---
name: ddd-agent-handoff
description: >
  Who owns each Domain-Driven Design and architecture concern across this
  plugin's agents, in what order the decisions are made, and how work passes
  between agents: the ownership matrix (subdomain classification after the
  Big Picture; the read side decided by enterprise-architect before Read
  Models; event meaning with the domain-modeler, envelope and schema
  registry with the data-architect; service decomposition, tenancy and
  orchestration with enterprise-architect), the hand-over record and its
  two modes (hand-over by default, joint review when the receiver's
  knowledge shapes the artifact), flags back instead of editing another
  agent's artifact, ownership disputes, and resuming an interrupted phase,
  including routing back when the model itself is found wrong. Use when a
  task spans agents, the owner or order of a decision is unclear, an agent
  finds a defect in another agent's artifact, or a phase resumes after an
  interruption. Used by every agent that hands DDD work on.
version: 3.0.0
phase: cross-cutting
owner: factory-governance
created: 2026-07-22
tags: [design, ddd, cross-cutting, governance, handoff, agents, ownership]
produces: handoff-record
domain: domain-modeling
status: stable
related: [subdomain-distillation, event-storming-facilitation, ubiquitous-language, bounded-context-mapping, context-map-patterns, aggregate-design, domain-event-catalog, event-schema-design, command-catalog, cqrs-pattern, read-model-design, container-diagram, multi-tenancy-design, workflow-orchestration, glossary-management]
sources:
  - research/devops-and-delivery/platform-engineering-fournier-nowland.md
  - research/domain-driven-design/learning-ddd-khononov.md
  - research/domain-driven-design/domain-driven-design-evans.md
---

# DDD Agent Handoff

## Purpose

Which agent owns a concern, what must be decided before it, and how the work passes on. Every concept is taught in the skill named in the matrix; this skill only routes. Khononov's boundaries (subdomain, Bounded Context, Aggregate, service) are each drawn by a different decision; the matrix says whose.

## 1. Who Owns What, in Order

| Concern | Owner | Skill | After |
|---|---|---|---|
| Domain Storytelling, Event Storming (agent-run or workshop, D047-8) | domain-modeler | `domain-storytelling`, `event-storming-facilitation` | Ideate approved |
| Subdomain classification (Core / Supporting / Generic) | domain-modeler | `subdomain-distillation` | the Big Picture (D047-14) |
| Ubiquitous Language per Bounded Context, in the product's artifacts | domain-modeler | `ubiquitous-language` | Event Storming |
| Bounded Contexts and the Context Map; relationship patterns | domain-modeler | `bounded-context-mapping`; `context-map-patterns` | language (D047-5) |
| Aggregates, invariants, business-logic pattern, event sourcing | domain-modeler | `aggregate-design` | the Context Map |
| Domain Events: what each means, its payload's meaning, its consumers | domain-modeler | `domain-event-catalog` | Aggregates |
| Event envelope, serialization, versioning, schema registry | data-architect | `event-schema-design` | the event catalog (D047-1, D047-2) |
| Commands | domain-modeler | `command-catalog` | Aggregates |
| Read side per context; queries across services | enterprise-architect | `cqrs-pattern` | Commands; **before Read Models** (D047-4) |
| Read Models | domain-modeler | `read-model-design` | the read-side decision |
| System context; containers, service decomposition, deployment view, gateway placement | enterprise-architect | `system-context-diagram`, `container-diagram` | the domain model (D047-6, D047-11, D047-13) |
| Tenant isolation | enterprise-architect | `multi-tenancy-design` | NFRs and compliance; before the deployment view (D047-7) |
| Components (only for services that differ from the default) | enterprise-architect | `component-diagram` | containers |
| Choreography, outbox, consumers; orchestration and sagas; broker | enterprise-architect | `event-driven-patterns`; `workflow-orchestration` (D047-3); `message-broker-selection` | the event catalog |
| External integrations; HTTP and gRPC contracts | enterprise-architect | `integration-design`; `api-contract-design`, `grpc-contract-design` | Commands and Read Models |
| ADRs; architecture evaluation | enterprise-architect | `adr-authoring`; `architecture-evaluation` (being built, #1411) | the decisions they record |
| Physical data model, canonical data model | data-architect | `data-model-design`, `canonical-data-model` | Aggregates and Read Models |
| Threats, access control, privacy, compliance design | security-architect | `access-control-model`, `privacy-design`, `compliance-design` | the domain model |
| Code: Aggregates, handlers, publishers, consumers, projectors | backend-engineer | the stack's skills (`go-*` or `python-*`) | Design approved |
| UI flows, screens; frontend code | ux-architect; frontend-engineer | `ux-flow-design`; `react-component-design` | the language and Read Models |
| Gateway configuration, pipelines, clusters | platform-engineer | `api-gateway-design`, `ci-pipeline`, `kubernetes-manifest` | Deploy (D047-11) |
| Data pipelines, analytics content | data-engineer | `data-pipeline-implementation`, `analytics-requirements` | the data model |
| Tests bound to Aggregates and Domain Events | test-strategist | `test-pyramid`, `bdd-feature-file` | Commands and events |
| Security controls, compliance checks | security-engineer | `security-implementation`, `compliance-verification` | security design |
| The plugin's own vocabulary | factory-governance | `glossary-management` (D047-9) | — |

Where a decision comes *after* another, the later agent reads the earlier artifact and never makes the earlier decision itself. Edge cases and Definition of Done per stage: `./references/ownership-and-order.md`.

## 2. Rules Every Agent Follows

1. **Never edit another agent's artifact.** A defect found in it (a wrong invariant, a missing event, a contradiction) is a **flag back**: recorded in the hand-over record with what is wrong and the evidence, routed to the owner, who fixes it. A fixed artifact the product owner had approved returns to draft and needs re-approval (#1288).
2. **Never take over an upstream decision.** A Read Model designer who finds a query rung 1 can't serve sends the evidence to enterprise-architect; a backend-engineer who finds the Aggregate boundary unworkable sends it to the domain-modeler.
3. **Disputes:** Bounded Context scope → the domain-modeler decides; a product term → the context's Ubiquitous Language; plugin vocabulary → `glossary-management`; meaning vs. envelope of an event → split per D047-2. Anything else is recorded as *blocked* and goes to the product owner; neither agent proceeds alone.
4. **Nothing fits:** ask one question naming the two closest owners rather than guess.

## 3. Two Ways to Hand Over

- **Hand-over (default).** The producer finishes its artifacts to their Definition of Done; the receiver takes them as input. Gaps come back as flags. Fournier & Nowland's X-as-a-Service: a finished, self-service input the receiver does not renegotiate.
- **Joint review (temporary).** The receiver reviews the producer's draft **before** the product owner approves it, and flags go back and forth until none is open. Use it when the receiver's knowledge shapes the artifact: a Core subdomain, personal or regulated data, a disputed boundary, or a first hand-over of that kind on this product. It ends when the artifact is stable, returning to hand-over (Fournier & Nowland: collaboration is temporary).

Escalate a hand-over to joint review after a second flag of the same kind; record why. Detail: `./references/handoff-protocol.md`.

## 4. Recording a Hand-over

1. **When:** an agent finishes a stage another agent builds on (each agent's *Handoff Rules* list them), or an agent is interrupted mid-stage.
2. **Where:** `artifacts/<product>/<phase>/handoffs/<from>-to-<to>.md`, one per pair per phase (`./templates/handoff-record.md`). At lean the record is the concerns table and any flags.
3. **What:** the concerns and artifacts handed over, each with its Definition of Done met or not; the mode and why; flags back; open questions; resumption, if interrupted.
4. **Validate, then loop.** Run `./scripts/validate-handoff-record.sh <path>`, fix every FAIL, re-run until clean; then `./resources/checklist.md`.
5. **Accept:** the receiver marks the record *accepted* only when every Definition of Done is met and no flag is open.

## 5. Resuming an Interrupted Phase

Read the open hand-over records first. Two kinds of interruption:
- **Operational pause** (a session ended, a limit was hit): continue from the artifacts produced and the open questions; nothing is redone.
- **Model found wrong** (an Aggregate boundary, a context relationship or a classification turned out wrong): do **not** resume forward. Route back to the model's owner to revise it, Evans' refactoring toward deeper insight, and mark every downstream artifact built on it for review.

Worked cases: `./examples/01-lean-single-handover.md`, `./examples/02-standard-flag-back-and-event-schema-split.md`, `./examples/03-enterprise-resume-after-model-found-wrong.md`.

## Gotchas

Each trap comes with the reason to give in full.

- **"I'll just fix the invariant in their aggregates.md; it's quicker."** *Reason:* the owner never learns their model is wrong, approval is bypassed, and the next regeneration overwrites the fix. *Instead:* flag it back with evidence; the owner fixes it.
- **"The domain-modeler can decide CQRS while designing Read Models."** *Reason:* the read side is enterprise-architect's, decided first; the Read Model's shape depends on it. *Instead:* `cqrs-pattern`, then `read-model-design`.
- **"The data-architect owns the event, so it decides what `OrderPlaced` means."** *Reason:* meaning is the domain's; the data-architect owns envelope, serialization and registry. *Instead:* split per D047-2.
- **"Resume where we left off"** after the boundary was found wrong. *Reason:* everything downstream builds on a model known to be wrong. *Instead:* route back to the owner, then review what depended on it.
- **"Joint review for everything, to be safe."** *Reason:* every artifact then waits on two agents for no gain. *Instead:* hand-over by default; joint review on a named reason.
- **"Mark it accepted; the open flag is minor."** *Reason:* an accepted record with open flags tells the next session the input is sound. *Instead:* close or decline each flag with a reason first.
- **"Two agents disagree; the faster one proceeds."** *Reason:* the slower one's artifact now contradicts. *Instead:* record *blocked*; the rule in § 2 or the product owner decides.

## References

| Question | File |
|---|---|
| Definition of Done per stage, edge cases of ownership, the order in full | `./references/ownership-and-order.md` |
| Modes in detail, escalation, flags, disputes, resumption | `./references/handoff-protocol.md` |
| Checking a record before acceptance | `./resources/checklist.md` |
