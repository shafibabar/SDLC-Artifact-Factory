---
name: subdomain-distillation
description: >
  Classify a product's subdomains as Core, Supporting or Generic and decide
  where design effort, building and buying go. Covers finding subdomains by
  splitting business capabilities from coarse to fine until each piece has
  one type; Khononov's tests (competitive advantage, complexity, already
  solved elsewhere); why "hard" is not "Core" and "simple" is not Core;
  buy or adopt for Generic, a cheap build or outsourcing for Supporting,
  in-house for Core; dating a classification and revisiting it; a
  security-sensitive slice that needs Core-level rigor inside a Generic or
  Supporting subdomain; the Domain Vision Statement and Highlighted Core;
  and, for an existing system, which subdomain to transform first and which
  Generic ones to replace. Use when classifying subdomains after Event
  Storming Big Picture, deciding build versus buy, asking whether something
  is Core, or prioritising a legacy modernisation. Used by domain-modeler;
  produces the subdomain-classification artifact.
version: 3.1.0
phase: design
owner: domain-modeler
created: 2026-07-22
tags: [design, ddd, strategic-design, subdomain, distillation, core-domain, build-vs-buy, security, legacy]
produces: subdomain-classification
domain: domain-modeling
status: stable
related: [event-storming-facilitation, bounded-context-mapping, aggregate-design, ddd-agent-handoff, ubiquitous-language, vision-statement, strategy-kernel, access-control-model, container-diagram]
sources:
  - research/domain-driven-design/strategic-design-supplement.md
  - research/domain-driven-design/domain-driven-design-evans.md
  - research/domain-driven-design/learning-ddd-khononov.md
  - research/security/secure-by-design.md
  - research/software-architecture/building-microservices-newman.md
---

# Subdomain Distillation

## Purpose

Not every part of a product deserves the same effort. Evans (*Domain-Driven Design*, Ch. 15, "Distillation") argues that keeping the Core Domain small, and putting the best effort on it rather than on generic parts, is one of the most important strategic choices a team makes. This skill classifies each **subdomain**, a part of what the business does, as Core, Supporting or Generic, and records why.

A subdomain belongs to the **problem space**: it exists whether or not software is built. A Bounded Context belongs to the **solution space**: it is a modelling choice (Vernon; Khononov). Subdomains are *discovered*; Bounded Contexts are *designed*. The two can map one-to-one, but nothing forces them to, and a subdomain is not a microservice. Contexts are drawn afterwards, by `bounded-context-mapping`.

**When it runs (D047-14):** straight after Event Storming Big Picture, before contexts are drawn. The domain-modeler writes `artifacts/<product>/design/subdomain-classification.md` and presents it at its first review gate with the Event Storming findings.

**Asked to classify without a Big Picture** (from a feature list, to save time): the step runs on the Big Picture's output, and the Big Picture is required at every profile, lean included. It needs no workshop: in agent-run mode the domain-modeler builds it from the Ideate artifacts (`event-storming-facilitation`). So run it first. If a table is given before it, every label is marked **provisional** until the Big Picture confirms it, and the reply says which labels it might change. Feature headings are a product's menu, not its subdomains.

## 1. Find the Subdomains: Coarse to Fine

Khononov (*Learning Domain-Driven Design*, Ch. 1):

1. Start from the business capabilities the Big Picture shows (the pivotal events and swimlanes are good hints), or from the company's departments.
2. Split a capability into finer subdomains **while the parts would get different types**.
3. Stop when further splitting gives only sets of use cases of the same type.

Stopping matters as much as splitting. Split a capability only where a part gets a *different* type, and keep the same-type rest together: "membership records, inspections and the treasurer's report" is one Supporting subdomain, not three rows. A table with one row per feature has split too far.

"Logistics" is too coarse to classify: it holds route optimisation (perhaps Core), driver payroll (Generic) and depot scheduling (Supporting). Classify the pieces, not the heading.

## 2. Classify Each One

Khononov's three tests, asked together:

