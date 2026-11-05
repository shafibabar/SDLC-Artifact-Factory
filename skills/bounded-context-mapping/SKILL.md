---
name: bounded-context-mapping
description: >
  Find a product's Bounded Contexts and draw its Context Map: where one model
  and its Ubiquitous Language end and the next begins. Covers the evidence
  (words whose meaning changes, Event Storming pivotal events and
  swimlanes, domain story groups, homonyms across contexts, who writes each
  record), defining each context, sizing (start wide around the Core, never
  one context per Aggregate or per team), drawing the current map as it is
  and the target map apart from it, upstream marked on every line, and
  moving a boundary later. Includes agent-run mode, with every boundary
  cited to its evidence and open questions sent to the product owner. Use
  when deciding whether something is one context or two, drawing or
  reviewing a Context Map, or challenging a boundary. Choosing the
  relationship pattern on each line is context-map-patterns; turning
  contexts into deployable services is container-diagram. Used by
  domain-modeler after subdomain classification and Ubiquitous Language.
version: 3.1.0
phase: design
owner: domain-modeler
created: 2026-06-25
tags: [design, domain-modeling, bounded-context, context-map, ddd, boundary, agent-run]
produces: context-map
domain: domain-modeling
status: stable
related: [context-map-patterns, subdomain-distillation, ubiquitous-language, event-storming-facilitation, domain-storytelling, aggregate-design, container-diagram]
sources:
  - research/domain-driven-design/strategic-design-supplement.md
  - research/domain-driven-design/domain-driven-design-evans.md
  - research/domain-driven-design/learning-ddd-khononov.md
  - research/domain-driven-design/introducing-eventstorming-brandolini.md
  - research/domain-driven-design/domain-storytelling-hofer-schwentner.md
  - research/software-architecture/building-microservices-newman.md
---

# Bounded Context Mapping

## Purpose

A Bounded Context (Evans, *Domain-Driven Design*, Ch. 14) is the boundary of one model and its language: inside it, every term means exactly one thing. It is nothing more by definition. Khononov (*Learning Domain-Driven Design*) states the force precisely: a context is a **linguistic and model-consistency** boundary. That is a different force from an Aggregate's transactional boundary (much finer, inside a context) and from a deployment unit (decided later).

A **subdomain** is part of what the business does: problem space, *discovered* (`subdomain-distillation`). A **Bounded Context** is a modelling choice: solution space, *designed*. Aim for one subdomain per context (Vernon), but nothing forces it.

**This skill's job (D047-5):** find the contexts, define them, and draw the map. Which relationship pattern governs each line, and why, is `context-map-patterns`. How contexts become services is `container-diagram` (D047-6). Both write into the same artifact, `design/context-map.md`.

## 1. Agent-Run Mode First (D047-8)

The domain-modeler usually draws boundaries from artifacts, not in a workshop with experts. So:

1. **Every boundary cites its evidence:** the Event Storming hint, the story group, the homonym in the language documents, the record-ownership split (§ 2). A boundary with no cited evidence isn't drawn.
2. **A judgement with thin evidence is marked *assumed*** and becomes an open question for the product owner, with the boundary used meanwhile.
3. **Present the map as candidates until the product owner approves it** at the review gate.

## 2. The Evidence for a Boundary

Read the upstream artifacts; don't start from a blank page. In order of strength:

| Evidence | From | Reads as |
|---|---|---|
| **A word whose meaning changes** | `ubiquitous-language` homonyms; a term divergence table (`./references/discovery-techniques.md` § 1) | The primary signal: the boundary sits where the meaning changes |
| **Event Storming boundary hints** | Pivotal events, swimlanes, a change of actors (`event-storming-facilitation`) | Evidence *for* the language signal, not a separate signal |
| **Domain story groups** | Groups with their hints (`domain-storytelling`) | Same: evidence, not decisions |
| **Who writes each record** | A data-ownership pass (`./references/discovery-techniques.md` § 2) | Confirms a boundary; contested ownership points at one |
| **Subdomain types** | `subdomain-classification` | Guides size and investment, never draws the line alone |

