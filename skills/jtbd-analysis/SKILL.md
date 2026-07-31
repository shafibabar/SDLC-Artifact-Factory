---
name: jtbd-analysis
description: >
  Teaches the requirements-analyst to analyze Jobs To Be Done — the job statement
  format (When [situation], I want to [motivation], so I can [expected outcome]), the
  functional/emotional/social dimensions of a job, and the customer-discovery interview
  technique (grounded in The Mom Test) that surfaces real jobs rather than imagined
  ones. Used during Strategy to understand the underlying job a customer hires the
  product for, feeding personas and stories. Covers job stories vs user stories, core
  vs related vs consumption jobs, forces of progress, the Opportunity Score, Mom-Test
  question discipline, and screening for earlyvangelists.
version: 2.0.0
phase: strategy
owner: requirements-analyst
created: 2026-06-24
tags: [strategy, requirements, jobs-to-be-done, job-statement, customer-motivation, discovery]
related: [user-persona, user-story-writing, moscow-prioritization, business-model-canvas, impact-mapping]
---

# Jobs To Be Done Analysis

## Purpose

Jobs To Be Done (JTBD) is a lens for understanding what people are actually trying to
accomplish — the **progress** they are trying to make in a **situation** — independent of
any product. People don't buy products; they **hire** a product to do a job. The core
insight is that **the job is stable while solutions change**: the Compliance Officer's job
of "prove the estate is compliant before an audit" existed before any software, is served
today by spreadsheets and consultants, and will outlive whatever we build. Design for the
job, not for the current solution.

JTBD answers: **what job is the customer hiring this product to do?** A correct job
statement reveals the motivation behind behaviour, the context that triggers it, and the
outcome the customer expects — far more useful for design than knowing what they clicked.

---

## The Job Statement Format

```
When [situation or trigger that creates the need],
I want to [the motivation — what I'm trying to do, not the feature],
so I can [the progress/outcome I'm trying to make].
```

The situation replaces the role because **the same person has different jobs in different
situations**. "I want to" names a motivation, not a product capability. "so I can" names
progress the person makes, not a benefit the product delivers.

Worked example (good):
```
When I'm preparing for a quarterly compliance review and need to report on our data
estate's risk posture, I want to see a current, prioritised list of compliance gaps
across all our storage sources, so I can brief the CISO with confidence that nothing
critical has been missed.
```

Full format rules, more worked examples for this product, the core/related/consumption
job types, the forces of progress, and the Opportunity Score ranking step:
**`references/job-statements-and-dimensions.md`**.

---

## The Three Job Dimensions

Every job has three dimensions, and a product that serves only the first gets replaced by
a cheaper alternative:

| Dimension | The question it answers | Compliance Officer example |
|---|---|---|
| **Functional** | The practical task to accomplish | Prove the data estate is compliant across all sources |
| **Emotional** | How they want to feel (or avoid feeling) | Not fear being surprised by a finding in a board meeting |
| **Social** | How they want to be perceived by others | Be seen by the CISO as the person who managed data risk diligently |

For the compliance domain the emotional and social dimensions are frequently **decisive** —
fear of a surprise audit and standing with the CISO drive purchases the functional job
alone would not. Never run functional-only analysis. Each dimension worked through with
repo examples: `references/job-statements-and-dimensions.md`.

---

## JTBD vs User Stories

JTBD does not replace user stories — it **precedes** them. JTBD identifies what the customer
is trying to achieve; a user story defines what the product must do to enable it.

| | Job Story (JTBD) | User Story |
|---|---|---|
| **Focus** | The customer's motivation and situation | The product capability needed |
| **Format** | "When [situation], I want to [motivation], so I can [outcome]" | "As a [persona], I want [action], so that [benefit]" |
| **Produced by** | This skill, during Strategy | `user-story-writing`, later |

Each job story maps to at least one implied product capability, which becomes input for
`user-story-writing`; the jobs and their dimensions also feed `user-persona`. How JTBD
output threads into both: `references/jtbd-interviewing.md`.

---

## Surfacing Real Jobs: The Mom-Test Discipline

