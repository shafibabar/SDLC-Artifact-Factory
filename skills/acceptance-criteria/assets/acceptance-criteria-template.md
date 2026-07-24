---
name: acceptance-criteria
product: [product name]
story-id: US-[ID]
version: 1.0.0
phase: ideate
created: [date]
owner: requirements-analyst
---

# Acceptance Criteria: US-[ID] — [Story title]

## Story Reference
As a [Persona], I want to [action], so that [outcome].

## Derived From
Example map: EM-[ID] ([N] rule cards, [N] example cards, 0 open question cards)

## Happy Path

### AC-001: [Short title]
```gherkin
Given [precondition],
When [action],
Then [outcome].
```

## Error / Negative Scenarios

### AC-002: [Short title]
```gherkin
Given [error precondition],
When [action],
Then [error outcome visible to user].
```

## Boundary / Edge Cases

### AC-003: [Short title]
```gherkin
Given [boundary condition],
When [action at limit],
Then [expected behaviour at limit].
```

## Rule-Based Criteria

### AC-004: [Rule name]
**Rule:** [Statement]
**Verify:** [How to verify]
**Example:** [Concrete illustration]

## Explicitly Out of Scope
- [Edge case or scenario explicitly not covered by this story]
