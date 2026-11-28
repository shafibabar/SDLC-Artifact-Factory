# Retry and Quarantine: the Go Mechanics

Self-contained. Read when a journey fails intermittently, when wiring the suite's verdict, or when reviewing how a pipeline re-runs tests. **The policy is owned by `test-pyramid`**: one automatic retry at the end-to-end layer and none below it; a retried pass is flaky, not green; tagged, non-blocking quarantine with an issue and a deadline; deletion only with a record. This file holds only how Go makes that real. Everything was run with Go 1.27.4 through `../scripts/run-go-e2e-suite.sh`.

## One command per selection

| Command | Runs |
|---|---|
| `tests/e2e/run-go-e2e-suite.sh journeys` | `go test -tags e2e -count=1 -timeout 20m -json -run '^Test' [-skip '^(<quarantined>)$'] ./tests/e2e/` |
| `tests/e2e/run-go-e2e-suite.sh smoke [-- -tenant=<id>]` | `go test -tags smoke -count=1 -timeout 20m -json -run '^TestSmoke' ./tests/e2e/` |
| `tests/e2e/run-go-e2e-suite.sh quarantine` | The same as journeys, with `-run '^(<quarantined>)$'` only |

- `-count=1` turns off Go's test result cache: a cached "ok" would report a run that never touched the cluster.
- `-timeout` bounds the whole test binary. When it expires the binary panics; no test is retried after that.
- `-json` gives one event per test, which is how the script knows what ran.

## The retry

The script reads the events of the first run, takes the **top-level** tests that failed and runs exactly those once more with `-run '^(TestA|TestB)$'`.

| First run | Second run | Verdict | Exit |
|---|---|---|---|
| All pass | none | Passed | 0 |
| `TestA` fails | `TestA` passes | **Flaky**: printed as `FLAKY`, written to `results/journeys-summary.json` with the trace id of the failed attempt | 0 |
| `TestA` fails | `TestA` fails | Failed | 1 |
| Build error, a refusal in `TestMain`, a panic, a timeout (non-zero exit and no failed test) | none | The run broke; nothing is retried | 1 |
| No test ran, or all were skipped | none | The selection proves nothing | 3 |

Run: a test made to fail only on its first attempt was reported `FLAKY` and the run passed; a test that always fails was retried once and failed the run; there is no third attempt.

Three traps this avoids, each found in the earlier hand-written rerun (`go test ... || go test -run "$(failed names)"`):

- An empty list of failed names makes `-run ""`, which runs **everything** again. A build failure then looks like a retry.
- A subtest name contains `/`, which `-run` treats as a level separator. The script retries by top-level name.
- `go test` exits 0 with `[no tests to run]` when a pattern matches nothing (run). The script counts tests.

A flaky result is a finding. Record it in the test report with its trace id; on the second flake across recent runs, quarantine the test (`test-pyramid`).

## Quarantine

`tests/e2e/quarantine.txt`, one line per test:

```text
# TestName | issue URL | deadline (two weeks from quarantine unless the strategy says otherwise)
TestJourney_BulkImportIsScheduled | https://github.com/<owner>/<repo>/issues/231 | 2026-12-12
```

| Rule of the policy | Mechanism | Run |
|---|---|---|
| Out of the blocking run | `journeys` passes `-skip '^(<names>)$'` and prints each as `QUARANTINED ... proves nothing` | Yes |
| Still runs, without blocking | `quarantine` runs only those tests, prints each result, exits 0 whether they pass or fail | Yes |
| An issue and a deadline, in the same change | A line without all three fields is refused before anything runs (exit 2) | With a fake `go` |
| Red at the deadline | From the day after the deadline, `journeys` and `quarantine` exit 1 until the test is restored or removed with a record | With a fake `go` |
| No silent rot | A quarantined name that matches no test makes the quarantine run fail | With a fake `go` |

The test's code does not move or change, so restoring it is deleting one line. A file-level build tag would also keep a test out; the list is used here because it carries the issue and the deadline and lets the runner enforce them.

The issue says: the test, the runs and trace ids of each flake, what is unproven while it is out (which `AC-US-n.m`), the suspected cause (timing, shared data, order, resources), and the deadline. Before the deadline: fix the cause and delete the line; or delete the test with a record of what proves the behaviour now. A growing list points at the environment, the waits or the test data, not at the tests one by one.

Never: `t.Skip` in a journey (a deletion with no record), a retry loop inside a test, a second automatic retry, or re-running the workflow until it is green.
