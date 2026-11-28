# Enterprise: a Blood Donation Appointment Platform

Several regional blood services (tenants) share one platform: an `appointments` service (two replicas, PostgreSQL) that asks a `notifications` service to tell the donor, and a web shell. A release must not go out on an old test run, one journey is quarantined, and the pipelines run read-only smoke tests after each tenant's deployment.

Run on 2026-11-28: Go 1.27.4, kind v0.33.0 (Kubernetes v1.37.0), Helm v4.3.2, kubectl v1.36.1, Docker 29.9.3, macOS arm64. The services in the run were a lab stand-in configured with this product's resources, tenant header and charts; the script, the guard and the suite files are the shipped ones, unchanged. **Not run:** anything on GitHub Actions, a service mesh, more than one node, and smoke tests against a real environment.

## Plan

| Journey | Acceptance criteria | Why it is end-to-end |
|---|---|---|
| A booked donation is notified | AC-US-7.1, AC-US-7.2 | Two deployed services and a later effect |
| One region cannot read another's appointment or notification | AC-US-9.1 | Tenant isolation must hold across both services as deployed, not only in one service's queries |
| A moved appointment is notified | AC-US-7.4 | Same path; **quarantined** after two flakes |

Tenant isolation is also tested lower (row-level rules in `go-integration-test`); the journey proves that the tenant travels correctly from one deployed service to the next. Tenants in the suite are synthetic and carry the run id (`e2e-<run id>-north`): no real blood service has such an id, and the suite never runs where real tenants exist.

## Files

The copied files and the two scripts are unchanged.

### `tests/e2e/e2e.conf`

```bash
# tests/e2e/e2e.conf: read by tests/e2e/run-e2e-environment.sh
E2E_NODE_IMAGE="kindest/node:v1.37.0@sha256:a1ed56cfb0e7b93589bdf97c8cd566405a265939e3620fc4f5de89adff580ae5"
E2E_NAMESPACE="donations"
E2E_BUILD="make e2e-images"
E2E_IMAGES="appointments:e2e notifications:e2e web-shell:e2e"
E2E_RELEASES="
postgres|deploy/e2e/postgres|tests/e2e/values/postgres.yaml
notifications|charts/notifications|tests/e2e/values/notifications.yaml
appointments|charts/appointments|tests/e2e/values/appointments.yaml
web-shell|charts/web-shell|tests/e2e/values/web-shell.yaml
"
E2E_ENDPOINTS="
api|30080
notifications|30081
web|30082
"
E2E_SMOKE_ENDPOINT="api"
E2E_INSTALL_TIMEOUT="240s"
E2E_SUITES="
./tests/e2e/run-go-e2e-suite.sh journeys
./tests/e2e/run-go-e2e-suite.sh smoke -- -tenant=e2e-smoke
./tests/e2e/run-go-e2e-suite.sh quarantine
"
```

### `tests/e2e/values/appointments.yaml`

```yaml
replicas: 2
env:
  RESOURCE: appointments
  DATABASE_URL: postgres://app:e2e-only-not-a-secret@postgres:5432/app
  DOWNSTREAM_URL: http://notifications:8080
  DOWNSTREAM_RESOURCE: notifications
  DOWNSTREAM_DELAY_MS: "800"
service:
  type: NodePort
  nodePort: 30080
```

With `replicas: 2` the script's `kubectl rollout status` returns only when both replicas are available; Helm's own wait may return at minimum availability.

### `tests/e2e/quarantine.txt`

```text
# TestName | issue URL | deadline
TestJourney_RebookedDonationIsNotified | https://github.com/example-org/donations/issues/412 | 2026-12-09
```

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

// asTenant returns a client for one endpoint that acts as a synthetic tenant of
// this run. The tenant id carries the run id: no real blood service has it.
func asTenant(t *testing.T, endpoint, region string) *Client {
	t.Helper()
	client, err := env.Client(endpoint)
	if err != nil {
		t.Fatal(err)
	}
	client.Header.Set("X-Tenant", "e2e-"+env.RunID+"-"+region)
	return client
}

// appointment is what the public API returns for a donation appointment.
type appointment struct {
	ID     string         `json:"id"`
	Status string         `json:"status"`
	Body   map[string]any `json:"body"`
}

// bookDonation books an appointment through the public API as the client's
// tenant and registers its cancellation at once.
func bookDonation(t *testing.T, ctx context.Context, api *Client, fields map[string]any) appointment {
	t.Helper()
	var made appointment
	status, err := api.Do(ctx, http.MethodPost, "/appointments", fields, &made)
	if err != nil || status != http.StatusCreated {
		t.Fatalf("book donation: status %d, err %v", status, err)
	}
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		status, err := api.Do(ctx, http.MethodDelete, "/appointments/"+made.ID, nil, nil)
		if err != nil || (status != http.StatusNoContent && status != http.StatusNotFound) {
			t.Errorf("cleanup of appointment %s: status %d, err %v", made.ID, status, err)
		}
	})
	return made
}

