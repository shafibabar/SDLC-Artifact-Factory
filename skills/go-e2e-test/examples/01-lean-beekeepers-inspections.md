# Lean: a Beekeepers' Association Hive Log

One Go service (`hive-log`) with a PostgreSQL database and a small web shell; one team, no tenants, no broker. **Lean changes the number of releases and journeys. It does not change the environment**: the suite still runs in a throwaway kind cluster that the run creates and deletes, through the same script, guard and build tags.

Run on 2026-11-28: Go 1.27.4, kind v0.33.0 (Kubernetes v1.37.0), Helm v4.3.2, kubectl v1.36.1, Docker 29.9.3, macOS arm64. The service in the run was a lab stand-in configured with this product's resource (`inspections`) and its charts; the script, the guard and the suite files are the shipped ones, unchanged.

## Plan

| Journey | Acceptance criteria | Why it is end-to-end |
|---|---|---|
| A recorded inspection is kept and listed | AC-US-1.1, AC-US-1.2 | The deployed service must reach its deployed database through the chart's configuration |
| A withdrawn inspection is gone | AC-US-1.4 | The same path, for removal |

| Proven lower instead | Layer |
|---|---|
| Which fields an inspection needs, date rules | Unit (`go-unit-test`) |
| SQL, constraints, migration | Integration (`go-integration-test`) |
| Response shapes | Contract (`go-contract-test`) |

Two journeys and one read-only smoke test are the whole suite. The browser journey ("a beekeeper records an inspection on the page") belongs to `react-e2e-testing` and would be one more line of `E2E_SUITES`; the web shell is installed and awaited here so that suite has something to open.

## Files

`env_test.go`, `main_test.go`, `client_test.go`, `await_test.go`, `trace_test.go`, `guard_selfcheck_test.go`, `smoke_main_test.go` and the two scripts are copied unchanged.

### `tests/e2e/e2e.conf`

```bash
# tests/e2e/e2e.conf: read by tests/e2e/run-e2e-environment.sh
E2E_NODE_IMAGE="kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5"
E2E_NAMESPACE="hive-log"
E2E_BUILD="make e2e-images"
E2E_IMAGES="hive-log:e2e web-shell:e2e"
E2E_RELEASES="
postgres|deploy/e2e/postgres|tests/e2e/values/postgres.yaml
hive-log|charts/hive-log|tests/e2e/values/hive-log.yaml
web-shell|charts/web-shell|tests/e2e/values/web-shell.yaml
"
E2E_ENDPOINTS="
api|30080
web|30081
"
E2E_SMOKE_ENDPOINT="api"
E2E_SUITES="
./tests/e2e/run-go-e2e-suite.sh journeys
./tests/e2e/run-go-e2e-suite.sh smoke
"
```

### `tests/e2e/values/hive-log.yaml`

```yaml
env:
  RESOURCE: inspections
  DATABASE_URL: postgres://app:e2e-only-not-a-secret@postgres:5432/app
service:
  type: NodePort
  nodePort: 30080
```

The database is not published to the test process: no journey here needs a direct write, so `E2E_ENDPOINTS` has no `db` line.

### `tests/e2e/seed_test.go`

```go
//go:build e2e && !smoke

package e2e

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

var refCounter atomic.Int64

// ref gives a reference that belongs to one test of one run; nothing is random.
func ref(t *testing.T) string {
	name := strings.NewReplacer("/", "-", "_", "-").Replace(strings.ToLower(t.Name()))
	return fmt.Sprintf("%s-%s-%d", env.RunID, name, refCounter.Add(1))
}

// inspection is what the public API returns for a hive inspection.
type inspection struct {
	ID     string         `json:"id"`
	Status string         `json:"status"`
	Body   map[string]any `json:"body"`
}

// recordInspection creates an inspection through the public API and registers
// its removal at once.
func recordInspection(t *testing.T, ctx context.Context, api *Client, fields map[string]any) inspection {
	t.Helper()
	var made inspection
	status, err := api.Do(ctx, http.MethodPost, "/inspections", fields, &made)
	if err != nil || status != http.StatusCreated {
		t.Fatalf("record inspection: status %d, err %v", status, err)
	}
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		status, err := api.Do(ctx, http.MethodDelete, "/inspections/"+made.ID, nil, nil)
		if err != nil || (status != http.StatusNoContent && status != http.StatusNotFound) {
			t.Errorf("cleanup of inspection %s: status %d, err %v", made.ID, status, err)
		}
	})
	return made
}
```

### `tests/e2e/journey_inspection_test.go`

