---
name: user-journey-mapping
description: >
  Teaches the ux-architect to build a User Journey Map — the horizontal stages a
  persona moves through, and per stage their actions, touchpoints, thoughts, and an
  emotion curve — plus the identification of moments of truth, pain points, and
  opportunities, and the extension into a Service Blueprint (front-stage vs back-stage
  actions separated by the line of visibility). Grounded in Stickdorn This Is Service
  Design Doing. Used during Ideate to see the end-to-end experience before designing
  screens.
version: 2.0.0
phase: ideate
owner: ux-architect
created: 2026-06-25
tags: [ideate, ux, journey-map, touchpoints, moments-of-truth, service-blueprint, line-of-visibility]
produces: user-journey-map
domain: ux
status: stable
related: [user-persona, ux-flow-design, information-architecture, event-storming-facilitation, glossary-management]
---

# User Journey Mapping

## Purpose

A User Journey Map is the end-to-end story of one persona completing one high-value
job — from the trigger that starts it to the outcome that ends it. It captures not
only what the persona *does* but what they *think* and *feel* at each stage, so the
experience can be seen and fixed before any screen is designed.

Journey maps reveal friction the feature list cannot. A product can have every right
feature and still fail because the path between them is painful. During Ideate, the
map makes that pain visible early — while it is still cheap to change. It is a
customer-perspective artifact, drawn from `user-persona` output and the persona's
job, and it feeds `information-architecture`, `ux-flow-design`, and (for journeys with
a thick operational backstage) a `service-blueprinting` pass in Design.

Grounded in Marc Stickdorn et al., *This Is Service Design Doing* — journey maps and
service blueprints are its core artifacts.

---

## The Persona Anchor — One Persona, One Journey

A journey belongs to a *named persona with stakes*, not to "a user." Map **one persona
per journey**; if two personas experience the same job differently (a Data Steward
classifying assets vs. a Compliance Officer preparing an audit), they get **two maps**,
not one blended map. Without a specific persona's stakes, the Thoughts and Emotions
lanes become fiction and the pain points become guesses.

Map the *highest-value job per primary persona* deeply. Add a second journey for a
persona only when it will change a design decision — ten shallow maps of uniform depth
are worth less than two deep ones.

---

## Journey Map Structure

Stages run **left to right** across the top (the persona's progression through their
job, never a tour of product screens). Under each stage sit four lanes plus the
analytical annotations:

| Lane | Captures |
|---|---|
| **Actions** | What the persona does at this stage |
| **Touchpoints** | Which part of the product (or external system) they interact with |
| **Thoughts** | What they think — verbatim from research where possible |
| **Emotion curve** | How they feel, plotted as a line across the stages (the arc, not isolated labels) |

The **emotion curve** is the spine of the map: a single line rising and falling across
the stages. Its **valleys** are the deliverable — the stages where the persona feels
anxious or frustrated are the highest-priority design opportunities. A map whose curve
never dips is a warning sign, not a clean bill of health (see Anti-Patterns).

Full definitions of each lane, how to set journey **scope and granularity**, how to
**source a journey from research rather than invention**, and the annotation mechanics
are in **`references/journey-map-structure.md`**.

---

## The Analytical Output — Moments of Truth, Pain Points, Opportunities

The lanes are the input; the analysis is the deliverable. Three annotations turn a
descriptive map into an artifact that changes decisions:

- **Moments of Truth** — the few touchpoints where the persona's overall perception of
  the whole service is disproportionately shaped (Jan Carlzon's term, cited by
  Stickdorn). Concentrate design effort here; do not spread investment evenly across
  every stage. A Moment of Truth usually sits at an emotion-curve valley or peak.
- **Pain points** — friction at a stage. Every pain point must resolve into one of:
  (1) a design decision in a downstream UX flow, (2) a new user story in the backlog,
  or (3) an explicitly accepted limitation with rationale. A pain-point lane with no
  follow-through is a poster, not an artifact.
- **Opportunities** — what the product could do better at this stage to remove friction
  or amplify delight, each traceable to a downstream artifact.

Annotation mechanics, the pain-point → action log format, and common mistakes are in
`references/journey-map-structure.md`.

---

## Journey Map vs Service Blueprint

The journey map is **customer-perspective only** — its Touchpoints lane records *where
the persona looks*, never *what has to succeed behind that screen* for the look to be
correct. That is a real and deliberate limit, not an oversight.

