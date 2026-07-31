# Journey Map Structure — Lanes, Scope, Sourcing, and Annotation

Reference for `user-journey-mapping`. The SKILL.md body gives the decision-shaping
overview; this file is the full mechanics — every lane defined, how to set scope and
granularity, how to source a journey from research, and how to annotate Moments of
Truth, pain points, and opportunities. Grounded in Stickdorn et al., *This Is Service
Design Doing* (journey maps, Ch. 3).

---

## 1. The Anatomy of a Journey Map

A journey map is a grid. **Stages** are the columns, running left to right in the order
the persona lives them. Under each stage sit the lanes (rows). The four descriptive
lanes below plus the emotion curve are the standard set; the three analytical
annotations (Section 5) are drawn on top of them.

```
Stage:      | Trigger         | Discovery       | Setup           | Analysis        | Reporting       | Closure
------------|-----------------|-----------------|-----------------|-----------------|-----------------|----------------
Actions:    | audit notice    | logs in first   | connects data   | reviews gap     | generates gap   | exports report;
            | from auditor    | time            | sources; scans  | report; drills  | report; reviews | shares w/ team
------------|-----------------|-----------------|-----------------|-----------------|-----------------|----------------
Touchpoints:| Email/Calendar  | Login remote;   | Connect Source  | Compliance      | Reports remote; | Export fn;
            |                 | Onboarding      | wizard (remote) | Dashboard       | Generate form   | Email/portal
------------|-----------------|-----------------|-----------------|-----------------|-----------------|----------------
Thoughts:   | "where do we    | "where do I     | "will it hit    | "so much data — | "will the       | "I hope the
            | stand before    | even start?"    | our S3? Drive?" | what matters    | auditor accept  | auditor finds
            | the auditor?"   |                 |                 | first?"         | this format?"   | this OK"
------------|-----------------|-----------------|-----------------|-----------------|-----------------|----------------
Emotion:    |   😟            |   😐            |   😐            |    😊           |    😊           |    😌
  curve →   | anxious ●───────── uncertain ●──── cautious ●──────── engaged ●──────── satisfied ●──── relieved ●
```

### Stages

The high-level phases of the persona's progression — named for *what the persona is
trying to accomplish*, never for a product screen. Choose a stage pattern that fits the
job:

| Journey type | Common stage pattern |
|---|---|
| New-capability discovery | Trigger → Awareness → Evaluation → Onboarding → First Use → Habit → Advocacy |
| Regular in-product task | Entry → Setup → Execution → Review → Outcome → Follow-on |
| Problem / compliance resolution | Problem identified → Investigation → Resolution → Verification → Closure |

Five to eight stages is typical. Fewer than four usually means the journey is too
coarse to reveal friction; more than nine usually means it has drifted into a
screen-by-screen flow (that belongs in `ux-flow-design`, not here).

### Actions lane

What the persona *does* at each stage, in their own terms ("connects the S3 bucket",
not "invokes the Connect Source API"). One to three short action phrases per stage.

### Touchpoints lane

