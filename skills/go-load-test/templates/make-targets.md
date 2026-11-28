# Make Targets and the Suite Lines

Self-contained. Add these when the load tests are set up. `go-makefile` owns the Makefile and its rule that CI calls make targets; it defines no load target today. All targets were run as written for this skill (GNU Make 3.81, macOS arm64, k6 v2.4.0, kind v0.33.0, Helm v4.3.2): `make load-verdict` passed in 172 seconds against a lab service and stopped at its first failing line when the service was slowed; `make load-indicative` created a cluster, ran the three lines and deleted it (exit 0; exit 2 when a line failed, with the cluster still deleted).

None of these is a prerequisite of `ci`. A load test never runs in `make ci` or on a pull request.

### `Makefile`

```makefile
.PHONY: load-indicative load-verdict load-verdict-one load-validate

LOAD_RUN := ./tests/load/run-load-test.sh --subjects-cmd ./tests/load/issue-subjects.sh
LOAD_VERDICT := $(LOAD_RUN) --tier verdict --designation tests/load/designation.json

load-indicative: ## The indicative load check alone, in its own throwaway cluster. Nightly it runs inside `make e2e`. Never part of `make ci`
	./tests/e2e/run-e2e-environment.sh --config tests/load/load-e2e.conf

load-verdict: ## Verdict against the stated targets, in the designated performance environment only. The first failure stops it
	$(LOAD_VERDICT) --type smoke
	$(LOAD_VERDICT) --type average-load
	$(LOAD_VERDICT) --type overload

load-verdict-one: ## One test type in the designated environment: make load-verdict-one TYPE=soak
	$(LOAD_VERDICT) --type $(TYPE)

load-validate: ## Text checks on the load tests and what runs them
	./tests/load/validate-go-load-tests.sh .
```

| Target | Who calls it | Notes |
|---|---|---|
| `load-indicative` | A developer; the nightly run does the same lines inside `make e2e` | Needs Docker, kind, Helm 4, kubectl and k6 v2.4.0 |
| `load-verdict` | The release workflow, or a person, before a release | Needs the designation record and `LOAD_TOKEN_CMD`. Smoke first: a broken script stops the run in seconds |
| `load-verdict-one` | A person, for stress, soak, spike or breakpoint | Each must be listed in the designation record |
| `load-validate` | Before hand-off and in `make ci` if wanted: it runs nothing | Copy `validate-go-load-tests.sh` next to the runner |

No line ends in `|| true`, starts with `-`, or pipes the runner into another command: each would replace the exit status that says a threshold was crossed.

## How the indicative tier attaches to the end-to-end environment

`go-e2e-test` owns the throwaway cluster and the script that creates it (`tests/e2e/run-e2e-environment.sh`). That script runs each line of `E2E_SUITES` in the product root once every release is ready, hands it `E2E_RUN_ID`, `E2E_KUBECONFIG` and `E2E_RESULTS_DIR`, counts a non-zero exit as a failed suite, and deletes the cluster afterwards. The indicative tier is three more lines of that list. Nothing else creates a cluster.

### `tests/load/indicative-suites.conf`

```bash
# tests/load/indicative-suites.conf: the load lines of the end-to-end environment run (indicative tier).
# Sourced by tests/e2e/e2e.conf and by tests/load/load-e2e.conf, so the two cannot drift apart.
LOAD_INDICATIVE_SUITES="
./tests/load/run-load-test.sh --tier indicative --type smoke --endpoint api --subjects-cmd ./tests/load/issue-subjects.sh
./tests/load/run-load-test.sh --tier indicative --type average-load --endpoint api --subjects-cmd ./tests/load/issue-subjects.sh --previous load-baseline/average-load-result.json
./tests/load/run-load-test.sh --tier indicative --type overload --endpoint api --subjects-cmd ./tests/load/issue-subjects.sh
"
```

In `tests/e2e/e2e.conf`, source that file on the first line and put `$LOAD_INDICATIVE_SUITES` last in `E2E_SUITES`, after the journeys and the smoke tests, so load never runs beside a journey:

```text
. tests/load/indicative-suites.conf
...
E2E_SUITES="
./tests/e2e/run-go-e2e-suite.sh journeys
./tests/e2e/run-go-e2e-suite.sh smoke
./tests/e2e/run-go-e2e-suite.sh quarantine
$LOAD_INDICATIVE_SUITES
"
```

### `tests/load/load-e2e.conf`

```bash
# tests/load/load-e2e.conf: the same throwaway cluster as `make e2e`, running only the load lines.
. tests/e2e/e2e.conf
E2E_SUITES="$LOAD_INDICATIVE_SUITES"
```

What the runner does with what the script hands it (each run with the unmodified script):

- It takes **no address from the caller**. It reads the run marker (ConfigMap `e2e-run-marker`) through `E2E_KUBECONFIG` and context `kind-e2e-<run id>`, requires the marker's run id to be this run's, the API server to be on loopback and the endpoint to be `127.0.0.1:<port>`, and refuses otherwise.
- It waits, by polling, until the product answers over HTTP. Seen without that wait: the published port accepted connections before the cluster routed them and all ten smoke requests ended in `EOF`.
- It writes `<type>-result.json` and the k6 summary under `$E2E_RESULTS_DIR/load/`, which the end-to-end workflow already uploads.
- `--previous` names the last run's result. Where it comes from on GitHub Actions is in `./workflows.md`. With no file the comparison is reported as absent and the line still passes.

Run: with the profile of `./profile.md` the three lines took about 50 seconds inside a 70-second environment run; a build slowed by 8 ms turned the average-load line red (`p(95) rose 533.9% against the previous run`), the script collected evidence, deleted the cluster and exited 1.
