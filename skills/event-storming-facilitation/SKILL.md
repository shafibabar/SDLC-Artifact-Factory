---
name: event-storming-facilitation
description: >
  Running an Event Storming workshop to model a domain — Big Picture, Process
  Level, and Design Level; Alberto Brandolini's sticky-note color grammar
  (orange Domain Event, blue Command, yellow Actor/Aggregate, purple Policy,
  green Read Model, pink External System, red Hotspot); the facilitation arc
  from chaotic event dump to enforced timeline to aggregates and Bounded
  Context boundaries; discovering Aggregates as transactional-consistency
  boundaries and Bounded Contexts as linguistic boundaries; producing a session
  output that feeds domain-event-catalog, aggregate-design, and
  bounded-context-mapping. Match when a domain or subdomain must be modeled
  before architecture decisions, when /sdlc-design or /sdlc-event-storm runs,
  or when the domain-modeler agent needs the workshop procedure, card taxonomy,
  hotspot handling, or a worked session. Event Storming is mandatory at Design.
version: 2.0.0
phase: design
owner: domain-modeler
created: 2026-06-25
tags: [design, domain-modeling, event-storming, facilitation, domain-events, bounded-context, brandolini]
produces: event-storming-session
domain: domain-modeling
status: stable
related: [domain-event-catalog, aggregate-design, bounded-context-mapping, subdomain-distillation, ubiquitous-language, command-catalog, read-model-design]
---

# Event Storming Facilitation

## Purpose

Event Storming (Alberto Brandolini) surfaces domain knowledge by mapping Domain
Events — things that happened, past tense — across a timeline, left to right,
then reconstructing the Commands, Actors, Policies, and boundaries around them.
It is the fastest way to build a shared model of a complex domain without first
committing to implementation.

Event Storming is **mandatory** in this plugin. No architecture is drawn, no
Bounded Context is named, and no service is designed until an Event Storming
session for the relevant domain is complete. This skill supplies the criteria
for *how* to run one; the domain-modeler agent applies them to a real domain.

---

## The Three Levels — and When to Run Each

Run in order. Never skip to Design Level without a completed Big Picture — a
boundary drawn before the events are on the wall ratifies a preconceived
architecture instead of discovering one.

| Level | Run it when | Produces |
|---|---|---|
| **Big Picture** | Starting a new domain; the whole event landscape is still unknown | Full event timeline, hotspots, rough subdomain areas |
| **Process Level** | One process from Big Picture needs cause-and-effect detail | Command/Actor/Policy/Read-Model/External-System flow |
| **Design Level** | A process is understood well enough to draw boundaries | Aggregate candidates, Bounded Context candidates, service list |

Each level has explicit **entry and exit criteria** — do not advance a level
until its exit criteria are met. Those criteria, plus each level in depth, are
in `references/color-grammar-and-levels.md`.

---

## Color Grammar — Compact Legend

The color *is* the signal; consistency is non-negotiable. Full meaning, shape
conventions, and the modeling element each color maps to:
`references/color-grammar-and-levels.md`.

| Color | Card | One-line meaning |
|---|---|---|
| Orange | Domain Event | Something that happened — past tense, business-significant |
| Blue | Command | An instruction to the system — imperative |
| Yellow (small) | Actor | Person/role that issues a Command |
| Yellow (large) | Aggregate | Cluster that handles Commands, emits Events, guards an invariant |
| Purple | Policy | Reaction rule: "Whenever [Event], then [Command]" |
| Green | Read Model | View an Actor consults before issuing a Command |
| Pink | External System | A system outside the domain boundary |
| Red | Hotspot | Conflict/uncertainty — recorded, not resolved on the spot |

---

## The Facilitation Arc

Every session, at every level, follows the same four-move arc. Detail,
participants, space, timeboxing, and anti-patterns:
`references/facilitation-guide.md`.

