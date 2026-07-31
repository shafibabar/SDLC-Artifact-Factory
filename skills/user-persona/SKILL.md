---
name: user-persona
description: >
  Teaches the requirements-analyst to create user personas — evidence-based archetypes of real
  user segments capturing goals, behaviors, pain points, and the jobs they need done — and to
  distinguish a proto-persona (assumption-based, clearly labeled) from a research-persona (grounded
  in real interviews). Used during Strategy to give discovery a concrete human anchor; the repo
  primary personas are the Data Steward and the Compliance Officer. Covers persona fields (segment,
  goals, behaviors, pains, JTBD link), the honesty rule for labeling assumptions, what to leave out
  (demographics that do not drive design), and how a persona becomes the "As a <persona>" role in a
  user story.
version: 2.0.0
phase: strategy
owner: requirements-analyst
created: 2026-06-24
related: [jtbd-analysis, user-story-writing, gtm-strategy, stakeholder-mapping]
tags: [strategy, requirements, persona, proto-persona, research-persona, user-research, discovery]
---

# User Persona

## Purpose

A user persona is a composite archetype of a real *type* of user — not a demographic stereotype and
not a fictional character. It gives discovery a concrete human anchor so that requirements stop being
abstract. "The system must scan files" is ambiguous. "The Data Steward must see a classified inventory
of every connected source within one working session, so she can answer *where does customer PII live*
with evidence instead of folklore" is actionable — because it names who, what progress they seek, and
what blocks them today.

A persona exists to make requirements concrete and traceable. Every attribute must be *load-bearing*:
it should shape a requirement, a job story, an onboarding decision, or an NFR. An attribute that could
not be used that way is decoration — cut it.

---

## The Honesty Rule: Proto vs Research Persona

The single most important distinction in this skill. Every persona is one of two kinds, and it must be
**labeled** as such at the top of the artifact:

| Kind | Grounded in | When to use | Label |
|---|---|---|---|
| **Proto-persona** | Team assumptions, existing knowledge, informed guesses | Before any customer interviews exist — to start discovery, not to end it | `PROTO — assumption-based` |
| **Research-persona** | Real interviews (Mom-Test-compliant, specific past behavior) | After design-partner conversations have produced evidence | `RESEARCH — interview-grounded` |

The honesty rule: **label assumptions as assumptions.** A proto-persona is legitimate and useful — it
seeds JTBD analysis and gives the team something to test against — but presenting an assumption-based
archetype as if it were validated fact is the failure this skill exists to prevent. The lifecycle is
*start proto, validate to research*: draft the proto-persona, then upgrade each attribute to research
grounding as real conversations confirm or correct it. Never let a proto-persona quietly become the
team's source of truth without that validation step.

Grounding standard: research-persona attributes come from questions that ask about **specific past
events**, not hypotheticals or compliments (Rob Fitzpatrick, *The Mom Test*). "Walk me through the last
time you needed to do this" produces a fact; "would you use a tool that…" produces flattery. See
`references/persona-fields-and-grounding.md` for the full grounding requirement and the elicitation
question mapped onto each field.

---

## Persona Fields

Every persona carries these fields. A persona missing goals, pains, or current approach cannot generate
a job story with real motivation, and is incomplete. Full definitions and the interview question that
elicits each: `references/persona-fields-and-grounding.md`.

- **Segment / role** — the user *type* and the company profile they sit in (size, industry,
  regulatory exposure), consistent with the ICP from `gtm-strategy`.
- **Goals** — the primary outcome this person most wants, plus 2-3 secondary goals and the success
  metric by which they judge themselves (what gets them recognized).
- **Behaviors** — how they work today: their current approach (the workaround they use *without* your
  product), decision-making style, technical literacy, and where they go to learn about tools.
- **Pain points** — the primary frustration with the current approach plus 2-3 secondary pains. These
  are the switching motivation; no pains means no reason to adopt.
- **Jobs to be done** — the link to `jtbd-analysis`: each persona names the core job(s) they are
  hiring a solution for, so every persona traces to at least one JTBD.

---

## What to Leave Out

Do not invent demographics or biography that do not drive a design decision. Age, gender, hometown, and
a stock photo do not predict product behavior — goals, pains, and current approach do. This is the
central anti-pattern: **a demographic-only persona is decoration.** If an attribute cannot be traced to
a requirement, a job story, an onboarding decision, or an NFR, it does not belong in the persona. The
full "leave out" list and the reasoning: `references/persona-fields-and-grounding.md`.

---

## Anti-Patterns

| Anti-Pattern | Why it fails |
|---|---|
| Inventing demographics that don't drive design | Age/gender/location don't predict behavior; goals and pains do. |
| Proto-persona presented as validated fact | Breaks the honesty rule — an assumption masquerading as evidence. |
| No pain points | A persona with only goals generates no job story with a real motive. |
| No current approach | Without knowing how they cope today you can't explain why they'd switch. |
| Aspirational persona | "Our ideal user is a visionary data leader" is marketing, not a real user. |
| Single blended persona for a multi-role product | Needs differ by role (Data Steward vs Compliance Officer); one average hides all of them. |

---

## How Personas Connect

- **→ `jtbd-analysis`**: the persona's jobs-to-be-done field is the handoff. Each persona names the
  core job it hires a solution for; JTBD analysis then writes the job stories against that persona.
  A persona with no linked job cannot feed JTBD.
- **→ `user-story-writing`**: the persona *is* the role in "**As a** \<persona\>, I want… so that…".
  A user story whose role is a generic "user" rather than a named persona has lost its human anchor.
- **← `gtm-strategy`**: the persona lives inside the ICP company profile from GTM strategy — the ICP
  is the *company* type, the persona is the *person* type within it.
- **← `stakeholder-mapping`**: "Manage Closely" stakeholders often correspond to the primary user,
  the economic buyer, or the champion — model each distinct role as its own persona.

---

## Repo Primary Personas

For the data-estate / compliance product, model at minimum these two primary personas (worked out in
full, each traceable to a JTBD, in `references/persona-template-and-examples.md`):

1. **The Data Steward** — operates the day-to-day mapping and classification workflow; needs an
   evidence-backed inventory of where sensitive data actually lives.
2. **The Compliance Officer** — owns the audit/attestation story; needs a defensible gap report across
   the estate before a SOC 2 window or a customer security questionnaire.

Model the economic buyer and technical champion as secondary personas when a multi-stakeholder deal
requires it — see the examples reference for how to extend beyond the two primaries.

---

## Producing the Artifact

1. Decide proto or research for this pass, and label it. If no interviews exist yet, it is proto.
2. Pull the ICP company profile from `gtm-strategy` and the roles from `stakeholder-mapping`.
3. Draft each field (segment, goals, behaviors, pains, JTBD link) from the best evidence available.
4. For a research pass, confirm each attribute came from a specific-past-event question, not a
   hypothetical or a compliment (grounding standard above).
5. Check anti-patterns: no pains, no current approach, invented demographics, or an unlabeled
   assumption all mean the persona is not done.
6. Confirm every persona links to at least one JTBD and can serve as an "As a \<persona\>" story role.
7. Present to Shafi for review before the personas feed `jtbd-analysis`.

Template and two fully worked repo personas: `references/persona-template-and-examples.md`.
Field definitions, grounding, proto→research lifecycle, and what to leave out:
`references/persona-fields-and-grounding.md`.
