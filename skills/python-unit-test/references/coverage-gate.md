# Python Coverage Gate

Self-contained. Use when running, reading or reporting Python coverage. The policy belongs to `test-pyramid`; this file says how Python meets it. Behaviour marked "seen" was run with coverage 7.17.5, pytest-cov 7.1.0 and pytest 9.2.0 on Python 3.14.4 (2026-11-26).

## The policy

- 100% of lines and 100% of branches, each judged separately.
- Only machine-generated code is excluded automatically. Every other exclusion is listed with a reason for the product owner's approval, including coverage.py's own defaults (`# pragma: no cover`, `...` bodies, `if TYPE_CHECKING:`) and `# pragma: no branch`.
- Above 90% and under 100% fails unless the product owner reviews the gap and waives it with recorded comments; 90% or below has no waiver. No result means nothing to waive. A waiver covers one run. Testing layers are never waived.
- Compute from counts, never a rounded figure: waivable only if `covered x 10 > total x 9` and `covered < total`. Add counts across packages; never average percentages or blend the two measures.
- The verdict comes from the full run of all suites in scope. A unit-only or filtered run gives no verdict.

## The command

```bash
check-python-coverage.sh [--source dir]... [--exclusions file] [--skip-suite e2e|chaos|performance|load]... [--python exe] [--out file] [project-dir]
```

Copy `../scripts/check-python-coverage.sh` into the product's `scripts/`; `make test` runs it (`python-makefile`), for example `uv run bash scripts/check-python-coverage.sh --source src/<pkg> --skip-suite e2e`. It needs `python3` (3.8 or later to run the script itself, unverified below 3.14) and pytest-cov in the interpreter it calls.

## What it reads and fails on

It runs the whole `tests/` folder and reads the JSON report it has just written, plus pytest's JUnit file and output.

| Condition | Exit |
|---|---|
| Any line not run or branch not taken, in either measure | 1 (waiver wording printed per measure) |
| Failed test, pytest error, no test collected or run, any test deselected | 2 |
| Report missing or without branch data; zero statements | 2 |
| A `.py` file under a source folder that is absent from the report | 2 |
| Lines left out by coverage.py or `no branch`, with no matching approval | 2 |
| Pending, malformed or undated exclusion entry; a skip of the unit, integration or contract folder; any test-selection argument | 2 |
| All counted lines and branches ran | 0 |

Any non-zero exit blocks the build. Skipped and expected-to-fail tests are counted and printed but do not change the exit code: read the line.

It ignores the product's coverage settings (`omit`, `exclude_also`, `partial_branches`, `fail_under`) and clears `addopts` and `PYTEST_ADDOPTS`, so the exclusion file is the only way to leave anything out.

## The old check is removed

The earlier `--cov-fail-under=80` in `addopts` is **removed, not kept**, and so is any printed-percentage check, not even as an extra step:

- it failed a one-test subset run whose test passed (seen: "Required test coverage of 80% not reached");
- one blended figure mixes lines and branches;
- raising it to 100 does not make it a gate. Seen, each with the tool reporting 100% and passing: a `# pragma: no cover` function; an `omit` entry hiding an untested file; branch measurement off with a branch untaken; an untested folder with no `__init__.py`. The script blocks or counts each.

## Exclusion file

One line each, approved entries only:

```text
src/<pkg>/wiring.py | file | approved YYYY-MM-DD | reason
src/<pkg>/ports.py | lines 0a1b2c3d4e5f | approved YYYY-MM-DD | reason
```

The script prints the `lines` entry to propose, marked `pending`, which it refuses until the product owner approves it. The fingerprint is of the left-out lines' text: change them and approval lapses. It mirrors the exclusion register in the test strategy. Excepted files are printed as not measured. Prefer a code change to an entry: a Protocol method with a docstring body instead of `...` leaves nothing out.

Generated code is recognised only by a marker in the file's leading comments (`@generated`, or "generated" with "DO NOT EDIT"); each such file is printed. Never add a marker to hand-written code.

## Not measured, stated in every report

| Case | What happens (seen unless marked) |
|---|---|
| `a and b`, `x if c else y`, a comprehension's filter | One line: no branch for each side |
| A loop or comprehension that runs zero times | Not required: a loop passed that never ran zero times |
| A function whose body is only a docstring | Counted as run though never called |
| Code run in a child process | Not measured (unverified here; the script turns no subprocess support on) |
| Anything outside the `--source` folders | Not measured |
| Tests hidden by `collect_ignore` in a `conftest.py` | Not detected (unverified) |
| Assertions | Coverage never shows that a test would notice a fault; `python-mutation-test` addresses that |

## Gaps and "no result"

For each gap, add the behaviour case it reveals, with its assertion, or delete dead code. For a no result, quote the message and give the two remedies: **change the code or tests so the run measures it**, or **list an exception** (path, reason) for the product owner, pending and blocking until approved. A pass on the rest is not a remedy.
