# Example 2 (standard): Renewing a Library Loan

Self-contained input and output. The point: two rules, a rule-format criterion, an outline cut from nine rows to the ones that prove something, a shared Background, and screen clicks rewritten.

## Input

- Product: a town library's member service. Profile **standard**. US-12 is Must Have.
- A draft from the developer: "When she clicks Renew", then an Examples table with renewals-so-far and result rows 0 allowed, 0 allowed, 1 allowed, 1 allowed, 1 allowed, 2 refused, 2 refused, 2 refused, 2 refused (differing only in book title).
- `ideate/acceptance-criteria/US-12.md` (approved):

````markdown
## Happy Path

### AC-US-12.1: A loan is renewed for three weeks
- From: R1 (R1.E1)

```gherkin
Given Omar's loan of "Middlemarch" is due on 3 December and has not been renewed,
When he renews the loan,
Then the loan is due on 24 December.
```

## Error / Negative Scenarios

### AC-US-12.2: A reserved book cannot be renewed
- From: R2 (R2.E1)

```gherkin
Given another member has reserved "Middlemarch",
When Omar renews his loan of it,
Then he is told "Reserved by another member"
But the due date does not change.
```

## Boundary / Edge Cases

### AC-US-12.3: A loan may be renewed at most twice
- From: R1 (R1.E2, R1.E3)

**Rule:** A loan is renewed at most 2 times.
**Verify:** Renew a loan that has 1 renewal, then one that has 2.
**Example:** With 1 renewal it is allowed; with 2 it is refused.
````

## The reply

"**Written, awaiting your approval.** Scenarios are required for this story. Criteria: `ideate/acceptance-criteria/US-12.md` (approved). File: `implement/features/US-12.feature`; `AC-US-12.1` happy, `AC-US-12.2` negative, `AC-US-12.3` edge (an outline on the limit). Replaced: your 'clicks Renew' became 'he renews the loan'. Removed: seven of your nine Examples rows (both '0 allowed' rows, already proven by `AC-US-12.1`; two repeat '1 allowed' rows; three repeat '2 refused' rows), because they differed only in book title and proved nothing new; one row at 1 renewal and one at 2 remain. Mismatches: none seen. Run status: not run. Open items: none. Agent-run; no workshop was held. Next: your approval, then step definitions."

## Output: `implement/features/US-12.feature`

````gherkin
# name: feature-file
# product: shelfmark
# story-id: US-12
# version: 1.0.0
# phase: implement
# owner: test-strategist
# created: 2026-11-26
# summary: Loan renewal, three scenarios proving AC-US-12.1 to 12.3 on the limit of two and reservations.
# run: agent-run
# traces_to: ideate/acceptance-criteria/US-12.md; ideate/example-maps/US-12.md
# Agent-run: one agent (test-strategist) wrote these from the approved criteria; no workshop was held.

Feature: Renew a loan
  As a library member
  I want to renew a loan
  So that I can finish the book without a fine

  Background:
    Given Omar has "Middlemarch" on loan, due on 3 December

  Rule: A loan is renewed for three weeks, at most 2 times

    @AC-US-12.1 @happy
    Scenario: A loan is renewed for three weeks
      Given the loan has not been renewed
      When he renews the loan
      Then the loan is due on 24 December

    @AC-US-12.3 @edge
    Scenario Outline: A loan may be renewed at most twice
      Given the loan has been renewed <renewals> time(s)
      When he renews the loan
      Then the renewal is <result>

      Examples:
        | renewals | result  |
        | 1        | allowed |
        | 2        | refused |

  Rule: A reserved book cannot be renewed

    @AC-US-12.2 @negative
    Scenario: A reserved book cannot be renewed
      Given another member has reserved "Middlemarch"
      When Omar renews his loan of it
      Then he is told "Reserved by another member"
      But the due date does not change
````
