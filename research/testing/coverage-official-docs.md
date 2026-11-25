# coverage.py and pytest-cov Official Documentation and Source
**Authors:** The coverage.py project (nedbat/coveragepy); the pytest-cov project (pytest-dev/pytest-cov)
**Domain:** Testing (coverage, Python); decision D048 follow-up A

Accessed 2026-11-25. coverage 7.17.5, Python >=3.11 (https://pypi.org/pypi/coverage/json). pytest-cov 7.1.0, Python >=3.9, needs `coverage[toml]>=7.10.6` (https://pypi.org/pypi/pytest-cov/json). `latest` doc pages state no version. Source links are tag-pinned. Nothing was run.

## Core Concepts

### Measurement
- Statement coverage by default; branch coverage needs `--branch`, `[run] branch = true` or `--cov-branch` (https://coverage.readthedocs.io/en/latest/config.html; https://pytest-cov.readthedocs.io/en/latest/config.html).
- A branch is a line-to-line transition. A line is partial when not all possible destinations ran. The total counts lines and branch destinations together (https://coverage.readthedocs.io/en/latest/branch.html). Source: (executed statements + executed branches) / (statements + branches); **a zero denominator gives 100.0** (https://raw.githubusercontent.com/nedbat/coveragepy/7.17.5/coverage/results.py).
- Inference: alternatives inside one line (ternary, `and`/`or`) are not separate branches.
- `source` makes unexecuted files appear; only importable files (tree root or directories with `__init__.py`) are found (https://coverage.readthedocs.io/en/latest/source.html). `include_namespace_packages` (7.0) extends this to directories without `__init__.py`; `source` overrides `include` (config page).

### Rounding and fail-under
- `precision` default 0 (config page).
- "A setting of 100 will fail any value under 100" at any precision (config page); source: `if fail_under == 100.0 and total != 100.0` fails. Displayed values strictly between 0 and 100 are never rounded to 0 or 100 (results.py).
- CLI: only reporting commands check it; exit 2 on failure, 1 on errors (https://raw.githubusercontent.com/nedbat/coveragepy/7.17.5/coverage/cmdline.py). No files left after filtering raises "No data to report." (https://raw.githubusercontent.com/nedbat/coveragepy/7.17.5/coverage/report_core.py).

### pytest-cov behaviour (https://raw.githubusercontent.com/pytest-dev/pytest-cov/v7.1.0/src/pytest_cov/plugin.py)
- Uses coverage's `should_fail_under`; on failure adds one to `testsfailed`, so pytest exits "tests failed".
- Without `--cov-fail-under`, **the coverage config `fail_under` is used**.
- The check is skipped with `--collect-only`; with `--no-cov` it never runs; with `--no-cov-on-fail` and a failed run, report and check are skipped.
- A report error warns and sets the total to 0.
- Options include `--cov`, `--cov-report`, `--cov-config`, `--cov-append`, `--cov-reset`, `--cov-precision`. `--cov=x` overrides `source`; `--cov-branch` overrides `branch`; `parallel` is overridden. A trailing bare `--cov` in `addopts` can swallow the next argument; use `--cov=` (config page).
- 7.0.0 removed subprocess measurement: use `[run] patch = subprocess`. 7.1.0 computes the total consistently whatever the report options (https://pytest-cov.readthedocs.io/en/latest/changelog.html). `patch` also offers `_exit`, `execv`; combine parallel files with `coverage combine` (https://coverage.readthedocs.io/en/latest/subprocess.html).

### Exclusions
- Defaults at 7.17.5 (https://raw.githubusercontent.com/nedbat/coveragepy/7.17.5/coverage/config.py): `# pragma: no cover` (case and spacing variants); `...` bodies; `if TYPE_CHECKING:`. Partial: `# pragma: no branch`; always: `while True/1/False/0:` and `if True/1/False/0:`. The `...` and `TYPE_CHECKING` defaults date from 7.10.0 (https://coverage.readthedocs.io/en/latest/excluding.html).
- A pragma on a clause line (`if`, `def`, `class`) excludes the whole clause. A conditional with one excluded choice is not counted as a branch (excluding page).
- `exclude_also` adds to defaults; `exclude_lines` replaces them. `partial_also` (7.10) adds; `partial_branches` replaces (config page). Multi-line regexes (7.6) can exclude whole files (excluding page).
- `omit`/`include` drop files from measurement or report (source page).
- No automatic generated-code exclusion was found on these pages [unverified as a general absence].

### Machine-readable output
`coverage json` / `--cov-report=json:PATH`. Keys at 7.17.5: `meta.branch_coverage`; `totals` with `num_statements`, `missing_lines`, `excluded_lines`, `num_branches`, `num_partial_branches`, `missing_branches`; per file `missing_lines`, `excluded_lines`, `missing_branches` (https://raw.githubusercontent.com/nedbat/coveragepy/7.17.5/coverage/jsonreport.py).

## Actionable Techniques (design is this note's, for D048 A)

1. Config: `branch = true`, `source` naming the product packages, `include_namespace_packages = true`, `omit` only for generated or approved files. No `--cov*` flag and **no `fail_under` in shared config or `addopts`**.
2. Full gate only: `pytest <all suites in scope> --cov=<pkg> --cov-branch --cov-report=json:coverage.json --cov-fail-under=100`. For several runs, `--cov-append` (or parallel files and `coverage combine`), then `coverage report --fail-under=100`; delete old data first.
3. Subset runs: no coverage flags, or `--no-cov`.
4. A tested script then fails unless: report is fresh; `meta.branch_coverage` is true; `num_statements > 0`; `missing_lines`, `missing_branches`, `num_partial_branches` are 0; every product `.py` file on disk is in `files` or in the approved list.
5. Same script holds the exclusion register: each `excluded_lines` entry, each `no branch` pragma (inference: not visible as excluded lines), and each `omit`, `exclude_*`, `partial_*` setting needs an approved reason. The built-in defaults are exclusions too: approve them as a class, or replace them with `exclude_lines` / `partial_branches` ([unverified] whether the "always" partial list can be overridden).

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| python-unit-test, python-makefile, test-pyramid, ci-pipeline | W3C-3; D048 A | Gate flags, rounding rule, exclusion register |
| python-mutation-test | Coverage flags during mutant runs | Keep coverage out of `addopts` |

## Candidate New Skills/Agents

None. The gate script needs one owning skill.

## Key Terminology

Statement Coverage, Branch Coverage, Partial Branch, Exclusion Pragma.

## Caveats

- [unverified] Differences between measurement cores (including `sys.monitoring`) for branch results.
- Pages were read through a summarising fetch tool; recheck exact strings at build time.

## Answers to audit questions

| Question | Answer | Status |
|---|---|---|
| D048 A: does 100 round up from 99.x | No; exact comparison | Confirmed |
| W3C-3: `--cov-fail-under` in `addopts` fails subset runs | The plugin checks whatever the run measured | Confirmed (mechanism; audit [Ran]) |
| W3C-3 [GK]: a mutmut 2 runner would count every mutant killed | mutmut 2 not researched; see the mutmut note for 3 | [unverified] |
| Moving the flag to config `fail_under` fixes subsets | No: pytest-cov reads it whenever coverage is on | Confirmed (source) |
