---
name: user-story-writing
description: >
  Teaches how to write the user story backlog in Ideate (ideate/user-stories.md):
  each story a short card (As a persona / I want / so that) that is a promise of
  a conversation (Cohn's Three Cs, after Ron Jeffries), checked against INVEST,
  traced to its epic, its user requirement (UR-n) and the job story (JS-n.m)
  beneath a job statement, carrying a provisional priority (never Must / Should
  / Could / Won't) and one concrete example as its readiness seed; and the one
  story-level splitting catalogue (workflow step, business rule, data, CRUD,
  defer the hard part, spike; SPIDR paths and interfaces) where every child
  stays an end-to-end slice. Use when writing, reviewing, rewriting or splitting
  user stories, fixing a vague "As a user" story or a circular "so that",
  turning epic story titles or functional requirements into stories, taking in
  gap stories the story map proposes, or writing the lean backlog that is also
  the requirements: its requirements header (scope, BR-n, TR-n), epic headings
  with a KR trace line and the closing Must / Won't-this-time block. Used by the
  requirements-analyst agent in Ideate (/sdlc-ideate) after the epic list and
  before example maps, acceptance criteria and the story map; required at every
  profile.
version: 3.0.0
phase: ideate
owner: requirements-analyst
created: 2026-06-24
tags: [ideate, requirements, user-story, backlog, invest, three-cs, story-splitting, traceability]
produces: user-story-backlog
domain: discovery
status: stable
related: [epic-definition, requirements-analysis, jtbd-analysis, user-persona, impact-mapping, okr-authoring, nfr-specification, example-mapping, acceptance-criteria, bdd-feature-file, story-mapping, moscow-prioritization, glossary-management, methodology-review]
sources:
  - research/requirements-and-user-stories/user-stories-applied-cohn.md
  - research/requirements-and-user-stories/lean-agile-atdd-pugh.md
  - research/requirements-and-user-stories/it-requirements-lean-agile-hathaway.md
  - research/requirements-and-user-stories/dsdm-agile-project-framework.md
---

# User Story Writing

## Purpose

The user story backlog answers: **what will each user be able to do, one small verifiable behaviour at a time, and why does each behaviour exist?** A story is the smallest unit of product work that changes something for a named user. It is not a task, a technical requirement or a specification.

Mike Cohn (*User Stories Applied*) grounds the format in Ron Jeffries' **Three Cs**: the **Card** is a short written story, a token rather than a spec; the **Conversation** is where the detail is negotiated, later; the **Confirmation** is the set of conditions that prove the conversation was delivered. A story is deliberately incomplete. Cohn treats a card written like a novel as a failure: the conversation never happened, or was frozen into text too early.

## Where It Sits

```
Ideate: personas ─► JTBD ─► OST ─► impact map ─► FRD ─► NFRs ─► epics ─► STORIES ─► example maps ─► acceptance criteria ─► story map ─► MoSCoW
```

| Reads | What it takes |
|---|---|
| `epic-definition` | Each epic's story titles in narrative order, and the traces every story inherits. At lean: the epic headings in this same file, or none |
| `requirements-analysis` | User requirements (UR-n) and their FRs, business rules (BR-n), transition requirements (TR-n). At lean there is no FRD: this file's requirements header holds them |
| `jtbd-analysis`, `user-persona` | Job statements (J-n), job stories (JS-n.m) and the personas who are the "As a" |
| `okr-authoring` | The Key Result (KR-n.m) every story ultimately serves |
| `story-mapping` | **Gap stories** the map narration proposes, and orphans it challenges (Intake, below) |

| Feeds | What it gives |
|---|---|
| `example-mapping` | Each story with its seed example, the rules (BR-n) it touches and open questions: the Conversation |
| `acceptance-criteria` | The Confirmation leg: Given/When/Then is written there, from the example map, never on the card |
| `story-mapping` | The stories placed in the map's body |
| `moscow-prioritization` | Provisional priorities; MoSCoW finalises them at standard and enterprise |

**Two tracks on purpose.** At standard and enterprise the FRD and the backlog coexist: the FRD is the durable, traceable record of what must be true; the stories are the lightweight units of conversation and build (the Hathaways, *Getting and Writing IT Requirements in a Lean and Agile World*). Do not prune either as duplication. A story cites its UR and FRs instead of restating them. At lean the backlog *is* the functional requirements.

## Writing the Card

```
As a <persona or user role>, I want to <action the user takes>, so that <change in the user's world>.
```

- **As a** names a persona from `user-persona` (P-n) or a user role, never "a user" and never a system ("As the API"). With no personas yet, use Cohn's **role brainstorming** (list every way someone interacts, merge duplicates, order by an axis that changes behaviour) and replace the role when the persona arrives.
- **I want to** is something the user does, in their words, with no implementation (no endpoint, dropdown, table or modal).
- **so that** names what concretely changes for the user: time saved, a decision made, a risk avoided. This plugin's **"so what?" test** (a house rule, not a book citation): keep asking "so what?" until the answer is a real change, not the feature restated ("so that I can export the data") and not a product benefit ("so that we collect more data"). If the benefit collapses, the story's value is unproven: escalate rather than write it.

**INVEST** (Bill Wake, popularised by Cohn) is the bar: Independent, Negotiable, Valuable, Estimable, Small, Testable. Two adaptations for an agent-built product: **Small** means one user-visible behaviour an agent can build and verify against its own acceptance criteria, not "fits a sprint" (there are no sprints); **Estimable** means its size can be judged at all, and Ken Pugh (*Lean-Agile Acceptance Test-Driven Development*) gives the test: a story with no concrete example is not understood well enough to size. Each letter, its test, its fix, the anti-pattern catalogue and role brainstorming in full: `./references/invest-criteria.md`. Read it whenever a story is borderline on any letter, and before writing the first story with no persona.

## What Every Story Carries

| Field | Rule |
|---|---|
| **ID and title** | `US-n`, outcome-named, matching the epic's story title |
| **Card** | One sentence, As a / I want / so that. More than a few lines means it needs a conversation, not more writing |
| **Traces to** | Epic (EPIC-n) · user requirement UR-n (and FR-n.m where one story carries part of a UR) · job J-n → job story JS-n.m · KR. **At lean** there are no URs: the epic heading (if any) · J-n → JS-n.m · KR. A transition story cites TR-n. **Every** story, low-priority and transition ones included, cites a job story by its full ID (JS-n.m, never just J-n): a story no job story explains is an orphan, so challenge it or propose the missing job story |
| **Rules** | BR-n the behaviour must honour, cited, never restated |
| **Priority (provisional)** | high / medium / low (lean, standard); value and penalty 1–9 (enterprise). **Never Must / Should / Could / Won't** (D045): `moscow-prioritization`, or at lean the closing block, finalises it. A story under a high epic is judged on its own (DSDM) |
| **Seed example** | One concrete, real-feeling case: names, numbers, the outcome. It is the readiness seed for the example map, not the acceptance criteria |
| **Notes** | Optional: split pattern used, spike it waits on, an ordering note, an NFR it is constrained by (cited) |

No size field: a story is one build-and-verify unit, and an over-big one is split, not sized.

## Splitting: This Skill Owns the Story-Level Catalogue

A story that fails **Small** or **Estimable** is split into INVEST-compliant children before it is written down, not planned as-is. `epic-definition` splits epics into epics by outcome and points here for story-level splits. **The golden rule:** every child is a thin **end-to-end slice** through every layer the behaviour needs, valuable and testable on its own. A frontend / backend / database "story" is a task, and a copy of a story per tenant that behaves the same is a duplicate: split by tenant only where policy or data really differs. A quality target ("within 5 minutes") is never a story or part of the card: the story cites the NFR that owns it.

| The story is too big because… | Split by |
|---|---|
| It joins several verbs ("connect, configure and monitor") | Verb before noun (house rule) |
| It is a multi-step workflow | Workflow step (Cohn) |
| It behaves differently per business rule, tier or tenant policy | Business-rule variation (Cohn); SPIDR **Rules** |
| It handles several data types, sources or formats | Data boundary (Cohn); SPIDR **Data** |
| It does all of create / read / update / delete | CRUD operation, each its own story (Cohn) |
| It has a happy path plus error and alternate paths | Happy path first; SPIDR **Paths** |
| It is offered through several interfaces or user classes | SPIDR **Interfaces** |
| The hard or large case holds the common one hostage | Simple then complex; defer performance or robustness (Cohn) |
| Nobody can say what it involves | A **spike** (Cohn; SPIDR **Spike**): a bounded investigation whose output is a decision, not software |

SPIDR is Cohn's later Mountain Goat Software material, not *User Stories Applied*. Every pattern, when to prefer which, and the bad splits: `./references/story-splitting-patterns.md`. Read it before splitting any story. A full split of one oversized story, step by step: `./examples/04-splitting-an-oversized-story.md`.

## Boundary: Card Here, Conversation and Confirmation Elsewhere

| Owned here | Handed off |
|---|---|
| The card, its traces, provisional priority, rules cited, the seed example | **Example map** (`example-mapping`): the Conversation. Rules, examples and questions, discovered before criteria (Pugh: examples before rules). The agent plays customer, developer and tester alone and says so; no workshop is claimed |
| Splitting and spikes | **Acceptance criteria** (`acceptance-criteria`): the Confirmation, declarative Given/When/Then in `ideate/acceptance-criteria/US-n.md`, drafted from the example map |
| Gap-story intake from the map | **Feature files** (`bdd-feature-file`, test-strategist, Implement): the criteria made executable as Gherkin |
| | **Walking skeleton and slices** (`story-mapping`); **final priority** (`moscow-prioritization`) |

Never write Given/When/Then on the card, and never write story detail that the example map should discover. A story with an open question that changes its scope goes back to the user, not into the criteria.

## Intake: Gap Stories From the Story Map

The story map narrates the journey and proposes **gap stories** (a step with nothing under it) and challenges **orphans** (a story no step needs). Nothing joins or leaves the backlog without the user.

1. For each proposed gap, ask the user. On approval, write it as a full story with the next free ID, marked `Source: story-map gap, approved <date>`, traced like any other, under the epic whose outcome it serves (or none at lean when there are no epic headings).
2. If it fits no epic at standard or enterprise, say so and propose the epic list change to the user (`epic-definition`): a missing story title, or a missing epic.
3. A declined gap is recorded in the backlog's intake log with the reason (often a named manual step on the map).
4. An orphan is either placed (the map missed a step) or removed with the user's agreement; record which.

## Producing the Artifact

1. **Check the profile** (Scale, below) and read the epics (or lean headings), URs/FRs/BRs/TRs (or the lean header), job stories and personas.
2. **Write one story per epic story title**, in narrative order; each UR's FRs are covered by at least one story.
3. **Apply the "so what?" test and INVEST** to each; split anything too big; carve out spikes.
4. **Trace, cite rules, set the provisional priority, write the seed example.**
5. **At lean**, write the requirements header first, then epic headings and stories; the closing Must / Won't-this-time block is added after the spine is walked (`story-mapping`).
6. **Validate** against `./resources/story-backlog-checklist.md` and run `python3 ./scripts/check-user-stories.py <artifact>`. If you cannot run it (replying in chat, no shell), re-read every Traces and Priority line by hand before handing off: the job story ID and the provisional label are the two slips most often made.
7. **Write** from `./templates/user-story-backlog.md` to `ideate/user-stories.md`; present it before example mapping. At enterprise, propose the forward-trace fill (epic list Stories column, FRD Story column); editing an approved artifact reopens it.

## Scale

`phase-requirements.json`: the backlog is **required** at every profile; at lean it is also the functional requirements.

| Profile | Shape |
|---|---|
| **lean** | One file holding everything Ideate decides: a **requirements header** (translation line, scope and exclusions, BR-n, TR-n, quality concerns for the NFR spec, assumptions, waiting room), **epic headings** each with a KR trace line (or none when stories are few), stories tracing to J-n → JS-n.m and the KR, and the closing **Must / Won't-this-time block**, which is the walking skeleton. `./examples/01-lean-toolshed.md` |
| **standard** | Stories per epic from `ideate/epics.md`, each traced to UR/FR and job story, high / medium / low, a coverage table (epic story titles and URs → stories), spikes, an intake log. No Must/Won't block: MoSCoW finalises. `./examples/02-standard-rebound.md` |
| **enterprise** | Adds value and penalty scores, stories for disfavoured user classes (access, tenant isolation), splits by tenant policy and interface, spikes for unknown external systems, per-tenant transition stories traced to TR-n, regulatory rules and NFRs cited, and the forward trace back into the epic list and FRD. `./examples/03-enterprise-permitry.md` |

The header, epic-heading and closing-block formats are in the template; they match `requirements-analysis`, `epic-definition` and `story-mapping` exactly.

## Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| **"As a user"** or **system as actor** | Which user? Systems have no wants: it is a task |
| **Circular "so that"** | Restates the want; no value is shown |
| **Solution card** | Names the implementation; Negotiable is lost (Cohn) |
| **The novel** | The detail the conversation should find is frozen too early |
| **MoSCoW on the card** | Pre-empts `moscow-prioritization` (or the lean block), which runs last |
| **Sprint or point sizing** | No sprints here; an over-big story is split |
| **Layer split** | Frontend / backend / database children deliver nothing alone |
| **Given/When/Then on the card** | Freezes the Confirmation before the example map's Conversation |
| **Orphan story** | No epic, UR or job story behind it: unjustified scope |
| **Silent gap fill** | A story added without the user, from the map or anywhere |
| **Product rules as skill rules** | A product's personas or compliance rules belong in its backlog, not every product's |

Use canonical terms from `glossary-management`: **User Story**, **Three Cs**, **INVEST**, **User Role**, **Spike**, **Provisional Priority**, **Job Story**, **User Requirement**, **Walking Skeleton**, **Specification by Example**. Run `methodology-review` before hand-off.
