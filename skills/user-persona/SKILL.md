---
name: user-persona
description: >
  Teaches how to write the user personas artifact: named, goal-directed archetypes
  of one behaviour pattern each (Cooper), synthesised from behavioural variables,
  each given a persona type (primary, secondary, supplemental, customer, served,
  negative) with exactly one primary per interface, goals split into end,
  experience and life goals, one solution-free job statement, and an honest
  provenance label: an agent-written persona is PROTO, says who wrote it, from what
  and that no user was interviewed, and carries validation questions. Use when
  creating, reviewing or revising user personas, proto-personas or provisional
  personas, turning interview notes or a buying committee into personas, choosing
  the primary persona, splitting a buyer from a daily user, writing a negative
  persona (anti-persona), or deciding when personas are reopened or retired. Used
  by the requirements-analyst agent as the first artifact of the Ideate phase
  (/sdlc-ideate), from the GTM's ICP and the stakeholder map's buying committee,
  before JTBD analysis; required at every profile.
version: 3.0.1
phase: ideate
owner: requirements-analyst
created: 2026-06-24
tags: [ideate, requirements, persona, proto-persona, persona-types, behavioural-variables, user-research, discovery]
produces: user-persona
domain: discovery
status: stable
related: [jtbd-analysis, user-story-writing, gtm-strategy, stakeholder-mapping, impact-mapping, moscow-prioritization, user-journey-mapping, glossary-management, methodology-review]
sources:
  - research/product-strategy-and-gtm/about-face-personas-cooper.md
  - research/product-strategy-and-gtm/competing-against-luck-christensen.md
  - research/product-strategy-and-gtm/the-mom-test-fitzpatrick.md
  - research/product-strategy-and-gtm/lean-product-playbook-olsen.md
  - research/product-strategy-and-gtm/loved-lauchengco.md
  - research/requirements-and-user-stories/user-stories-applied-cohn.md
  - research/data-governance-and-mdm/simple-data-mdm-srinivasan.md
---

# User Persona

## Purpose

A persona is a **named model of one behaviour pattern**, with goals, that the whole team designs for and argues about. It is not a portrait of one real customer, not an average of all of them, and not a demographic profile. The idea is Alan Cooper's (*The Inmates Are Running the Asylum*; Cooper et al., *About Face*): a composite archetype synthesised from patterns observed across real users.

The problem it solves is the **elastic user**. When a team says "the user", each person pictures someone different, a novice when arguing for a wizard and an expert when arguing for shortcuts, so no argument can be settled. "Would *this* person do that?" has an answer. That is why a persona has a name and specific attributes, and why a user story's role is a persona, never "a user".

Every attribute must be **load-bearing**: it shapes a requirement, a job, an onboarding decision, a usability NFR or a message. An attribute that cannot be used that way is decoration; cut it.

## Where It Sits

```
Strategy: vision ─► stakeholder map ─► … ─► GTM (ICP, beachhead)
Ideate:   USER PERSONAS ─► JTBD analysis ─► opportunity solution tree ─► impact map ─► functional requirements ─► …
```

| Reads | What it takes |
|---|---|
| `gtm-strategy` | The beachhead and ICP: the *company* (or, for B2C, the individual) the personas live inside. The ICP is not a persona |
| `stakeholder-mapping` §2 | The customer's **buying committee** roles. Personas come from these roles; **delivery stakeholders** (the product owner, design partners, reviewers, internal teams) never become personas |
| Problem statement, vision, any interview notes the user supplies | The protagonist, and the only first-hand evidence available |

| Feeds | What it gives |
|---|---|
| `jtbd-analysis` | One job statement per persona; JTBD refines it into job stories and forces. At lean, JTBD is folded into the persona |
| `impact-mapping` | The WHO actors, including blockers |
| `user-story-writing` | The "As a \<persona\>" role |
| `moscow-prioritization` | Needs scored per persona, not pooled (Olsen, *The Lean Product Playbook*); at enterprise, the persona-weighted feature matrix |
| `user-journey-mapping` | One journey per primary persona × high-value job |
| `gtm-strategy` messaging | Each customer persona's decision style and information sources, so proof points are chosen per audience (Lauchengco, *Loved*) |

## The Honesty Rule: Provenance, Not Just a Label

Every persona carries a grounding label at the top. Cooper's **provisional persona**, Don Norman's ad hoc persona, Adlin and Pruitt's **assumption persona** and Gothelf's proto-persona are one idea: a persona built without research, legitimate as a *hypothesis with a test attached*, never as a finding.

