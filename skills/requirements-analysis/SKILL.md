---
name: requirements-analysis
description: >
  Teaches how to write the functional requirements document (FRD) in Ideate,
  after the impact map: classify every input (Wiegers and Beatty's business,
  user and functional requirements, plus business rules, constraints, quality
  attributes, external interfaces, data and transition requirements), turn
  stakeholder wants and solution ideas into needs with a why-chain and a
  necessity test, and write each requirement with a rationale, a testable fit
  criterion and a provisional priority, traced to a selected-path deliverable
  on the impact map and to a job statement and the job story beneath it. Use
  when writing, reviewing or splitting functional requirements, turning a
  stakeholder request into a requirement, writing fit criteria or acceptance
  conditions for a requirement, cataloguing business rules, planning data
  migration, cutover or training for a replacement, or tracing requirements to
  goals. Used by the requirements-analyst agent in Ideate (/sdlc-ideate) after
  the impact map and before the NFR specification; required at standard and
  enterprise, replaced by the user story backlog at lean.
version: 2.0.0
phase: ideate
owner: requirements-analyst
created: 2026-06-24
tags: [ideate, requirements, functional-requirements, frd, fit-criteria, business-rules, transition-requirements, traceability]
produces: functional-requirements-document
domain: discovery
status: stable
related: [impact-mapping, opportunity-solution-tree, jtbd-analysis, user-persona, okr-authoring, strategy-kernel, vision-statement, stakeholder-mapping, competitive-analysis, nfr-specification, epic-definition, user-story-writing, acceptance-criteria, moscow-prioritization, glossary-management, methodology-review]
sources:
  - research/requirements-and-user-stories/software-requirements-wiegers-beatty.md
  - research/requirements-and-user-stories/it-requirements-lean-agile-hathaway.md
  - research/requirements-and-user-stories/user-stories-applied-cohn.md
  - research/requirements-and-user-stories/impact-mapping-adzic.md
  - research/product-strategy-and-gtm/the-mom-test-fitzpatrick.md
  - research/product-strategy-and-gtm/product-management-in-practice-lemay.md
---

# Requirements Analysis

## Purpose

The functional requirements document (FRD) answers: **what must the product let each user class do, and how will we know each requirement is met?** It turns the bet chosen on the impact map, and the jobs behind it, into requirements precise enough for Design to act on without asking again. Lemay (*Product Management in Practice*) calls this the connective work of product management: name the translation. Here the input is the impact map's selected path plus the JTBD analysis. The audiences are `nfr-specification`, `epic-definition` and the Design-phase agents.

The FRD states **what must be true**, not how. Cohn (*User Stories Applied*) warns that a fully specified document turns stories into transcription, so the conversation never happens. Detail that belongs to a story's conversation or to the architecture stays out.

## Where It Sits

```
Ideate: personas ─► JTBD ─► opportunity solution tree ─► impact map ─► FUNCTIONAL REQUIREMENTS ─► NFRs ─► epics ─► stories … ─► story map ─► MoSCoW
```

| Reads | What it takes |
|---|---|
| `impact-mapping` | The **selected path**: each selected deliverable (SOL-n or named option) and the impact it is meant to cause. Option branches are not requirements |
| `jtbd-analysis` | Job statements (J-n) and the job stories beneath them (JS-n.m); onboarding requirements from the Little Hire |
| `user-persona` | User classes and their personas; at lean, the persona's folded-in job statement and job stories |
| `okr-authoring`, `strategy-kernel`, `vision-statement` | The business requirements: cited by ID, never rewritten |
| `stakeholder-mapping`, `competitive-analysis` | Stakeholder concerns; table-stakes capabilities (a valid source) |

| Feeds | What it gives |
|---|---|
| `nfr-specification` | The **quality-attribute hand-off list**: each quality concern found, with the FRs it constrains. Targets are set there, never here |
| `epic-definition`, `user-story-writing` | User requirements grouped by deliverable become candidate epics; FRs become stories' substance |
| `acceptance-criteria` | Each fit criterion seeds the Given/When/Then of the stories that carry it |
| `moscow-prioritization` | The provisional priority. MoSCoW finalises it at the end of Ideate |

**Why the map comes first.** Adzic (*Impact Mapping*) puts goal → map → scope. Requirements written first invite drawing the map backwards to justify them. If requirements already exist when the map is drawn, check each one against the map rather than mapping from them. At standard, where the map is optional and was not produced, each user requirement traces to the Key Result directly.

