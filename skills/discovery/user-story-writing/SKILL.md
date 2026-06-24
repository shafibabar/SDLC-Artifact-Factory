---
name: user-story-writing
description: >
  Teaches how to write well-formed user stories — using the correct format, the
  INVEST criteria for story quality, how to write stories that lead naturally to
  testable acceptance criteria, story splitting techniques, and common anti-patterns.
  User stories are the atomic unit of the backlog and the input to the acceptance-criteria
  skill. Used by the requirements-analyst agent during the Ideate phase.
version: 1.0.0
phase: ideate
owner: requirements-analyst
tags: [ideate, user-stories, backlog, invest, agile, product-discovery]
---

# User Story Writing

## Purpose

A user story is the smallest unit of product work that delivers value to a specific user. It is not a task, a technical requirement, or a feature specification — it is a description of what a user needs to accomplish and why, written in a way that enables a conversation about how to build it.

A user story is a promise of a conversation — the acceptance criteria that follow it close the loop by defining when the promise has been kept.

---

## The Standard Format

```
As a [persona or role],
I want to [action or capability],
so that [outcome or benefit].

Acceptance Criteria: [defined separately, see acceptance-criteria skill]
```

**Important distinctions:**
- "As a" names a **persona or role** — not "a user" (too generic), not a system ("As the API")
- "I want to" names an **action** — something the user does, not something the system does ("I want the system to...")
- "so that" names the **outcome** — what changes for the user as a result of accomplishing the action

---

## INVEST Criteria

Every user story must pass all six INVEST criteria before it enters the backlog:

| Letter | Criterion | What it means | Fail condition |
|---|---|---|---|
| **I** | Independent | The story can be developed and delivered without depending on another in-flight story | Story A must be done before Story B can start |
| **N** | Negotiable | The story describes a need, not a solution — the "how" is negotiable | Story specifies implementation details |
| **V** | Valuable | The story delivers value to a real user (not a developer convenience) | Story only has internal technical value |
| **E** | Estimable | The team can form a rough view of the effort required | Story is too vague or too large to estimate |
| **S** | Small | The story can be completed within a single sprint | Story will take multiple sprints if not split |
| **T** | Testable | The story can be verified — it will have unambiguous acceptance criteria | "The system should be better" — not testable |

When a story fails an INVEST criterion, the required action is:

| Fails | Action |
|---|---|
| Not Independent | Identify the dependency; either reorder or refactor to remove the coupling |
| Not Negotiable | Rewrite without specifying implementation; move solution details to a spike or technical note |
| Not Valuable | Escalate to Shafi — if this story isn't valuable to a user, should it exist? |
| Not Estimable | Split or investigate (spike story) to reduce uncertainty |
| Not Small | Split using the decomposition strategies from `epic-definition` |
| Not Testable | Write at least one acceptance criterion before considering the story ready |

---

## Story Quality Anti-Patterns

| Anti-Pattern | Example | Problem |
|---|---|---|
| Solution story | "As a user, I want a REST endpoint that returns JSON..." | Specifies the solution, not the need |
| Persona-free story | "As a user, I want to..." | "User" is not a persona — which user? |
| System actor | "As the classification engine, I want to..." | Systems don't have wants; this is a technical task |
| Benefit-free story | "As a Compliance Officer, I want to export a report." | Why? The "so that" must be substantive |
| Epic masquerading as a story | A story with 15 acceptance criteria or that will take multiple sprints | Split it |
| Task masquerading as a story | "Set up the database schema" | No user actor, no user value — this is a technical task |

---

## Story Writing Process

1. **Source from epics.** Each story implements part of a parent epic. Use the epic's decomposition list as the starting point.
2. **Name a specific persona.** Use the persona names from the `user-persona` output. Never use "user".
3. **Write the want.** State what the persona wants to do — in their language, not engineering language.
4. **Write the so that.** State the outcome they get. Ask: "if they could do this, what would be different for them?" That difference is the "so that".
5. **Check INVEST.** Apply all six criteria. If any fail, refactor before continuing.
6. **Tag the parent epic and linked job story.** Every story should know where it came from.
7. **Write a one-line description** of what acceptance criteria will cover (detailed criteria are written by the `acceptance-criteria` skill).

---

## Story Splitting Strategies

When a story fails the Small criterion, use these splitting strategies:

| Strategy | Technique |
|---|---|
| Happy path first | Write the basic success scenario as Story 1; error and edge cases as subsequent stories |
| By data variation | If the story works on multiple data types (Drive / S3 / SharePoint), split by type |
| By workflow step | If the story covers a multi-step process, split each step |
| Read vs write | Separate viewing/reading stories from creating/editing stories |
| With vs without configuration | Deliver the no-configuration-required version first; add configuration options in a follow-on story |
| Spike story | When a story is not estimable due to technical uncertainty, create a time-boxed spike story whose output is knowledge, not software |

---

## Story Hierarchy

```
Business Goal (OKR KR)
     └── Impact (HOW on the impact map)
              └── Epic (EPIC-001)
                   ├── US-001: [Story — primary workflow]
                   ├── US-002: [Story — secondary user type]
                   ├── US-003: [Story — error/edge case]
                   └── US-004: [Story — configuration/admin]
```

Every story at the bottom must be traceable back up to the business goal. If the trace breaks at any level, the story's inclusion is unjustified.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Named persona | Specific persona or role from the persona list | "As a user" |
| Action-oriented want | Describes what the user does | "I want the system to..." |
| Substantive benefit | "so that" describes real change for the user | "so that I can use the feature" |
| INVEST compliance | All six criteria pass | Any criterion fails |
| Epic linkage | Linked to a parent epic | Orphan story with no epic parent |
| Job story linkage | References the job story that motivated it (where applicable) | No connection to JTBD analysis |

---

## Output Format

```markdown
---
artifact: user-story-backlog
product: [product name]
version: 1.0.0
phase: ideate
created: [date]
owner: requirements-analyst
---

# User Story Backlog

## Backlog Summary

| ID | Title | Epic | Persona | Priority | Size |
|---|---|---|---|---|---|

---

## Stories by Epic

### EPIC-001: [Epic Title]

#### US-001: [Short title]
**Story:**
As a [Persona Name],
I want to [action],
so that [outcome].

**Source:** Job Story JS-[ID] / Impact Map EPIC-[ID]
**Parent Epic:** EPIC-001
**Priority:** Must / Should / Could / Won't
**INVEST check:** [INVEST — pass / note any exceptions]
**Acceptance criteria:** [Defined separately in acceptance-criteria artifact — see AC-001]

---

#### US-002: [Short title]
[Repeat]
```
