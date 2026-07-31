# Job Statements and Dimensions — Reference

Comprehensive reference for the `jtbd-analysis` skill: the job statement format in full,
worked examples grounded in this product (a data-estate / compliance platform for SMBs,
primary personas the Data Steward and the Compliance Officer), the three job dimensions,
the forces of progress, the core/related/consumption job types, the Opportunity Score
ranking step, and the completed output template.

Jobs To Be Done is most closely associated with Clayton Christensen (the "milkshake" study
and *Competing Against Luck*), the switch-interview / forces-of-progress school of Bob
Moesta and Chris Spiek, and — for the needs-discovery framing used here — Dan Olsen's *The
Lean Product Playbook*. Where a technique below has a named originator it is credited.

---

## 1. The Core Insight

Customers do not want a quarter-inch drill; they want a quarter-inch hole — and really they
want to hang a shelf so the room feels finished. The **job** is the progress the person is
trying to make in a **situation**, together with the **outcome** that would count as
progress. Three properties follow, and they are what make JTBD useful:

1. **The job is stable; solutions churn.** The Compliance Officer's job of "prove the estate
   is compliant before an audit" predates all software, is served today by spreadsheets,
   emailed screenshots, and outside consultants, and will outlive whatever we ship. Anchor
   the design to the job, not to the incumbent solution.
2. **The job is solution-agnostic.** If it names a button, a screen, or our product, it is
   not a job — it is a task inside a job or a feature in disguise. A valid job statement
   would still make sense if our product never existed.
3. **The job has an emotional and social charge, not only a functional one** (see §4).

---

## 2. The Job Statement Format

```
When [situation or trigger that creates the need],
I want to [the motivation — what I am trying to do, expressed without naming a feature],
so I can [the progress / outcome I am trying to make].
```

| Clause | Holds | Test it passes |
|---|---|---|
| **When** | The triggering situation or context | Names a real moment in the person's work, not "when I use the app" |
| **I want to** | The motivation | Describes intent, not a UI action; more than one feature could satisfy it |
| **so I can** | The expected outcome / progress | Describes the person's progress, not the product's benefit |

The **"When" clause replaces the role** (contrast the user-story "As a…"). The same person
has different jobs in different situations, so the situation — not the persona label — is
what disambiguates the job.

### 2.1 Worked examples for this product

**Compliance Officer — good:**
```
When I'm preparing for a quarterly compliance review and need to report on our data
estate's risk posture, I want to see a current, prioritised list of compliance gaps
across all our storage sources, so I can brief the CISO with confidence that nothing
critical has been missed.
```

**Data Steward — good:**
```
When a new Google Drive shared folder appears in our tenant and I don't yet know what's
in it, I want to know within a day whether it holds personal or regulated data, so I can
apply the right handling rules before it spreads to more people.
```

**Weak statements and why:**

| Weak statement | Failure |
|---|---|
| "When I log in to the dashboard, I want to click the compliance report button…" | Situation names the product; motivation is a UI action (solution-shaped) |
| "As a Compliance Officer, I want to see compliance gaps…" | No situation — uses user-story form, not a job story |
| "…so I can use the compliance reporting feature." | Outcome is a feature benefit, not the person's progress |
| "When an audit is coming, I want to scan, classify, and report on the estate…" | Three motivations fused; produces one blurred capability |

### 2.2 The core-job shorthand

Before writing full job stories, capture each persona's **core job** in the compact form
`[verb] + [object] + [contextual clarifier]`. Example:

> "Maintain continuous visibility over our data estate's compliance posture without relying
> on manual audits."

This one-line, solution-agnostic statement is the anchor every job story for that persona
must trace back to.

---

## 3. Types of Jobs

| Job type | Definition | Design implication |
|---|---|---|
| **Core job** | The primary progress the person seeks — the main reason they look for a solution | Solve this exceptionally well first |
| **Related job** | Adjacent jobs the same person does that the product could also help with | Expansion opportunity for later phases |
| **Consumption job** | Acquiring, setting up, and maintaining the product itself | Solved through onboarding, self-service, docs — inputs to deployment/onboarding design |
| **Emotional job** | The feelings the person wants to achieve or avoid | A dimension of the core job (see §4), not a separate backlog item |
| **Social job** | The standing or perception the person wants among others | Likewise a dimension of the core job |

Rule of thumb: solve the **core** job outstandingly; treat **related** jobs as expansion;
design **consumption** jobs into onboarding and documentation, where they are usually
under-appreciated and quietly determine whether adoption sticks.

---

## 4. The Three Job Dimensions

Every job is simultaneously functional, emotional, and social. A product that serves only
the functional dimension competes on price and gets replaced; a product that serves all
three earns loyalty.

| Dimension | Definition | Data Steward example | Compliance Officer example |
|---|---|---|---|
| **Functional** | The practical task to accomplish | Find and classify every file holding personal data across Drive, S3, and PDFs/DOCX/XLSX | Prove the data estate is compliant across all sources |
| **Emotional** | How the person wants to feel, or avoid feeling | Feel in control instead of anxious that something ungoverned is spreading | Not fear being surprised by a finding in a board meeting |
| **Social** | How the person wants to be perceived | Be trusted by peers as the one who keeps the estate tidy | Be seen by the CISO as the person who managed data risk diligently |

