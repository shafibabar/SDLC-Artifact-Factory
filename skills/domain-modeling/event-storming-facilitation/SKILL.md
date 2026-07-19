---
name: event-storming-facilitation
description: >
  Teaches how to run a full Event Storming session — from Big Picture through
  Process Level to Design Level — including the card taxonomy, facilitation
  sequence, hotspot identification, bounded context discovery, and how to
  produce a session output that feeds directly into the domain-event-catalog,
  bounded-context-mapping, and aggregate-design skills. Event Storming is
  mandatory at the Design phase for every domain and subdomain. Used by the
  domain-modeler agent when /sdlc-design or /sdlc-event-storm is invoked.
version: 1.1.0
phase: design
owner: domain-modeler
created: 2026-06-25
tags: [design, event-storming, ddd, bounded-context, domain-events, mandatory]
---

# Event Storming Facilitation

## Purpose

Event Storming (Alberto Brandolini) is a collaborative modelling technique that surfaces domain knowledge by mapping Domain Events — things that happened in the domain — across time, left to right. It is the fastest way to build a shared understanding of a complex domain without committing to implementation details.

Event Storming is **mandatory** in this plugin. No architecture decisions are made, no bounded contexts are drawn, and no service designs are produced without first completing an Event Storming session for the relevant domain.

---

## Three Levels of Event Storming

Run the levels in order. Do not skip to Design Level without completing Big Picture.

| Level | Purpose | Duration | Output |
|---|---|---|---|
| **Big Picture** | Explore the entire domain; discover all Domain Events; identify hotspots and opportunities | Full day (or equivalent) | Complete event timeline; hotspot list; rough subdomain boundaries |
| **Process Level** | Zoom into one process; add Commands, Actors, Policies, Read Models, and External Systems | Half day | Detailed process flow with cause and effect |
| **Design Level** | Map Aggregates; define Bounded Contexts; identify services | Half day | Aggregate boundaries; Bounded Context candidates; service list |

---

## Card Taxonomy

Each card type has an assigned colour. Consistency is critical — the colour is the signal.

| Card | Colour | What it represents |
|---|---|---|
| **Domain Event** | Orange | Something that happened in the domain — past tense, always significant to the business |
| **Command** | Blue | An instruction given to the system — present tense, imperative |
| **Actor** | Yellow (small) | A person or role that issues a Command |
| **Aggregate** | Yellow (large) | A cluster of Domain Objects that handles Commands and emits Domain Events |
| **Policy** | Purple | A reaction rule: "Whenever [Domain Event], then [Command]" — automation |
| **Read Model** | Green | A view or query result that an Actor uses to make a decision before issuing a Command |
| **External System** | Pink | A system outside the domain boundary — third-party or another team |
| **Hotspot** | Red | A conflict, uncertainty, or area of disagreement — flagged for resolution, not resolved immediately |
| **Opportunity** | Green (small) | An insight about a better process — for backlog consideration |

---

## Big Picture Event Storming

### Setup

Place Domain Events (orange) left to right in the order they happen in the domain. Do not worry about completeness at first — the goal is to explore.

Facilitation prompt: *"Think of all the events that happen in this system's world. An event is something that happened — in the past — that is relevant to the business. Write each one on an orange card."*

### Pass 1 — Dump

Every participant places orange cards on the timeline without structure. No discussion. No organisation. Just events. Speed matters — aim for volume.

### Pass 2 — Enforce the Language

Walk the timeline and enforce two rules:
1. Every event is in **past tense** ("FileClassified", "ScanCompleted", "GapDetected") — if it's present or future, it's a Command or a goal, not an event
2. Every event is **business-meaningful** — "DatabaseRowInserted" is not a Domain Event; "DataAssetRegistered" is

### Pass 3 — Narrative Walk

Read the timeline aloud from left to right as a story. Ask: "Does this tell the story of how the business works?" Identify gaps — moments in the story where an event is clearly missing.

### Pass 4 — Hotspots

For every card that causes confusion, disagreement, or uncertainty — place a red hotspot card. Do not resolve disagreements during this pass. Record them and continue.