```go
//go:build e2e && !smoke

package e2e

import (
	"net/http"
	"testing"
)

// TestJourney_RecordedInspectionIsKept proves AC-US-1.1 and AC-US-1.2: a
// beekeeper records an inspection and finds it again in the hive's list. The
// deployed service and its deployed database take part, wired by the chart.
func TestJourney_RecordedInspectionIsKept(t *testing.T) {
	ctx, _ := startJourney(t)
	api, err := env.Client("api")
	if err != nil {
		t.Fatal(err)
	}
	reference := ref(t)
	made := recordInspection(t, ctx, api, map[string]any{"reference": reference, "hive": "orchard-3", "queen_seen": true})

	var listed []inspection
	if status, err := api.Do(ctx, http.MethodGet, "/inspections", nil, &listed); err != nil || status != http.StatusOK {
		t.Fatalf("list inspections: status %d, err %v", status, err)
	}
	for _, item := range listed {
		if item.ID == made.ID && item.Body["reference"] == reference {
			return
		}
	}
	t.Fatalf("inspection %s is not in the list of %d", made.ID, len(listed))
}

// TestJourney_WithdrawnInspectionIsGone proves AC-US-1.4: a withdrawn inspection
// can no longer be read.
func TestJourney_WithdrawnInspectionIsGone(t *testing.T) {
	ctx, _ := startJourney(t)
	api, err := env.Client("api")
	if err != nil {
		t.Fatal(err)
	}
	made := recordInspection(t, ctx, api, map[string]any{"reference": ref(t), "hive": "orchard-1"})
	if status, err := api.Do(ctx, http.MethodDelete, "/inspections/"+made.ID, nil, nil); err != nil || status != http.StatusNoContent {
		t.Fatalf("withdraw: status %d, err %v", status, err)
	}
	if status, err := api.Do(ctx, http.MethodGet, "/inspections/"+made.ID, nil, nil); err != nil || status != http.StatusNotFound {
		t.Fatalf("read after withdrawal: status %d, err %v; want 404", status, err)
	}
}
```

### `tests/e2e/smoke_test.go`

```go
//go:build smoke

package e2e

import (
	"net/http"
	"strings"
	"testing"
)

// TestSmoke_InspectionsCanBeListed reads the list: the service is up and its
// database answers. It creates nothing.
func TestSmoke_InspectionsCanBeListed(t *testing.T) {
	ctx, _ := startJourney(t)
	var listed []map[string]any
	status, err := smoke.Do(ctx, http.MethodGet, "/inspections", nil, &listed)
	if err != nil || status != http.StatusOK {
		t.Fatalf("list inspections: status %d, err %v", status, err)
	}
}

// TestSmoke_WritesAreRefused keeps the read-only guard honest on every run.
func TestSmoke_WritesAreRefused(t *testing.T) {
	ctx, _ := startJourney(t)
	for _, method := range []string{http.MethodPost, http.MethodPut, http.MethodPatch, http.MethodDelete} { // smoke-refusal-check: each must be refused
		_, err := smoke.Do(ctx, method, "/inspections", map[string]any{"x": 1}, nil)
		if err == nil || !strings.Contains(err.Error(), "read-only") {
			t.Errorf("%s was not refused: %v", method, err)
		}
	}
}
```

## The run

`make e2e`, start to finish:

```text
== creating cluster e2e-local-1795825208-63623 (kubeconfig /var/folders/.../tmp.sJvqZazVEL/kubeconfig)
== loading images: hive-log:e2e web-shell:e2e
== installing postgres from deploy/e2e/postgres
== installing hive-log from charts/hive-log
== installing web-shell from charts/web-shell
== waiting for endpoint api on 127.0.0.1:59904
== waiting for endpoint web on 127.0.0.1:59905
== suite: ./tests/e2e/run-go-e2e-suite.sh journeys
--- PASS: TestGuard_ClientRefusesAnotherHost (0.00s)
--- PASS: TestGuard_SeedingRefusesAnAddressOutsideTheCluster (0.00s)
--- PASS: TestGuard_MarkerMustBeThisRunAndLoopback (0.00s)
--- PASS: TestJourney_RecordedInspectionIsKept (0.01s)
--- PASS: TestJourney_WithdrawnInspectionIsGone (0.00s)
== journeys: 5 ran, 5 passed first time, 0 flaky, 0 failed, 0 skipped, 0 quarantined
== suite: ./tests/e2e/run-go-e2e-suite.sh smoke
--- PASS: TestSmoke_InspectionsCanBeListed (0.00s)
--- PASS: TestSmoke_WritesAreRefused (0.00s)
== smoke: 2 ran, 2 passed first time, 0 flaky, 0 failed, 0 skipped, 0 quarantined
== deleting cluster e2e-local-1795825208-63623
== end-to-end run local-1795825208-63623 passed; cluster deleted
```

`validate-go-e2e-tests.sh .` reported `0 FAIL, 0 WARN`. `kind get clusters` afterwards did not list the run's cluster.

## What a reply to "it's a tiny product, just run it with Docker Compose against the dev database" says

- No: the suite runs in a throwaway kind cluster created for the run, at every product size, and never against a shared or dev environment, because journeys create and delete data and because Compose is a second description of the deployment that the charts do not keep in step.
- Lean is already the small version: three releases, two journeys, one smoke test, about a minute.
- Whether a lean product may ever use something lighter than a cluster is a decision for the product owner; until it is made, the cluster stands.