**Team ownership is a constraint, not a signal** (Khononov; Newman's Conway's Law describes what teams do to systems, not where models end). Each context has exactly one owning team, but a second team doesn't create a second context. In an agent-built product one agent models every internal context, so the team axis rarely applies; it matters for external systems and vendors. **Deployment independence isn't a signal here either**; it belongs to `container-diagram`.

## 3. Size: Start Wide

- **Not one context per Aggregate.** Aggregates are transactional units inside a context; many Aggregates share one language. "One context per Aggregate" is a category error, not just too fine.
- **Not one context per microservice "to be safe".** Every microservice is a context; a context need not be a microservice (Khononov).
- **Start wide, especially around the Core,** whose model is the least stable. Split once the model settles; splitting early and wrongly costs far more than splitting late (Khononov). When unsure whether a line is real, keep one context and record the candidate split with what would trigger it.
- **Not a God Context either:** if one context's language holds several meanings for its key words, there are contexts hiding inside it.

The "one context or two?" test, and the God and Nano-Context patterns: `./references/discovery-techniques.md` § 3–4.

## 4. Define Each Context

Each context in `design/context-map.md` records: its name (a domain noun from the language, never "AssetService"); its responsibility in one sentence; the subdomain(s) it covers with their type; **the evidence for its boundary**; a pointer to its `design/<context>/ubiquitous-language.md`; the Aggregates it owns (candidates until `aggregate-design`); the Domain Events it publishes and what it consumes; its owner; and its open questions. No "deployable service" field: that is `container-diagram`'s decision.

## 5. Draw the Map: As It Is, Then As Intended

- **Map what is** (Evans; Vernon): draw the contexts and their points of contact as they exist today, including the mess: a legacy region with no coherent model is drawn as one boundary around it.
- **A target map is separate.** If *anything* does this work today (an old system, a shared spreadsheet, a bought tool, paper), draw a current map at every profile, lean included, with the target beside it. Only a product with nothing before it has a target map alone. "We're throwing today's setup away" is a reason to draw it: the current map is what the migration has to replace.
- **Every line marks its upstream side** (whose changes flow down) and carries **one relationship pattern with its reason**, both from `context-map-patterns`.
- **External systems are boxes on the map** with the line to the context that uses them.

Plain-text boxes and arrows are the primary notation (D047-13); conventions in `./references/map-notation.md`.

## 6. Moving a Boundary Later: Plan, Validate, Execute

Moving an Aggregate or a term between contexts changes the model, the language documents, the event contracts and possibly services. So:

1. **Plan:** list what moves (Aggregates, terms, events) and every artifact that names them.
2. **Validate:** the new boundary has its evidence (§ 2); the "one or two?" test passes; nothing would end up written by two contexts.
3. **Execute:** update the map and the language documents, bump the context map's MAJOR version, and flag `container-diagram` and the event catalogue for review.

## Producing the Context Map

Copy `./resources/context-map-checklist.md` and tick it as you go.

1. **Read** the Event Storming Big Picture (and Software Design where it exists), the domain stories, the `subdomain-classification` and each context's language document.
2. **Gather the evidence** (§ 2) into a term divergence table and a record-ownership list.
3. **Draw candidate boundaries** where the meaning changes; confirm with record ownership; size them wide (§ 3).
4. **Write** `design/context-map.md` from `./templates/context-map.md`: one section per context (§ 4), the current map (if anything exists) and the target map (§ 5).
5. **Hand each line to `context-map-patterns`** for its pattern and reason.
6. **Validate, then loop.** Run `./scripts/validate-context-map.sh design/context-map.md`. Fix every FAIL and run it again until it exits clean, then go through the checklist items the script can't judge.
7. **Present** at the review gate: the contexts, the evidence for each line, the open questions, and for every request you declined, its reason in full (§ Gotchas).

