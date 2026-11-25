# pytest Official Documentation
**Authors:** The pytest project (pytest-dev/pytest)
**Domain:** Testing (unit and runner, Python)

Accessed 2026-11-25. Latest 9.2.0, Python >=3.10, MIT (https://pypi.org/pypi/pytest/json). Doc pages are `stable`.

## Core Concepts

- **Async tests without a plugin fail** since 8.4.0; before that they warned and skipped (#11372, https://docs.pytest.org/en/stable/changelog.html). The deprecations page words the history as pytest long giving an error (https://docs.pytest.org/en/stable/deprecations.html); the changelog is the more specific statement.
- A sync test depending on an async fixture was deprecated in 8.4 and listed as removed in 9.0 (deprecations page).
- Since 8.4.0, a test returning a non-None value fails (changelog).
- Exit codes: 0 passed, 1 failed, 2 interrupted, 3 internal error, 4 usage error, **5 no tests collected**, 6 max warnings exceeded (https://docs.pytest.org/en/stable/reference/exit-codes.html).
- Config precedence, first match wins, never merged: `pytest.toml`, `pytest.ini`, `pyproject.toml` (`[tool.pytest]` from 9.0, or `[tool.pytest.ini_options]`), `tox.ini`, `setup.cfg` (https://docs.pytest.org/en/stable/reference/customize.html). The two pyproject tables cannot both be used (changelog, #13743).
- Unregistered marks warn; `strict_markers` makes them errors (https://docs.pytest.org/en/stable/how-to/mark.html). 9.0 added `strict` (config, markers, parametrization ids, xfail); more may join it, so pin the version. 9.2 also validates names in `-m` expressions under `strict_markers` (changelog).

## Actionable Techniques

- Own one pytest table; register every marker; enable strict settings with a pinned pytest.
- In CI treat exit 5 as failure; never mask it.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| python-unit-test, python-makefile, python contract/e2e/chaos skills | W3C-1, 5, 18 | Async failure, one config, exit codes |

## Candidate New Skills/Agents

None.

## Key Terminology

Fixture, Marker, Strict Mode, Exit Code.

## Caveats

- [unverified] Fixture scoping, parametrize and xfail details were not refetched; see `python-testing-with-pytest-okken.md` for patterns only.
- [unverified] That `getfixturevalue` of an async fixture inside an async test raises (W3C-19).

## Answers to audit questions

| Question | Answer | Status |
|---|---|---|
| W3C-1: un-awaited async test "passes" | It fails on 8.4+ | Refutes the skill; confirms the audit |
| W3C-1 [GK]: older releases skipped with a warning | Yes | Confirmed |
| W3C-18: all deselected exits 5 | Exit 5 means nothing collected | Confirmed (deselection case rests on audit [Ran]) |
| W3C-5: unregistered `chaos` under strict markers errors | Yes | Confirmed |
