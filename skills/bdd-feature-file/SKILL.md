---
name: bdd-feature-file
description: >
  Use when test-strategist (or anyone) writes, reviews, fixes or changes a
  Gherkin .feature file or executable BDD scenarios in the Implement or Quality
  phase (/sdlc-implement, /sdlc-quality): turning acceptance criteria
  AC-US-n.m into scenarios; Given/When/Then, Rule, Background, Scenario
  Outline, Examples tables, @ tags and criterion traceability; step definitions
  (godog, Python), browser journeys from the same criteria, living
  documentation; being asked to cover only the happy path, skip criteria or a
  small (lean) product, script clicks or endpoints into steps, change a
  scenario so it matches the code or passes, or report scenarios as passing
  without a run. Produces artifacts/<product>/implement/features/US-n.feature.
version: 3.0.0
phase: implement
owner: test-strategist
created: 2026-06-25
tags: [implement, quality, bdd, gherkin, feature-file, godog, executable-spec, given-when-then]
produces: gherkin-feature-file
domain: testing
status: stable
related: [acceptance-criteria, example-mapping, test-pyramid, go-e2e-test, python-e2e-test, react-e2e-testing, uat-scenario, nfr-specification, glossary-management, methodology-review]
sources:
  - research/testing/specification-by-example-adzic.md
  - research/requirements-and-user-stories/lean-agile-atdd-pugh.md
  - research/testing/agile-testing-crispin-gregory.md
  - research/testing/software-testing-craftsman-jorgensen.md
  - research/testing/gherkin-official-reference.md
  - research/testing/godog-official-docs.md
  - research/testing/playwright-official-docs.md
  - research/testing/pytest-official-docs.md
---

# BDD Feature File

## Purpose

A feature file turns a story's agreed acceptance criteria into scenarios the product owner can read and a test runner can execute: the example that was agreed is the test, with no paraphrase in between (Ken Pugh, *Lean-Agile Acceptance Test-Driven Development*; Gojko Adzic, *Specification by Example*). These are the business-facing tests that guide development (Crispin and Gregory, *Agile Testing*). BDD is mandatory in this plugin.

## Fixed rules: a request does not change them

These hold at every size (lean, standard, enterprise), whoever asks, the product owner included.

1. **Every criterion of every Must Have story gets an executable scenario.** A small product gets fewer and shorter files, never none and never a subset. Any other story with agreed criteria gets the same when it is built.
2. **Scenarios come only from approved criteria** (`ideate/acceptance-criteria/US-n.md`). Missing or unapproved: the file is not written; go to `acceptance-criteria` (and `example-mapping`).
3. **Automate, never decide.** Step wording may be refined; no value, limit, actor or outcome changes, and no new behaviour is added. A case the criteria do not settle goes back to the example map as a question.
4. **A mismatch is the product owner's decision.** When the code or the request differs from a criterion, report both values and ask: keep the criterion (the build is then a defect, and the scenario fails until fixed), or change it through the map. Do not pick, and never soften a scenario so it passes.
5. **Traceable:** one file per story, `US-n.feature`; every scenario tagged `@AC-US-n.m` plus one of `@happy`, `@negative`, `@edge`. No trailing comments, no other ID scheme. All three angles, always; no "no meaningful edge" exemption.
6. **Declarative:** the product's own terms (`glossary-management`), one `When`, an observable `Then`; clicks, requests and queries live in step definitions.
7. **Executable, written before the code.** Step definitions follow and run in CI; undefined, pending or zero scenarios fail the run. Nothing is called passing without a run.
8. **A skipped or quarantined scenario proves nothing** (`test-pyramid`).
9. **Approval is the product owner's.** Editing an approved file returns it to draft until re-approved.
10. **No false session.** An agent-run file says one agent wrote it and no workshop was held.

When asked to break one: name the rule in a sentence or two, then do the useful work at once (write the scenarios the criteria support, rewrite the step declaratively, draft the question). Never offer to switch a fixed rule on request. What the product owner **can** do is answer a question or change a criterion through the example map.

## What every answer states

In a chat reply as much as with the file:

- that scenarios are required for this product; at lean, say plainly that a small product still covers every Must Have criterion;
- that an **edge-case scenario is required at every product size**, lean included, whether or not it was asked for;
- when asked for notes at the end of a line: that Gherkin has **no trailing comments; a comment must start on its own line**, so labels go in tags above the scenario;
- when click, request or query steps are asked for: that they are rewritten **because** a step states business behaviour, and interface detail makes scenarios break when the screen changes and hides what is being agreed; the detail goes in step definitions;
- for browser journeys: plain Playwright tests tagged with the same criterion IDs **plus a coverage check that fails when a Must Have criterion has no tagged test**. Do not offer a Gherkin adapter as an alternative;
- that a pipeline run publishes a report readable without opening the code;
- the criteria file used, by path, and whether it is approved;
- the feature file path, and **each criterion ID** with its scenario and angle; any ID without one, with the reason;
- everything of the user's that was replaced, removed or not written, **by name**, with the reason (for example, "your 'When she sends a DELETE request' became 'When she cancels the order': a step says what, not how");
- any mismatch between the criteria and the code or the request, as a **decision addressed to the product owner** with both options (the scenarios meanwhile follow the agreed criterion);
- the verdict: **Written, awaiting your approval**, or **Not written**, with what blocks it;
- the run status: **not run**, or the runner's actual counts (passed, failed, undefined, skipped);
- open items and questions for the product owner, or "none"; agent-run (or who took part);
- the next step: answers or approval; then step definitions, seen failing, before the code.

