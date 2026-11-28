# Suite Lines, the Release Lines, Make Targets and the Workflow (Python)

Self-contained. Add these when the experiments are set up. `go-e2e-test` owns the throwaway cluster and its script for every stack (`python-e2e-test` keeps the same program as `tests/e2e/run-e2e-environment.sh`); the script installs every line of `E2E_RELEASES` into one namespace, runs each line of `E2E_SUITES` with `E2E_RUN_ID`, `E2E_KUBECONFIG`, `E2E_RESULTS_DIR` and `E2E_ADDR_<NAME>`, and always deletes the cluster. Chaos uses that script unchanged, through its own configuration, so a chaos run gets its own cluster. How Chaos Mesh fits that contract (one more release line, privileged daemon, containerd settings): `./chaos-mesh-manifests.md` and `../references/chaos-mesh-on-kind.md`.

**What was run for Python, and what was not.** The runner's `pytest` and `toxiproxy` tools were run end to end on 2026-11-28 against the lab product and a real Toxiproxy v2.13.0 on loopback, with the run marker served by a stand-in `kubectl` (`../examples/02-standard-bike-share-docks.md`). The kind cluster, the release lines and Chaos Mesh were run by `go-chaos-test` with this same script and runner; **a kind run with a Python image, the Python suite line and a Chaos Mesh fault was not run for this skill (unverified)**.

## Files to put in the product

| File | From | Change |
|---|---|---|
| `tests/chaos/run-chaos-experiment.sh` | `../scripts/run-chaos-experiment.sh` | Nothing. A product with Go and Python services keeps one copy: the program is the same in both skills |
| `tests/chaos/validate-python-chaos-tests.sh` | `../scripts/validate-python-chaos-tests.sh` | Nothing |
| `tests/chaos/conftest.py`, `tests/chaos/support/` | `./chaos-support.md` | Only the ASGI module name in `stall_app.py` |
| `tests/chaos/experiments/*.json` | `./experiment-definition.md` | One per hypothesis |
| `tests/chaos/charts/toxiproxy/`, `tests/chaos/values/` | `./toxiproxy-setup.md` | The proxies and the product's values |
| `tests/chaos/mesh/*.yaml`, `tests/chaos/chaos-mesh-values.yaml` | `./chaos-mesh-manifests.md` | Names, namespace and labels |
| `.gitignore` | Add `chaos-evidence/` | |

No new dependency: the suite uses pytest, pytest-asyncio and httpx, which the product's `dev` group already pins (`python-makefile`). The breaker and retry libraries are the product's own choice, never added for the test.

### `tests/chaos/chaos-e2e.conf`

```bash
# tests/chaos/chaos-e2e.conf: the chaos run. Same throwaway cluster as `make e2e`, with Toxiproxy
# between the docks service and the stations service, and Chaos Mesh 2.8.8 installed into this cluster only.
. tests/e2e/e2e.conf
E2E_RELEASES="
stations|charts/stations|tests/chaos/values/stations.yaml
toxiproxy|tests/chaos/charts/toxiproxy|tests/chaos/charts/toxiproxy/values.yaml
docks|charts/docks|tests/chaos/values/docks.yaml
chaos-mesh|tests/chaos/charts/chaos-mesh-2.8.8.tgz|tests/chaos/chaos-mesh-values.yaml
"
E2E_ENDPOINTS="
api|30080
toxiproxy|30474
"
. tests/chaos/chaos-suites.conf
E2E_SUITES="$CHAOS_SUITES"
```

### `tests/chaos/chaos-suites.conf`

One line per experiment; the in-process patterns first, cluster faults last. `uv run` puts the product's own environment first on the `PATH`, which is where the `pytest` experiment's `python -m pytest` finds pytest. Each line's exit status is its verdict; the environment script counts any non-zero line as failed and still deletes the cluster.
```bash
CHAOS_SUITES="
uv run ./tests/chaos/run-chaos-experiment.sh --experiment tests/chaos/experiments/patterns-in-process.json
uv run ./tests/chaos/run-chaos-experiment.sh --experiment tests/chaos/experiments/degrade-on-stations-latency.json
uv run ./tests/chaos/run-chaos-experiment.sh --experiment tests/chaos/experiments/pod-kill-docks.json
"
```