| Type | Competitive advantage? | Complex? | Solved elsewhere? | Where the effort goes |
|---|---|---|---|---|
| **Core** | Yes: customers choose the product for it | Yes. A simple capability is easy to copy, so it gives no lasting advantage | No | Built in-house by the strongest people. Richest modelling: a **Domain Model** (Aggregates, Domain Events), deepest Event Storming |
| **Generic** | No | Yes, but already solved: everyone needs it the same way | Yes | **Buy or adopt** (a product, a library, a published model). Evans also lists outsourcing, or a minimal in-house build. Modelling: a thin integration, behind a translation where its model doesn't fit |
| **Supporting** | No | No: often plain data entry or moving data around | No (too specific to buy) | **Build cheaply** in-house, or **outsource the build**. Modelling: the simplest pattern that works, usually **Transaction Script** or **Active Record** |

Three traps, each a common mistake:

- **"It's hard, so it's Core."** Complexity and advantage are separate questions. A complex capability with no advantage is Generic if a solution exists and Supporting if not. The hardest code in a product is often a parser, an integration or a sync engine, and customers don't choose the product for any of them.
- **"It's simple, but it's what we sell, so it's Core."** A simple capability can't be Core (Khononov): competitors copy it in a sprint. Look for the real Core elsewhere, often a richer set of rules the simple feature sits on top of.
- **"Would you outsource it?" as the type test.** Outsourcing fits Supporting (Khononov), and Evans lists it among the Generic options too, so the answer doesn't decide the type. Classify on the three tests first; the sourcing choice follows from the type.

Expect few Core subdomains. If most of a product comes out Core, rerun the tests more sceptically. When unsure between Core and Supporting, record Supporting with the open question, rather than giving everything the most expensive treatment.

The full tests with probing questions, and what each type means for modelling: `./references/classification-techniques.md` § 1–3.

## 3. What the Type Decides

- **Effort and people:** the Core gets the most design attention and the most careful review; Generic gets as little as possible.
- **Build or buy:** as in the table. A Generic subdomain built from scratch is effort spent where no customer will notice.
- **How rich the business logic is:** the type is a *necessary* input to `aggregate-design`'s choice of business-logic pattern (Transaction Script, Active Record, Domain Model, Event-Sourced Domain Model), not a sufficient one. That choice is made per Aggregate or use case. Domain-Driven Design still applies everywhere (CLAUDE.md): the language and the boundaries are never skipped, only the tactical machinery is scaled.
- **How wide its context starts:** the Core's model is the least stable, so the Bounded Context around it starts wide and is split once the model settles. Splitting early and wrongly costs far more than splitting late, and a context need not be a microservice (Khononov). The contexts themselves are drawn by `bounded-context-mapping`.
- **How agents work together:** `ddd-agent-handoff` reads the type to choose the interaction mode.

## 4. Security Is a Separate Axis

The type answers *how much advantage does this create?* It doesn't answer *what happens if the model is wrong here?* Secure by Design (Ch. 3) treats security sensitivity as a separate axis, rated alongside the type. A Generic identity subdomain is bought, but how this product's roles, tenants and records decide who may see what is product-specific, and a mistake there is a breach. That **slice** gets Core-level rigor (Domain Primitives, explicit trust boundaries) even though the subdomain stays Generic. The rest follows the type. Checklist and techniques: `./references/security-sensitive-subdomains.md`.

## 5. Date It and Revisit It

A classification is a hypothesis with a date (Khononov Ch. 11). Types change: a Core capability becomes Generic once the market catches up and products appear; a Supporting one becomes Core when the strategy moves. Record the date, the evidence for each label, and what would change it. Revisit when that trigger fires, at each new release's Design phase, or when the strategy changes (`strategy-kernel`).

## 6. Make the Core Visible

Evans's distillation tools, written into the artifact at standard and enterprise:

- **Domain Vision Statement:** about a page on what the Core Domain is and what value its model brings. It describes the model, not the product's market position (that is `vision-statement`).
- **Highlighted Core:** which Bounded Contexts, Aggregates and terms carry the Core, flagged so anyone can tell.

For an already-built system whose Core is tangled with generic code, or has grown too large to reason about, Evans's **Segregated Core** and **Abstract Core** apply: `./references/classification-techniques.md` § 4.

## 7. Existing Systems

For a system that already exists, the classification also decides **order**: which subdomain to transform first, which to leave, and which Generic ones to replace with a product rather than migrate. Newman's Strangler Fig (*Building Microservices*) is how the chosen piece is moved while the old system keeps running. Sequencing rules and mechanics: `./references/legacy-transformation-guidance.md`.

## Scale

