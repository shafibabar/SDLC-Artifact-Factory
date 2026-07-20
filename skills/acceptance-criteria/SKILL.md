---
name: acceptance-criteria
description: >
  Teaches how to write acceptance criteria that are unambiguous, testable, and
  complete. Covers the Gherkin Given/When/Then format, the rule-based format,
  how to handle edge cases and negative scenarios, and how acceptance criteria
  connect directly to BDD feature files. Acceptance criteria are the primary
  handoff from the requirements-analyst to the test-strategist. Used during the
  Ideate phase after user stories are written.
version: 1.1.0
phase: ideate
owner: requirements-analyst
created: 2026-06-24
tags: [ideate, acceptance-criteria, bdd, gherkin, testing, product-discovery]
---

# Acceptance Criteria

## Purpose

Acceptance criteria define the boundary of "done" for a user story — they are the verifiable conditions that prove the story has been implemented correctly from the user's perspective.

Good acceptance criteria:
- Leave no room for interpretation about what "done" means
- Are readable by the persona the story is written for (not just engineers)
- Map directly to BDD scenarios in the `test-strategist`'s Gherkin feature files
- Prevent scope creep by explicitly stating what is NOT included

---

## Formats

### Format 1: Gherkin (Given/When/Then)

Use for: all functional behaviour stories. This is the primary format because it directly generates BDD feature files.

```gherkin
Given [a system state or precondition],
When [an action is performed by the user or system],
Then [a verifiable outcome occurs].

And [additional outcome, if any].
But [a related condition that must NOT occur].
```

**Rules:**
- "Given" describes the starting state, not the action — use past tense ("the user has connected...")
- "When" names exactly one action — if you need two "Whens", split the criterion
- "Then" describes a directly observable outcome — something the user can see, read, or measure
- "And" extends the previous step; "But" adds a negative constraint to a "Then"

**Example:**
```gherkin
Given the Compliance Officer has connected a Google Drive with 10,000 files,
When the initial scan is triggered,
Then the scan completes within 30 minutes
And all files are classified with a sensitivity level
And the compliance dashboard reflects the updated classification counts
But no file contents are transmitted outside the customer's infrastructure boundary.
```

---

### Format 2: Rule-Based

Use for: business rules, system constraints, non-functional rules, and conditions that don't map naturally to a user action flow.

```
Rule: [Statement of the rule]
Verify: [How to verify the rule is enforced]
Example: [Concrete example that illustrates the rule]
```

**Example:**
```
Rule:    No file content may be transmitted outside the customer's infrastructure boundary.
Verify:  Network traffic analysis during scan shows zero outbound file content payloads.
         Redpanda event stream shows file metadata only — never file content.
Example: A Google Drive file containing personal data is scanned; only the file path,
         size, type, and extracted metadata appear in the event stream.
```

---

## The Golden Triangle

For every user story, acceptance criteria must cover three angles:

| Angle | Covers | At least one criterion |
|---|---|---|
| Happy path | The primary success scenario where everything works as expected | Required |
| Negative / error | What happens when input is invalid, the system errors, or the operation fails | Required |
| Boundary / edge | Conditions at the limits of acceptable input or system state | Required for complex stories |

A story with only happy-path criteria is not ready for the backlog. It guarantees that a passing test suite will miss real-world failure modes.

---

## Writing Criteria for Edge Cases

For each story, identify:
1. **Permission edge**: what happens if the user doesn't have access?
2. **Empty state edge**: what happens if there is no data yet?
3. **Scale edge**: what happens at the maximum expected data volume?
4. **Concurrency edge**: what happens if two users perform the same action simultaneously?
5. **Network/infrastructure edge**: what happens if a downstream service is unavailable?

Not all edge cases require a separate criterion — but each must be considered, and those not covered must be explicitly documented as out of scope.

---

## Criteria That Fail the Testability Check

| Pattern | Problem | Fix |
|---|---|---|
| "The system should be fast" | Unmeasurable | "The page loads in under 2 seconds on a 4G connection" |
| "The user can easily navigate" | Subjective | "The user can reach their compliance gap report in 3 clicks from the home screen" |
| "The system handles errors gracefully" | Unmeasurable | "When a network error occurs, the user sees a message explaining what failed and how to retry" |
| "All data is secure" | Unmeasurable | "File content is encrypted at rest with AES-256 and is never logged to stdout" |
| "The feature works for all users" | Untestable | Specify the user type and the exact condition to test |

---

## Criteria Count Guidelines

| Story size | Expected criteria count |
|---|---|
| Small (S) | 3-5 criteria |
| Medium (M) | 5-8 criteria |
| Large (L) | 8-12 criteria |

If a story requires more than 12 criteria to be fully specified, it should be split. Criteria bloat is usually a sign of a story that is doing too much.

---

## Handoff to Test-Strategist

Acceptance criteria are the primary input to BDD feature files. For every Gherkin-format criterion, the test-strategist will create a corresponding `Scenario:` block in the feature file. The criteria written here become the verbatim source for those scenarios — the language must be precise enough to be executable.

When handing off to the test-strategist, include:
- All Gherkin criteria (becomes Scenarios in the feature file)
- All rule-based criteria (becomes background conditions or step definitions)
- A list of explicitly out-of-scope edge cases (prevents uncontrolled test expansion)

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Testability | Every criterion can be evaluated as pass/fail | Any criterion containing "should", "easily", "properly", "well" |
| Happy + negative + edge | All three angles covered | Only happy-path criteria |
| Gherkin format for behaviour | Given/When/Then used for all behavioural criteria | Prose sentences with no verifiable structure |
| Observer-friendly Then | "Then" statements describe observable outcomes | "Then the system processes the file" (not observable) |
| Explicit scope boundary | Out-of-scope cases named | Implicit assumptions about what is not covered |
| BDD handoff ready | Language is precise enough to become Gherkin scenarios verbatim | Criteria that would require interpretation to implement as scenarios |

---

## Anti-Patterns

**Criteria written after implementation:** documenting what was built instead of defining "done" before building. This inverts the entire BDD flow — the criteria become a mirror of the code, and every bug in the code is faithfully reflected as a "requirement."

**UI-coupled criteria:** "Then the green Export button appears in the top-right corner." Brittle against every redesign and says nothing about the outcome. Describe what the user can now *do or know* ("Then the gap report can be exported as PDF"), not the pixels that enable it.

**Compound When:** "When the user connects a source and triggers a scan…" — two actions means a failing test cannot tell you which action broke. One When, one action; the first action belongs in the Given as established state.

**Implementation-observable Then:** "Then a row is inserted into the `classifications` table." No user can observe a table row. Then-statements must be observable at the persona's surface (UI, report, notification) or at an explicitly named operational surface (audit log, metrics endpoint).

**Boundary-blind criteria:** happy path plus one error case, with the interesting limits unexamined — the 500,001st file, the empty Google Drive, the scan that hits the 30-minute mark exactly. The Golden Triangle requires the edge angle for a reason: production incidents live at the boundaries.

---

## Output Format

```markdown
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
```
