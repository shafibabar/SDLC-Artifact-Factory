---
name: user-journey-mapping
description: >
  Teaches how to produce a user journey map — the end-to-end experience of a
  specific persona completing a high-value job-to-be-done across all touchpoints,
  capturing what the user does, thinks, and feels at each stage, along with
  friction points and opportunities. User journey maps bridge the persona and
  JTBD analysis from the Ideate phase to the UX flow and component design in the
  Design phase. Produced by the ux-architect agent during the Design phase.
version: 1.0.0
phase: design
owner: ux-architect
tags: [design, ux, user-journey, persona, jtbd, touchpoints, friction, opportunity]
---

# User Journey Mapping

## Purpose

A user journey map is a narrative of a specific persona's experience completing a specific job-to-be-done — from their initial trigger through to their final outcome. It captures not just what the user does (the steps) but what they think and feel (the emotional state) at each step.

Journey maps reveal friction points that the feature list does not. A product can have all the right features and still fail because the journey between them is painful. Journey maps make that pain visible before any UI is built.

---

## Journey Map vs User Flow

These are distinct artifacts with different purposes:

| Artifact | Question it answers | Level of detail | Created when |
|---|---|---|---|
| **User Journey Map** | What is the user's full experience? What do they think and feel? | High-level; whole experience; emotional | Before UX flow design; based on persona + JTBD |
| **User Flow** | What are the exact steps and system decisions? | Detailed; screen by screen; logical | After journey map; input to frontend-engineer |

The journey map identifies *what* experience to design. The user flow specifies *how* to implement it.

---

## Journey Map Structure

A journey map has six rows. Every stage of the journey populates all six rows.

| Row | Name | Content |
|---|---|---|
| 1 | **Stages** | The high-level phases of the journey (Trigger → Awareness → Onboarding → Core Use → Outcome) |
| 2 | **Actions** | What the user does at each stage |
| 3 | **Touchpoints** | Which part of the product (or external system) the user interacts with |
| 4 | **Thoughts** | What the user is thinking — verbatim if possible from user research |
| 5 | **Emotions** | How the user feels — expressed on a simple scale: Frustrated / Neutral / Satisfied / Delighted |
| 6 | **Opportunities** | What the product could do better at this stage to reduce friction or increase delight |

---

## Journey Stages

Choose the stages appropriate to the job being mapped. Common stage patterns:

### Awareness → Action journey (for new capability discovery)
```
Trigger → Awareness → Evaluation → Onboarding → First Use → Habit → Advocacy
```

### Task completion journey (for regular in-product use)
```
Entry → Setup → Execution → Review → Outcome → Follow-on Action
```

### Problem resolution journey (for support or compliance workflows)
```
Problem identified → Investigation → Resolution → Verification → Closure
```

---

## Journey Map Example

**Persona:** Maya Chen — Compliance Officer  
**Job:** When a compliance audit approaches, I want to understand my data estate's compliance gaps, so I can prioritise remediation and demonstrate control.

```
Stage:      | Trigger            | Discovery          | Setup              | Analysis           | Reporting          | Closure
------------|--------------------|--------------------|--------------------|--------------------|--------------------|------------------
Actions:    | Audit notification | Logs into product  | Connects data      | Reviews compliance | Generates gap      | Exports report;
            | received from      | for the first time | sources; initiates | gap report; drills | report; marks      | shares with
            | auditor            |                    | first scan         | into gaps          | items as reviewed  | audit team
------------|--------------------|--------------------|--------------------|--------------------|--------------------|------------------
Touchpoints:| Email / Calendar   | Login screen       | Connect Source     | Compliance         | Reports section;   | Export function;
            |                    | Onboarding flow    | wizard             | Dashboard; Data    | Generate Report    | Email / portal
            |                    |                    |                    | Asset Detail pages | form               |
------------|--------------------|--------------------|--------------------|--------------------|--------------------|------------------
Thoughts:   | "I need to know    | "Where do I even   | "Will it connect   | "This is a lot of  | "Can I get this    | "I hope the
            | where we stand     | start? What do     | to our S3? Google  | data — what do I   | in a format the    | auditor finds
            | before the         | I connect first?"  | Drive?"            | need to look at    | auditor will       | this acceptable"
            | auditor arrives"   |                    |                    | first?"            | accept?"           |
------------|--------------------|--------------------|--------------------|--------------------|--------------------|------------------
Emotions:   | 😟 Anxious         | 😐 Uncertain       | 😐 Cautious        | 😊 Engaged         | 😊 Satisfied       | 😌 Relieved
            | (high stakes)      | (new product)      | (will it work?)    | (making progress)  | (almost done)      | (task complete)
------------|--------------------|--------------------|--------------------|--------------------|--------------------|------------------
Friction:   | —                  | No clear starting  | Unclear which      | Too many assets —  | Report format may  | No confirmation
            |                    | point; onboarding  | source to connect  | no guidance on     | not match auditor  | of successful
            |                    | overwhelming       | first              | what matters most  | expectations       | submission
------------|--------------------|--------------------|--------------------|--------------------|--------------------|------------------
Opportunity:| —                  | Audit-readiness    | "Start here"       | Prioritised gap    | Audit-ready        | Submission
            |                    | onboarding track   | guided wizard      | view; severity     | report templates   | checklist with
            |                    | for compliance     | with source        | scoring            | per framework      | audit summary
            |                    | officers           | recommendations    |                    | (SOC 2, GDPR)      |
```

