# Hypothesis Official Documentation and Source
**Authors:** The Hypothesis project (HypothesisWorks/hypothesis)
**Domain:** Testing (property-based, Python)

Accessed 2026-11-25. Latest 6.170.17, Python >=3.11 (https://pypi.org/pypi/hypothesis/json). Doc pages are `latest`.

## Core Concepts

- Defaults: `max_examples` 100; `deadline` 200 ms; `derandomize` false; example database `.hypothesis/examples`; all phases (https://hypothesis.readthedocs.io/en/latest/reference/api.html).
- Built-in `ci` profile in CI: no deadline, derandomized, no database, `too_slow` suppressed, prints the reproduction blob (same page). Detection uses `CI` and vendor variables including `GITHUB_ACTIONS` (https://raw.githubusercontent.com/HypothesisWorks/hypothesis/master/hypothesis/src/hypothesis/_settings.py, unpinned).
- `@example` inputs run first and do not count toward the limit; `@seed` fixes generation; `@reproduce_failure` is temporary and version-bound (API page).
- `register_profile` / `load_profile`; pytest flags `--hypothesis-profile`, `--hypothesis-seed`, `--hypothesis-show-statistics` (https://hypothesis.readthedocs.io/en/latest/reference/integrations.html).
- `builds`, `composite`, `from_type` build strategies (https://hypothesis.readthedocs.io/en/latest/reference/strategies.html).
- `HealthCheck.function_scoped_fixture`: such fixtures run once per test function, not per generated case (settings source).
- Stateful testing: `RuleBasedStateMachine`, `@rule`, `Bundle`, `@initialize`, `@precondition`, `@invariant`; `stateful_step_count` (https://hypothesis.readthedocs.io/en/latest/stateful.html).

## Actionable Techniques (design is this note's)

- Properties for invariants and round trips; stateful tests for Aggregate transitions; pin found failures with `@example`.
- Under coverage or mutation gates use a derandomized profile so verdicts repeat.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| python-unit-test, python-domain-model | W3C-10 | Case generation, CI determinism, fixture trap |

## Candidate New Skills/Agents

None.

## Key Terminology

Strategy, Property, Shrinking, Profile, Stateful Test.

## Caveats

- Nothing was run. [unverified] Interaction with mutmut timeouts and async tests.

## Answers to audit questions

| Question | Answer | Status |
|---|---|---|
| W3C-10 / "documentation suffices" for Hypothesis | Covers the property-based option | Confirmed |
