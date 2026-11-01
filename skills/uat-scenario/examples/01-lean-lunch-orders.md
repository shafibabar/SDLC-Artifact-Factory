# Example 1 (lean): one criterion, one scenario

Self-contained. The simplest real case: a single-tenant tool, one Must criterion, one scenario, a solo product owner executing under `uat-plan`'s solo-operator exception.

## Input

**Product:** Crumb, lunch ordering for one office of 40 people. Profile: lean.
**Story US-2:** As an office manager, I want orders to close at the cut-off, so that I can send one order to the caterer.

**Agreed criterion AC-US-2.1:**

```gherkin
Given today's menu has a cut-off of 10:30
And Priya has ordered "Falafel wrap" at 10:12
When the office manager closes today's orders at 10:30
Then the order list shows Priya's "Falafel wrap"
And the order list cannot be changed
And the caterer summary shows 1 × Falafel wrap
```

## Output

`artifacts/crumb/customer-validation/uat-scenarios/US-2.md` (frontmatter omitted here):

```markdown
### UAT-2a: Office manager closes today's lunch orders at the cut-off

**Traces to:** AC-US-2.1
**Performed by:** office manager

**Preconditions and test data** (seeded by the product owner, before the window):
- Today's menu "Thursday" exists with cut-off 10:30 — confirm by: the menu page shows "Orders close 10:30"
- Test colleague "Priya Shah" has ordered "Falafel wrap" — confirm by: her order is in Today's orders

**Environment:** canary · build 2026.11.2

**Context (Given):** Today's orders are open and show one order, Priya Shah's Falafel wrap.

**Steps (When):**
1. At or after 10:30, open Today's orders.
2. Choose "Close orders".

**Expected Outcome (Then):**
- The list still shows Priya Shah — Falafel wrap.
- The list shows "Closed" and has no Edit or Add buttons.
- "Caterer summary" shows 1 × Falafel wrap.

**Runs:**

| Date | Tester (role) | Result | Evidence | Defect / workaround | Re-test of | Found outside this scenario |
|---|---|---|---|---|---|---|
| 2026-11-06 | Sam Okafor (product owner, solo exception) | Pass | shots/UAT-2a-1.png, -2.png | — | — | FB-07 (menu page typo "Falfel") |
```

## Why it looks like this

- **One criterion, one scenario, still `UAT-2a`.** The letter is there so a second scenario later does not rename this one.
- **Named data.** "Priya Shah — Falafel wrap" is checkable; "an order" is not.
- **"The list cannot be changed" became something visible:** no Edit or Add buttons, and the word Closed.
- **The typo is FB-07, not a Fail.** It is outside this scenario's Context, so it is logged separately and the result stays Pass.
- **Evidence matters more here:** the tester and approver are the same person, so screenshots let anyone re-judge the result later.