**Why this matters for the compliance domain specifically.** For an SMB compliance buyer,
the emotional job (fear of a surprise audit finding) and the social job (standing with the
CISO / the board) are frequently the **deciding** factors — they drive purchases the
functional job alone would not justify. Analysis that stops at the functional dimension will
consistently under-explain why customers buy and will under-design the product's most
persuasive value. Address all three for every core job.

---

## 5. Forces of Progress

From the switch-interview school (Bob Moesta, Chris Spiek; popularised in Christensen's
*Competing Against Luck*), four forces act on whether a person actually switches from the
current solution to a new one. A job story is stronger when the analysis has named all four.

| Force | Direction | What it is | Compliance example |
|---|---|---|---|
| **Push** of the situation | Toward change | The pain of the current situation | Last audit prep took three weeks of manual spreadsheet work |
| **Pull** of the new solution | Toward change | The appeal of the imagined better state | A single always-current gap list, no scramble |
| **Anxiety** of the new solution | Against change | Fear/uncertainty about the new thing | "Will it miss a source? Can I trust its classification?" |
| **Habit** of the present | Against change | Comfort with the incumbent, however bad | "Our spreadsheet is ugly but I know exactly where everything is" |

The two forces **for** change (push, pull) must outweigh the two **against** (anxiety,
habit) for a switch to happen. This is directly actionable: reducing **anxiety** (trust,
transparency of classification, a way to spot-check) and displacing **habit** (import the
existing spreadsheet, mirror the familiar workflow at first) are design levers as real as
adding functional pull. Many products lose not because their pull is weak but because they
never addressed the customer's anxiety and habit.

---

## 6. Ranking Jobs: The Opportunity Score

A well-written but **unranked** list of job stories has no forcing function to decide which
jobs represent the biggest opportunity versus which are already adequately served by
workarounds. Dan Olsen's *The Lean Product Playbook* (building on Tony Ulwick's
Outcome-Driven Innovation) supplies the ranking step. This converts a qualitative job list
into a ranked opportunity list before it feeds `moscow-prioritization` or `impact-mapping`.

For each candidate job (or the underserved need behind it), collect two ratings on a 1–10
scale from the customer:

- **Importance** — how important is making this progress to you?
- **Satisfaction** — how satisfied are you with how well it's met today?

Then:

```
Opportunity Score = Importance + max(Importance − Satisfaction, 0)
```

| Case | Reading |
|---|---|
| High importance, low satisfaction | **High opportunity** — important and poorly served; build here |
| High importance, high satisfaction | Low opportunity — already well served; don't build |
| Low importance | Low opportunity regardless of satisfaction |

An **underserved need** is one that is important *and* poorly satisfied; the qualifier is
load-bearing (a well-served important need is not an opportunity, however important it
remains).

**Scaling caveat for this product.** Olsen's survey-based version assumes a respondent pool
large enough to average meaningfully. This product's actual context is a 3–5 named design
partner cohort — far below a survey sample size. Scale the *rigor* down, not the *logic*:
score importance and satisfaction from structured design-partner interviews rather than a
survey, and treat the ranked list as directional. Critically, at n=3–5 there is no
large-sample averaging to dilute one politeness-driven rating, so every scoring conversation
must be conducted with Mom-Test discipline (see `references/jtbd-interviewing.md`) or the
numbers are worthless.

---

## 7. Completed Output Template

```markdown
---
name: jtbd-analysis
product: DataEstate Compliance Platform
version: 1.0.0
phase: strategy
created: 2026-07-31
owner: requirements-analyst
---

# Jobs To Be Done Analysis

## Core Jobs

| Persona | Core Job Statement | Functional | Emotional | Social | Opportunity Score |
|---|---|---|---|---|---|
| Compliance Officer | Maintain continuous visibility over the estate's compliance posture without manual audits | Prove the estate is compliant across all sources | Not fear a surprise audit finding | Be seen by the CISO as diligent | 9 + (9−3) = 15 |
| Data Steward | Know what regulated data lives where, as soon as it appears | Find and classify personal data across Drive/S3/documents | Feel in control, not anxious | Be trusted as the estate's keeper | 8 + (8−4) = 12 |

## Job Stories

### Compliance Officer

#### JS-001: Quarterly review prep (trigger situation)
**Situation:** When I'm preparing for a quarterly compliance review and need to report on
our data estate's risk posture,
**Motivation:** I want to see a current, prioritised list of compliance gaps across all our
storage sources,
**Expected outcome:** so I can brief the CISO with confidence that nothing critical has been
missed.
**Implied capability:** Cross-source gap aggregation with severity ranking, current as of
today.

#### JS-002: Routine monthly check (routine situation)
...

#### JS-003: Regulator arrives early (high-stakes situation)
...

### Data Steward
#### JS-004: New shared folder appears
...

## Related Jobs (Expansion Opportunities)
- Respond to a data-subject access request by locating every copy of one person's data.

## Consumption Jobs (Onboarding Implications)
- Connect Google Drive and S3 without a security review blocking the pilot.
- Import the estate's existing manual compliance spreadsheet so the first view feels familiar
  (displaces habit — see §5).
```

---

## 8. Handoff

- Each **core job + dimensions** feeds `user-persona` (goals, frustrations, and the trigger
  that starts a persona looking for a solution).
- Each **job story's implied capability** feeds `user-story-writing` as the "so that" a user
  story must serve.
- The **ranked opportunity list** feeds `moscow-prioritization` and `impact-mapping` so
  scoping traces back to the highest-opportunity jobs, not to team intuition.

The interviewing discipline that produces trustworthy raw input for all of the above is in
`references/jtbd-interviewing.md`.