// awaitConfirmed polls until the appointment is confirmed, which happens once
// the notification service has accepted the donor's notification.
func awaitConfirmed(t *testing.T, ctx context.Context, api *Client, id string) appointment {
	t.Helper()
	var got appointment
	eventually(t, ctx, 20*time.Second, "appointment "+id+" confirmed", func(ctx context.Context) error {
		status, err := api.Do(ctx, http.MethodGet, "/appointments/"+id, nil, &got)
		if err != nil {
			return err
		}
		if status != http.StatusOK || got.Status != "confirmed" {
			return fmt.Errorf("status %d, appointment status %q", status, got.Status)
		}
		return nil
	})
	return got
}
```

### `tests/e2e/journey_donation_test.go`

```go
//go:build e2e && !smoke

package e2e

import (
	"net/http"
	"testing"
)

// TestJourney_BookedDonationIsNotified proves AC-US-7.1 and AC-US-7.2: a donor
// books an appointment and the notification service records a notification for
// it, in the same tenant.
func TestJourney_BookedDonationIsNotified(t *testing.T) {
	ctx, _ := startJourney(t)
	api := asTenant(t, "api", "north")
	notifications := asTenant(t, "notifications", "north")

	made := bookDonation(t, ctx, api, map[string]any{"reference": ref(t), "centre": "harbour-road", "slot": "2026-12-03T09:30"})
	confirmed := awaitConfirmed(t, ctx, api, made.ID)

	notificationID, _ := confirmed.Body["downstream_id"].(string)
	var sent appointment
	status, err := notifications.Do(ctx, http.MethodGet, "/notifications/"+notificationID, nil, &sent)
	if err != nil || status != http.StatusOK {
		t.Fatalf("notification %q: status %d, err %v", notificationID, status, err)
	}
	if sent.Body["source_id"] != made.ID {
		t.Fatalf("notification is for appointment %v, want %s", sent.Body["source_id"], made.ID)
	}
}

// TestJourney_OneRegionCannotReadAnothers proves AC-US-9.1: an appointment booked
// in one blood service is invisible to another, in the appointment service and
// in the notification it caused.
func TestJourney_OneRegionCannotReadAnothers(t *testing.T) {
	ctx, _ := startJourney(t)
	north := asTenant(t, "api", "north")
	south := asTenant(t, "api", "south")

	made := bookDonation(t, ctx, north, map[string]any{"reference": ref(t), "centre": "harbour-road"})
	confirmed := awaitConfirmed(t, ctx, north, made.ID)

	if status, err := south.Do(ctx, http.MethodGet, "/appointments/"+made.ID, nil, nil); err != nil || status != http.StatusNotFound {
		t.Fatalf("south read north's appointment: status %d, err %v; want 404", status, err)
	}
	var listed []appointment
	if status, err := south.Do(ctx, http.MethodGet, "/appointments", nil, &listed); err != nil || status != http.StatusOK {
		t.Fatalf("south list: status %d, err %v", status, err)
	}
	for _, item := range listed {
		if item.ID == made.ID {
			t.Fatalf("south's list contains north's appointment %s", made.ID)
		}
	}
	notificationID, _ := confirmed.Body["downstream_id"].(string)
	southNotifications := asTenant(t, "notifications", "south")
	if status, err := southNotifications.Do(ctx, http.MethodGet, "/notifications/"+notificationID, nil, nil); err != nil || status != http.StatusNotFound {
		t.Fatalf("south read north's notification: status %d, err %v; want 404", status, err)
	}
}

