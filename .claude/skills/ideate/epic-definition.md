# Skill: ideate/epic-definition

## Purpose
Define one Epic — a large, coherent unit of work that delivers a meaningful outcome to a user or the business. Epics are the backlog's primary planning unit: large enough to represent a meaningful outcome, small enough that a team can deliver it within a quarter. Each epic maps to at least one OKR Key Result.

## Inputs
Read before generating:
- `artifacts/ideate/story-map.md` — must exist (epics derive from story map activities/steps)
- `artifacts/strategy/okrs.md` — must exist
- `sdlc-config.json` — product_name
- **Argument required:** epic ID and title (e.g. "EP-01 Storage Registration")

## Output
**File:** `artifacts/ideate/backlog/epics/{id}.md` (e.g. `backlog/epics/ep-01.md`)
**Registers in manifest:** yes

## Epic Rules (enforced)
- An epic has a clear outcome: what a user can do after the epic is complete that they could not do before.
- An epic is not a feature list. It is an outcome with acceptance criteria.
- An epic has 3–10 user stories. If it has more than 10, it should be split.
- An epic links to at least one OKR Key Result.
- An epic has explicit non-goals — what it does NOT include.

## Process
1. Read the story map and identify which activities/steps this epic covers.
2. Write the epic's outcome statement.
3. Define the acceptance criteria at the epic level (high-level, not story-level detail).
4. Derive the list of user stories this epic will contain (stubs — full stories are created by the user-story skill).
5. Link to OKR Key Results.
6. Define explicit non-goals.
7. Run core/glossary → validate. Write file. Register with manifest.

## Artifact Template

```markdown
# Epic: {EP-ID} — {Epic Title}

**Product:** {product_name}
**Phase:** Ideate
**Artifact:** Epic Definition
**Epic ID:** {EP-ID}
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## Outcome Statement
> When this epic is complete, a **{primary persona}** will be able to **{capability}** so that **{business/user outcome}**.

## OKR Linkage
| OKR | Key Result | Contribution |
|-----|-----------|--------------|
| {Objective title} | {KR text} | {how this epic moves this KR} |

## Problem Context
{2–3 sentences. What problem does this epic solve? Why is it important now (not in a later phase)?}

## In Scope
{Bullet list of what this epic explicitly covers.}
- {capability 1}
- {capability 2}
- {capability 3}

## Non-Goals (Explicitly Out of Scope)
{Bullet list of related things this epic does NOT include. Prevents scope creep during delivery.}
- {excluded item 1 — with reason or deferral phase}
- {excluded item 2}

## High-Level Acceptance Criteria
{At the epic level — testable statements that define "done" for the whole epic. Story-level AC is defined in individual story artifacts.}

- [ ] {AC 1 — e.g. An administrator can register a Google Drive workspace in under 5 minutes without engineering assistance}
- [ ] {AC 2 — e.g. The system begins the initial scan within 60 seconds of a storage location being registered}
- [ ] {AC 3 — e.g. The registration workflow is accessible on all modern browsers without a native app}

## User Stories (Stubs)
{List the stories this epic will contain. Each story is created in detail by the user-story skill.}

| Story ID | Title | Priority | Status |
|----------|-------|----------|--------|
| {US-ID} | As a {persona}, I want to {action} | MUST | Pending |
| {US-ID} | As a {persona}, I want to {action} | MUST | Pending |
| {US-ID} | As a {persona}, I want to {action} | SHOULD | Pending |

## Dependencies
{What must exist before this epic can begin delivery?}

| Dependency | Type | Status |
|-----------|------|--------|
| {e.g. OAuth 2.0 integration with identity provider} | Technical prerequisite | {exists / in progress / pending} |
| {e.g. Google Drive API credentials provisioned} | External dependency | {status} |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| {risk} | Low/Med/High | Low/Med/High | {mitigation} |

## Definition of Done (Epic Level)
- [ ] All MUST stories are complete and accepted
- [ ] All high-level acceptance criteria are verified
- [ ] No open P1 defects
- [ ] All artifacts updated (API contracts, data models, runbooks updated if affected)
- [ ] Security review completed for any new data flows introduced
```

## Quality Checks
Before writing:
- [ ] Outcome statement follows "When complete, a {persona} will be able to {capability} so that {outcome}"
- [ ] Non-Goals section is populated — an epic without non-goals has unbounded scope
- [ ] At least one OKR Key Result is linked
- [ ] 3–10 story stubs listed — if fewer than 3, the epic is not an epic; if more than 10, split it
- [ ] No undefined ubiquitous language terms