### Pass 5 — Swim Lanes / Subdomain Boundaries

Group related events into rough areas. These areas are candidates for subdomains. Draw boundaries (lines, tape) between them. Name each area. These names become Bounded Context candidates.

---

## Process Level Event Storming

Zoom into one process flow identified in Big Picture. Add the remaining card types.

### Sequence: Cause and Effect

For every orange Domain Event, ask:
1. **What Command caused this event?** → Add a blue Command card to the left of the event
2. **Who issued that Command?** → Add a yellow Actor card to the left of the Command
3. **What did the Actor look at to decide to issue this Command?** → Add a green Read Model card
4. **Did this event trigger another Command automatically?** → Add a purple Policy card: "Whenever [Event], then [Command]"
5. **Does anything external cause or receive this event?** → Add a pink External System card

### The Flow Pattern

```
[Read Model] → [Actor] → [Command] → [Aggregate] → [Domain Event] → [Policy] → [Command] ...
```

Every step should be traceable. An event with no Command that caused it is a gap. A Command with no Actor or Policy that triggered it is a gap.

---

## Design Level Event Storming

### Aggregate Discovery

Group Commands and Events that naturally belong together. Ask: "Which Commands and Events happen to the same 'thing'?" That thing is an Aggregate. Name it — this name enters the Ubiquitous Language.

Rules for Aggregate boundaries:
- A Command is handled by exactly one Aggregate
- An Aggregate enforces its own invariants — if a rule must be checked before an event is emitted, it lives inside the Aggregate
- Aggregates communicate only through Domain Events — never direct method calls across Aggregate boundaries

### Bounded Context Discovery

Group Aggregates that belong to the same subdomain and use the same Ubiquitous Language. Draw a box. Name the box — this is the Bounded Context.

