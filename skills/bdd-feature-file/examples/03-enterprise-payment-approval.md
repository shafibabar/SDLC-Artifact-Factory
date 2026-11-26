# Example 3 (enterprise): Approving Payments Under a Tenant's Limit

Self-contained input and output. The point: a multi-tenant payments product, a decision table before the examples, an eventual outcome another system observes, tenant isolation, a build that disagrees with a criterion, and a combination nobody agreed.

## Input

- Product: payment approvals for many companies (tenants), two regions. Profile **enterprise**. US-31 is Must Have. Strategy: scenarios bind at the integration layer; one journey also runs end to end.
- Developer's note: "A payment exactly on the limit asks for a second approver in our build. Make the scenario match so the pipeline is green."
- `ideate/acceptance-criteria/US-31.md` (approved):

````markdown
## Happy Path

### AC-US-31.1: A payment up to the limit is released by one approver
- From: R1 (R1.E1, R1.E2)

```gherkin
Given Northwind's single-approver limit is €10,000 and Dana is a Northwind approver who did not create payment P-88 for €10,000,
When she approves P-88,
Then P-88 is released
And Northwind's ledger system receives the PaymentReleased event for P-88.
```

## Error / Negative Scenarios

### AC-US-31.2: The creator cannot approve their own payment
- From: R2 (R2.E1)

```gherkin
Given Dana created payment P-90 for €500,
When she approves P-90,
Then she is told "You created this payment"
But P-90 is not released.
```

### AC-US-31.3: Another company's approver sees nothing
- From: R3 (R3.E1)

```gherkin
Given payment P-88 belongs to Northwind and Raj is an approver at Contoso,
When Raj opens P-88,
Then he is told no such payment exists
But nothing about P-88 is shown to him.
```

## Boundary / Edge Cases

### AC-US-31.4: One cent over the limit waits for a second approver
- From: R1 (R1.E3)

```gherkin
Given Northwind's single-approver limit is €10,000 and Dana did not create payment P-89 for €10,000.01,
When she approves P-89,
Then P-89 shows "Waiting for second approval"
But P-89 is not released.
```
````

## Decision table (built before the scenarios)

| Approver's tenant owns it | Approver created it | Amount | Outcome | Agreed in |
|---|---|---|---|---|
| no | any | any | not visible | AC-US-31.3 |
| yes | yes | up to the limit | refused | AC-US-31.2 |
| yes | yes | over the limit | **not agreed** | Q-9 |
| yes | no | up to the limit | released | AC-US-31.1 |
| yes | no | over the limit | waits for second approver | AC-US-31.4 |

## The reply

"**Written, awaiting your approval**, with two decisions for you. Scenarios are required for this story. Criteria: `ideate/acceptance-criteria/US-31.md` (approved). File: `implement/features/US-31.feature`; `AC-US-31.1` happy, `AC-US-31.2` and `AC-US-31.3` negative, `AC-US-31.4` edge. Refused: 'make the scenario match' the build; the scenario keeps 'exactly €10,000 is released', so it will fail against today's build.

Decision 1, `AC-US-31.1`: the criterion releases a €10,000 payment with one approver; the build asks for a second. Do you (a) keep the criterion, making the build a defect to fix, or (b) change the rule through the US-31 example map, after which the criteria and this file are updated and re-approved?

Question Q-9 (decision table): may a creator approve their own payment over the limit as one of the two approvals? Options: refuse as for smaller amounts, or allow. No scenario is written for it until the example map and criteria answer it.

Run status: not run. Agent-run; no workshop was held. Next: your answers and approval, then step definitions."

## Output: `implement/features/US-31.feature`

````gherkin
# name: feature-file
# product: paygate
# story-id: US-31
# version: 1.0.0
# phase: implement
# owner: test-strategist
# created: 2026-11-26
# summary: Single-approver limit, own-payment refusal and tenant isolation, proving AC-US-31.1 to 31.4.
# run: agent-run
# traces_to: ideate/acceptance-criteria/US-31.md; ideate/example-maps/US-31.md
# Agent-run: one agent (test-strategist) wrote these from the approved criteria; no workshop was held.

Feature: Approve a payment
  As a company's payment approver
  I want to approve payments within my company's limit
  So that suppliers are paid without needless second approvals

  Background:
    Given Northwind's single-approver limit is €10,000
    And Dana is a Northwind approver

  Rule: One approver releases a payment up to the tenant's limit

    @AC-US-31.1 @happy
    Scenario: A payment on the limit is released by one approver
      Given Dana did not create payment P-88 for €10,000
      When she approves P-88
      Then P-88 is released
      And Northwind's ledger system receives the PaymentReleased event for P-88

    @AC-US-31.4 @edge
    Scenario: One cent over the limit waits for a second approver
      Given Dana did not create payment P-89 for €10,000.01
      When she approves P-89
      Then P-89 shows "Waiting for second approval"
      But P-89 is not released

  Rule: The creator of a payment cannot approve it alone

    @AC-US-31.2 @negative
    Scenario: The creator cannot approve their own payment
      Given Dana created payment P-90 for €500
      When she approves P-90
      Then she is told "You created this payment"
      But P-90 is not released

  Rule: A payment is visible only inside its own company

    @AC-US-31.3 @negative
    Scenario: Another company's approver sees nothing
      Given payment P-88 belongs to Northwind
      And Raj is an approver at Contoso
      When Raj opens P-88
      Then he is told no such payment exists
      But nothing about P-88 is shown to him
````

The ledger step waits, with a bounded timeout, for the event to arrive; the wait lives in the step definition.
