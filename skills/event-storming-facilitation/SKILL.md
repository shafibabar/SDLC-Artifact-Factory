---
name: event-storming-facilitation
description: >
  Run Event Storming to model a product's domain before any architecture:
  the Big Picture, Process Modelling (also called Process Level) and
  Software Design (also called Design Level) formats, which to run for which
  question, and what each produces. Covers the Big Picture phases (chaotic
  exploration, enforcing the timeline, people and systems, the walkthrough
  and reverse narrative, problems and opportunities, voting on hotspots);
  pivotal events and swimlanes as Bounded Context hints, including at lean
  where only the Big Picture runs; the Process Modelling chain that every
  path must complete; aggregates as consistency units, a different boundary
  from a Bounded Context; hotspots as a main output routed to the product
  owner; and agent-run mode, a hypothesis wall built from named artifacts
  with every card cited or labelled an assumption. Use when modelling a
  domain from documents or in a workshop, when /sdlc-design or
  /sdlc-event-storm runs, or when asked to "event storm" a product. Used by
  domain-modeler.
version: 3.0.0
phase: design
owner: domain-modeler
created: 2026-06-25
tags: [design, domain-modeling, event-storming, facilitation, big-picture, process-modelling, software-design, hotspot, agent-run, brandolini]
produces: event-storming-session
domain: domain-modeling
status: stable
related: [subdomain-distillation, ubiquitous-language, domain-storytelling, bounded-context-mapping, aggregate-design, domain-event-catalog, command-catalog, read-model-design]
sources:
  - research/domain-driven-design/introducing-eventstorming-brandolini.md
  - research/domain-driven-design/strategic-design-supplement.md
  - research/domain-driven-design/implementing-ddd-vernon.md
  - research/domain-driven-design/learning-ddd-khononov.md
---

# Event Storming Facilitation

## Purpose

Event Storming (Alberto Brandolini, *Introducing EventStorming*) builds a shared model of a domain by putting **Domain Events**, business facts in the past tense, on a timeline, then adding what causes them and what reacts to them. Brandolini's point is that software encodes the developers' understanding of the domain, gaps included. The workshop puts the people with questions and the people with answers in front of one wall, so the gaps show.

Event Storming is mandatory at Design in this plugin, at every profile (CLAUDE.md). No Bounded Context is drawn and no architecture decided before the Big Picture exists. This skill holds the method; the domain-modeler applies it.

## 1. Agent-Run Mode First (D047-8)

The domain-modeler usually runs Design with nobody else in the room, so the normal case is **agent-run mode**: a *hypothesis wall* built from named artifacts. It is this plugin's adaptation, not Brandolini's method, which assumes the right people are present. So be honest about what it loses:

1. **Every card cites its source:** the artifact it came from (`ideate/job-stories.md`, `strategy/vision.md`, a persona), or it is labelled **assumed**. An event no artifact supports is never presented as a fact.
2. **Stand in for the many authors.** Chaotic exploration works because many people write at once. Sweep the domain from each persona's and stakeholder's point of view in the artifacts, one at a time.
3. **Ask for the unhappy paths:** "what goes wrong here?", "what if nobody acts?". Then run the timeline backwards from the end to find missing events.
4. **Hotspots become open questions for the product owner** at the domain-modeler's review gate, each with the assumption used meanwhile. None is marked resolved without an answer.

**What it can't claim:** shared understanding, resolved disagreements, or knowledge no document contains. A real session stays optional. When held, it replaces the assumptions it confirms. Procedure in full: `./references/agent-run-mode.md`.

## 2. Pick the Format from the Question

| Format (alias) | The question | Room, if held | Produces | Profiles |
|---|---|---|---|---|
| **Big Picture** | What does the business look like end to end, and where does it hurt? | Large and mixed: experts from every department, decision makers, technical people | Timeline, pivotal events, swimlanes, people and systems, ranked hotspots, boundary hints | All, lean included (timeboxed) |
| **Process Modelling** (Process Level) | How should this one process work? | The people who run it, change it and build it | One process with every path complete | Standard, enterprise: optional, for the processes the vote picks |
| **Software Design** (Design Level) | What software units carry these rules? | Mostly developers, experts on hand | Consistency units (aggregates), read models, policies, Bounded Context candidates confirmed | Standard, enterprise: required |

Never run Software Design on a process nobody has modelled: the boundaries would come from preference, and the session would only ratify a decision already made.

## 3. Big Picture

The phases, in order (Brandolini):