1. **Chaotic exploration** — everyone writes orange Events in parallel, no
   structure, no discussion. Volume first. Include failures, disputes, timeouts
   — the hardest rules live in what goes wrong, not the happy path.
2. **Enforce the timeline** — order events left to right in real domain time;
   enforce past tense and business-meaning ("DataAssetClassified", not
   "DatabaseRowInserted"); walk it aloud as a story; mark gaps and red Hotspots.
3. **Add Commands, Actors, Policies** — for each Event, ask what Command caused
   it, who or what Policy issued that Command, and what Read Model informed it.
4. **Find Aggregates and boundaries** — cluster Commands/Events that share a
   consistency rule into Aggregates; group Aggregates sharing one Ubiquitous
   Language into Bounded Contexts.

---

## Two Boundaries, Two Forces

Aggregate and Bounded Context boundaries are **different kinds of boundary
shaped by different forces** — do not let one line answer both questions:

- An **Aggregate boundary** is a *transactional-consistency* boundary: it exists
  because a true invariant must hold atomically (Vernon, Khononov). Draw it
  around the smallest set of Commands/Events that share that invariant.
- A **Bounded Context boundary** is a *linguistic/model* boundary: it exists
  where a Ubiquitous Language term changes meaning, or a different team/capability
  owns the area. Many Aggregates nest inside one Bounded Context.

Conflating them ("one Bounded Context per Aggregate") is a category error, not
merely too-fine granularity. Aggregate-discovery criteria belong to
`aggregate-design`; boundary-mapping to `bounded-context-mapping`. This skill
only surfaces the candidates.

---

## Hotspots

Every red Hotspot is recorded during the session and resolved *after* it — never
settled mid-session by the loudest or most senior voice, which suppresses real
domain knowledge. The resolution approaches per hotspot type (language dispute,
process uncertainty, technical-feasibility concern, missing expert, scope
dispute → escalate to Shafi) are tabulated in `references/facilitation-guide.md`.

---

## Session Outputs — What Feeds What

Transcribe the wall into the Output Format the *same day*; un-transcribed walls
decay within days and force downstream skills to re-derive everything.

| Output | Feeds skill |
|---|---|
| Ordered Domain Event timeline | `domain-event-catalog` |
| Named Aggregate candidates | `aggregate-design` |
| Named Bounded Context candidates | `bounded-context-mapping` |
| Command list | `command-catalog` |
| Read Model list | `read-model-design` |
| Policy (reaction) list | `domain-event-catalog` |
| Hotspot list | Architecture risk register |
| Ubiquitous Language candidates | `ubiquitous-language` |

A full worked session for this repo's DataAsset ingestion → classification →
compliance domain — the sticky sequence and the Aggregates and Bounded Contexts
it discovers — is in `references/worked-session.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Levels in sequence | Big Picture → Process → Design | Jumping to Design first |
| Past-tense events | All Events past tense | Present/future "events" |
| Cause and effect | Every Event traces to a Command or Policy | Orphan events |
| Hotspots recorded | Disagreements captured as red cards | Settled by authority silently |
| Aggregate boundaries | Justified by a true invariant | Drawn from CRUD tables |
| Bounded Context boundaries | Justified by language change or ownership | Arbitrary service split |
| Named outputs | All items named in Ubiquitous Language | Numbered placeholders |

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
[Orange cards left to right — include swim-lane / subdomain groupings]

## Commands
| Command | Actor / Policy | Aggregate | Resulting Event |

## Aggregates
| Aggregate | Commands handled | Events emitted | Key invariant |

## Policies (Reactions)
| Trigger Event | Policy Name | Resulting Command |

## Read Models
| Read Model | Used by (Actor) | Informs (Command) |

## External Systems
| System | Produces Events | Consumes Commands |

## Bounded Context Candidates
| Candidate Name | Aggregates | Language-boundary justification |

## Hotspots
| ID | Description | Type | Resolution | Status |

## Ubiquitous Language Candidates
[Terms discovered — to be formalized via the ubiquitous-language skill]
```
