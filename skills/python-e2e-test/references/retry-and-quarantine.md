# Retry and Quarantine: the pytest Mechanics

Self-contained. Read when a Python journey fails intermittently, when wiring the suite's verdict, or when reviewing how a pipeline re-runs tests. **The policy is owned by `test-pyramid`**: one automatic retry at the end-to-end layer and none below it; a retried pass is flaky, not green; non-blocking quarantine with an issue and a deadline; deletion only with a record. This file holds only how pytest makes that real. Everything was run with pytest 9.2.0 through `../scripts/run-python-e2e-suite.sh`.

## One command per selection

| Command | Runs |
|---|---|
| `tests/e2e/run-python-e2e-suite.sh journeys` | `python3 -m pytest tests/e2e/journeys -m "e2e and not smoke" -o addopts= -p no:rerunfailures -p no:flaky -p no:cacheprovider -v --junitxml=...`, minus the quarantined tests |
| `tests/e2e/run-python-e2e-suite.sh smoke` | The same on `tests/e2e/smoke` with `-m smoke` |
| `tests/e2e/run-python-e2e-suite.sh quarantine` | The journeys folder, only the quarantined tests |

- `python3` is the first one on the `PATH`: start the runner with `uv run` so that it is the product's environment (`E2E_PYTHON` names another).
- `-o addopts=` and a cleared `PYTEST_ADDOPTS`: nothing in the product's settings can narrow the selection or add retries.
- The runner hands pytest a small plugin of its own, which applies the quarantine list and the retry selection by **exact node id** and records each test's outcome. The verdict comes from those records, not from pytest's exit status.
- `E2E_PY_TIMEOUT` (default 1200 seconds) bounds one pytest process. At the limit pytest is interrupted, runs teardown and writes its report; no test is retried after that.

## Why the verdict is not pytest's exit status

Run with pytest 9.2.0:

| Situation | pytest exits | The runner exits |
|---|---|---|
| Every test deselected (`-m`, `-k`, `--deselect`), or nothing collected | 5 | 3 |
| **Every selected test skipped** | **0** | 3 |
| A usage error: an unregistered marker under strict markers, a test outside the two folders | 4 | 1 (the run broke; the runner's side with a stand-in for pytest) |
| A test failed, then passed on a rerun by `pytest-rerunfailures` (`--reruns 1`) | **0** | Not applicable: the plugin is switched off |

## The retry

The runner takes the tests that failed in the first run (in setup, in the test, or in teardown) and runs exactly those once more, by node id, in a **new pytest process**.

| First run | Second run | Verdict | Exit |
|---|---|---|---|
| All pass | none | Passed | 0 |
| A test fails | It passes | **Flaky**: printed as `FLAKY ... Not green`, written to `results/python-journeys-summary.json` with the trace id of the failed attempt | 0 |
| A test fails | It fails | Failed | 1 |
| The guard refuses, a collection or usage error, an interrupt, the time limit | none | The run broke; nothing is retried | 1 |
| No test ran, or all were skipped | none | The selection proves nothing | 3 |

Run in the cluster: a test made to fail only on its first attempt was reported `FLAKY` and the run passed; a test that always fails was retried once and failed the run; there is no third attempt.

**Why not `pytest-rerunfailures`.** It was run (16.7 with pytest 9.2.0; it works) and it is one way to get a single rerun: `--reruns 1`. Alone it does not meet the policy:

- A test that passes on its rerun makes pytest exit 0, and the JUnit file shows it as an ordinary pass: no trace of the first failure (run: `failures="0"`, the word "rerun" absent). Only the terminal line `1 rerun` and `-rR` show it.
- `--fail-on-flaky` turns that into exit 7, which makes a flaky test red, not "reported and passed".
- Only function-scoped fixtures ran again on the rerun; session and module fixtures were reused (run). A new process repeats the guard and takes a new trace id.
- The earlier `--only-rerun ""` did not narrow anything: an empty pattern matches every failure (run: an assertion failure was rerun).
- A `--reruns` setting in `addopts` applies to unit and integration tests too, where `test-pyramid` and `python-integration-test` allow no retry. With the plugin switched off by the runner, `--reruns` is a usage error and `@pytest.mark.flaky` is an unknown marker (run: exit 4 and exit 2).

A product that keeps the plugin installed for another reason loses nothing: the runner turns it off for its own runs. Retries exist in the end-to-end runner and nowhere else.

A flaky result is a finding. Record it in the test report with its trace id; on the second flake across recent runs, quarantine the test (`test-pyramid`).

## Quarantine

`tests/e2e/quarantine-python.txt`, one line per test:

```text
# node id | issue URL | deadline (two weeks from quarantine unless the strategy says otherwise)
tests/e2e/journeys/test_journey_loan.py::test_journey_bulk_import_is_scheduled | https://github.com/<owner>/<repo>/issues/231 | 2026-12-12
```

Quarantine is a list file, not a marker (product owner's decision of 2026-11-28): a marker carries no issue and no deadline, and nothing can enforce them.

| Rule of the policy | Mechanism | Run |
|---|---|---|
| Out of the blocking run | `journeys` deselects the listed node ids and prints each as `QUARANTINED ... left out here, proves nothing` | In the cluster |
| Still runs, without blocking | `quarantine` runs only those tests, prints each result as "not blocking, and not counted as passed", exits 0 whether they pass or fail | In the cluster |
| An issue and a deadline, in the same change | A line without all three fields is refused before anything runs (exit 2) | Yes |
| Red at the deadline | From the day after the deadline, `journeys` and `quarantine` exit 1 until the test is restored or removed with a record | In the cluster |
| No silent rot | A quarantined node id that matches no test makes the quarantine run fail | With a stand-in for pytest |

The test's code does not move or change, so restoring it is deleting one line. A parametrized case is listed by its full node id (`...::test_name[case]`).

**A product with Go journeys too** keeps two lists: `tests/e2e/quarantine.txt` holds Go test names (`go-e2e-test`) and `tests/e2e/quarantine-python.txt` holds pytest node ids. Run: the Go runner refuses a line with a node id, and this runner refuses a line with a Go test name, both with exit 2, so one shared file stops both. The runners also read different variables (`E2E_QUARANTINE_FILE`; `E2E_PY_QUARANTINE_FILE`).

The issue says: the test, the runs and trace ids of each flake, what is unproven while it is out (which `AC-US-n.m`), the suspected cause (timing, shared data, order, resources), and the deadline. Before the deadline: fix the cause and delete the line; or delete the test with a record of what proves the behaviour now. A growing list points at the environment, the waits or the test data, not at the tests one by one.

Never: `pytest.skip`, a `skip` or `xfail` marker, a `flaky` or `quarantine` marker, a retry loop inside a test, a second automatic retry, or re-running the workflow until it is green.