// TestJourney_RebookedDonationIsNotified proves AC-US-7.4: after a donor moves an
// appointment, the new one is notified. Quarantined: see tests/e2e/quarantine.txt.
func TestJourney_RebookedDonationIsNotified(t *testing.T) {
	ctx, _ := startJourney(t)
	api := asTenant(t, "api", "north")
	first := bookDonation(t, ctx, api, map[string]any{"reference": ref(t), "slot": "2026-12-03T09:30"})
	awaitConfirmed(t, ctx, api, first.ID)
	if status, err := api.Do(ctx, http.MethodDelete, "/appointments/"+first.ID, nil, nil); err != nil || status != http.StatusNoContent {
		t.Fatalf("cancel first appointment: status %d, err %v", status, err)
	}
	second := bookDonation(t, ctx, api, map[string]any{"reference": ref(t), "slot": "2026-12-04T11:00"})
	confirmed := awaitConfirmed(t, ctx, api, second.ID)
	if id, _ := confirmed.Body["downstream_id"].(string); id == "" {
		t.Fatal("the moved appointment has no notification")
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

// TestSmoke_TenantCanListAppointments reads the appointment list as the tenant
// given with -tenant: the service is up, its database answers and the tenant is
// accepted. It creates nothing.
func TestSmoke_TenantCanListAppointments(t *testing.T) {
	if *tenant == "" {
		t.Fatal("pass the tenant to read as: -tenant=<id>")
	}
	ctx, _ := startJourney(t)
	var listed []map[string]any
	status, err := smoke.Do(ctx, http.MethodGet, "/appointments", nil, &listed)
	if err != nil || status != http.StatusOK {
		t.Fatalf("list appointments: status %d, err %v", status, err)
	}
}

// TestSmoke_WritesAreRefused keeps the read-only guard honest on every run.
func TestSmoke_WritesAreRefused(t *testing.T) {
	ctx, _ := startJourney(t)
	for _, method := range []string{http.MethodPost, http.MethodPut, http.MethodPatch, http.MethodDelete} { // smoke-refusal-check: each must be refused
		_, err := smoke.Do(ctx, method, "/appointments", map[string]any{"x": 1}, nil)
		if err == nil || !strings.Contains(err.Error(), "read-only") {
			t.Errorf("%s was not refused: %v", method, err)
		}
	}
}
```

## The run

```text
== suite: ./tests/e2e/run-go-e2e-suite.sh journeys
+ go test -tags e2e -count=1 -timeout 20m -json -run ^Test -skip ^(TestJourney_RebookedDonationIsNotified)$ ./tests/e2e/
--- PASS: TestGuard_ClientRefusesAnotherHost (0.00s)
--- PASS: TestGuard_SeedingRefusesAnAddressOutsideTheCluster (0.00s)
--- PASS: TestGuard_MarkerMustBeThisRunAndLoopback (0.00s)
--- PASS: TestJourney_BookedDonationIsNotified (0.81s)
--- PASS: TestJourney_OneRegionCannotReadAnothers (1.01s)
== journeys: 5 ran, 5 passed first time, 0 flaky, 0 failed, 0 skipped, 1 quarantined
QUARANTINED TestJourney_RebookedDonationIsNotified: skipped here, proves nothing (issue https://github.com/example-org/donations/issues/412, deadline 2026-12-09)
== suite: ./tests/e2e/run-go-e2e-suite.sh smoke -- -tenant=e2e-smoke
+ go test -tags smoke -count=1 -timeout 20m -json -run ^TestSmoke ./tests/e2e/ -args -tenant=e2e-smoke
--- PASS: TestSmoke_TenantCanListAppointments (0.01s)
--- PASS: TestSmoke_WritesAreRefused (0.00s)
== smoke: 2 ran, 2 passed first time, 0 flaky, 0 failed, 0 skipped, 0 quarantined
== suite: ./tests/e2e/run-go-e2e-suite.sh quarantine
+ go test -tags e2e -count=1 -timeout 20m -json -run ^(TestJourney_RebookedDonationIsNotified)$ ./tests/e2e/
--- PASS: TestJourney_RebookedDonationIsNotified (2.01s)
== quarantine: 1 ran, 1 passed first time, 0 flaky, 0 failed, 0 skipped, 1 quarantined
QUARANTINED TestJourney_RebookedDonationIsNotified: pass (issue https://github.com/example-org/donations/issues/412, deadline 2026-12-09); not blocking
== deleting cluster e2e-local-1795825318-64366
== end-to-end run local-1795825318-64366 passed; cluster deleted
```

Reading it:

- The run is green **and AC-US-7.4 is unproven**: the quarantined journey passed this time in the non-blocking run, which is what a flaky test usually does. The test report lists AC-US-7.4 under "criteria unproven meanwhile". It stays out until the cause is fixed and the line is deleted.
- From 2026-12-10 the journeys run exits 1 until the test is restored or removed with a record.

## The release gate

The workflow that publishes calls `.github/workflows/e2e.yml` as a job, and its publishing job declares `needs: e2e` (`../templates/workflows.md`). The suite installs the release candidate's images: `E2E_BUILD` pulls them by digest and tags them `:e2e` instead of building. A `release:` trigger is not used: it starts after the release exists. Not run on GitHub Actions.

## Smoke tests after each tenant's deployment

`cd-pipeline` deploys tenant by tenant. After each one, with a short-lived read-only credential for that tenant that the pipeline supplies:

```bash
E2E_SMOKE_URL=https://north.donations.example ./tests/e2e/run-go-e2e-suite.sh smoke -- -tenant=north
```

What that selection can do there: read the appointment list as that tenant. What it cannot do: the smoke build holds no code that creates or deletes, and its client refuses every method but GET and HEAD before sending. The journeys above are never run there; their `TestMain` refuses to start outside the cluster of their own run. A deployment check that needs a write is not a smoke test and stays in the throwaway cluster.

## Report excerpt

| Test | Acceptance criteria | First attempt | Retry | Result |
|---|---|---|---|---|
| `TestJourney_BookedDonationIsNotified` | AC-US-7.1, AC-US-7.2 | pass | not needed | passed |
| `TestJourney_OneRegionCannotReadAnothers` | AC-US-9.1 | pass | not needed | passed |

| Quarantined | Issue | Deadline | Non-blocking run | Unproven meanwhile |
|---|---|---|---|---|
| `TestJourney_RebookedDonationIsNotified` | #412 | 2026-12-09 | pass | AC-US-7.4 |

What this environment does not prove: one node, so nothing about the two replicas landing on different nodes or zones; no mesh, so no mutual TLS between the services; no second region. Each is listed in the report with the environment or test that covers it, or as an open question. The report goes to the product owner for approval.
