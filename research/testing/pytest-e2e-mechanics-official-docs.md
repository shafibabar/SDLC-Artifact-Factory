# pytest End-to-End Mechanics: Official Documentation
**Authors:** The pytest project (pytest-dev/pytest); pytest-rerunfailures maintainers (pytest-dev/pytest-rerunfailures); pytest-timeout maintainers (pytest-dev/pytest-timeout)
**Domain:** Testing (end-to-end, selection, rerun, reporting, Python)

Accessed 2026-11-28. pytest latest 9.2.0, 2026-10-27, MIT, Python >=3.10 (https://pypi.org/pypi/pytest/9.2.0/json); doc pages are `stable`, source read at tag `9.2.0`. pytest-rerunfailures latest 16.7, 2026-09-17, MPL-2.0, Python >=3.10, requires `pytest>=8.2,!=8.2.2` (https://pypi.org/pypi/pytest-rerunfailures/json); read at tag `16.7`. pytest-timeout latest 2.4.0, 2025-05-05, MIT, Python >=3.7, requires `pytest>=7.0.0`; a 2.5.0 exists but is yanked (https://pypi.org/pypi/pytest-timeout/json); read at tag `2.4.0`. This note adds to `pytest-official-docs.md` and does not repeat it.

Sources:
- [P] https://raw.githubusercontent.com/pytest-dev/pytest/9.2.0/src/_pytest (files `main.py`, `outcomes.py`, `junitxml.py`, `hookspec.py`, `cacheprovider.py`, `faulthandler.py`, `runner.py`)
- [EX] https://docs.pytest.org/en/stable/reference/exit-codes.html
- [MK] https://docs.pytest.org/en/stable/example/markers.html
- [US] https://docs.pytest.org/en/stable/how-to/usage.html
- [PC] https://docs.pytest.org/en/stable/example/pythoncollection.html
- [CA] https://docs.pytest.org/en/stable/how-to/cache.html
- [OUT] https://docs.pytest.org/en/stable/how-to/output.html
- [FX] https://docs.pytest.org/en/stable/how-to/fixtures.html
- [CU] https://docs.pytest.org/en/stable/reference/customize.html
- [RR] https://raw.githubusercontent.com/pytest-dev/pytest-rerunfailures/16.7/README.rst
- [RS] https://raw.githubusercontent.com/pytest-dev/pytest-rerunfailures/16.7/src/pytest_rerunfailures.py
- [RC] https://raw.githubusercontent.com/pytest-dev/pytest-rerunfailures/16.7/CHANGES.rst
- [TO] https://raw.githubusercontent.com/pytest-dev/pytest-timeout/2.4.0/README.rst

## Core Concepts

**Collection and selection**
- Node ids: `module.py::function`, `module.py::Class::method`; a parametrized case needs its id, `module.py::function[param]` [MK] [US]. Node ids are rooted at the rootdir [CU].
- `--deselect` is repeatable and its value is a node id **prefix**: help text "Deselect item (via node id prefix) during collection (multi-allowed)"; the code tests `colitem.nodeid.startswith(prefixes)` [P main.py] [PC]. A class or file prefix therefore deselects everything under it.
- `--ignore` (path) and `--ignore-glob` (pattern) are repeatable and skip collection of the path altogether [PC]. `-k` is a case-insensitive substring match on names and marker names; `-m` matches markers exactly [MK] [US].
- Arguments can be read from a file with an `@file` prefix, one argument per line (added in 8.2) [US].
- `pytest_collection_modifyitems(session, config, items)` "May filter or re-order the items in-place"; an implementation that removes items must call `config.hook.pytest_deselected(items=...)` so other plugins are told [P hookspec.py].
- Deselected tests are counted in the header ("collected 4 items / 3 deselected / 1 selected") and the last line ("1 passed, 3 deselected") [MK].
- Exit codes 0 to 5 are as listed in the existing note [EX]. Code 5 is returned when `session.testscollected == 0` and nothing failed; `testscollected` is `len(items)` taken after `pytest_collection_modifyitems` has run [P main.py]. So a run in which every collected test is deselected ends with 5. The exit-codes page itself does not mention deselection [EX].

**Rerunning with the cache plugin**
- `--lf`/`--last-failed`: "Rerun only the tests that failed at the last run (or all if none failed)". `--ff`: run all, failures first. `--cache-clear`: "Remove all cache contents at start of test run" [P cacheprovider.py] [CA].
- `--lfnf`/`--last-failed-no-failures` takes `all` (default, run everything) or `none` [P cacheprovider.py]. With `none` the plugin passes every item to `pytest_deselected` and empties the list [P cacheprovider.py].
- The cache is the `cache_dir` setting, default `.pytest_cache` in the rootdir [P cacheprovider.py] [CU]. The plugin is named `cacheprovider`; plugins are disabled with `-p no:<name>` [CA] [US].

**pytest-rerunfailures 16.7**
- Supports pytest 9: "Add support for pytest 9.0" in 16.2 and "Add support for pytest 9.1" in 16.4; minimum pytest is 8.2 [RC]. Support for 9.2 by name is not stated in the official documentation.
- `--reruns N`; `--reruns-delay <seconds>`; `--reruns-delay-backoff-factor` (default 1.0); `--max-suite-reruns`; `--rerun-exclude-path` [RR] [RS].
- `--only-rerun <regex>` and `--rerun-except <regex>` are repeatable. The pattern is applied with `re.search` to the string `f"{type(exc).__name__}: {exc}"`; `--only-rerun` also walks `__cause__` and `__context__`, `--rerun-except` only `__cause__` [RS] [RR].
- An empty pattern is not stated in the README. In source an empty list means "not configured", and an empty string is not special-cased, so `re.search("", err)` matches every failure [RS].
- Marker: `@pytest.mark.flaky(reruns=5, reruns_delay=2)`, also `condition`, `only_rerun`, `rerun_except`. Priority is marker, then command line, then ini (`reruns`, `only_rerun`, `rerun_except`); `--force-reruns` overrides all [RR].
- Reporting: each retried attempt has outcome `rerun`, letter `R`, word `RERUN`; the last line counts them ("1 failed, 2 rerun"), and `-rR` adds a "rerun test summary info" section [RS] [RR]. "Tests that fail on all the re-runs will be marked as failed" [RR].
- Exit code: the README does not mention it. A test that passes on a rerun is a pass to pytest, so the run exits 0 unless `--fail-on-flaky` is given: "Fail the test run with exit code 7 if a flaky test passes on a rerun" [RS] [RC].
- Fixtures: "Failed fixture or setup_class will also be re-executed" [RR]. Source clears cached results "for only failed fixtures" and removes setup state for "only the current item, not higher-scoped items" [RS]. Which successful class, module or session fixtures run again is not stated in the README.
- Incompatible with pytest-xdist `--looponfail`, core `--pdb` (raises a usage error) and the `flaky` plugin [RR] [RS]. A crashed test is rerun only under pytest-xdist 2.3.0+ with `-n` [RR].

**Reporting**
- `--junit-xml=path` (also `--junitxml`) writes the report [OUT] [P junitxml.py]. `junit_family` defaults to `xunit2`; values `legacy`, `xunit1`, `xunit2`. `junit_suite_name` defaults to `pytest`. `junit_logging` defaults to `no`; values `no`, `log`, `system-out`, `system-err`, `out-err`, `all` [P junitxml.py].
- `record_property` adds a property to the test case but warns that it "is incompatible with junit_family 'xunit2'" [P junitxml.py]. `record_testsuite_property` is session-scoped, writes a `<property>` under the root `<testsuite>`, is compatible with xunit2, and "does not work" with pytest-xdist [OUT] [P junitxml.py].
- A skipped test is a `<skipped type="pytest.skip" message="...">` child; a call failure is `<failure>`, a setup or teardown failure is `<error>`; the suite carries `errors`, `failures`, `skipped`, `tests`, `time`, `timestamp`, `hostname` [P junitxml.py].
- pytest's JUnit writer has no handling of a rerun outcome, and the rerunfailures README and changelog do not mention JUnit XML [P junitxml.py] [RR] [RC].
- `-r` chars: `f`, `E`, `s`, `x`, `X`, `p`, `P`, `a` (all except passes), `A` (all), `N` (none); default `fE` [OUT]. `--durations=N` shows the N slowest setup/test durations, 0 for all [P runner.py].

**Timeouts**
- pytest-timeout: `--timeout=<seconds>`, ini `timeout`, env `PYTEST_TIMEOUT`, marker `@pytest.mark.timeout(300)`; the timeout covers fixtures unless `timeout_func_only` or `func_only=True` [TO].
- Method `signal` (default where SIGALRM exists): dumps other threads' stacks and uses `pytest.fail()`; the run continues. Method `thread`: prints stacks and ends the process with `os._exit()`, so "no teardown, JUnit XML output etc." [TO].
- `--session-timeout=<seconds>` (ini `session_timeout`, added in 2.3.0) is checked "at the end of each test function"; it stops further tests and does not interrupt a running one [TO].
- pytest's own `faulthandler_timeout` only dumps tracebacks of all threads; the process exits only with `faulthandler_exit_on_timeout` (default false) [P faulthandler.py].

**Fixtures and aborting the session**
- Scopes `function`, `class`, `module`, `package`, `session`; teardown after `yield` runs in reverse order; finalizers are first-in-last-out; if a fixture raises before `yield`, its own teardown does not run but earlier fixtures are still torn down [FX].
- `pytest.exit(reason, returncode=None)` raises `pytest.exit.Exception`, "Raised for immediate program exits (no tracebacks/summaries)" [P outcomes.py]. The session wrapper catches it, uses `returncode` when given (otherwise 2), and prints the reason to stderr when raised in `pytest_configure` or `pytest_sessionstart`, before collection [P main.py].
- `pytest.fail(reason, pytrace=True)` is documented to "fail an executing test" [P outcomes.py]. Its effect in a session fixture is not stated in the official documentation.

**Configuration**
- `testpaths`: "Directories to search for tests when no files or directories are given on the command line" [P main.py]. Naming a directory on the command line therefore runs it even when it is outside `testpaths`.
- `norecursedirs` default: `*.egg`, `.*`, `_darcs`, `build`, `CVS`, `dist`, `node_modules`, `venv`, `{arch}` [P main.py].
- `-c FILE` loads that file and makes its directory the rootdir; `--rootdir` cannot be put in `addopts` [CU]. `--strict-markers` "Enables the strict_markers option"; markers are registered in the `markers` list [P main.py] [MK].

## Actionable Techniques (design is this note's)

- Retry a journey once with `--reruns 1` and add `--fail-on-flaky`, so a pass on rerun ends the run with exit 7 instead of 0; show `-rR` in the log.
- Keep quarantined node ids in a list file and deselect them in `pytest_collection_modifyitems`, calling `pytest_deselected`; use full node ids because `--deselect` matches prefixes.
- Treat exit 5 as failure in the pipeline; a selection that deselects everything produces it.
- Check the target in `pytest_sessionstart` (or a session autouse fixture) and call `pytest.exit(reason, returncode=<chosen>)`.
- Use the `signal` timeout method where a report is needed; `thread` loses the JUnit file.

## Applies To

| Skill/Agent | Gap | What the docs add |
|---|---|---|
| python-e2e-test | A failed journey is retried exactly once and reported as flaky, never as green | `--reruns 1`, the `R`/"rerun" count, exit 0 by default, `--fail-on-flaky` exit 7 |
| python-e2e-test | Quarantined tests are named in a list file with an issue and a deadline | Hook plus `pytest_deselected`, `@file` arguments, prefix matching of `--deselect`; issue and deadline fields are the suite's own |
| python-e2e-test | A selection that runs no test must fail | Exit 5 follows the item count after deselection |
| python-e2e-test | The suite must refuse to start when its target is not its own run's cluster | `pytest.exit(reason, returncode)` before collection |
| python-e2e-test | A test report for the product owner | JUnit options and defaults, suite properties, `-r` flags, durations |

## Candidate New Skills/Agents

None.

## Key Terminology

Node Id, Deselection, Rerun, Flaky Marker, Session Timeout, JUnit Family.

## Caveats

- Nothing was run. No package was installed; behaviour is read from documentation and from source at the tags above.
- Not stated in the official documentation: how a rerun attempt, or a test that passed on rerun, appears in JUnit XML.
- Not stated: the exit code after a pytest-timeout session timeout ("will results in a test failure" is all the README says), and what an empty `--only-rerun` pattern does (source reading only).
- Not stated: which successfully set-up class, module or session fixtures are re-executed on a rerun.
- Unresolved: `--lfnf none` is documented as "exits successfully", yet it empties the item list, which by the exit-code logic would give 5. Confirm by a run.
- The exit-5-when-all-deselected and `pytest.exit`-before-collection behaviours come from source, not a documentation page.
- pytest-timeout's README states "Python 3.6 and higher" while its PyPI metadata says >=3.7; compatibility with pytest 9 is not stated.
