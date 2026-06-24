---
name: epic-definition
description: >
  Teaches how to define epics — the large, outcome-oriented units of work that
  sit between the impact map and the user story backlog. Covers the epic format,
  what makes an epic well-scoped (vs too large or too small), the epic hypothesis
  structure, and how epics decompose into user stories. Used by the
  requirements-analyst agent during the Ideate phase, after impact mapping.
version: 1.0.0
phase: ideate
owner: requirements-analyst
tags: [ideate, epic, backlog, decomposition, product-discovery]
---

# Epic Definition

## Purpose

An epic is a large unit of product work that:
- Delivers a meaningful outcome to a user or to the business
- Is too large to complete in a single sprint or iteration
- Decomposes into multiple user stories, each of which can be completed independently

Epics bridge the gap between impact map deliverables (which are high-level) and user stories (which are granular and immediately implementable). An epic answers: **what is the outcome we are trying to deliver, and roughly what will be involved?**

---

## What Makes a Good Epic

A well-scoped epic has all five properties:

| Property | Description |
|---|---|
| **Outcome-oriented** | Defined by the outcome it delivers, not the features it includes |
| **Traceable** | Linked to one or more WHAT deliverables in the impact map, which in turn traces to a business goal |
| **Estimable (in relative terms)** | The team can form a rough view of its size without knowing every implementation detail |
| **Decomposable** | Can be split into 3-10 user stories without losing coherence |
| **Hypothesis-testable** | Has a stated hypothesis: if we build this, we believe [behaviour change] will occur, which will advance [business goal] |

---

## Epic Size Signals

| Signal | Problem | Resolution |
|---|---|---|
| Epic takes longer than a quarter | Too large | Split into multiple epics by outcome or user segment |
| Epic contains a single user story | Too small | Promote the story to a standalone requirement; no epic needed |
| Epic's "done" state cannot be described | Poorly scoped | Rewrite starting from the outcome, not the features |
| Epic spans multiple bounded contexts | Architectural concern | Flag for domain-modeler and enterprise-architect; may indicate a missing bounded context |

---

## Epic Format

```
EPIC-[ID]: [Short title — outcome phrase, not feature name]

As a result of this epic, [actor] will be able to [outcome].

Hypothesis: If we [build this capability], we believe [this actor behaviour will change],
            which will contribute to [business goal or OKR KR].

Business Goal Link: [OKR KR or impact map goal]
Impact Map Link:    [WHAT deliverable(s) this epic implements]
Personas affected:  [Which personas this epic serves]
Bounded Context:    [Which domain this epic primarily belongs to — for handoff to domain-modeler]

Acceptance Criteria (epic level — high-level only; detailed criteria live on stories):
- [ ] [High-level condition that must be true when this epic is complete]
- [ ] [...]

Decomposition (user stories — titles only at epic definition stage):
- US-001: [Story title]
- US-002: [Story title]
- ...

Priority: [Must / Should / Could — MoSCoW]
Estimated size: [S / M / L / XL — relative, not story points]
Phase: [Which SDLC phase this epic will be implemented in]
```

---

## Epic Naming Convention

Name epics after the outcome they deliver, not the features they contain:

| Poor epic name | Better epic name |
|---|---|
| "Build the dashboard" | "Compliance Officers can review their full estate risk in one screen" |
| "Storage connector" | "Connect any supported storage source in under 5 minutes" |
| "Authentication" | "Users authenticate securely without IT involvement" |
| "API layer" | "External tools can query the compliance data via a documented API" |

---

## Epic Decomposition

When splitting an epic into user stories, use these decomposition strategies:

| Strategy | When to use |
|---|---|
| **By user workflow step** | The epic covers a multi-step process; each story is one step |
| **By user type** | Different personas use the same capability differently; each persona gets their own story |
| **By data variation** | The epic works the same way but with different data types (Google Drive vs S3 vs SharePoint) |
| **By configuration** | Happy path story first; edge cases and error states as separate stories |
| **By reading vs writing** | Separate stories for viewing/reading and creating/editing |

Never decompose by technical layer (frontend story + backend story + database story). Stories are user-facing outcomes, not technical tasks. Technical tasks live inside a story's implementation, not as separate stories.

---

## Epic Readiness Checklist

Before epics are handed to `user-story-writing`, each epic must pass:

- [ ] Title is outcome-oriented (not feature-named)
- [ ] Outcome statement is written ("As a result of this epic, [actor] will be able to...")
- [ ] Hypothesis is written
- [ ] OKR KR or business goal is linked
- [ ] Impact map deliverable is linked
- [ ] At least 3 user story titles are listed (decomposition started)
- [ ] Bounded context is identified
- [ ] MoSCoW priority is assigned

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Outcome orientation | Title and outcome statement focus on user capability | Title names a feature or system component |
| Traceability | Linked to impact map and OKR KR | Epic with no business goal linkage |
| Hypothesis | Stated as "if we build X, we believe Y will happen" | No hypothesis — just a description |
| Decomposability | At least 3 user story titles | Monolithic epic with no decomposition |
| Bounded context | Named bounded context or explicit flag to domain-modeler | Cross-cutting epic without architectural flag |

---

## Output Format

```markdown
---
artifact: epic-list
product: [product name]
version: 1.0.0
phase: ideate
created: [date]
owner: requirements-analyst
---

# Epic List

## Epic Summary

| ID | Title | Personas | OKR KR | Priority | Size |
|---|---|---|---|---|---|

---

## Epics (Detailed)

### EPIC-001: [Title]
[Full epic format as specified above]

---

### EPIC-002: [Title]
[Full epic format]
```
