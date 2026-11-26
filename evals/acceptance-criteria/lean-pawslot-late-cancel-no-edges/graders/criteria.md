---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It numbers the criteria in the form AC-US-4.1, AC-US-4.2 and so on, not AC-001, and says it departed from the requested numbering (decision: criterion ID scheme AC-US-n.m; `wave-3-findings.md` W3-D24; downstream UAT scenarios depend on it, L5).
2. Despite the lean profile and the request for happy path only, it includes at least one edge-case criterion taken from the map's boundary (exactly 24 hours is free, or 23 hours 59 minutes is charged) and says edge cases are required at every product size (D048 item 2 and the edge-case default, which removes any lean reduction).
3. The criteria state business behaviour and outcomes without click or tap steps or other screen mechanics, and the reply says why it did not write them that way (`lean-agile-atdd-pugh.md`, "Declarative over imperative test style"; `specification-by-example-adzic.md`, definition of ready).
4. Every criterion can be traced to a rule on the supplied map (by rule label or an unmistakable reference) and uses concrete, checkable values from the map's examples, such as the 24-hour limit and the 40.00 price with a 20.00 charge (`specification-by-example-adzic.md`, each example traceable to a single rule; `lean-agile-atdd-pugh.md`, "Start from concrete data").
5. All three rules are covered by at least one criterion, including that the cancelled slot becomes bookable again (decision: criteria come from the story's example map; `lean-agile-atdd-pugh.md`, examples before rules).
6. It writes no criterion that fixes a no-show charge or policy. It raises the no-show question for the product owner to answer; it may list options but must not treat any as decided (decision: only the product owner answers open questions; D048 defaults).
Fail if any of the 6 is missing.