| Profile | The artifact |
|---|---|
| `lean` | A short table, but every row still answers the three tests briefly (yes/no with a few words of evidence), and gives the sourcing, the modelling approach, the security flag and a revisit trigger, with the date. Usually one Core, everything else bought or kept simple |
| `standard` | The table with evidence per label, the revisit triggers, a Domain Vision Statement and Highlighted Core |
| `enterprise` | As standard, plus the security-sensitive slices named with their rigor, and, for an existing system, the transformation order |

## Producing the Artifact

Copy `./resources/classification-checklist.md` and tick it as you go.

1. **Read** the Event Storming Big Picture (`design/event-storming/big-picture.md`), the vision and the strategy kernel. No Big Picture yet: run it first (agent-run needs no workshop), or mark every label provisional.
2. **Split** the Big Picture's capabilities coarse to fine (§ 1), stopping where the parts share one type. Same-type siblings stay one row.
3. **Classify** each piece on all three tests with evidence (§ 2); set sourcing and modelling from the type; run the security checklist (§ 4); add a revisit trigger and the date (§ 5).
4. **Write** `design/subdomain-classification.md` from `./templates/subdomain-classification.md`. At standard and enterprise, add the Domain Vision Statement and Highlighted Core (§ 6).
5. **Validate, then loop.** Run `./scripts/validate-subdomain-classification.sh design/subdomain-classification.md`. Fix every FAIL, read every WARN (more than two Core, or none), and run it again until it exits clean. Then go through the checklist items the script can't judge.
6. **Present** at the review gate with the Event Storming findings, disputed labels as open questions.

**An existing system's transformation order: plan, validate, execute.** Starting the wrong piece first is costly to undo, so:
1. **Plan:** fill the Transformation Order table (`./references/legacy-transformation-guidance.md` § 4), citing the sequencing rule behind each position.
2. **Validate the plan:** the first piece is Core with bounded risk; every Generic subdomain is marked Replace or has a stated reason not to be; a tangled Core has Segregated Core as its first step; each move names its Strangler Fig mechanic. Present disputed positions to the product owner, a business-priority call.
3. **Execute** only the first piece, then re-run the plan with what was learned. The order is revisited after each move, not fixed up front.

Worked cases, simplest to hardest: `./examples/01-lean-volunteer-rota.md` (one Core, the rest bought), `./examples/02-standard-route-planning.md` ("the hardest code is Core" corrected, and a simple feature that isn't Core), `./examples/03-enterprise-loan-origination-legacy.md` (an existing system, a security slice inside Generic identity, transformation order).

## Gotchas

- **Classifying from a feature list "to save time".** The step runs on the Big Picture. Run it first (agent-run needs no workshop) or mark every label provisional. Feature headings are a menu, not subdomains.
- **One row per feature.** Splitting goes only as far as types differ; "membership records, inspections and the treasurer's report" is one Supporting row.
- **One-line reasons.** Even at lean, each row answers all three tests briefly. A bare "simple record keeping" is a conclusion, not evidence.
- **Saying where effort goes but not how it is built.** Each row states the modelling: a Domain Model for Core, Transaction Script or Active Record for Supporting, a thin integration for Generic.
- **"It's outsourced, so it's Generic."** Outsourcing the build fits Supporting. Generic means something already exists to buy or adopt.
- **"Lock the classification for good."** It has a date and a revisit trigger, because types move as markets do.

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Hard = Core** | Effort goes to the difficult part customers don't choose the product for | The three tests; complexity alone decides nothing |
| **Everything is Core** | No focus; the expensive treatment everywhere | Expect one or two Core subdomains; rerun sceptically |
| **Classifying the heading** ("Logistics: Core") | Mixed types under one label | Split coarse to fine until each piece has one type |
| **Subdomain = Bounded Context = service** | Problem space and solution space confused; boundaries forced | Classify subdomains; draw contexts afterwards (`bounded-context-mapping`); services in `container-diagram` |
| **Generic means no thought** | A security mistake in the product-specific slice of a bought subdomain | Rate the security axis separately; the slice gets Core-level rigor |
| **Classified once, never revisited** | The label goes stale as the market moves | A date, evidence and a revisit trigger per label |
| **Classifying before Event Storming** | Labels from guesses about what the business does | Classify from the Big Picture (D047-14) |
