---
name: jtbd-analysis
description: >
  Teaches how to apply Jobs To Be Done (JTBD) theory — using the job story format
  (not user story format), identifying functional/emotional/social job dimensions,
  distinguishing the core job from related and consumption jobs, and translating
  job stories into testable product requirements. Used by the requirements-analyst
  agent during the Ideate phase, after user personas are complete.
version: 1.0.0
phase: ideate
owner: requirements-analyst
tags: [ideate, jtbd, job-stories, product-discovery, user-needs]
---

# Jobs To Be Done Analysis

## Purpose

Jobs To Be Done (JTBD) is a framework for understanding what people are actually trying to accomplish — the progress they are trying to make in their work or life — independent of any particular product or solution. People don't buy products; they hire products to do a job.

JTBD answers the question: **what job is the user hiring your product to do?** When a job story is written correctly, it reveals the motivation behind a user's behaviour, the context in which that motivation arises, and the outcome the user expects. This is far more useful for designing features than knowing what users clicked.

---

## JTBD vs User Stories

JTBD does not replace user stories. It precedes them. JTBD analysis identifies what the user is trying to achieve. User stories define what the product must do to enable it.

| | JTBD Job Story | User Story |
|---|---|---|
| **Focus** | The user's motivation and context | The product capability needed |
| **Format** | "When [situation], I want to [motivation], so I can [expected outcome]" | "As a [persona], I want to [action], so that [benefit]" |
| **Source** | Research, observation, stakeholder interviews | JTBD output + acceptance criteria |
| **Output** | Understanding of the job to be done | Backlog item with acceptance criteria |
| **Owner** | requirements-analyst (JTBD) | requirements-analyst (user stories) |

---

## Job Dimensions

Every job has three dimensions. All three must be addressed:

| Dimension | Definition | Example |
|---|---|---|
| **Functional** | The practical task the person needs to accomplish | "Scan all files in our storage estate and identify which ones contain personal data" |
| **Emotional** | How the person wants to feel (or avoid feeling) while doing the job | "Feel confident I won't be surprised by a compliance violation in a board meeting" |
| **Social** | How the person wants to be perceived by others when doing the job | "Be seen by the CISO as the person who proactively managed our data risk" |

Products that only address the functional dimension will be replaced by cheaper alternatives. Products that address all three dimensions create loyalty.

---

## Types of Jobs

| Job Type | Definition |
|---|---|
| **Core job** | The primary progress the person is trying to make — the main reason they're looking for a solution |
| **Related job** | Adjacent jobs the same person does that the product could also help with |
| **Consumption job** | The process of acquiring, setting up, and maintaining the product itself (often under-appreciated) |
| **Emotional job** | The personal feelings the person is trying to achieve or avoid |
| **Social job** | The person's desired standing or perception among others |

For product design: solve the core job exceptionally well first. Related jobs become expansion opportunities. Consumption jobs are solved through onboarding, self-service, and documentation.

---

## Job Story Format

```
When [situation or trigger that creates the need],
I want to [the action or capability I'm looking for],
so I can [the progress/outcome I'm trying to make].
```

**Key distinctions from user story format:**
- "When" (not "As a") — the situation replaces the role, because the same person has different jobs in different situations
- "I want to" focuses on motivation, not the product feature
- "so I can" expresses the outcome the person is trying to achieve, not the benefit the product delivers

### Good Job Story
```
When I'm preparing for a quarterly compliance review and need to report on our data estate's risk posture,
I want to see a current, prioritised list of compliance gaps across all our storage sources,
so I can brief the CISO with confidence that nothing critical has been missed.
```

### Weak Job Story (anti-patterns)
```
[Too solution-specific] When I log in to the dashboard, I want to click the compliance report button...
[No situation] As a Compliance Officer, I want to see compliance gaps...
[Feature, not outcome] ...so I can use the compliance reporting feature.
```

---

## Analysis Process

### Step 1: Identify the Core Job

For each primary persona, ask:
- "What progress is this person trying to make in their life or work?"
- "What would change for them if this product didn't exist?"
- "If the product disappeared tomorrow, what would they do instead?"

The answer is the core job. Write it as a job statement: **[verb] + [object] + [contextual clarifier]**.

Example: "Maintain continuous visibility over our data estate's compliance posture without relying on manual audits."

### Step 2: Identify Job Dimensions

For the core job, identify:
- Functional dimension: what does "done" look like practically?
- Emotional dimension: how do they want to feel when the job is done?
- Social dimension: how does completing this job affect their standing?

### Step 3: Write Job Stories

For each persona and for each job (core + related), write at minimum 3 job stories covering:
- The trigger situation that causes the need
- The routine situation where the job is performed
- The edge or high-stakes situation where failure is most costly

### Step 4: Map to Product Capabilities

For each job story, identify what product capability is implied. This becomes input for `user-story-writing`. Write: "Job Story JS-[ID] implies the system must be able to [capability]."

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Situation specificity | "When" clause names a real context that triggers the job | Generic "When I use the product" |
| Motivation vs feature | "I want to" describes a motivation, not a product feature | "I want to click the export button" |
| Outcome vs benefit | "so I can" describes progress the person makes, not a feature benefit | "so I can use the feature" |
| Dimension coverage | All three dimensions addressed for the core job | Only functional dimension addressed |
| Core job identified | A clear, solution-agnostic core job statement exists per persona | No core job statement — only a list of stories |
| Product capability link | Each job story maps to at least one implied product capability | Job stories that don't connect to anything buildable |

---

## Output Format

```markdown
---
artifact: jtbd-analysis
product: [product name]
version: 1.0.0
phase: ideate
created: [date]
owner: requirements-analyst
---

# Jobs To Be Done Analysis

## Core Jobs

| Persona | Core Job Statement | Functional Dimension | Emotional Dimension | Social Dimension |
|---|---|---|---|---|

## Job Stories

### [Persona Name]

#### JS-001: [Short title]
**Situation:** When [context]...
**Motivation:** I want to [action]...
**Expected outcome:** so I can [progress/outcome]...
**Implied capability:** [What the product must do to enable this job]

[Repeat for each job story]

---

## Related Jobs (Expansion Opportunities)
[Jobs adjacent to the core that this persona also does and that the product could address in later phases]

## Consumption Jobs (Onboarding Implications)
[Jobs involved in adopting and maintaining the product itself — inputs to onboarding and deployment design]
```
