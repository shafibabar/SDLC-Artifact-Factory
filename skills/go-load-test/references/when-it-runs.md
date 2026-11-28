# When a Load Test Runs

Self-contained. Read when placing load tests in the pipelines, when asked for a load test on a pull request, or when deciding what a release waits for. The workflow is in `../templates/workflows.md` and the make targets in `../templates/make-targets.md`. `test-pyramid` owns the rule for when each suite runs; `ci-pipeline` and `cd-pipeline` own the pipelines. Local behaviour was run on 2026-11-28; nothing was run on GitHub Actions.

| Trigger | Runs | Why |
|---|---|---|
| Pull request | **Never** any load test, not even the smoke script | Slow suites stay out of the pull-request check (`test-pyramid`). The earlier "smoke on every pull request" aimed at staging and is gone. The commit stage stays fast and capacity tests are a later, automated stage (Humble and Farley) |
| Nightly | The indicative tier, as the last lines of `E2E_SUITES` inside `make e2e` | The throwaway cluster already exists then; a red line turns the night's run red and its results are uploaded with the end-to-end evidence |
| By hand | `make load-indicative` (its own throwaway cluster), or `make load-verdict` and `make load-verdict-one TYPE=...` | Checking a fix; stress, soak, spike and breakpoint runs |
| Before a release | `make load-verdict` as a job the publishing job needs | The verdict must be finished before publication. A `release:` trigger fires afterwards and cannot stop anything |
| Scheduled verdict | Optional, where the designated environment is free | A dropped or late scheduled run is not a pass |
| After a deployment to staging or production | **Nothing from this skill** | Those environments get read-only smoke tests (`go-e2e-test`) and their own SLO monitoring |

Rules that hold everywhere:

- **Through a make target.** CI calls `make e2e` or `make load-verdict` and nothing else of the suite (`go-makefile`).
- **Zero retries.** A failed or invalid run stops the job. Re-running is a decision a person takes after reading the result.
- **Exit status untouched.** 1 (FAIL), 3 (REFUSED), 4 (INVALID) and 130 all stop a release.
- **Results kept.** `<type>-result.json` and the k6 summary are uploaded with `if: always()`.
- **A report for evidence.** A run put forward for a release or a phase approval gets a report under `artifacts/<product>/quality/test-reports/` that the product owner approves (`../templates/load-test-report.md`). A green job or a dashboard does not replace it.

A lean product with no approved performance environment has the nightly line and the by-hand target only. Its release waits for the end-to-end run, which contains the indicative lines; the report says no target was verified.