Which part of the product — or which external system — the persona interacts with. In
this repo's microfrontend front-end, name the **remote** (shell fragment) the touchpoint
lives in when it is known (e.g. "Connect Source wizard — sources remote"), because a
single journey routinely crosses several independently-deployable remotes, and the
seams between them are where hand-off friction hides. External touchpoints (Email,
Google Drive, S3, an auditor's portal) belong here too — the persona's experience does
not stop at the product boundary.

### Thoughts lane

What the persona is thinking — ideally a near-verbatim quote from research (an
interview, a support ticket, a sales call). If no real quote exists, write the most
honest hypothesis and **label it as an assumption** (see Section 4). The Thoughts lane
is where an ungrounded map quietly turns into fiction.

### Emotion curve

The persona's emotional state plotted as a **single continuous line** across the
stages — the arc, not six disconnected labels. A simple scale works: Frustrated <
Anxious < Cautious < Neutral < Engaged < Satisfied < Delighted. What matters is the
*shape*:

- **Valleys** — stages of frustration or anxiety. These are the highest-priority
  design opportunities and the deliverable of the whole map.
- **Peaks** — stages of satisfaction or delight. Preserve and amplify them.
- **Flat runs** — neutral stretches. Acceptable, but scan for cheap wins.

A valley at "Setup" (connecting sources) translates directly to a P1 investment in the
Connect Source wizard, which flows on to a `ux-flow-design` priority and a component
spec priority.

---

## 2. Setting Journey Scope

Scope is the pair of brackets around the journey: **where does it start, where does it
end?** Get this wrong and every lane below inherits the error.

- **Start at the real trigger, not the first click.** Maya's audit journey starts when
  the auditor's email lands — days before she opens the product — not at the login
  screen. The pre-product stages are often where the sharpest anxiety (and the sharpest
  opportunity) lives.
- **End at the persona's outcome, not the product's last screen.** The journey ends when
  Maya has *submitted a report the auditor accepts*, not when she clicks Export.
  "Closure" includes the anxious wait for the auditor's reaction.
- **One job per journey.** If the bracket contains two distinct jobs (connect sources
  *and* prepare an audit), split it into two maps. A map that tries to cover everything
  reveals nothing.

---

## 3. Setting Granularity

Granularity is how finely the stages slice the journey. Match it to the decision the
map must inform:

| If the map is for... | Granularity |
|---|---|
| Seeing the whole experience shape (Ideate) | Coarse — 5–7 stages, one line of the story per stage |
| Prioritising which flows to design next | Medium — enough detail that each valley points to one flow |
| Specifying a screen sequence | Too fine for a journey map — switch to `ux-flow-design` |

The journey map answers *what* experience to design; the user flow answers *how* to
build it. Keep the map above the level of buttons and fields.

---

## 4. Sourcing a Journey From Research, Not Invention

A journey map is a research synthesis, not a creative-writing exercise. Every lane
should trace to evidence:

| Lane | Preferred source | If no evidence exists |
|---|---|---|
| Stages | Observed task sequence, JTBD interview | Hypothesise; mark the map "draft — unvalidated" |
| Actions | Contextual inquiry, session recordings | Reasoned assumption, labelled |
| Touchpoints | The actual product + integration inventory | Usually knowable without research |
| Thoughts | Interview quotes, support tickets, reviews | Assumption in *[square brackets]* or italics |
| Emotion | Interview affect, survey/NPS verbatims, ticket tone | Assumption, labelled |

**Label assumptions explicitly.** A persuasive map built on invented detail is more
dangerous than an honestly-incomplete one, because a filled-in grid reads as more
authoritative than it is. Mark every unvalidated cell so it can be tested, and read the
map back to a real user whenever a source exists.

---

## 5. Annotating the Analysis

The descriptive lanes are the input; these three annotations are the output that
changes decisions.

### Moments of Truth

A Moment of Truth (Jan Carlzon, cited by Stickdorn) is a touchpoint that shapes the
persona's perception of the *whole* service out of all proportion to its size — an
emotionally charged, high-stakes, or trust-critical interaction. Mark the **two or
three** Moments of Truth on the map (not every touchpoint — the discipline is
selection) and concentrate design and prototyping effort there. A Moment of Truth
almost always coincides with an emotion-curve valley or peak; if you find one with a
flat, neutral emotion, re-examine — either it is not actually a Moment of Truth, or the
emotion lane is under-researched.

A Moment of Truth can be *caused* by something the persona never sees — a late report
(front-stage Moment of Truth) whose root cause is a stalled back-stage scan. When a
valley has no visible front-stage cause, that is the signal to extend the map into a
Service Blueprint (see `service-blueprint.md`).

### Pain points

Friction at a stage. Every pain point must resolve into exactly one of three
dispositions — this is what makes the map an artifact rather than a poster:

1. **A design decision** in a downstream `ux-flow-design` flow (how to remove it).
2. **A new user story** in the backlog (a gap the flow alone cannot close).
3. **An explicitly accepted limitation**, with written rationale.

Record every disposition in a **pain-point → action log**:

| Stage | Pain point | Resolution | Downstream artifact |
|---|---|---|---|
| Discovery | No clear starting point | Audit-readiness onboarding track | Story: "guided onboarding for compliance audits" |
| Setup | Unclear source-connect order | "Start here" recommendation in wizard | Flow: connect-source-guided-wizard |
| Analysis | Too many assets, no priority | Severity-scored gap view sorted by risk | Component spec: ComplianceGapReport (severity sort) |
| Reporting | Report format mismatch | SOC 2 / GDPR report templates | Story: "audit-ready report templates per framework" |

### Opportunities

The positive framing of a pain point — what the product could do better at this stage.
Each opportunity should point to a downstream flow, story, or component so it does not
evaporate after the workshop.

---

## 6. Journey Map Inventory

Before drawing any single map, list the journeys worth drawing — one row per
persona × highest-value job — so effort goes where it changes decisions:

| Persona | Job | Journey name | Priority |
|---|---|---|---|
| Maya Chen (Compliance Officer) | Prepare for an audit | Audit preparation journey | P1 |
| Maya Chen (Compliance Officer) | First estate scan | First data estate scan | P1 |
| Alex Rivera (Data Steward) | Classify data assets | Data asset classification | P1 |
| Sam Okafor (CISO) | Review security posture | Security posture review | P2 |

---

## 7. Common Mistakes

- **Stages named after screens.** "Dashboard stage", "Reports stage" — the journey has
  become a feature tour. Rename stages after the persona's intent.
- **Starting at the login screen.** The trigger and its anxiety live before the product;
  a journey that starts at login amputates the most valuable stages.
- **An all-satisfied emotion curve.** No valley means the map was written to flatter the
  design. Re-check the Thoughts lane against real evidence.
- **Filled-in cells with no source.** A complete-looking grid of invented Thoughts.
  Label assumptions; a dry honest gap beats a confident fiction.
- **Pain points with no action log.** Friction listed and abandoned. Every pain point
  gets a disposition.
- **Uniform Moments of Truth.** Marking every touchpoint as critical is the same as
  marking none. Pick two or three.
- **Blending two personas.** One map, one persona. Split when experiences diverge.
- **Never updating.** The map is a living hypothesis; when usability or support data
  disagrees with it, reality wins.
