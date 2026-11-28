# The Verdict, the Record and the Scope

Self-contained. Read when judging a run, writing a record line, asking for a waiver, deciding what is in scope, or explaining how the mutation gate relates to the coverage gate. The rule is the product owner's (decision D048 and its follow-ups of 2026-11-25 and 2026-11-28); `test-pyramid` states it for every language; this file says how a Python run meets it. `check-python-mutation.sh` applies all of it.

## The rule

- **Every planted mutant is killed by a test, or recorded individually with the reason it cannot be**: the change does not alter behaviour. This replaced the earlier 60% target, which is rejected; so is any other percentage target.
- **Timed-out and type-checker-rejected mutants** count as caught only once each is checked and recorded with a one-line reason; never automatically. A timed-out mutant that a test kills when rerun with a longer limit counts as killed (product owner, 2026-11-28).
- **Result = (killed + individually recorded) / all planted mutants**, as counts. mutmut's summary line, `export-cicd-stats` and badge are not used (`./mutmut-3.8.1.md`).
- **100% passes.** **More than 90% and under 100%** fails unless the product owner reviews every mutant not caught and waives the gap with recorded comments; **90% or below has no waiver**. Computed from counts: waivable only if `caught x 10 > planted x 9`. Line coverage, branch coverage and the mutation result are each judged separately. A waiver covers one result, these counts for this source id; any change to the code, tests, `pyproject.toml`, `uv.lock` or the record needs a new review, and so does the next release.

## How each mutant is classified

| mutmut status | Runner's recheck (timeout_multiplier 60) | Counts as | What to do |
|---|---|---|---|
| killed | (none) | Killed | Nothing |
| timeout | killed | Killed | Nothing: it was slow, not endless |
| timeout | survived | Not caught until killed, or recorded `equivalent` | As for survived |
| timeout | timeout again | Not caught until recorded `timeout` | Check the mutated code really never finishes, record it |
| survived | (none) | Not caught until killed, or recorded `equivalent` | Triage: write the test, or prove no input can tell it apart |
| caught by type check | (none) | Not caught until recorded `not-viable` | Read the type checker's message, record it |
| no tests | (none) | Not caught; **never recordable** | A test that reaches the function, or an approved exclusion |
| not checked, skipped, suspicious, segfault, check was interrupted by user | (none) | No result: the run is INVALID | Fix the cause (a crash, a flaky or interrupted run) and run again |

A record line matches a mutant by name and the fingerprint of its `mutmut show` diff; when only the number changed within the same function, it still matches and the script prints "Renamed". One that matches nothing (the code changed, or a test now kills it) fails the run until it is re-checked or removed: a stale record cannot be waived. A record of the wrong kind (equivalent for a timeout) fails too.

## Verdicts

| Verdict | When | Exit |
|---|---|---|
| PASS | Every planted mutant killed or recorded; or more than 90% with a waiver row naming this run and these counts | 0 |
| WAIVER-NEEDED | More than 90% and under 100%, no matching waiver | 3 |
| FAIL | 90% or below; or a stale or wrong record line | 1 |
| INVALID | No `run.txt` (the run did not finish), missing or empty results, a run of another commit, mutmut's run not exiting 0, a changed-code run judged as a release, a no-result status, a timeout without a recheck line, code hidden from mutation without approval, a malformed record, a pending exclusion, nothing planted | 2 |

`--mode scheduled` prints the same verdict but exits 0 unless INVALID: scheduled runs report only, and are never waived.

**The run's identity.** `run.txt` holds the commit and a **source id**: a hash of the tracked `.py` files, `pyproject.toml`, `uv.lock`, `setup.cfg` and `mutation/`. Adding the product owner's waiver row to the report is a commit of its own; the source id does not change, so the release re-run that reads the row matches it (seen: source `7ad8e658ab801cec` before and after the report commit). A waiver row names the source id or the commit, with at least seven hex characters.

## Scope

- **All product code**, at every product size (D048.2 and 2026-11-28): `source_paths = ["src/<pkg>"]`, the whole package in the `python-project-structure` layout. The earlier "domain and service layer only" is withdrawn: `adapters/`, `entrypoints/` and `bootstrap.py` are in scope. A file or folder left out is an **exclusion**: listed in `mutation/exclusions.txt` with a reason, for the product owner's approval; `pending` excludes nothing.
- **Generated code** is left out as the coverage gate leaves it out: a file whose leading comments carry `@generated`, or "generated" with "DO NOT EDIT". The script finds them itself and lists them; a `do_not_mutate` entry for a generated file only saves time.
- **Test support** (`tests/fakes.py`, `tests/conftest.py`, factories) is never mutated: it sits outside `source_paths`. It is the class the product owner approved once (2026-11-27) and the script lists it in every report. Test support only, never code that ships: a helper under `src/` is product code.
- **Hidden lines**: a `# pragma: no mutate` (any form), a `do_not_mutate_patterns` match, `only_mutate`, or `mutate_only_covered_lines` would keep code out of the count. Each needs an approved entry, or the script refuses the run. Equivalent mutants go in the record, never behind a pragma.
- **Never mutated by mutmut** (module-level code, most decorated functions, ...; `./mutmut-3.8.1.md`): stated as a limit in every report. Logic in a decorated route handler is untested by mutation, which is one more reason it belongs in the service layer.

## How the mutation gate relates to the coverage gate

| | Coverage gate (`python-unit-test`) | Mutation (this skill) |
|---|---|---|
| Asks | Did each line run, and each branch go both ways? | Would a test notice if this code changed? |
| Target | 100% of lines and of branches | Every planted mutant killed or recorded |
| Runs | Every `make test`, every pull request | Before each release (blocks); scheduled between releases (reports) |
| Coverage flags | Only on its own command | `--no-cov`: mutmut runs the suite without coverage |

A `no tests` mutant means no test reaches that function at all; with the coverage gate at 100% this happens only for code the coverage gate does not measure (an exception, or a file it never imports). Coverage proves code ran; only an assertion kills a mutant, so 100% coverage with survivors is not a contradiction (the lab's `is_late` ran on every test and still let `>` become `>=`).

## Research grounding

- Khorikov, *Unit Testing* (`research/testing/unit-testing-khorikov.md`): coverage is a gameable indicator; a surviving mutant is a **protection-against-regressions** gap, one of the four pillars, not a general quality score.
- Quigley (`research/testing/testing-vv-dictionary-quigley.md`): use the exact terms (statement, branch) when the two gates are compared.
- pytest's documentation (`research/testing/pytest-official-docs.md`): exit code 5 (no tests collected) is a failure, never a pass; one pytest table, strict settings with a pinned pytest. Okken (`research/testing/python-testing-with-pytest-okken.md`): parametrize rows as the place a missing boundary case goes, and custom markers registered in configuration. mutmut's runs inherit both settings.
