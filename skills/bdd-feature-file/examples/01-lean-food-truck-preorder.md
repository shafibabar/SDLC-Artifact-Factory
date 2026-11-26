# Example 1 (lean): Cancelling a Food-Truck Pre-Order

Self-contained input and output. The point: a small product still covers every Must Have criterion; "happy path only" and a scripted step are refused by name; tags replace trailing comments.

## Input

- Product: pre-orders for one food truck. Profile **lean**. US-4 is Must Have.
- Request: "It's a tiny app, just write the happy path: When the customer sends DELETE /orders/17, Then 200 OK. # happy"
- `ideate/acceptance-criteria/US-4.md` (approved by the product owner):

````markdown
## Happy Path

### AC-US-4.1: An order not yet cooking is cancelled
- From: R1 (R1.E1)

```gherkin
Given Priya's order 17 is waiting to be cooked,
When she cancels order 17,
Then she sees that order 17 is cancelled
But order 17 no longer shows on the cooking list.
```

## Error / Negative Scenarios

### AC-US-4.2: Cancelling is refused once cooking has started
- From: R1 (R1.E2)

```gherkin
Given Priya's order 17 is being cooked,
When she cancels order 17,
Then she is told "Already cooking"
But order 17 stays on the cooking list.
```

## Boundary / Edge Cases

### AC-US-4.3: A second cancel changes nothing
- From: R1 (R1.E3)

```gherkin
Given Priya has already cancelled order 17,
When she cancels order 17,
Then she sees that order 17 is cancelled
But no second refund is made.
```
````

## The reply

"**Written, awaiting your approval.** Scenarios are required: a small product still covers every criterion of every Must Have story, so 'just the happy path' is not applied; `AC-US-4.2` and `AC-US-4.3` are written too. Criteria: `ideate/acceptance-criteria/US-4.md` (approved). File: `implement/features/US-4.feature`; `AC-US-4.1` happy, `AC-US-4.2` negative, `AC-US-4.3` edge. Replaced: your 'sends DELETE /orders/17' became 'she cancels order 17' and '200 OK' became what Priya sees, because steps say what, not how (the request belongs in the step definition). '# happy' became the tag `@happy`; a trailing comment would join the title. Mismatches: none seen. Run status: not run. Open items: none. Agent-run; no workshop was held. Next: your approval, then step definitions, seen failing, before the code."

## Output: `implement/features/US-4.feature`

````gherkin
# name: feature-file
# product: kerbside
# story-id: US-4
# version: 1.0.0
# phase: implement
# owner: test-strategist
# created: 2026-11-26
# summary: Cancelling a food-truck pre-order, three scenarios proving AC-US-4.1 to 4.3.
# run: agent-run
# traces_to: ideate/acceptance-criteria/US-4.md; ideate/example-maps/US-4.md
# Agent-run: one agent (test-strategist) wrote these from the approved criteria; no workshop was held.

Feature: Cancel a pre-order
  As a customer
  I want to cancel my pre-order
  So that I do not pay for food I cannot collect

  Rule: An order can be cancelled until cooking starts

    @AC-US-4.1 @happy
    Scenario: An order not yet cooking is cancelled
      Given Priya's order 17 is waiting to be cooked
      When she cancels order 17
      Then she sees that order 17 is cancelled
      But order 17 no longer shows on the cooking list

    @AC-US-4.2 @negative
    Scenario: Cancelling is refused once cooking has started
      Given Priya's order 17 is being cooked
      When she cancels order 17
      Then she is told "Already cooking"
      But order 17 stays on the cooking list

    @AC-US-4.3 @edge
    Scenario: A second cancel changes nothing
      Given Priya has already cancelled order 17
      When she cancels order 17
      Then she sees that order 17 is cancelled
      But no second refund is made
````