A **Service Blueprint** extends the map across the **line of visibility**: it adds
back-stage lanes (the internal actions and systems the customer never sees) beneath the
front-stage actions the customer does see. Where the journey map asks "what does the
persona experience?", the blueprint also asks "what must act, unseen, for that
experience to work?"

| | User Journey Map | Service Blueprint |
|---|---|---|
| Perspective | Customer / front-stage only | Front-stage **and** back-stage |
| Question | What does the persona experience? | What must succeed, seen and unseen, for it to work? |
| Key boundary | — | The **line of visibility** (front-stage above, back-stage below) |
| Reveals | Emotion valleys, pain points | Back-stage gaps a map hides (a stalled scan behind a slow report) |
| Built when | Ideate — every primary journey | Design — journeys with a thick backstage |

**When to use each.** Always draw the journey map first — every primary persona's
highest-value job gets one, in Ideate. Extend to a blueprint only for journeys where
the front-stage/back-stage gap is large (an estate scan, a classification pass, a
compliance evaluation), using the emotion-curve valleys as the prioritisation signal.
A simple CRUD-like journey (editing a display name) has a thin backstage and does not
earn a blueprint.

The blueprint's full lane structure, the line of visibility, the two companion boundary
lines, support processes, how a blueprint sources its back-stage lanes from the
`event-storming-facilitation` output (never from the agent's own inference), and a
worked blueprint for a Compliance Officer requesting an audit-ready report are in
**`references/service-blueprint.md`**.

> Microfrontend note: this repo's front-stage is a shell plus independently-deployable
> remotes, so a single journey's touchpoints and a blueprint's front-stage lane span
> fragment boundaries. A Moment of Truth often lands exactly at a hand-off *between*
> remotes — flag those explicitly; see `references/service-blueprint.md`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Persona grounded | Uses a named persona from `user-persona` with real stakes | Generic "user" with no attributes |
| One persona per map | Each map is a single persona's journey | Two personas blended into one map |
| Emotion curve present | A curve is plotted; valleys identified | No emotional assessment, or all-flat |
| Moments of Truth marked | The few high-weight touchpoints identified | Every stage weighted equally |
| Pain points actioned | Each resolves to a flow decision, story, or accepted limitation | Pain listed with no follow-through |
| Sourced, not invented | Thoughts trace to research or are labelled assumptions | Plausible-sounding verbatims with no basis |
| Blueprint scoped correctly | Blueprint added only where the backstage is thick | Blueprint for every journey, or none where needed |

---

## Anti-Patterns

- **The generic user.** Mapping "a user" instead of a named persona with a deadline and
  a stake. The Thoughts and Emotions lanes become fiction.
- **Feature tour dressed as a journey.** Stages named after screens ("Dashboard stage")
  rather than the persona's progression. The journey belongs to the persona; the
  product is only the Touchpoints lane.
- **Happy-feelings mapping.** Every stage marked Satisfied. A curve with no valley is
  evidence the map was written to flatter the design. The valleys are the deliverable.
- **Invented verbatims.** Writing plausible Thoughts with no basis in research and not
  labelling them as assumptions. Unvalidated thoughts are hypotheses — label them.
- **Pain with no follow-through.** Friction that never becomes a story, a flow decision,
  or an accepted limitation.
- **Front-stage blindness.** Treating the Touchpoints lane as the whole truth and never
  asking what must succeed behind it — a slow report blamed on the UI when the real
  cause is a stalled back-stage scan. Escalate to a blueprint instead.
- **One-time artifact.** Mapping once and never revisiting when usability or support
  data contradicts it. Reality wins; update the map.

---

## Output Format (skeleton)

```markdown
---
name: user-journey-map
product: [product name]
version: 1.0.0
phase: ideate
created: [date]
owner: ux-architect
---

# User Journey Map: [Journey Name]

**Persona:** [name and role]  **Job:** [the job this journey completes]
**Scenario:** [brief narrative context]

| Lane | Stage 1 | Stage 2 | Stage 3 | ... |
|---|---|---|---|---|
| Actions | | | | |
| Touchpoints | | | | |
| Thoughts | | | | |
| Emotion | | | | |

## Emotion Curve
[line across the stages; valleys marked]

## Moments of Truth
[the few high-weight touchpoints]

## Pain Point → Action Log
| Stage | Pain point | Resolution | Downstream artifact |
```

Full annotated template and the blueprint output format: see `references/`.