The failure mode JTBD analysis must avoid is **inventing** jobs at a desk, or collecting
data so contaminated by politeness that it only confirms what we already decided to build.
Rob Fitzpatrick's *The Mom Test* supplies the interview discipline that prevents this. Its
one organizing rule: **ask about specific past behaviour, not hypotheticals**.

- Talk about **their life**, not your idea — never pitch before you've listened.
- Ask about **specifics in the past**, not generics or opinions about the future.
  "Walk me through the last time this happened" beats "what would you do if…".
- **Listen more than you talk** — you are extracting facts, not selling.

Note the trap inside this skill's own analysis prompts. Questions like "what would you do
if the product disappeared?" are useful for the analyst's *own* synthesis once real data is
in hand, but asked **verbatim to a customer** they are exactly the counterfactual the Mom
Test warns against. Convert them to past-tense, specific-instance questions before a real
conversation. The full three-rule filter, the bad-data taxonomy to discard, the
question-rewrite bank, screening for earlyvangelists, and the persona/story handoff:
**`references/jtbd-interviewing.md`**.

---

## Analysis Process

1. **Identify the core job** per primary persona — the main progress they seek, written
   solution-agnostically as `[verb] + [object] + [contextual clarifier]`.
2. **Identify the three dimensions** of that core job (functional, emotional, social).
3. **Gather real input** via Mom-Test-compliant conversations, not desk invention — see
   `references/jtbd-interviewing.md`.
4. **Write job stories** — at least three per core job: the trigger situation, the routine
   situation, and the high-stakes/edge situation where failure is most costly.
5. **Rank the jobs** (optional but recommended) with the Opportunity Score so the list is
   prioritised, not just enumerated — see `references/job-statements-and-dimensions.md`.
6. **Map to capabilities** — each job story implies a product capability, handed to
   `user-story-writing`.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Situation specificity | "When" names a real triggering context | Generic "When I use the product" |
| Motivation vs feature | "I want to" is a motivation | "I want to click the export button" |
| Outcome vs benefit | "so I can" is progress made | "so I can use the feature" |
| Dimension coverage | All three dimensions for the core job | Only functional addressed |
| Solution-agnostic | Job survives if the product vanished | Situation names the product's UI |
| Grounded in real behaviour | Traceable to a specific-instance conversation | Traceable to a compliment or a hypothetical |
| Capability link | Each story maps to a buildable capability | Stories that connect to nothing |

---

## Anti-Patterns

**Solution-shaped jobs.** "When I open the compliance dashboard, I want to…" — the
situation names the product. Rewrite from the person's work context. (This is the same
discipline Olsen calls keeping the "need" in problem space, not solution space.)

**Jobs at task altitude.** "Export a CSV of flagged files" is a task inside a job. If a
single button would satisfy the statement, it is too low. The job is what the export is
*for* — "assemble evidence the auditor will accept."

**Multiple jobs in one story.** "Scan, classify, and report…" fuses three motivations into
one blurred capability. One story, one motivation, one outcome. Split.

**Backwards JTBD.** Writing job stories to justify an already-decided feature. The tell:
every implied capability matches the existing roadmap exactly. This is a *post-hoc* integrity
check on the written-up analysis — distinct from, and not a substitute for, the Mom-Test
question discipline that keeps bad data out of the raw input in the first place. You need
both safeguards.

**Functional-only analysis.** Ignoring the emotional and social dimensions because they
feel "soft." In compliance they are often the deciding factors.

---

## Output Format

```markdown
---
name: jtbd-analysis
product: [product name]
version: 1.0.0
phase: strategy
created: [date]
owner: requirements-analyst
---

# Jobs To Be Done Analysis

## Core Jobs
| Persona | Core Job Statement | Functional | Emotional | Social | Opportunity Score |
|---|---|---|---|---|---|

## Job Stories
### [Persona Name]
#### JS-001: [Short title]
**Situation:** When [context]...
**Motivation:** I want to [action]...
**Expected outcome:** so I can [progress]...
**Implied capability:** [what the product must do]

## Related Jobs (Expansion Opportunities)
## Consumption Jobs (Onboarding Implications)
```

Full template with a completed worked instance: `references/job-statements-and-dimensions.md`.
