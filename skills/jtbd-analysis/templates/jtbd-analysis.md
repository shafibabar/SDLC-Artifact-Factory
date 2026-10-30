---
name: jtbd-analysis
product: <product>
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: <yyyy-mm-dd>
summary: <one sentence, ≤ 200 chars: the core jobs, the target outcome per job, and how well evidenced they are>
profile: <standard | enterprise>
evidence: <snapshot files cited, e.g. ideate/interviews/snapshots/2026-10-05-dp-1.md … | none: every item is an assumption>
ranking: <compare-and-contrast (n = <k> design partners) | opportunity score (survey, n per segment)>
traces_to: ideate/user-personas.md; <strategy/competitive-analysis.md>; <problem statement>
---

<!-- Copy into ideate/jtbd-analysis.md and fill. Delete these comments.
     Not used at lean: there, JTBD folds into each persona.
     Every item without a snapshot behind it is tagged [assumption] and listed under Assumptions to Validate. -->

# Jobs To Be Done Analysis — <Product>

## Evidence

| Snapshot | Date | Participant | Segment / role | Interviewer | Interview type |
|---|---|---|---|---|---|
| [<yyyy-mm-dd>-<participant>] | <date> | <pseudonymous ID> | <segment, role> | <the user / design-partner lead> | <switch / story-based> |

<!-- With no snapshots: "None yet. Interview guide: ideate/interviews/guides/<file>.md." -->

## Core Jobs

| ID | Job statement (Ulwick) | Executor | Beneficiary | Buyer | Target outcome |
|---|---|---|---|---|---|
| J-1 | <verb> <object> <contextual clarifier> | <persona> | <persona or —> | <persona> | O-1.<n> |

<!-- No score column here: opportunity is scored on desired outcomes, never on whole jobs.
     When executor and buyer differ, the buyer's financial job gets its own J-row. -->

---

## J-1: <short name>

**Job statement (Ulwick):** <verb> <object> <contextual clarifier>
**Executor:** <persona> · **Beneficiary:** <persona or —> · **Buyer:** <persona>

### Job spec

- **Functional:** <the practical progress>
- **Emotional:** <the feeling sought or avoided>
- **Social:** <how they want to be seen>
- **Obstacles:** <what stops progress today> [<evidence>]
- **Purchase experience:** <what buying must feel like> [<evidence>]
- **Use experience:** <what first use and an ordinary week must feel like> [<evidence>]

### What gets fired

| Alternative | Who uses it | Evidence |
|---|---|---|
| <spreadsheet / consultant / adjacent tool / nothing: non-consumption> | <segment or persona> | [<snapshot>] |

### Big Hire / Little Hire

- **Big Hire:** <what wins the purchase decision> [<evidence>]
- **Little Hire:** <what brings the executor back on an ordinary week> [<evidence>]

### Forces of progress

| Force | Specific event | Evidence |
|---|---|---|
| Push | <the struggling moment, as it happened> | [<snapshot>] |
| Pull | <the better state they pictured> | [<snapshot>] |
| Anxiety | <what nearly stopped them> | [<snapshot>] |
| Habit | <what kept them on the old way> | [<snapshot>] |

### Job stories (Klement / Intercom)

#### JS-1.1: <title> (trigger)

When <situation>, I want to <motivation, not a product output>, so I can <progress>.

- **Evidence:** [<snapshot>] <!-- or [assumption] and a row under Assumptions to Validate -->
- **Implied capability:** <what the product must make possible; a hand-off, not a design>

#### JS-1.2: <title> (routine)

#### JS-1.3: <title> (high stakes)

### Desired outcomes

<!-- Standard, few design partners: compare-and-contrast columns (below). Ratings, if any, labelled "directional (n = k)".
     Survey sample: replace Sizing / Importance (strongest event) / Served today with
     Importance | Satisfaction | Opportunity (= I + max(I − S, 0)), one table per segment.
     Enterprise: add a Job-map step column (define, locate, prepare, confirm, execute, monitor, modify, conclude). -->

| ID | Desired-outcome statement (Ulwick) | Evidence | Sizing | Importance (strongest event) | Served today | Rank |
|---|---|---|---|---|---|---|
| O-1.1 | Minimize the <metric> <object of control> <clarifier> | [<snapshot>] | <k of n> | <event> | <how well today> | <n> |

**Target outcome:** O-1.<n>. <One sentence: why, from the comparison.>

---

## Onboarding Requirements

<!-- From consumption-chain jobs, obstacles, purchase and use experiences, the Little Hire, and the anxiety and habit forces. -->

| ID | Requirement | From |
|---|---|---|
| ONB-1 | <requirement> | J-1 anxiety; Little Hire |

## Related Jobs

- <adjacent job the same executor does: expansion, not this release>

## Assumptions to Validate

| Item | Validation question (a specific past event) | Wrong if |
|---|---|---|
| <JS-1.2 / O-1.3 / force> | "<Tell me about the last time…>" | <the answer that would overturn it> |

## Hand-off

- `impact-mapping`: target outcome per job; job stories explain each actor's behaviour change.
- `requirements-analysis` / `user-story-writing`: implied capabilities, each traced to a job statement and job story.
- `business-model-canvas`: job statements and ranked outcomes by ID.
- `competitive-analysis` / `gtm-strategy`: what gets fired, including non-consumption.
- `user-persona`: refined job statements, if they changed.

## Version Log

| Version | Date | Change | Trigger |
|---|---|---|---|
| 1.0.0 | <date> | First analysis | Ideate |