---

## Emotional Arc

After completing the journey map, draw the emotional arc — the user's emotional state plotted across the stages. The arc reveals:

- **Valleys** — stages where users feel frustrated or anxious: high-priority improvement opportunities
- **Peaks** — stages where users feel satisfied or delighted: preserve and amplify these
- **Flat sections** — neutral stages: acceptable but look for quick wins

```
Emotion
Delighted  |                                          *
Satisfied  |                              *       *
Neutral    |              *           *
Cautious   |     *    *
Frustrated |  *
           |-----|-----|-----|-----|-----|-----|
            Trigger  Disc  Setup  Analysis  Report  Close
```

An emotional valley at "Setup" (connecting sources) signals that the Connect Source wizard needs significant UX investment. This translates directly to a P1 priority for the `ConnectSourceWizard` component spec.

---

## Friction Points and Opportunities

Every friction point identified in the journey map must become either:
1. A design decision in the UX flow (how to reduce the friction)
2. An input to the product backlog (a new user story to address the gap)
3. An accepted limitation (explicitly noted with rationale)

| Stage | Friction point | Resolution | Artifact |
|---|---|---|---|
| Discovery | No clear starting point | Audit-readiness onboarding track | User story: "As Maya, I want a guided onboarding flow for compliance audits" |
| Setup | Unclear source connection order | "Start here" recommendation in Connect Source wizard | UX flow: connect-source-guided-wizard |
| Analysis | Too many assets, no prioritisation | Severity-scored gap view sorted by risk | Component spec: ComplianceGapReport with severity sort |
| Reporting | Report format mismatch | SOC 2 and GDPR report templates | User story: "As Maya, I want audit-ready report templates" |

---

## Journey Map Inventory

Before designing individual journeys, produce the journey map inventory. Every primary persona gets at least one journey for their highest-value job.

| Persona | Job Story ID | Journey name | Priority |
|---|---|---|---|
| Maya Chen (Compliance Officer) | JS-003 | Audit preparation journey | P1 |
| Maya Chen (Compliance Officer) | JS-001 | First data estate scan | P1 |
| Alex Rivera (Data Steward) | JS-002 | Data asset classification | P1 |
| Sam Okafor (CISO) | JS-005 | Security posture review | P2 |

---

## Connecting Journey Maps to Downstream Artifacts

| Journey map output | Downstream artifact |
|---|---|
| Friction points at each stage | User stories in the backlog |
| Emotional valleys | P1 priority in component inventory |
| Touchpoints identified | IA sections to include |
| Opportunities noted | UX flows to design |
| New questions raised | Open questions for the requirements-analyst |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Persona grounded | Each journey uses a named persona from the user-persona skill | Generic "user" or "customer" with no persona attributes |
| JTBD connected | Each journey maps to a Job Story ID | Journeys disconnected from the job-to-be-done analysis |
| All six rows complete | All stages have Actions, Touchpoints, Thoughts, Emotions, Friction, Opportunity populated | Rows left blank or marked "TBD" |
| Emotional arc present | Emotional journey drawn; valleys identified | Journey with no emotional state assessment |
| Opportunities actioned | Every friction point has a resolution or explicit acceptance | Friction points listed with no follow-through |
| Downstream artifacts connected | Journey outputs connected to backlog, IA, UX flows, or component specs | Standalone journey with no connection to downstream work |

---

## Output Format

```markdown
---
artifact: user-journey-map
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: ux-architect
---

# User Journey Map: [Journey Name]

**Persona:** [Persona name and role]
**Job Story:** [JS-NNN — job statement]
**Scenario:** [Brief narrative context]

## Journey Map

| Row | Stage 1 | Stage 2 | Stage 3 | ... |
|---|---|---|---|---|
| Actions | | | | |
| Touchpoints | | | | |
| Thoughts | | | | |
| Emotions | | | | |
| Friction | | | | |
| Opportunity | | | | |

## Emotional Arc
[ASCII chart of emotional state across stages]

## Friction → Action Log
| Stage | Friction | Resolution | Artifact created |
|---|---|---|---|
```
