# From Agreed Criteria to Scenarios

Self-contained. Use when turning a story's acceptance criteria (`ideate/acceptance-criteria/US-n.md`, IDs `AC-US-n.m`) into scenarios (`implement/features/US-n.feature`), sizing an Examples table, or handling a criterion that is questioned.

## Why the criteria are the input

Feature files realise criteria that were drawn from concrete examples on the story's example map and agreed before coding (Ken Pugh, *Lean-Agile Acceptance Test-Driven Development*). Each restatement between intent and code is a place for understanding to leak (Pugh's translation waste), so keep the criterion's names, values and outcomes.

## Ready to automate

A Specification Workshop is a short, focused session in which business, development and testing perspectives work out concrete examples together (Adzic; Crispin and Gregory describe the same three-way collaboration). Its output is ready to become an automated scenario when it meets three checks:

1. **Business language only.** If the example cannot be stated without naming an implementation detail, it is not ready.
2. **Traceable to a single rule.** An example doing duty for two rules means the rules are not yet separated.
3. **Explicit agreement.** The people present confirmed it shows the intended behaviour. In this plugin the record of agreement is the product owner's approval of the criteria file.

When one agent plays all perspectives, say so; no session was held. Before writing, re-read the criteria from the testing perspective: can each be passed or failed by an observer? An untestable one goes back to `acceptance-criteria` with a proposed rewrite.

## Criterion to scenario

| In the criteria file | In the feature file |
|---|---|
| Gherkin criterion | A scenario; same state, action and outcome |
| Rule / Verify / Example criterion | A scenario from the Example, checking what Verify says; an outline if the Rule covers several values the map shows |
| Map rule `R1` (the From line) | `Rule:` block holding its scenarios |
| Heading: Happy Path / Error / Boundary | `@happy` / `@negative` / `@edge` |
| `But` or `And` line | Kept; it is part of what was agreed |
| Out-of-scope line | No scenario |
| Quality target (NFR ID) | No scenario step; performance and load tests own it |

One criterion may need several scenarios; each carries its ID. One scenario carries a second ID only when one behaviour proves both under one rule. Extra scenarios use only values the criteria or map already agreed.

Refinements you may make: name "she", move a shared Given to `Background`, shorten a title, merge same-behaviour examples into an outline. Not allowed: a different number, a looser outcome, a dropped `But`, a new actor or error message.

## Key examples: how many rows

Use the smallest set of examples that pins the rule down (Adzic's key examples). For each Examples row ask: would removing it change what the rule is proven to do? If not, remove it and say which rows went and why. A table that keeps growing usually holds several rules; split it. Never remove a row that is the only proof of a criterion, a limit or an agreed value; a row carrying an agreed example the product owner expects to see is raised, not silently dropped. Re-prune when rules change.

## Three or more conditions: decision table first

Examples chosen by intuition miss combinations. When a rule depends on three or more independent conditions, list every combination in a decision table (condition rows, action row), merge only conditions that truly do not matter, and check that it is complete and free of contradictions (Jorgensen, *Software Testing: A Craftsman's Approach*). A combination with no agreed outcome is a question for the example map. Then keep the key rows as scenarios: completeness checks the rule, pruning keeps the table readable.

## When a criterion is questioned or changes

1. Name the ID, what the criterion says, and what the code or request says.
2. Put it to the product owner as a decision: keep (the build is a defect; the scenario stays and fails) or change (through the story's example map, then the criteria file, then this file). Give both; choose neither.
3. Until answered, the scenario states the agreed criterion.
4. After an approved change: update scenarios and step definitions, bump `version`, and name the dependants (browser tests, UAT scenarios, test strategy). The edited file returns to draft for re-approval.

Scenarios written after the code, describing what it does, turn defects into requirements. For existing code, write from approved criteria and let mismatches fail.
