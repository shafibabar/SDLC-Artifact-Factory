# End-to-End Environment Configuration

Self-contained. Copy when setting up a product's end-to-end environment, or when a chart, a dependency or the web shell is added to it. The files below are the ones the run for this skill used (kind v0.33.0, Helm v4.3.2, kubectl v1.36.1, Docker 29.9.3, macOS arm64); the product is an observatory's booking service with a scheduler, a database and a web shell.

## Files to put in the product

| File | From | Change |
|---|---|---|
| `tests/e2e/run-e2e-environment.sh` | `../scripts/run-e2e-environment.sh` | Nothing: all product detail is in the configuration |
| `tests/e2e/run-go-e2e-suite.sh` | `../scripts/run-go-e2e-suite.sh` | Nothing |
| `tests/e2e/e2e.conf` | Below | Every line |
| `tests/e2e/values/<release>.yaml` | Below | One per release |
| `tests/e2e/quarantine.txt` | Created when the first test is quarantined | See `../references/retry-and-quarantine.md` |
| `.gitignore` | Add the line `e2e-evidence/` | |

## The configuration

### `tests/e2e/e2e.conf`

```bash
# tests/e2e/e2e.conf: read by tests/e2e/run-e2e-environment.sh
E2E_NODE_IMAGE="kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5"
E2E_NAMESPACE="observatory"
E2E_BUILD="make e2e-images"
E2E_IMAGES="bookings:e2e scheduler:e2e web-shell:e2e"
# <release>|<chart dir>|<values file>, dependencies first
E2E_RELEASES="
postgres|deploy/e2e/postgres|tests/e2e/values/postgres.yaml
scheduler|charts/scheduler|tests/e2e/values/scheduler.yaml
bookings|charts/bookings|tests/e2e/values/bookings.yaml
web-shell|charts/web-shell|tests/e2e/values/web-shell.yaml
"
# <name>|<nodePort>: each is published on a free port of 127.0.0.1
E2E_ENDPOINTS="
api|30080
scheduler|30081
web|30082
db|30432
"
E2E_SMOKE_ENDPOINT="api"
E2E_SUITES="
./tests/e2e/run-go-e2e-suite.sh journeys
./tests/e2e/run-go-e2e-suite.sh smoke
./tests/e2e/run-go-e2e-suite.sh quarantine
"
```

| Setting | Rule |
|---|---|
| `E2E_NODE_IMAGE` | Pinned by digest; the script refuses a bare tag. Take the digest from the kind release notes for the kind version in use |
| `E2E_BUILD` | Builds the images of the commit under test. For a release run it may instead pull the release candidate's images by digest and tag them: the suite must test the artifact that will ship, not a rebuild of it (Humble and Farley) |
| `E2E_IMAGES` | Only images built from this commit. A third-party image (the database) is pulled by the node from its pinned reference: in the run for this skill `kind load docker-image postgres:17.12-alpine` failed with `content digest ... not found`, because Docker had stored only one platform of a multi-platform image |
| `E2E_RELEASES` | **Every** chart the deployment plan names, the web shell included, dependencies first. Each is the product's real chart; only the values file differs. A dependency the charts need (a broker, an ingress controller, the service mesh) is a line here too |
| `E2E_ENDPOINTS` | Each name is an address the tests may use; nothing else is reachable from the test process. The NodePort must be the one the release's values file sets |
| `E2E_SMOKE_ENDPOINT` | The endpoint the read-only smoke tests read from inside this run |
| `E2E_SUITES` | Commands run in order, each in the product root. A browser suite of `react-e2e-testing` is one more line here; it reads the address from `E2E_ADDR_<NAME>` |

Each suite receives `E2E_RUN_ID`, `E2E_KUBECONFIG`, `E2E_RESULTS_DIR`, `E2E_SMOKE_URL` and one `E2E_ADDR_<NAME>` per endpoint (`E2E_ADDR_WEB=127.0.0.1:<port>`). The Go journey build ignores the address variables and reads the run marker instead.

## Values files

The values file may change only what `environment-config` allows to differ between environments: the endpoint (a NodePort Service), sizing, and test-only identities and credentials. It never changes the chart.

### `tests/e2e/values/bookings.yaml`

```yaml
env:
  RESOURCE: bookings
  DATABASE_URL: postgres://app:e2e-only-not-a-secret@postgres:5432/app
  DOWNSTREAM_URL: http://scheduler:8080
  DOWNSTREAM_RESOURCE: allocations
  DOWNSTREAM_DELAY_MS: "1500"
service:
  type: NodePort
  nodePort: 30080
```

### `tests/e2e/values/postgres.yaml`

```yaml
service:
  type: NodePort
  nodePort: 30432
```

The cluster configuration the script writes for kind from these settings (shown for reference; it is generated on each run with free ports):

```text
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  apiServerAddress: "127.0.0.1"
nodes:
  - role: control-plane
    image: kindest/node:v1.37.0@sha256:a1ed56cf...
    extraPortMappings:
      - containerPort: 30080
        hostPort: 58920
        listenAddress: "127.0.0.1"
        protocol: TCP
```

Charts must label their workloads `app.kubernetes.io/instance: <release>` (the `helm-chart` standard): the script waits for the rollout of every Deployment, StatefulSet and DaemonSet with that label, and prints a note for a release that has none.
