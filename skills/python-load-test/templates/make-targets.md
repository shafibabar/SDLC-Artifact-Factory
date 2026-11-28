# Make Targets and the Suite Lines for a Python Product

Self-contained. Add these when a Python product's load tests are set up. `python-makefile` owns the Makefile and its rule that CI calls make targets and nothing else; it defines no load target today, so these are the lines to add. The runner, the profile check and the validator run with the system `python3 -I` and import nothing from the product, so no line needs `uv run`. Run for this skill on 2026-11-28 (GNU Make 3.81, macOS arm64, k6 v2.4.0): `make load-validate` and `make load-verdict` as written against a lab FastAPI service under a lab designation (PASS, exit 0); `make load-verdict` stopped at `load-validate` (exit 2) when the profile's limiter had not been multiplied by the processes. `make load-indicative` was **not** run for a Python product: it starts the end-to-end script, which needs a kind cluster and the product's charts (see the last section).

None of these is a prerequisite of `ci`. A load test never runs in `make ci` or on a pull request; `load-validate` runs no load and may be added to `ci`.

### `Makefile`

```makefile
.PHONY: load-indicative load-verdict load-verdict-one load-verify load-validate

# Test subjects for every run: enough that each stays within ONE process's rate (check-python-profile.sh names the least).
export LOAD_SUBJECT_COUNT ?= 5
LOAD_RUN := ./tests/load/run-load-test.sh --subjects-cmd ./tests/load/issue-subjects.sh
LOAD_VERDICT := $(LOAD_RUN) --tier verdict --designation tests/load/designation.json

load-indicative: load-validate ## The indicative load check alone, in its own throwaway cluster. Nightly it runs inside `make e2e`. Never part of `make ci`
	./tests/e2e/run-e2e-environment.sh --config tests/load/load-e2e.conf

load-verdict: load-validate ## Verdict against the stated targets, in the designated performance environment only. The first failure stops it
	$(LOAD_VERDICT) --type smoke
	$(LOAD_VERDICT) --type average-load
	$(LOAD_VERDICT) --type overload

load-verdict-one: load-validate ## One test type in the designated environment: make load-verdict-one TYPE=soak
	$(LOAD_VERDICT) --type $(TYPE)

load-verify: load-validate ## Verification on another system, only under a signed impact statement: make load-verify STATEMENT=tests/load/statements/<id>.json TYPE=smoke
	$(LOAD_RUN) --tier verdict --statement $(STATEMENT) --type $(TYPE)

load-validate: ## Text checks on the load tests, and the Python profile check (workers, replicas, per-process limiter). Runs no load
	./tests/load/validate-python-load-tests.sh .
	./tests/load/check-python-profile.sh tests/load/profile.json --subjects $(LOAD_SUBJECT_COUNT)
```

| Target | Who calls it | Notes |
|---|---|---|
| `load-indicative` | A developer; the nightly run does the same lines inside `make e2e` | Needs Docker, kind, Helm 4, kubectl and k6 v2.4.0 |
| `load-verdict` | The release workflow, or a person, before a release | Needs the designation record and `LOAD_TOKEN_CMD`. Smoke first: a broken script stops the run in seconds |
| `load-verdict-one` | A person, for stress, soak, spike or breakpoint | Each must be listed in the designation record |
| `load-verify` | A person, by hand, inside the statement's window | Load on any system other than the throwaway cluster or the designated environment, for verification only. The runner refuses without the product owner's signed impact statement for that exact address, and refuses a run that would exceed it. The result is not a capacity verdict |
| `load-validate` | Every other target first; before hand-off | Copy `validate-python-load-tests.sh` and `check-python-profile.sh` next to the runner |

No line ends in `|| true`, starts with `-`, or pipes the runner into another command: each would replace the exit status that says a threshold was crossed.

In a product with Go and Python services there is one `tests/load/` folder, one set of these targets and one copy of each script; `go-load-test`'s `validate-go-load-tests.sh` and this skill's `validate-python-load-tests.sh` are the same program, so keep one. Keep `check-python-profile.sh` whenever any service under load is a Python one.

## How the indicative tier attaches to the end-to-end environment

`go-e2e-test` owns the throwaway cluster and the script that creates it; `python-e2e-test` carries the same script for a Python product (`tests/e2e/run-e2e-environment.sh`). It runs each line of `E2E_SUITES` once every release is ready, hands it `E2E_RUN_ID`, `E2E_KUBECONFIG` and `E2E_RESULTS_DIR`, counts a non-zero exit as a failed suite, and deletes the cluster afterwards. The indicative tier is three more lines of that list.

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

In `tests/e2e/e2e.conf` (`python-e2e-test`'s `environment-config` template), source that file on the first line and put `$LOAD_INDICATIVE_SUITES` last in `E2E_SUITES`, after the journeys and the smoke tests, so load never runs beside a journey:

```text
. tests/load/indicative-suites.conf
...
E2E_SUITES="
uv run ./tests/e2e/run-python-e2e-suite.sh journeys
uv run ./tests/e2e/run-python-e2e-suite.sh smoke
uv run ./tests/e2e/run-python-e2e-suite.sh quarantine
$LOAD_INDICATIVE_SUITES
"
```

### `tests/load/load-e2e.conf`

```bash
# tests/load/load-e2e.conf: the same throwaway cluster as `make e2e`, running only the load lines.
. tests/e2e/e2e.conf
E2E_SUITES="$LOAD_INDICATIVE_SUITES"
```

The values file of the product's chart in that cluster (`tests/e2e/values/<release>.yaml`) sets the **same workers and replicas** as the profile's `server` block. `environment-config` lets sizing differ in a test environment, but the overload check's ceiling is computed from those two numbers; a cluster with fewer processes than the profile says passes an overload check it should fail.

What the runner does with what the end-to-end script hands it: it takes no address from the caller, reads the run marker through `E2E_KUBECONFIG` and context `kind-e2e-<run id>`, requires the marker's run id to be this run's, the API server to be on loopback and the endpoint to be `127.0.0.1:<port>`, waits by polling until the service answers, and writes `<type>-result.json` and the k6 summary under `$E2E_RESULTS_DIR/load/`.

**Not run for a Python product.** These three lines are byte for byte the ones `go-load-test` ran inside real throwaway clusters with the unmodified end-to-end script, and that script is the one `python-e2e-test` ran with Python suites; the runner is the same program. For this skill the indicative lines were run with real k6 against the FastAPI lab service, with a stand-in `kubectl` serving the run marker (`../examples/01-lean-seed-library.md`). The whole chain, a FastAPI chart in a kind cluster with the load lines last, is unverified.
