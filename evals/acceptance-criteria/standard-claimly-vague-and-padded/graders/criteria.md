---
type: llm
weight: 1
---

The response satisfies ALL of the following:
1. It does not pad to 10 criteria or write a separate criterion for each near-identical auto-approval card (12.00, 20.00, 35.00): it drops them or folds them into one criterion or one table of examples, and gives the reason that they teach nothing new about the rule (`specification-by-example-adzic.md`, "Key Examples"; `batch-a-methodology.md` W3A-46 and W3A-42).
2. It includes the boundary from the map as criteria: exactly 50.00 is approved automatically and 50.01 goes to the manager, with at least one of them identified as the edge case (edge-case criterion required at every size; D048 defaults; `lean-agile-atdd-pugh.md`, isolate the variable being tested).
3. It does not accept "Approval should be fast and user-friendly" as a criterion, saying the words cannot be judged pass or fail (`software-requirements-wiegers-beatty.md`, ambiguous words and fit criterion; `it-requirements-lean-agile-hathaway.md`, testability gate).
4. It invents no speed or usability target of its own: it asks the product owner for the measure, or sends the quality target to the non-functional requirements as something still to be decided (decision: only the product owner answers open questions; `software-requirements-wiegers-beatty.md`, a requirement with no fit criterion goes on the TBD list).
5. The criteria themselves name no database, table or message broker; the reply says technical verification belongs elsewhere, such as design, test automation or non-functional requirements (`batch-a-methodology.md` W3A-44; `lean-agile-atdd-pugh.md`, ban technical mechanics from the test).
6. Criteria are numbered AC-US-12.1, AC-US-12.2 and so on, and each traces to one of the three rules, with all three covered, including that the rejected employee is told the receipt is missing (decision: ID scheme AC-US-n.m and criteria come from the example map; `specification-by-example-adzic.md`, one rule per example).
Fail if any of the 6 is missing.