## One Taxonomy: Classify Before Writing

Wiegers and Beatty (*Software Requirements*) give three **levels**: **business** requirements (why: objectives and success measures, already in the Strategy artifacts), **user** requirements (what users must be able to do) and **functional** requirements (what the software must do so they can). Other **types** sit beside the levels: **business rules**, **constraints**, **quality attributes**, **external interfaces** and **data requirements**. The Hathaways (*Getting and Writing IT Requirements in a Lean and Agile World*) add the type most often forgotten: **transition requirements**, the one-time work of moving from today's tool to the new one.

| Input | Goes to |
|---|---|
| A goal or success measure | Cited from the OKR set, not restated |
| What a user class must be able to do | User requirement (UR-n), traced to a deliverable and a job story |
| What the software must do for that | Functional requirement (FR-n.m) under its UR, with a fit criterion |
| A policy, regulation, formula or fact true without any software | Business rule (BR-n), catalogued once and cited by FRs |
| How well, how fast, how available, how secure | Quality-attribute hand-off to `nfr-specification` |
| A limit imposed from outside (customer, regulator, contract) | Constraint (CON-n), with who imposed it |
| A widget, screen, technology or vendor someone asked for | **Solution idea**: run the why-chain, record the need |
| Data migration, cutover, parallel run, training, decommission | Transition requirement (TR-n) |
| Something believed but not known | Assumption log (ASM-n), never a requirement |
| A question nobody can answer yet | TBD list, tied to the requirement it blocks |

**Wants are not requirements.** Stakeholders describe solutions ("a dropdown that emails the report to my boss"). Ask why until the answer names a capability or an outcome, not a UI element or a vendor (the Hathaways' why-chain; Wiegers' solution-idea bucket). When the person who said it cannot be asked now, write the most likely need as a hypothesis (an assumption) with the why-question for the user to put to them; never park the want with no need stated, and never adopt the solution as the requirement. Then apply the **necessity test**: what happens if we don't build this? Nothing consequential means it is a preference: it goes to the waiting room, not the FRD.

The levels and types in full, the business-rule taxonomy, user classes and the why-chain with worked wants: `./references/requirement-types-and-classification.md`. Read it before the classification pass and whenever an input fits no row.

## Evidence: Elicit From What Exists, Never Invent It

The agent has no stakeholders in a room. Its sources are the written artifacts, interview snapshots the user supplied, and the user. So:

- **Never simulate an interview.** A requirement is never attributed to a conversation that did not happen. Reasoning about what an unheard stakeholder probably needs is written as an **assumption** (ASM-n) with the question that would confirm it (Fitzpatrick, *The Mom Test*: a past specific beats an imagined opinion).
- **Pick techniques by situation, not a fixed order.** Document analysis of the Strategy and Ideate artifacts always runs. Existing-system and data analysis runs when something is being replaced (even a spreadsheet). Asking the user runs for every gap: the user is the **product champion** for every user class unless a design partner is named.
- **A customer's feature idea is evidence of a problem**, not a spec. Record the problem behind it.

Technique selection and how to label each source: `./references/elicitation-and-evidence.md`. Read it before eliciting, and whenever the user asks for interviews, workshops or "what stakeholders want".

## Writing Each Requirement

Each functional requirement is one verifiable behaviour, from the user's or the system's point of view (Wiegers allows either; pick one style per document). It carries the Volere shell's core fields (the Robertsons, *Mastering the Requirements Process*, via the Wiegers research file):

| Field | Rule |
|---|---|
| **Statement** | One behaviour. "And" joining two capabilities means two FRs. No technology unless it is a real constraint |
| **Rationale** | Why it exists: the impact or job story it serves |
| **Fit criterion** | Measurable pass/fail, precise enough for a tester: who, what input, what observable result, how many. If none can be written yet, the requirement is not understood: it stays on the TBD list, not in the requirements table |
| **Traces to** | On its UR: a selected-path deliverable **and** a job statement → the job story beneath it (and the KR) |
| **Rules / NFRs** | BR-n it implements; quality concern handed to `nfr-specification` |
| **Priority (provisional)** | high / medium / low from value and penalty (Wiegers); **finalised by `moscow-prioritization`**. Never Must / Should / Could / Won't here |
| **Status** | proposed → approved (baseline) → implemented → verified |