Worked cases, simplest to hardest: `./examples/01-lean-one-context.md` (one context and two external systems), `./examples/02-standard-e-learning-three-contexts.md` ("Course" means three things; a team-based split rejected), `./examples/03-enterprise-retail-legacy-erp.md` (current and target maps, a legacy ERP drawn as one boundary).

## Scale

| Profile | The map |
|---|---|
| `lean` | Usually one or two contexts; a map of a box or two and its external systems. A current map too if anything exists today. Later a modular monolith (`container-diagram`) |
| `standard` | Each context defined with its evidence; a target map, and a current map if anything exists today |
| `enterprise` | As standard, plus the boundary-move procedure when contexts change |

## Gotchas

Each trap below comes with the reason to give. When you decline a request, give its reason in full: the product owner needs the *why* to approve the map, not only the verdict.

- **"Make each Aggregate its own context."** *Reason:* an Aggregate is a transactional-consistency boundary (what must change together in one step); a Bounded Context is the boundary of a whole model and its language. They are different forces at different levels, so a context usually holds several Aggregates, and sizing contexts by Aggregates is a category error. *Instead:* draw contexts where the language changes.
- **"We have two teams (or two apps), so two contexts."** *Reason:* team ownership is a constraint, not a signal: each context has exactly one owning team, and one team may own several, but a team doesn't create a boundary. In an agent-built product, where one agent models every internal context, it adds little or nothing. A user interface (mobile, web) is not a model either. *Instead:* ask where the words change meaning; then assign owners to the contexts found.
- **"Each context is a microservice, so split as fine as we can now."** *Reason:* every microservice is a context, but a context need not be a microservice (Khononov), so the number of contexts says nothing about the number of deployables. Start wide, especially around the Core, whose model is the least stable, because splitting early and wrongly costs far more than splitting late. *Instead:* fewer, wider contexts, and each split you didn't make recorded as a candidate split with its trigger.
- **"Tell me which services to deploy."** *Reason:* turning contexts into services is `container-diagram`'s step, and at lean it starts from a modular monolith (D047-6). *Instead:* don't decide it, and don't recommend a number of deployables.
- **"Skip the subdomain classification, it's paperwork."** *Reason:* it comes before contexts are drawn (D047-14), because size and investment depend on it. *Instead:* produce it first, in the same reply if need be, as a short dated table with evidence per label, or stop and ask for it.
- **"Exactly one context per subdomain", or "one per swimlane".** *Reason:* a subdomain is part of what the business does (problem space, discovered); a context is a modelling choice (solution space, designed). One-to-one is an aim, not a rule: one context can hold more than one subdomain, and one subdomain can span more than one context. Swimlanes and pivotal events are hints, not boundaries. *Instead:* confirm each line with the words that change meaning, and record that evidence.
- **"Skip today's setup, we're replacing it; draw only the target."** *Reason:* a Context Map shows what is, mess included (Evans; Vernon); hiding today's setup hides the migration. *Instead:* draw a current map at every profile, with a shared spreadsheet as one tangled region and bought tools as external boxes, upstream marked on every line; the target goes beside it.
- **Picking the patterns here.** *Reason:* the trade-offs live in `context-map-patterns`; there is no "external system means ACL always" rule. *Instead:* hand each line to that skill.
- **Presenting agent-drawn boundaries as settled.** *Reason:* nobody has confirmed them. *Instead:* cite the evidence for each, mark thin ones *assumed*, and send the open questions to the product owner.

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Context per Aggregate or per table** | Integration overhead explodes; no language boundary justifies the splits | Aggregates live inside a context |
| **Technical layers as contexts** ("API context", "DB context") | They share one language | Boundaries where the language changes |
| **God Context** | One language overloaded until it means nothing precisely | Look for the meanings hiding inside it |
| **Shared database across contexts** | An unnamed, unmanaged shared model | Each context owns its records; others consume events or read models |
| **A line with no upstream and no pattern** | "Depends on" says nothing about who adapts to whom | Upstream marked; pattern and reason from `context-map-patterns` |
| **A boundary with no evidence** | A preference dressed as a model | Cite the word, the hint or the ownership split |