Ask for each Bounded Context boundary:
- Does the language change at this boundary? (If "File" means something different here, there's a boundary)
- Does a different team or capability own this area?
- Is there a distinct deployment unit here?

Each Bounded Context boundary is an input to the `bounded-context-mapping` skill.

---

## Hotspot Resolution

After the session, every hotspot must be resolved or explicitly deferred:

| Hotspot type | Resolution approach |
|---|---|
| Language disagreement | Run a ubiquitous-language session; choose the canonical term |
| Process uncertainty | Schedule a domain expert interview or secondary session |
| Technical feasibility concern | Flag to enterprise-architect; record as an architecture risk |
| Missing domain expert knowledge | Identify the knowledge holder; schedule a follow-up |
| Scope dispute | Escalate to Shafi; this is a product decision |

---

## Session Output

An Event Storming session produces these outputs, which feed subsequent skills:

| Output | Feeds skill |
|---|---|
| Ordered Domain Event timeline | `domain-event-catalog` |
| Named Aggregate candidates | `aggregate-design` |
| Named Bounded Context candidates | `bounded-context-mapping` |
| Command list | `command-catalog` |
| Read Model list | `read-model-design` |
| Policy list | `domain-event-catalog` (reaction rules) |
| Hotspot list | Architecture risk register |
| Ubiquitous Language candidates | `ubiquitous-language` |

---

## Worked Example

Process Level flow for classification in the data-estate product, read left to right:

```
[Read Model: Unclassified Assets Queue]
        → (Actor: Compliance Officer)
        → [Command: ClassifyDataAsset]
        → {Aggregate: DataAsset}
        → <Domain Event: DataAssetClassified>
        → «Policy: Whenever DataAssetClassified with SensitivityLevel = Restricted,
                    then RequestAccessReview»
        → [Command: RequestAccessReview]
        → {Aggregate: AccessReview}
        → <Domain Event: AccessReviewRequested>
        → (External System: Google Drive — sharing settings checked via ACL)
```

What this fragment demonstrates:
- Every `<Domain Event>` traces back to a `[Command]`, issued by either an `(Actor)` or a «Policy» — no orphan events.
- The «Policy» card captures automation discovered in a domain story ("whenever something is Restricted, someone must review access") — it is domain language, not a technical trigger.
- The `(External System)` card marks where the model's authority ends; the boundary it implies feeds `bounded-context-mapping` (an ACL toward Google Drive).
- A hotspot raised during this walk: *"Can the engine reclassify an asset a human has manually overridden?"* — recorded red, not debated; resolved later as an `AccessReview` invariant question.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| All three levels completed | Big Picture → Process Level → Design Level run in sequence | Jumping to Design Level without Big Picture |
| Past-tense events | All Domain Events are in past tense | Events in present tense or future tense |
| Cause-and-effect chains | Every event has a Command that caused it (or a Policy) | Orphan events with no cause |
| Hotspots recorded | All disagreements captured as hotspot cards | Disagreements resolved by authority without recording |
| Aggregate boundaries | Every Aggregate has a clear invariant that justifies its boundary | Aggregates defined by CRUD tables, not domain rules |
| Bounded Context boundaries | Language change or team ownership boundary justifies each BC | Arbitrary service boundaries with no domain justification |
| Named outputs | All Aggregates, BCs, Events, and Commands are named in Ubiquitous Language | Unnamed or numbered placeholders |

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **Design-first storming** — jumping straight to Aggregates and services | Boundaries get drawn from architectural preference, not domain evidence; the session ratifies what someone already decided | Complete Big Picture first; let Aggregates emerge from Command/Event clustering |
| **Technical events on the wall** — "DatabaseRowInserted", "KafkaMessagePublished" | These describe the implementation, not the domain; they crowd out the business narrative | Enforce Pass 2: every event must be meaningful to a domain expert |
| **Resolving hotspots by authority** — the loudest or most senior voice settles disagreements mid-session | The disagreement is real domain knowledge; suppressing it hides a risk instead of recording it | Red card, move on; resolve after the session via the Hotspot Resolution table |
| **CRUD lane sorting** — organising cards by entity ("all File events here, all User events there") | Recreates a data model, destroying the temporal narrative that reveals process and causality | Keep the timeline temporal; group into subdomains only in Pass 5 |
| **Happy-path timeline** — no failure, dispute, or timeout events | The domain's hardest rules live in exceptions; a happy-path model produces naive Aggregates | Explicitly prompt for "what goes wrong" events in Pass 1 and the narrative walk |
| **Facilitator writes all the cards** | Participants disengage; the model reflects the facilitator's understanding, not the room's | Everyone writes; the facilitator sequences, questions, and enforces language |
| **Storming without a domain expert** — engineers modelling from assumption | Every card is a guess; hotspots cannot be distinguished from facts | Require at least one person with first-hand domain knowledge; otherwise run discovery interviews first |
| **Wall archaeology** — the session ends and the cards are never transcribed | Outputs decay within days; downstream skills re-derive everything | Transcribe into the Output Format the same day; every output row names the skill it feeds |

---

## Output Format

```markdown
---
name: event-storming-session
product: [product name]
domain: [domain or subdomain name]
level: [big-picture | process | design | all]
version: 1.0.0
phase: design
created: [date]
owner: domain-modeler
---

# Event Storming: [Domain Name]

## Domain Events (ordered timeline)
[Orange cards left to right — include swim lane / subdomain groupings]

## Commands
| Command | Actor / Policy | Aggregate | Resulting Event |
|---|---|---|---|

## Aggregates
| Aggregate | Commands handled | Events emitted | Key invariant |
|---|---|---|---|

## Policies (Reactions)
| Trigger Event | Policy Name | Resulting Command |
|---|---|---|

## Read Models
| Read Model | Used by (Actor) | Informs (Command) |
|---|---|---|

## External Systems
| System | Produces Events | Consumes Commands |
|---|---|---|

## Bounded Context Candidates
| Candidate Name | Aggregates | Language boundary justification |
|---|---|---|

## Hotspots
| ID | Description | Type | Resolution | Status |
|---|---|---|---|---|

## Ubiquitous Language Candidates
[Terms discovered during session — to be formally defined in ubiquitous-language skill]
```