A product with Go and Python services: one `chaos-e2e.conf`, one runner copy, and both kinds of line in `CHAOS_SUITES` (a `go-test` experiment and a `pytest` experiment), one cluster, one evidence folder.

### `Makefile`

None of these is a prerequisite of `ci`. `make test` already leaves the suite out (`--skip-suite chaos` in `python-makefile`'s coverage-gate line); `chaos-chart` fetches the pinned chart once and checks its SHA-256 against the digest the project's chart index publishes for 2.8.8.
```makefile
.PHONY: chaos chaos-chart chaos-verify chaos-validate

CHAOS_MESH_CHART := tests/chaos/charts/chaos-mesh-2.8.8.tgz
CHAOS_MESH_SHA256 := 35f3caded3d33428d0864eb6d6ece97a5d859a1c0a6e49020fb4d07dd3676bdf

chaos: chaos-chart ## Every experiment, in its own throwaway kind cluster. Never part of `make ci` or a pull request
	./tests/e2e/run-e2e-environment.sh --config tests/chaos/chaos-e2e.conf

chaos-chart: ## The pinned Chaos Mesh chart, checked against the digest in the project's chart index
	@[ -f $(CHAOS_MESH_CHART) ] || helm pull chaos-mesh --repo https://charts.chaos-mesh.org --version 2.8.8 -d tests/chaos/charts
	@python3 -c 'import hashlib, sys; d = hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest(); sys.exit(0 if d == sys.argv[2] else "chart digest " + d + " is not the pinned one")' $(CHAOS_MESH_CHART) $(CHAOS_MESH_SHA256)

chaos-verify: ## One Toxiproxy experiment on another system, only under a signed statement: make chaos-verify EXPERIMENT=... STATEMENT=...
	./tests/chaos/run-chaos-experiment.sh --experiment $(EXPERIMENT) --statement $(STATEMENT)

chaos-validate: ## Text checks on the experiments and what runs them
	./tests/chaos/validate-python-chaos-tests.sh .
```

| Target | Who calls it | Notes |
|---|---|---|
| `chaos` | The nightly workflow; a person | Needs Docker, kind v0.33.0, Helm 4, kubectl and uv |
| `chaos-chart` | `chaos` | Refuses a chart whose digest differs |
| `chaos-verify` | A person, inside a signed statement's window | Toxiproxy faults only; refused without the signed statement |
| `chaos-validate` | Before hand-off; in `make ci` if wanted, since it runs nothing | |

### `.github/workflows/chaos.yml`

Nightly and by hand, never on a pull request; one run, no retry step, no `continue-on-error`; the evidence is uploaded whatever the outcome. **Not run on GitHub Actions** (unverified).
```yaml
name: chaos
# Chaos experiments in a throwaway kind cluster, nightly and by hand. Never on a pull request.
on:
  schedule:
    - cron: "30 2 * * *"
  workflow_dispatch:
permissions:
  contents: read
concurrency:
  group: chaos-${{ github.ref }}
  cancel-in-progress: false
jobs:
  chaos:
    runs-on: ubuntu-24.04
    timeout-minutes: 60
    env:
      E2E_EVIDENCE_DIR: chaos-evidence
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v4
      - run: uv sync --frozen
      - uses: azure/setup-helm@v4
        with:
          version: v4.3.2
      - name: kind
        run: |
          curl -fsSLo kind https://github.com/kubernetes-sigs/kind/releases/download/v0.33.0/kind-linux-amd64
          echo "$(curl -fsSL https://github.com/kubernetes-sigs/kind/releases/download/v0.33.0/kind-linux-amd64.sha256sum | cut -d' ' -f1)  kind" | sha256sum -c
          chmod +x kind && sudo mv kind /usr/local/bin/kind
      - name: Chaos experiments (one run, no retry)
        run: make chaos
      - name: Evidence
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: chaos-evidence-${{ github.run_id }}-${{ github.run_attempt }}
          path: chaos-evidence
          retention-days: 14
```
