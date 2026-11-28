# Suite Lines, the Release Lines, Make Targets and the Workflow

Self-contained. Add these when the experiments are set up. `go-e2e-test` owns the throwaway cluster and its script (`tests/e2e/run-e2e-environment.sh`), which installs every line of `E2E_RELEASES` into **one namespace** (`E2E_NAMESPACE`, created by Helm without labels), runs each line of `E2E_SUITES` with `E2E_RUN_ID`, `E2E_KUBECONFIG`, `E2E_RESULTS_DIR` and `E2E_ADDR_<NAME>`, and always deletes the cluster. Chaos uses that script unchanged, through its own configuration, so a chaos run gets its own cluster and never shares one with the journeys.

How Chaos Mesh fits that contract (run 2026-11-28): it is one more release line, installed into the same namespace as the product. Its daemon needs a namespace that admits privileged pods: kind applies no Pod Security labels, so the namespace the script creates admits it (seen: the namespace's only labels were `kubernetes.io/metadata.name` and `name`). On a cluster whose admission defaults to Baseline or Restricted the release would be rejected, and this script cannot label the namespace; that cluster is not a place for Chaos Mesh anyway. The chart's own CRDs are installed with it on the fresh cluster. The containerd settings are in `chaos-mesh-values.yaml` (`./chaos-mesh-manifests.md`).

### `tests/chaos/chaos-e2e.conf`

```bash
# tests/chaos/chaos-e2e.conf: the chaos run. Same throwaway cluster as `make e2e`, with Toxiproxy
# between the product and the tide tables, and Chaos Mesh 2.8.8 installed into this cluster only.
. tests/e2e/e2e.conf
E2E_RELEASES="
tides|deploy/harbour|tests/chaos/values/tides.yaml
toxiproxy|tests/chaos/charts/toxiproxy|tests/chaos/charts/toxiproxy/values.yaml
harbour|deploy/harbour|tests/chaos/values/harbour.yaml
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

One line per experiment; the in-process patterns first, cluster faults last. Each line's exit status is its verdict; the environment script counts any non-zero line as failed and still deletes the cluster.
```bash
CHAOS_SUITES="
./tests/chaos/run-chaos-experiment.sh --experiment tests/chaos/experiments/patterns-in-process.json
./tests/chaos/run-chaos-experiment.sh --experiment tests/chaos/experiments/degrade-on-tides-latency.json
./tests/chaos/run-chaos-experiment.sh --experiment tests/chaos/experiments/pod-kill-harbour.json
./tests/chaos/run-chaos-experiment.sh --experiment tests/chaos/experiments/network-partition-tides.json
"
```

### `tests/e2e/e2e.conf`

The lab's end-to-end configuration that `chaos-e2e.conf` sources (owned by `go-e2e-test`; shown so the chaos run can be reproduced).
```bash
E2E_NODE_IMAGE="kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5"
E2E_NAMESPACE="harbour"
E2E_BUILD="CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -o build/harbour ./cmd/harbour && docker build -q -t harbour:e2e -f build/harbour.Dockerfile build"
E2E_IMAGES="harbour:e2e"
E2E_RELEASES="
tides|deploy/harbour|tests/chaos/values/tides.yaml
harbour|deploy/harbour|tests/chaos/values/harbour.yaml
"
E2E_ENDPOINTS="
api|30080
"
E2E_SUITES="
true
"
```

### `Makefile`

None of these is a prerequisite of `ci`. `chaos-chart` fetches the pinned chart once and checks its SHA-256 against the digest the project's chart index publishes for 2.8.8.
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
	./tests/chaos/validate-go-chaos-tests.sh .
```

| Target | Who calls it | Notes |
|---|---|---|
| `chaos` | The nightly workflow; a person | Needs Docker, kind v0.33.0, Helm 4, kubectl and Go. Under 10 minutes in the lab run, cluster included |
| `chaos-chart` | `chaos` | Refuses a chart whose digest differs |
| `chaos-verify` | A person, inside a signed statement's window | Toxiproxy faults only; refused without the signed statement |
| `chaos-validate` | Before hand-off; in `make ci` if wanted, since it runs nothing | |

### `.github/workflows/chaos.yml`

Nightly and by hand, never on a pull request; one run, no retry step, no `continue-on-error`; the evidence (results, logs, events) is uploaded whatever the outcome. **Not run on GitHub Actions** (unverified): the same `make chaos` was run on macOS arm64.
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
      - uses: actions/setup-go@v5
        with:
          go-version: "1.27.4"
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