1. **Chaotic exploration:** orange events only, written in parallel, no order, no debate. Volume first, failures and timeouts included.
2. **Enforce the timeline:** order left to right, remove duplicates, settle near-duplicates. Mark **pivotal events** (the few that mark a change of phase) and **swimlanes** (parallel flows).
3. **People and systems:** add actors and external systems where they cause or receive events.
4. **Walkthrough:** tell the story aloud along the timeline and correct it; then the **reverse narrative**, end to start, to find missing events.
5. **Problems and opportunities:** hotspots for pain, risk and disagreement; opportunities for ideas.
6. **Pick the problem:** each participant places a few votes on hotspots. In agent-run mode the agent ranks them and states why. The top hotspots and the pivotal events choose what goes to Process Modelling.

Notation is added step by step (incremental notation): orange first, the rest as the session needs it.

**Boundary hints, at every profile.** The Big Picture suggests boundaries without drawing them: pivotal events, swimlanes, a change of actors, and a word that starts to mean something else. Record each hint as a **Bounded Context candidate with its evidence**. At lean, where only the Big Picture runs, these hints *are* how the candidates are found, so they are never skipped. They are candidates, not decisions; `bounded-context-mapping` confirms them. Subdomain classification follows straight after (`subdomain-distillation`, D047-14). Don't name aggregates in a Big Picture, and don't supply them under another name: no consistency units, no table of rules or invariants per area, no advice on where engineering can start building. They belong to Software Design, after a process has been modelled. A boundary candidate carries evidence (pivotal events, actors, words), not invariants. A rule you notice goes on the wall as a hotspot or, later, a policy.

## 4. Process Modelling

One process, end to end, with the stricter grammar. **The picture that explains everything:** an actor looks at a read model and issues a command; the command reaches a system, which produces an event; a policy reacts to the event and issues the next command; new events update the read models. **Every path must reach a stable end**, with each element in its place. A break in the chain is a hotspot to ask about, never a gap to fill silently. Policies are written "whenever [event], then [command]", including policies a person carries out by hand.

Build the chain **right to left**, from each event, asking in turn: what command caused this? Who issued it, or did a policy react to another event? What did they look at to decide (a read model)? Does an external system produce or receive it? An event with no cause, or a command with no actor and no policy, is a break.

## 5. Software Design: Two Boundaries, Two Forces

The modelled process becomes software units. Two kinds of boundary, shaped by different forces, so one line must not answer both questions:

