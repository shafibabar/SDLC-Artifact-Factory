# StrykerJS Mutation Testing Official Documentation
**Authors:** The Stryker Mutator project
**Domain:** Testing (mutation, JavaScript/TypeScript); decision D048 follow-up B

Accessed 2026-11-25. `@stryker-mutator/vitest-runner` 10.1.1: Node >=22, peers `vitest >=2.0.0`, core 10.1.1 (https://registry.npmjs.org/@stryker-mutator/vitest-runner/latest). Base D = https://stryker-mutator.io/docs. Pages are unversioned and were read through a summarising fetch tool. Nothing was run.

## Core Concepts

### Statuses (D/mutation-testing-elements/mutant-states-and-metrics/)

| Status | Meaning | Score |
|---|---|---|
| Killed | a test failed | detected |
| Timeout | tests exceeded the limit | detected |
| Survived | all tests passed | undetected |
| NoCoverage | no test covers it | undetected |
| RuntimeError, CompileError | run or compile error | invalid, excluded |
| Ignored | not tested by choice | excluded, shown |
| Pending | not yet run | not valid |

Mutation score = detected / valid x 100; a second score uses covered mutants only.

### Configuration (D/stryker-js/configuration/)
- `thresholds`: `high` 80, `low` 60, `break` null; below `break` exits 1; set all three or none.
- `mutate`: default covers `src`/`lib` JS-like files minus spec, test and `__tests__`; globs, `!`, line ranges (default globs: https://raw.githubusercontent.com/stryker-mutator/stryker-js/master/packages/api/schema/stryker-core.json).
- `mutator.excludedMutations`, `ignorers`, `ignoreStatic` (false; needs `perTest`), `coverageAnalysis` (`perTest`), `reporters` (`clear-text`, `progress`, `html`; also `json`), `checkers` (e.g. `typescript`), `timeoutMS` 5000, `timeoutFactor` 1.5, `allowEmpty` false (fails when no tests run), `disableTypeChecks` true, `incremental` false, `force` false.

### Suppression (D/stryker-js/disable-mutants/)
- `// Stryker [disable|restore] [next-line] mutatorList[: reason]`; list or `all`; the reason is shown in the report.
- Disabled mutants stay in the report as Ignored and do not count against the score.
- Ignorer plugins (since 7.3): `shouldIgnore(path)` returns a reason string.

### Equivalent mutants
- No automatic detection (D/mutation-testing-elements/equivalent-mutants/). That page says there is no way to mark them ignored, which conflicts with the disable-comment page; treat the comment as the StrykerJS mechanism.

### Vitest runner (D/stryker-js/vitest-runner/)
- `testRunner: "vitest"`; `vitest.configFile`, `.dir`, `.related` (true; disable if tests reach code indirectly), `.pool` (default `threads`).
- Forces coverage off, one worker, no watch, bail. `coverageAnalysis` is ignored (always `perTest`). Browser Mode unsupported; the page also states only threads are supported.

### Incremental mode (D/stryker-js/incremental/)
- Detects changes only in mutated and test files, not other files, dependencies, environment variables or snapshots; static mutants cannot see test changes. `--force` reruns.

### Report format
JSON: `files.<path>.mutants[]` with `id`, `mutatorName`, `location`, `status`, optional `replacement`, `statusReason`, `static` (https://raw.githubusercontent.com/stryker-mutator/mutation-testing-elements/master/packages/report-schema/src/mutation-testing-report-schema.json).

## Actionable Techniques (design is this note's, for D048 B)

1. Pin core, runner and checker versions; `thresholds: { high: 100, low: 100, break: 100 }`; add the `json` reporter; no `incremental` on the gate (or `--force`).
2. Do not rely on the score alone. A tested script reads the JSON: fail on `Survived`, `NoCoverage`, `Pending`, `RuntimeError`, missing or empty report, or zero mutants.
3. `Ignored` and `CompileError`: allowed only with a register entry. For equivalent mutants use `// Stryker disable next-line <Mutator>: <reason: behaviour unchanged ...>`; reject `all`, blanket blocks and empty reasons.
4. `Timeout` counts as detected by Stryker, but D048 B says caught by a test: record it, and ask the product owner for a ruling.
5. List `mutate` negations, `excludedMutations`, `ignorers` and `ignoreStatic` in the register; all hide mutants from the score.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| react-component-testing, test-pyramid | No front-end mutation method | Tool, statuses, gate |

## Candidate New Skills/Agents

A front-end mutation skill (twin of the Go and Python ones), or a reference inside `react-component-testing`.

## Key Terminology

Killed, Survived, NoCoverage, Ignored, Mutation score, Equivalent mutant.

## Caveats

- [unverified] Vitest 5 compatibility beyond the open peer range; core package version and mutator list; status given to mutants removed by `excludedMutations`; score when there are no valid mutants; effect of project coverage thresholds (the runner forces coverage off).

## Answers to audit questions

The React audit batch raises no mutation claim. D048 B for the front end is answered under Actionable Techniques.
