---
name: assumption-test
product: <product>
version: 1.0.0
phase: ideate
owner: requirements-analyst
created: <yyyy-mm-dd: the day the criterion was set>
summary: <one sentence: the assumption, the test, and the verdict once run>
tree: <ideate/opportunity-solution-tree.md or ideate/opportunity-solution-trees/<outcome>.md>
test-id: <T-n>
assumption: <A-n: what must be true>
assumption-type: <desirability | viability | feasibility | usability | ethical>
solutions: <SOL-1, SOL-2, SOL-3>
success-criterion: <at least N of M <population> do X>
criterion-set-on: <yyyy-mm-dd>
run-by: <the user | design-partner lead | <engineering agent> for a feasibility spike>
run-on: <yyyy-mm-dd, or "not yet run">
verdict: <supported | not supported | inconclusive | not yet run>
---

<!-- Copy into ideate/assumption-tests/<yyyy-mm-dd>-<slug>.md. One file per test.
     Fill everything above "Result" before the test runs; never change the success criterion afterwards.
     criterion-set-on must be on or before run-on. -->

# Assumption Test <T-n> — <short name>

## What we are testing

- **Assumption:** <A-n>, <type>. Why it matters: <importance>. Evidence before this test: <none / refs>.
- **Solutions compared:** <SOL-…>
- **Test:** <form: comparison test, concierge, data look, prototype walkthrough, spike>
- **Population:** <who, how many, how recruited>
- **Success criterion:** <at least N of M …> (set <date>)

## Result

<!-- Filled after the run. Raw counts, not adjectives. -->

| Measure | Value |
|---|---|
| Participants / events | <M> |
| Met the bar | <N> |

**Verdict:** <supported | not supported | inconclusive>, against the criterion as set.

## What changes on the tree

<At the next cycle's revision: move the assumption to strong evidence, change or drop a solution, or question the opportunity.>
