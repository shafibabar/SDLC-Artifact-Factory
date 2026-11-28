# End-to-End Environment Configuration for a Python Product

Self-contained. Copy when setting up a Python product's end-to-end environment, when a chart, a dependency or the web shell is added to it, or when a product that already has Go journeys gets Python ones. `go-e2e-test` owns the environment and its script for every stack; this file is what a Python product fills in. The files below are the ones the run for this skill used (kind v0.33.0, Kubernetes v1.37.0, Helm v4.3.2, kubectl v1.36.1, Docker 29.9.3, macOS arm64); the product is a museum's exhibit loans with a courier service, a database and a web shell.

## Files to put in the product

| File | From | Change |
|---|---|---|
| `tests/e2e/run-e2e-environment.sh` | `../scripts/run-e2e-environment.sh` | Nothing: all product detail is in the configuration |
| `tests/e2e/run-python-e2e-suite.sh` | `../scripts/run-python-e2e-suite.sh` | Nothing |
| `tests/e2e/e2e.conf` | Below | Every line |
| `tests/e2e/values/<release>.yaml` | Below | One per release |
| `tests/e2e/quarantine-python.txt` | Created when the first test is quarantined | See `../references/retry-and-quarantine.md` |
| `.gitignore` | Add the line `e2e-evidence/` | |

`../scripts/run-e2e-environment.sh` is this skill's copy of the script `go-e2e-test` owns. The program is the same in both skills and a test fails when the two differ; change it only together with `go-e2e-test`.

## The configuration

### `tests/e2e/e2e.conf`

```bash
# tests/e2e/e2e.conf: read by tests/e2e/run-e2e-environment.sh
E2E_NODE_IMAGE="kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5"
E2E_NAMESPACE="museum"
E2E_BUILD="make e2e-images"
E2E_IMAGES="loans:e2e couriers:e2e web-shell:e2e"
# <release>|<chart dir>|<values file>, dependencies first
E2E_RELEASES="
postgres|deploy/e2e/postgres|tests/e2e/values/postgres.yaml
couriers|charts/couriers|tests/e2e/values/couriers.yaml
loans|charts/loans|tests/e2e/values/loans.yaml
web-shell|charts/web-shell|tests/e2e/values/web-shell.yaml
"
# <name>|<nodePort>: each is published on a free port of 127.0.0.1
E2E_ENDPOINTS="
api|30080
couriers|30081
web|30082
db|30432
"
E2E_SMOKE_ENDPOINT="api"
E2E_SUITES="
uv run ./tests/e2e/run-python-e2e-suite.sh journeys
uv run ./tests/e2e/run-python-e2e-suite.sh smoke
uv run ./tests/e2e/run-python-e2e-suite.sh quarantine
"
```

| Setting | Rule |
|---|---|
| `E2E_NODE_IMAGE` | Pinned by digest; the script refuses a bare tag. Take the digest from the kind release notes for the kind version in use |
| `E2E_BUILD` | Builds the images of the commit under test. For a release run it may instead pull the release candidate's images by digest and tag them: the suite must test the artifact that will ship, not a rebuild of it (Humble and Farley) |
| `E2E_IMAGES` | Only images built from this commit. A third-party image (the database) is pulled by the cluster node from its pinned reference, not preloaded (product owner's decision of 2026-11-28) |
| `E2E_RELEASES` | **Every** chart the deployment plan names, the web shell included, dependencies first. Each is the product's real chart; only the values file differs. A dependency the charts need (a broker, an ingress controller, the service mesh) is a line here too |
| `E2E_ENDPOINTS` | Each name is an address the tests may use; nothing else is reachable from the test process. The NodePort must be the one the release's values file sets |
| `E2E_SMOKE_ENDPOINT` | The endpoint the read-only smoke tests read from inside this run |
| `E2E_SUITES` | Commands run in order, each in the product root. `uv run` puts the product's own Python environment first on the `PATH`, which is where the runner finds pytest (run with uv 0.13.9). A browser suite of `react-e2e-testing` is one more line here |

Each suite receives `E2E_RUN_ID`, `E2E_KUBECONFIG`, `E2E_RESULTS_DIR`, `E2E_SMOKE_URL` and one `E2E_ADDR_<NAME>` per endpoint. The Python journeys ignore the address variables and read the run marker instead.

## A product with Go and Python services

One environment, one script run, one suite line per language. Nothing else is duplicated: one `e2e.conf`, one cluster, one evidence folder.

```text
E2E_SUITES="
./tests/e2e/run-go-e2e-suite.sh journeys
uv run ./tests/e2e/run-python-e2e-suite.sh journeys
./tests/e2e/run-go-e2e-suite.sh smoke
uv run ./tests/e2e/run-python-e2e-suite.sh smoke
./tests/e2e/run-go-e2e-suite.sh quarantine
uv run ./tests/e2e/run-python-e2e-suite.sh quarantine
"
```

- The Go files stay in `tests/e2e/` (package `e2e`, `go-e2e-test`); the Python files are in `tests/e2e/journeys/` and `tests/e2e/smoke/`. Neither tool reads the other's files.
- Each language has its own quarantine list: `tests/e2e/quarantine.txt` for Go test names and `tests/e2e/quarantine-python.txt` for pytest node ids. One shared file does not work: each runner refuses the other's lines (run: exit 2 from both).
- The two runners read different variables (`E2E_QUARANTINE_FILE` and `E2E_TEST_TIMEOUT` for Go; `E2E_PY_QUARANTINE_FILE` and `E2E_PY_TIMEOUT` for Python) and write differently named files into the same `E2E_RESULTS_DIR` (`journeys-summary.json`; `python-journeys-summary.json`).
- A journey that spans a Go and a Python service is written once, in either language: it drives both over the network and imports neither.

## Values files

The values file may change only what `environment-config` allows to differ between environments: the endpoint (a NodePort Service), sizing, and test-only identities and credentials. It never changes the chart.

### `tests/e2e/values/loans.yaml`

```yaml
env:
  RESOURCE: loans
  DATABASE_URL: postgres://app:e2e-only-not-a-secret@postgres:5432/app
  DOWNSTREAM_URL: http://couriers:8080
  DOWNSTREAM_RESOURCE: pickups
  DOWNSTREAM_DELAY_MS: "1500"
service:
  type: NodePort
  nodePort: 30080
```

### `tests/e2e/values/couriers.yaml`

```yaml
env:
  RESOURCE: pickups
service:
  type: NodePort
  nodePort: 30081
```

### `tests/e2e/values/web-shell.yaml`

```yaml
env:
  STATIC_TITLE: Museum loans
service:
  type: NodePort
  nodePort: 30082
```

### `tests/e2e/values/postgres.yaml`

```yaml
service:
  type: NodePort
  nodePort: 30432
```

Charts must label their workloads `app.kubernetes.io/instance: <release>` (the `helm-chart` standard): the script waits for the rollout of every Deployment, StatefulSet and DaemonSet with that label, and prints a note for a release that has none.