- An **aggregate** (Brandolini's consistency unit) is a **transactional-consistency** boundary: the smallest set of commands and events that must hold one true invariant at every instant (Vernon, *Implementing DDD*, Ch. 10). Small, referenced by identity, updated by others through Domain Events.
- A **Bounded Context** is a **linguistic and model** boundary: it sits where a term's meaning changes (Khononov, *Learning DDD*). Many aggregates nest in one context.

"One aggregate per Bounded Context" confuses the two. The criteria for aggregates belong to `aggregate-design`; for contexts, to `bounded-context-mapping`. This skill surfaces the candidates with their evidence: the invariant for an aggregate, the language change for a context.

## 6. Hotspots Are a Main Output

A hotspot marks missing knowledge, disagreement or pain. Record it and keep going; never let the loudest voice settle it. The ranked hotspot list is often the most useful thing a Big Picture produces. Where each goes:

| Hotspot | Goes to |
|---|---|
| A disputed or unclear word | An open language question in `ubiquitous-language` |
| A business rule or fact nobody knows | An open question for the product owner at the review gate |
| A risk to quality attributes (scale, availability, security) | `architecture-evaluation`'s risks and scenarios |
| A scope dispute | The product owner |
| An opportunity | The backlog, via the requirements-analyst |

## 7. Notation

The plugin's legend, a **house choice**: colours vary between Brandolini's editions and practitioners, and what matters is one legend used consistently. Transcripts record the element type, so the colour never carries meaning on its own.

| Element | Colour (house) | Format |
|---|---|---|
| Domain Event | Orange | All |
| Hotspot | Magenta, turned 45° | All |
| Actor | Small yellow | All |
| External system | Large pink | All |
| Opportunity | Green, marked "+" | Big Picture |
| Command | Blue | Process Modelling, Software Design |
| Policy | Lilac | Process Modelling, Software Design |
| Read Model | Green | Process Modelling, Software Design |
| Aggregate (consistency unit) | Large pale yellow | Software Design only |

Each element in depth, naming rules ("`BookingConfirmed`", not "`RowInserted`") and the entry and exit criteria per format: `./references/notation-and-formats.md`. Running a real session (people, space, timeboxes, remote): `./references/facilitation-guide.md`.

## Running It: Plan, Build, Validate

Copy `./resources/session-checklist.md` and tick it as you go.

1. **Plan.** Read `sdlc-context.json` and the product's manifest for the profile, then list the input artifacts. Decide the formats from § 2: Big Picture always; Process Modelling for the processes the hotspot vote picks; Software Design at standard and enterprise. Agent-run unless the product owner holds a session.
2. **Big Picture.** Run the phases in § 3 (agent-run: `./references/agent-run-mode.md` § 2). Fill `./templates/big-picture.md` and write it to `design/event-storming/big-picture.md`.
3. **Validate, then loop.** Run `./scripts/validate-event-storming.sh design/event-storming/big-picture.md`. Fix every FAIL, read every WARN, and run it again until it exits clean. Then go through the checklist items the script can't judge.
4. **Hand on.** Subdomain classification is next (`subdomain-distillation`), then the processes chosen for Process Modelling.
5. **Process Modelling,** one process at a time: build the chain right to left (§ 4), fill `./templates/process-modelling.md` as `process-<name>.md`, validate and loop as in step 3.
6. **Software Design:** fill `./templates/software-design.md` as `design-level.md`, validate and loop.
7. **Present** at the domain-modeler's review gate: the mode, how many cards are *assumed*, the boundary candidates, and the ranked hotspots as questions.

| Output | Feeds |
|---|---|
| Timeline, pivotal events, boundary hints | `subdomain-distillation`, then `bounded-context-mapping` |
| Domain Events | `domain-event-catalog` |
| Commands; Read Models | `command-catalog`; `read-model-design` |
| Aggregate candidates with invariants | `aggregate-design` |
| Words and disputed words | `ubiquitous-language` |
| Hotspots | § 6 |

Worked cases, simplest to hardest: `./examples/01-lean-food-truck-big-picture.md` (Big Picture only, agent-run, boundary candidates from pivotal events), `./examples/02-standard-rental-process-modelling.md` (one process with an external payment system and breaks in the chain), `./examples/03-enterprise-warranty-software-design.md` (several regions, aggregates versus contexts, hotspots routed). Transcribe the same day; an untranscribed wall decays.

## Gotchas

- **Asked for aggregates from a Big Picture.** "So engineering can start straight away." Don't hand them over under another name either: a table of "rules each area must respect" or "start building here" is aggregates in disguise. Say aggregates come from Software Design, after Process Modelling, and name the processes to model next.
- **Asked for code in a design session.** The user asks for Go structs (or any code) "so the backend can start". Design skills are stack-neutral (D047-10): give the aggregates as tables of commands, events and invariants, and say the code comes in Implement from the `go-*` skills. Don't add code "as a candidate".
- **Writing up an agent-run wall as "the agreed outcome".** Nobody agreed to it. Say it is a hypothesis from documents and how many cards are *assumed*, even when asked to circulate it as settled.
- **"Make a reasonable guess and mark it resolved."** A guessed hotspot answer hardens into a business rule. Record the assumption used meanwhile and keep the hotspot open for the product owner.
- **Skipping boundaries "because lean only runs the Big Picture".** That's exactly why the Big Picture must yield candidates at lean.
- **Dropping hotspots as clutter.** They are the most useful output; rank and route them.
- **Designing a flow that hasn't been modelled.** Asked for aggregates on a flow with no Process Modelling, decline and send it to Process Modelling; anything said about it is provisional.
- **Filling a break in the chain "to make the diagram complete".** A sensible-looking policy is still an invented rule. Leave the break as a hotspot.

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **An agent-run wall presented as a workshop** | Invented events read as facts; assumptions pass the gate | Cite each card or label it *assumed*; hotspots to the product owner |
| **No boundary candidates at lean** | The lean profile then has no way to find contexts | Pivotal events, swimlanes, actor and language changes, with evidence |
| **Aggregates in the Big Picture** | Design decided before the process is understood | Consistency units in Software Design only |
| **One aggregate per Bounded Context** | Two different forces forced onto one line | Invariant for aggregates; language for contexts |
| **Hotspots tidied away or settled by authority** | Loses the most useful output | Record, rank, route (§ 6) |
| **A gap in the chain filled silently** | A guessed command or policy hardens into the model | Every break is a hotspot |
| **Technical events** (`RowInserted`, `MessagePublished`) | The wall describes the database, not the business | Past-tense business facts |
| **Sorting by entity** ("all the order events here") | Rebuilds a data model and destroys the timeline that shows cause and effect | Keep the timeline in time order; group only into swimlanes of parallel flow |
