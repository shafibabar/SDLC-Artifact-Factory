---
name: domain-storytelling
description: >
  Tell or draft domain stories to understand how work is done before
  modelling it: one concrete scenario per story, told as numbered actor –
  activity – work object sentences, often with a recipient, in the
  storytellers' words. Covers choosing the three scope factors (coarse- or
  fine-grained; as-is or to-be; pure or digitalised), the pictographic
  elements (actors, work objects, activities, sequence numbers, annotations,
  groups), the storyteller, moderator and modeller roles and the retelling
  check, telling variants as separate stories instead of branches, groups as
  Bounded Context hints, and feeding the Ubiquitous Language, boundaries and
  acceptance criteria. Includes agent-run mode: drafting stories from named
  artifacts with every sentence cited or labelled an assumption and open
  questions sent to the product owner. Use when asked to "draft domain
  stories from these artifacts", run a Domain Storytelling workshop, or
  understand who does what with what before Event Storming. Used by
  domain-modeler at standard and enterprise.
version: 3.0.0
phase: design
owner: domain-modeler
created: 2026-06-25
tags: [design, domain-modeling, domain-storytelling, actor, work-object, scope-factors, agent-run, hofer-schwentner]
produces: domain-story
domain: domain-modeling
status: stable
related: [event-storming-facilitation, ubiquitous-language, bounded-context-mapping, acceptance-criteria, user-journey-mapping, subdomain-distillation]
sources:
  - research/domain-driven-design/domain-storytelling-hofer-schwentner.md
  - research/domain-driven-design/strategic-design-supplement.md
  - research/domain-driven-design/domain-driven-design-evans.md
---

# Domain Storytelling

## Purpose

Domain Storytelling (Stefan Hofer and Henning Schwentner, *Domain Storytelling*) is told by the people who do the work and drawn while they tell it. Each sentence is drawn with a few icons, so the tellers see the picture grow and correct it. The picture records a conversation; the conversation is the point. Where Event Storming asks *what happened?*, a domain story asks *who does what with what, for whom, in what order?* It differs from a user journey map (`user-journey-mapping`), which follows one customer's experience; a domain story follows the work, across everyone who does it.

**When it runs:** at standard and enterprise, optional, where the work has clear hand-overs between people. It is skipped at lean (`phase-requirements.json`). The plugin runs it before Event Storming when the plan includes it. The book gives no fixed order; the two methods complement each other.

## 1. Agent-Run Mode First (D047-8)

The domain-modeler usually has no storyteller. The book makes the storyteller a domain expert telling their own work, and treats the retelling to that person as the check. An agent-run story is therefore a **draft to be confirmed**, never presented as a told story:

1. **Every sentence cites its source:** the artifact it came from (a persona, a job story, a journey map, the problem statement), or it is labelled **assumed**.
2. **State the scope factors** (§ 2) in the story's frontmatter.
3. **Pose the variants:** a variant story per persona or failure case worth telling.
4. **Open questions go to the product owner** at the review gate, for example "who actually does step 4?", each with the assumption used meanwhile.
5. **Give the product owner the retelling to check:** the story read back as numbered sentences, for them or a person who does the work to correct.

**What it can't claim:** the storytellers' own words, a validated sequence, or knowledge no document holds. Its terms are terms found in documents, not expert language. A real session stays optional; its validated stories replace the drafts they confirm. Procedure in full: `./references/agent-run-mode.md`.

## 2. Pick the Scope: Three Factors

Every story is described by three factors (Hofer & Schwentner), recorded together:

| Factor | Values | Means |
|---|---|---|
| **Granularity** | coarse-grained · fine-grained | Detail per sentence. Coarse: a whole process or value chain, each sentence covering a lot. Fine: one part, step by step. It is not a step count |
| **Point in time** | as-is · to-be | Today's work, or the intended future work |
| **Domain purity** | pure · digitalised | Without software, or with software systems as actors and electronic artefacts as work objects |

Pick the combination from the question:

| Question | Scope |
|---|---|
| Orientation; where the boundaries might be | coarse-grained / as-is / pure |
| Requirements for the new system | fine-grained / to-be / digitalised |
| Where today's tools hurt, including spreadsheets and email doing real work | fine-grained / as-is / digitalised |

A common path is coarse as-is pure first, then fine to-be digitalised for the parts being built. Software is never added to a pure story as an overlay; a digitalised view is its own story.

## 3. The Sentence and the Elements

Every sentence reads **actor – activity – work object**, often with a recipient: "The customer sends the claim form *to* the clerk." Arrows go actor → work object → actor. One verb per sentence; "checks and files" is two sentences.

| Element | Is |
|---|---|
| **Actor** | A person, group or software system that does something; a role name ("Pharmacist"), never a personal name, and never "the system" |
| **Work object** | What actors create, use, pass on or talk about: a form, a phone call, an email, money |
| **Activity** | The labelled arrow, the storyteller's own verb |
| **Sequence number** | The order told. Actors and work objects are drawn once and reused |
| **Annotation** | Free text for conditions, minor variants, example data |
| **Group** | A labelled outline around part of the story: an organisation, a place, a candidate boundary |

