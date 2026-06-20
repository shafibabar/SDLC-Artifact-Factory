# Skill: ideate/user-story

## Purpose
Write one User Story with full acceptance criteria, ready for Example Mapping and BDD feature file generation. A well-formed story is the atomic unit of delivery: small enough to be completed in one sprint, specific enough that acceptance is unambiguous, written from the user's perspective.

## Inputs
Read before generating:
- `artifacts/ideate/backlog/epics/{parent-epic-id}.md` — must exist
- `artifacts/ideate/personas/{persona}.md` — relevant persona
- `sdlc-config.json` — product_name
- **Arguments required:** story ID, story title or description, parent epic ID

## Output
**File:** `artifacts/ideate/backlog/stories/{id}.md` (e.g. `backlog/stories/us-001.md`)
**Registers in manifest:** yes

## Story Writing Rules (enforced)
- Format: "As a {persona}, I want to {action}, so that {outcome}."
- {persona} is always a specific persona, never "user" or "admin" generically.
- {action} describes what the user does, not what the system does.
- {outcome} describes the value to the user, not the system behaviour.
- Acceptance criteria use BDD format: Given / When / Then.
- Each AC scenario has exactly one When clause. Multiple outcomes belong in multiple scenarios.
- The story has a clear INVEST profile: Independent, Negotiable, Valuable, Estimable, Small, Testable.

## Process
1. Read the parent epic and the relevant persona.
2. Write the story in the required format.
3. Derive 3–5 acceptance criteria scenarios in Given/When/Then format.
4. Include at least one negative/edge-case scenario.
5. Identify the bounded context this story belongs to.
6. List the technical notes that will help implementation (not prescriptive, just context).
7. Run core/glossary → validate. Write file. Register with manifest.

## Artifact Template

```markdown
# User Story: {US-ID} — {Story Title}

**Product:** {product_name}
**Phase:** Ideate
**Artifact:** User Story
**Story ID:** {US-ID}
**Epic:** {EP-ID} — {Epic Title}
**Persona:** {persona role}
**Bounded Context:** {which BC this story belongs to}
**Version:** 1.0
**Date:** {date}
**Status:** Draft

---

## Story Statement
> As a **{specific persona}**, I want to **{action}**, so that **{outcome/value}**.

## Priority
**{MUST / SHOULD / COULD}** — {one sentence rationale}

## INVEST Check
| Criterion | Status | Note |
|-----------|--------|------|
| Independent | ✓ / ✗ | {dependency if any} |
| Negotiable | ✓ / ✗ | {what is open for discussion} |
| Valuable | ✓ / ✗ | {who gets the value} |
| Estimable | ✓ / ✗ | {any unknowns that make estimation hard} |
| Small | ✓ / ✗ | {split suggestion if too large} |
| Testable | ✓ / ✗ | {ACs make it testable} |

---

## Acceptance Criteria

### Scenario 1: {Happy path — e.g. Successful storage registration}
```gherkin
Given {a precondition that sets up the context}
  And {additional context if needed}
When {the user takes the primary action}
Then {the primary observable outcome}
  And {secondary observable outcome if any}
```

### Scenario 2: {Alternative path}
```gherkin
Given {context}
When {action}
Then {outcome}
```

### Scenario 3: {Edge case or error path — REQUIRED}
```gherkin
Given {context that sets up an error condition}
When {user takes the action}
Then {the system handles the error gracefully}
  And {the user is informed of what happened and what to do next}
```

### Scenario 4: {Security/compliance scenario — include if story touches auth, data, or access}
```gherkin
Given {a user without the required permission / an expired token / etc.}
When {they attempt the action}
Then {access is denied}
  And {the attempt is recorded in the audit log}
```

---

## Out of Scope for This Story
{What related things this story does NOT cover — to prevent scope creep during implementation.}
- {excluded item 1}
- {excluded item 2}

## Technical Notes
{Context for implementation — not prescriptive instructions, but relevant constraints or decisions the developer should know.}
- {note 1 — e.g. "Google Drive API credentials are stored in secrets management, not environment variables"}
- {note 2 — e.g. "Registration must be idempotent — re-registering the same location is a no-op"}

## Definition of Done (Story Level)
- [ ] All acceptance criteria scenarios pass in the test suite
- [ ] BDD feature file exists at `artifacts/implement/features/{story-id}.feature`
- [ ] TDD spec exists at `artifacts/implement/specs/{story-id}.md`
- [ ] No open defects against this story's ACs
- [ ] Code reviewed and merged
- [ ] Audit log records the relevant events for this story (if it touches data or access)
```

## Quality Checks
Before writing:
- [ ] Story follows "As a {specific persona} / I want to / so that" — no generic "user"
- [ ] At least 3 AC scenarios: one happy path, one alternative, one error/edge case
- [ ] At least one security/compliance scenario if the story touches authentication, data access, or sensitive data
- [ ] Each scenario has exactly one When clause
- [ ] Out of Scope section is populated
- [ ] No undefined ubiquitous language terms