## Procedure

1. **Read** the criteria file, its example map, the glossary, the test strategy (layer and runner), any existing feature file and step definitions, and in the manifest whether the criteria are approved.
2. **Check the gate** (rules 2 and 4). A blocked story is reported **Not written**; settled stories continue.
3. **Create the file** from the product repository root: `./scripts/scaffold-bdd-feature-file.sh <product> <story-id> <story-title>` (path relative to this skill), or copy `./templates/feature-file.feature` with Write. Finish with Edit or Write.
4. **Shape the scenarios.** One `Rule:` per map rule; at least one scenario per criterion; real names and values from the criteria. For criterion-to-scenario mapping, readiness, outlines, pruning, decision tables or a changed criterion, read `./references/deriving-scenarios.md`.
5. **Write the Gherkin.** For tags, `Background`, `Rule`, comments, tables and syntax traps, read `./references/gherkin-syntax.md`.
6. **Validate:** `./scripts/validate-bdd-feature-file.sh <US-n.feature>`; fix every FAIL, re-run until clean, answer each WARN. Never pass by deleting a criterion or changing one.
7. **Check coverage across stories:** `./scripts/validate-bdd-feature-file.sh --product artifacts/<product> --must <Must Have IDs from ideate/moscow.md or the backlog>`.
8. **Tick** `./resources/checklist.md`, run `methodology-review`, and present with the answer list above.
9. **Bind and run:** step definitions before implementation, seen failing for the expected reason. Read `./references/binding-and-running.md` for godog, Python, browser journeys, the living-documentation report and suite upkeep.

## Shape

```gherkin
  Rule: An order can be cancelled until cooking starts

    @AC-US-4.2 @negative
    Scenario: Cancelling is refused once cooking has started
      Given Priya's order 17 is being cooked
      When she cancels order 17
      Then she is told "Already cooking"
      But order 17 stays on the cooking list
```

Not `When she sends a DELETE request`, not `Then the row is removed`, not a `# negative` after the title.

## Boundary with neighbouring skills

| Skill | Owns |
|---|---|
| `example-mapping` | Rules, examples, questions, readiness (Ideate) |
| `acceptance-criteria` | What "done" means, the criterion IDs, any change to them |
| **This skill** (test-strategist, Implement) | Feature files, titles, tags, criterion coverage, `Background`, outlines, step definitions |
| `test-pyramid` | Which layer proves each scenario, suite selection, flaky policy |
| `go-e2e-test`, `python-e2e-test`, `react-e2e-testing` | Journey environments and browser tests |
| `uat-scenario` | Human scripts after deployment; never a substitute for a missing scenario |

## Gotchas

- **"Happy path now, the rest later."** *Reason:* the uncovered criteria are where defects live, and approval would claim they are proven. *Instead:* one scenario per criterion before presenting.
- **"The code refunds 50%, so I'll write 50%."** *Reason:* the defect becomes the specification. *Instead:* keep the agreed value, name the ID and both values, ask.
- **"I'll add a scenario for the case they forgot."** *Reason:* its outcome is a rule nobody agreed. *Instead:* put the question to the product owner; add it once the criteria have it.
- **`Scenario: Refused # negative`.** *Reason:* a comment must start its own line, so trailing text is not a comment and filters nothing. *Instead:* tags above the scenario.
- **"All tests passed" from an unbound or empty suite.** *Reason:* godog passes undefined steps unless strict, and passes when it finds no features. *Instead:* strict mode, assert features were found, report counts.
- **Eleven near-identical Examples rows.** *Reason:* a row that proves nothing new only hides the rules. *Instead:* keep rows whose removal would lose something; split mixed rules.
- **`@wip` to get CI green.** *Reason:* the criterion is now unproven. *Instead:* say the gate is red for that ID.
- **"It runs in CI, so it is living documentation."** *Reason:* that is half; the verified result must also be rendered readably. *Instead:* generate the report.
- **"The browser journey reuses the .feature file."** *Reason:* Playwright does not read it as written. *Instead:* plain browser tests tagged with the same IDs.

## Files

| File | When to open it |
|---|---|
| `./templates/feature-file.feature` | Writing the artifact by hand |
| `./scripts/scaffold-bdd-feature-file.sh` | Starting a story's file from its criteria |
| `./scripts/validate-bdd-feature-file.sh` | Before hand-off, after every edit, and for product-wide coverage |
| `./resources/checklist.md` | After the script passes |
| `./references/deriving-scenarios.md` | Criteria to scenarios, readiness, examples, changes |
| `./references/gherkin-syntax.md` | Writing or fixing Gherkin |
| `./references/binding-and-running.md` | Step definitions, running, reporting, upkeep |
| `./examples/01-lean-food-truck-preorder.md` | A small product, or a request to cover only the happy path |
| `./examples/02-standard-library-renewal.md` | Rules, an outline pruned, rule-format criteria, clicks rewritten |
| `./examples/03-enterprise-payment-approval.md` | Tenants, a decision table, eventual outcomes, a build that disagrees |