**A performance or availability number is not a functional requirement.** "Classify each file within 30 minutes" is two things: the FR (classify each file) and a quality attribute (30 minutes) that `nfr-specification` owns. Write the FR with a functional fit criterion and hand the number off.

Sweep every draft for ambiguous words ("fast", "user-friendly", "flexible", "support", "etc.", "and/or", "as appropriate"). Each is replaced with a number and a condition, or moved to the TBD list.

Fit criteria, the shell in full, provisional priority, the waiting room, baseline and change control: `./references/requirement-shell-and-fit-criteria.md`. Read it before writing the first FR, and when a fit criterion will not come.

## Producing the Artifact

1. **Check the profile** (Scale, below). At lean, write no FRD.
2. **Read** the impact map's selected path (or, with no map, the KR), the JTBD analysis, personas, OKRs, stakeholder map and competitive analysis. If the map or JTBD analysis the profile requires is missing, stop and say so.
3. **Name the translation**: one line saying which inputs become which requirements for which consumers.
4. **Classify** every input; run the why-chain on each solution idea and the necessity test on each candidate.
5. **List user classes** (favoured, disfavoured, ignored) with their champion.
6. **Write URs per selected deliverable**, each with its traces, then the **FRs** beneath them with fit criteria.
7. **Catalogue** business rules, constraints, external interfaces, data and **transition requirements** (a replacement always has some; greenfield says "none, because …").
8. **Hand off quality attributes**; log assumptions, TBDs and the waiting room.
9. **Validate** against `./resources/frd-checklist.md` and run `python3 ./scripts/check-frd.py <artifact>`.
10. **Write** from `./templates/functional-requirements-document.md` to `ideate/requirements.md`, present it, and on approval it becomes the baseline. A later change is a change request with an impact note.

## Scale

`phase-requirements.json`: FRD **skipped** at lean, **required** at standard and enterprise. The Robertsons' advice applies: fit the formality to the project.

| Profile | Shape |
|---|---|
| **lean** | **No FRD.** The user story backlog is the functional requirements: a short header on `ideate/user-stories.md` holds scope and exclusions, business rules and any transition lines; each story traces to the KR and a persona's job story; its acceptance criteria are its fit criteria. If asked for an FRD at lean, say so and write that header instead: `./examples/01-lean-makerspace-loans.md` |
| **standard** | One FRD: user classes, URs per selected deliverable with FRs and fit criteria, business rules, constraints, transition requirements, quality-attribute hand-off, assumption log, TBD list, waiting room, backward traceability: `./examples/02-standard-clinic-reminders.md` |
| **enterprise** | Adds per-tenant and disfavoured user classes, a typed business-rules catalogue with sources, external interfaces and data requirements, a transition plan per tenant (migration, parallel run, decommission), forward traceability (FR → story → acceptance criteria → test, filled as they are written), stakeholder conflicts recorded for the user to decide, and a baseline with a change log: `./examples/03-enterprise-council-permits.md` |

## Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| **Requirements before the map** | The map is then drawn backwards to justify them (Adzic) |
| **Option deliverables as requirements** | Only the selected path is in scope; options wait on the map |
| **Solution smuggled in** | "Store it in PostgreSQL", "a dropdown": a design choice dressed as a need |
| **Compound requirement** | One failing test cannot say which capability failed |
| **NFR inside an FR** | The number has no owner, and `nfr-specification` duplicates or contradicts it |
| **"Test:" with no fit criterion** | Names a test type, not what passes |
| **MoSCoW at FRD time** | Pre-empts `moscow-prioritization`, which runs last |
| **Simulated interviews** | Invented evidence reads as real; label it an assumption |
| **No transition requirements** | Migration, training and cutover surface on launch day |
| **Default stack as a constraint** | A configured default is a decision, not a limit imposed from outside |
| **A rule restated in many FRs** | Catalogue it once as BR-n and cite it |
| **Product rules as skill rules** | A compliance rule belongs in that product's FRD, not every product's |

Use canonical terms from `glossary-management`: **Business Requirement**, **User Requirement**, **Functional Requirement**, **Business Rule**, **Quality Attribute**, **Fit Criterion**, **Transition Requirement**, **User Class**, **Solution Idea**, **Provisional Priority**, **TBD List**, **Waiting Room**, **Requirements Baseline**, **Selected Path**, **Job Statement**, **Job Story**. Run `methodology-review` before hand-off.