| Label | When |
|---|---|
| `PROTO — assumption-based · written by requirements-analyst (AI) from <inputs> · no user research` | Default for anything the agent writes. `<inputs>` names the real sources: problem statement, ICP, stakeholder map §2, the user's own descriptions |
| `MIXED — <n> of <m> load-bearing attributes interview-grounded` | Some attributes trace to interviews the user (or a design-partner session) actually held, with notes the agent was given |
| `RESEARCH — interview-grounded` | Every load-bearing attribute traces to such an interview, and the **user** confirmed the upgrade at review |

**The agent may never apply a RESEARCH label on its own authority**, and it cannot hold an interview: the user or a design-partner session is the interviewer. The agent writes the interview guide (the validation questions) and tags each attribute with its source. Three more rules:

- **Source tag on every attribute** (Pruitt and Adlin's sourced factoid): `[DP-2 · 2026-11-03]` for an interview, `[support tickets]` or `[stakeholder map §2]` for second-hand evidence, `[assumption]` otherwise. A reviewer can see the seam between evidence and guess.
- **Validation questions on every PROTO or MIXED persona**: for each load-bearing assumption, the question about a **specific past event** that would confirm or overturn it, and the answer that would mean the persona is wrong (Fitzpatrick, *The Mom Test*: compliments, fluff and feature ideas ground nothing).
- **Worked examples that show RESEARCH are marked illustrative**; an example never teaches the agent to claim interviews nobody held.

Field definitions, elicitation questions and the leave-out list: `./references/persona-fields-and-grounding.md`. Read it when filling a field or labelling grounding.

## Persona Types: Design for One Primary per Interface

Every persona gets exactly one **type** (Cooper et al., *About Face*):

| Type | Who | Design consequence |
|---|---|---|
| **Primary** | Needs cannot be met by an interface built for anyone else | The design target. **Exactly one per interface**; two primaries means two surfaces, named. More than about three primaries means the scope is too broad |
| **Secondary** | Mostly served by the primary's interface, plus a few additions | Accommodated without compromising the primary |
| **Supplemental** | Fully served by the primary's design | Listed so the team knows they were considered |
| **Customer** | The buyer, not necessarily a user (the committee's economic buyer, often a security or finance reviewer) | Feeds the purchase, admin and trust story, not the daily interface |
| **Served** | Never touches the product but is affected by it (patients, data subjects, a firm's clients who receive its emails) | Constraints and NFRs; no interface designed for them |
| **Negative** | Explicitly not designed for (the power user, a disqualified segment) | Named so scope creep can be refused |

"Design for one" is the core claim of *Inmates*: a design that delights one well-chosen primary tends to satisfy many others; one that tries to please everyone pleases no one. Buyer and daily user are **separate personas** whenever they differ.

## Producing the Artifact

1. **Label kind and provenance first.** No interview notes from the user means PROTO with the provenance line.
2. **Read the inputs** (Where It Sits). List the candidate roles from the committee; with no committee (lean, consumer), run Cohn's **role brainstorming** (*User Stories Applied*): every way someone interacts with the system, near-duplicates merged.
3. **List behavioural variables** per role: two-ended ranges under activities, attitudes, aptitudes, motivations and skills (for example "trusts automated output ↔ verifies every result by hand"). Place each interviewee on each range; with none, place **hypothesised** positions and say so. The table is then the **persona hypothesis** and the recruiting plan.
4. **Find patterns.** People who cluster together across several variables are one candidate persona. **Merge** candidates that differ only in demographics or job title; a gap in the mapping is a missing persona.
5. **Fill the fields from the pattern**, each with a source tag: goals split three ways, context, forces, trust, one job statement.
6. **Designate types**: one primary per interface, a customer persona where buyer ≠ user, served where the product acts on non-users, one negative persona.
7. **Write validation questions** per PROTO / MIXED persona, and who to recruit first.
8. **Set `review-by:`** and the reopen triggers (Lifecycle below).
9. **Validate** against `./resources/persona-checklist.md`, run `python3 ./scripts/check-user-personas.py <artifact>`, then write `ideate/user-personas.md` from `./templates/user-personas.md` and present it to the user for review before `jtbd-analysis`.

The full synthesis procedure, with a worked variable table, and the persona lifecycle: `./references/synthesis-and-lifecycle.md`. Read it at step 3 whenever there are interview notes, or more than two roles.

## Goals, Forces and the Job

- **Goals, not tasks** (Cooper). Tasks are today's steps with today's tools; goals change slowly. Split them: **end goals** (what they want done → functional requirements and the job), **experience goals** (how they want to feel: in control, not stupid → usability NFRs and onboarding), **life goals** (who they want to be, including what gets them recognised → messaging; one line or omitted for a B2B tool). Write every goal **solution-free**: "never send a client a reminder she has not seen", not "use the AI reminder assistant".
- **Forces of progress in persona form** (Christensen et al., *Competing Against Luck*): **Trigger = push** (the struggling moment that ends passive looking), **Current approach = habit** (what gets fired), **Adoption barrier = anxiety**. The **pull** of a new solution belongs in `jtbd-analysis`, because a persona stays solution-free.
- **Trust in automated output** (Ram Srinivasan, *Simple Data*): where the product drafts, classifies or decides for this person, record whether they must see the reasoning before acting. A trust barrier needs a different fix from a usability barrier.
- **The job defines the segment; the persona describes the person who executes it.** The persona's job field holds **one line**: the job statement, `[verb] [object] [clarifier]`, solution-free. Job stories, forces tables and outcome ranking live in `jtbd-analysis`; repeating them here creates the duplicate artifacts of dogfood defect #1256. Personas that share a job and circumstance and differ only in demographics are one persona.

## Scale

`phase-requirements.json` **requires** the artifact at every profile (`ideate/user-personas.md`); at lean, `jtbd-analysis` is skipped and folded in here.

| Profile | Shape |
|---|---|
| **lean** | One or two PROTO personas with the provenance line, one primary per interface, a one-line negative persona. Each: end and experience goals, current approach, primary frustration, trigger, adoption barrier; **JTBD folded in**: the job statement plus one or two job stories and a one-line forces summary; two or three validation questions; behavioural variables as a single line. No narrative, no variable table, no feature matrix: `./examples/01-lean-lunch-tracker.md` |
| **standard** | A behavioural-variable table across roles; full type designation (primary per interface, secondaries, a customer persona when buyer ≠ user, served where relevant, one negative); source tags on every attribute; validation questions; job statement only; `review-by:`. Attributes move to interview-grounded one by one as the user's design-partner sessions confirm them: `./examples/02-standard-ledgerline.md` |
| **enterprise** | Personas **per tenant role** (and per tenant type where they buy or work differently), served personas, a **persona-weighted feature matrix** feeding `moscow-prioritization`, a foundation section listing the factoids behind each persona, and a reuse and retirement policy across releases: `./examples/03-enterprise-platform.md` |

## Lifecycle: Reopen, Revisit, Retire

Pruitt and Adlin (*The Persona Lifecycle*) found personas fail more often from neglect than from bad construction. The set is a living artifact with five stages: plan (persona hypothesis), build (factoids → skeletons → personas), communicate, use (journeys, stories, the weighted matrix) and review and retire. **Reopen triggers**, each a change request back to `requirements-analyst`:

- `ux-architect` finds a job no persona covers, or a missing persona at journey-map review ("what about the auditor who reads reports but never logs in?"). That is usually a secondary or served persona the type list should have caught.
- A design-partner session contradicts an attribute: correct or delete it, never defend it.
- The GTM adds a segment or tenant type, or `review-by:` passes.

A persona that no longer matches the evidence, product or market is marked `Status: retired` with the reason, never silently deleted. Editing an approved artifact sends it back to draft for the user's re-approval.

## What to Leave Out

Age, gender, hometown, hobbies, invented biography and quotes nobody said: they predict nothing and they make an assumption look like a person. Firmographic facts that do drive requirements (company size, regulatory exposure) stay, with the reason. Keep a **first name**, because a named persona defeats the elastic user; **use no photo or generated face**. Cooper and Pruitt-Adlin recommend one, and this skill departs from them deliberately: an agent-chosen face encodes a stereotype and makes an assumption look like a real person.

## Anti-Patterns

| Anti-pattern | Why it fails |
|---|---|
| **Elastic user** | "The user" bends to every argument; stories with a generic role settle nothing |
| **Agent-claimed research** | A RESEARCH label with no interviews the user held: a guess masquerading as evidence |
| **Too many personas / no primary** | A cast of a dozen means designing for none; fix with types, one primary per interface |
| **Edge case as primary** | A rare, extreme user drives the main interface; handle edge cases, do not design for them |
| **Blended persona** | Buyer and daily user in one block: the buyer's trust story and the user's flow both vanish |
| **Demographic-only difference** | Two personas that sit in the same place on the variables are one persona; merge |
| **Self-referential persona** | The team's (or the agent's) own idea of a user, built from no input |
| **Solution-shaped goals or job** | "Wants our dashboard" automates the current workaround and pre-decides the design |
| **Job stories in the persona** (standard and enterprise) | Duplicates `jtbd-analysis`; the persona holds one job statement |
| **Never revisited** | No `review-by:`, no retirement: stale guesses keep steering decisions |
| **Product-specific personas as rules** | A role from one product (a data steward, a nurse) required of every product; they belong in examples |

Use canonical terms from `glossary-management`: **Persona**, **Persona Type**, **Provisional Persona**, **Behavioural Variable**, **Elastic User**, **Ideal Customer Profile**, **Buying Committee**, **Delivery Stakeholder**, **Jobs To Be Done (JTBD)**. Run `methodology-review` before hand-off.