**One diagram, one concrete scenario.** No branches, loops or "if". The usual case comes first; an important variant or error case is its own story, cross-referenced; a minor one is an annotation. Branches belong to flowcharts and BPMN, which the authors keep apart. The icon set is open, chosen per domain. Egon.io, the authors' free browser modeller, is the reference tool; any canvas works. Notation in depth: `./references/notation-guide.md`.

## 4. Telling a Story with People

The book's roles: **storytellers** (domain experts, possibly several, each telling the part they do), the **moderator** (runs the session, asks questions), the **modeller** (draws, ideally on a shared screen; may be the moderator) and **listeners** (developers, product people). Start from a concrete case ("tell me about the last time a repeat prescription was late"), not "how does the process work?". **The retelling is the main quality check:** the modeller reads the picture back sentence by sentence, during the session and at the end, and every correction is a vocabulary or ordering finding. Procedure: `./references/facilitation-guide.md`.

## 5. Groups as Boundary Hints

On a coarse-grained story, draw groups around sentences that belong together, and record the hint behind each: a work object changes name or meaning; a different department or role takes over; part of the story runs at a different pace or on a different trigger; a hand-over to another actor. A group is a **candidate** boundary to test, sent on as evidence to `bounded-context-mapping`, not a decision.

## 6. What Stories Feed

| Output | Feeds |
|---|---|
| Actors, work objects and verbs, in the tellers' words (or labelled document terms) | `ubiquitous-language`; retelling with a proposed term tests it |
| Groups with their hints | `bounded-context-mapping`, alongside the Event Storming boundary hints |
| Person-and-software sentences in to-be digitalised stories | Candidate user stories |
| Variant stories | Candidate acceptance criteria and Gherkin scenarios (`acceptance-criteria`) |
| Work objects and activities | Candidate model elements for `aggregate-design`. No code here (D047-10) |

## Producing the Stories

Copy `./resources/story-checklist.md` and tick it as you go.

1. **Plan.** Check the profile (skip at lean). List the input artifacts and the scenarios worth telling; give each its three scope factors (§ 2).
2. **Draft or tell** the usual case first: numbered sentences with sources (§ 1) or from a session (§ 4).
3. **Variants** as separate stories, cross-referenced; minor ones as annotations.
4. **Groups** with their hints (§ 5) on coarse-grained stories.
5. **Write** each story from `./templates/domain-story.md` to `design/domain-stories/coarse-<name>.md` or `fine-<name>.md`.
6. **Validate, then loop.** Run `./scripts/validate-domain-story.sh <file>`. Fix every FAIL and run it again until it exits clean, then go through the checklist items the script can't judge.
7. **Present** at the review gate: the run (agent-run or workshop), the open questions and the retelling for the product owner to check. For an agent-run draft, also say that a real session with the people who do the work stays optional, and that if one is held, its told stories replace the draft sentences they confirm.

Worked cases, simplest to hardest: `./examples/01-standard-library-reservation-coarse.md` (coarse as-is pure, agent-run, groups as hints), `./examples/02-standard-pharmacy-repeat-prescription-fine.md` (fine to-be digitalised, a variant told as its own story), `./examples/03-enterprise-customs-clearance.md` (several organisations, a group per party, a story per party's part).

## Gotchas

- **"Draw it with a decision diamond for the approval."** Say why not: a domain story tells one concrete case, and branches, loops and yes/no paths belong to flowcharts and BPMN, which the authors keep apart from Domain Storytelling. Tell the approved case and the rejected case as two stories, cross-referenced; a minor case is an annotation. No 5a/5b numbering either.
- **Presenting a drafted story as told by experts.** Nobody told it. Mark it agent-run, cite each sentence or label it *assumed*, and give the product owner the retelling to check. Also say that a real session with the people who do the work stays optional, and that its told stories would replace the draft sentences they confirm; the emailed retelling is the cheap check, not a substitute for that choice.
- **"Pure vs annotated".** Those aren't the book's terms. Use the three scope factors; a story with software in it is a separate digitalised story, not an annotated pure one.
- **Describing the scope only in plain words** ("today's work, no software"). Name all three factors for every story, then gloss them: *coarse-grained / as-is / pure (today's whole process, no software)*. The names are what the template, the validator and later skills read.
- **Dropping the recipient** to force three parts. "The customer sends the form to the clerk" keeps the clerk.
- **"The system" as an actor.** Name which system, or in a pure story, which person.
- **Groups treated as decided Bounded Contexts.** They are candidates with evidence.
- **Mixing as-is and to-be in one story** without saying so. Each story has one point in time.

## Anti-Patterns

| Anti-pattern | Why it fails | Correction |
|---|---|---|
| **A general process description** ("usually…") | Hides the exceptions and the real words | One concrete case, told as it happened |
| **Designing while drawing** | Draws the system intended, not the work told | Draw what was said, in the teller's words |
| **Translating on the fly** | Replaces the teller's words with technical terms | Record the exact word; reconcile in `ubiquitous-language` |
| **Variants as numbered sub-steps** (4a, 4b) | A branch in disguise | A separate story per important variant |
| **Never retold** | No check that the picture matches the work | Read it back sentence by sentence; record each correction |
| **Shelfware story** | Nothing downstream uses it | Fill the Feeds Forward table (§ 6) |
