# The Go End-to-End Suite

Self-contained. Copy these files into `tests/e2e/` when a product gets its first end-to-end journey. Compiled and run on Go 1.27.4 with `go.opentelemetry.io/otel` and `otel/sdk` v1.47.0 and `otelhttp` v0.72.0, against a kind v0.33.0 cluster (Kubernetes v1.37.0) created by `../scripts/run-e2e-environment.sh`.

```bash
go get go.opentelemetry.io/otel@v1.47.0 go.opentelemetry.io/otel/sdk@v1.47.0 \
  go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp@v0.72.0
go mod tidy
```

`go mod tidy` keeps these: it reads files behind every build tag.

## The three rules of the layout

1. **Every file is a `_test.go` file in package `e2e`.** A helper in a plain `.go` file behind a tag cannot be measured by the coverage gates of `go-unit-test`, which then give no result and block the build.
2. **Every file carries one of three build tags.** With no tag given, the package has no files: `go build ./...`, `go vet ./...`, `go test ./...` and so `make ci` and the coverage gates never compile it (run: `go list ./...` does not list the package).
3. **Addresses never come from the environment in the journey build.** They come from the run marker inside the cluster that `run-e2e-environment.sh` created.

| Build tag | Files | Compiled by |
|---|---|---|
| `e2e && !smoke` | Guard, `TestMain`, seeding, journeys, guard self-checks | `-tags e2e` only |
| `smoke` | Smoke `TestMain`, smoke tests | `-tags smoke`, and `-tags e2e,smoke` |
| `e2e \|\| smoke` | Client, polling, tracing: nothing here can write on its own | Both |

Run and seen: `-tags smoke` and `-tags e2e,smoke` both list only the `TestSmoke_` tests; a smoke file that calls `createBooking` fails to compile (`undefined: createBooking`).

| Copy unchanged | Write for the product |
|---|---|
| `env_test.go`, `main_test.go`, `client_test.go`, `await_test.go`, `trace_test.go`, `guard_selfcheck_test.go`, `smoke_main_test.go` | `seed_test.go` (one create helper per kind of test data), one `journey_<name>_test.go` per journey, `smoke_test.go` |

The product below is an observatory's booking service; replace `booking`, `/bookings` and the endpoint names (`api`, `scheduler`) with the product's own. Endpoint names are the ones listed under `E2E_ENDPOINTS` in `tests/e2e/e2e.conf` (see `./environment-config.md`).

## Copy unchanged

### `tests/e2e/env_test.go`

```go
//go:build e2e && !smoke

package e2e

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/netip"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"
)

// Env is the throwaway cluster this run created. requireThrowawayCluster is the
// only way to get one, so nothing in the journey build can address anything else:
// no address is read from an environment variable or a flag.
type Env struct {
	RunID     string
	endpoints map[string]string // name -> 127.0.0.1:port, as written by the script
}

var runIDPattern = regexp.MustCompile(`^[a-z0-9][a-z0-9-]{0,39}$`)

// requireThrowawayCluster refuses unless the kubeconfig the script wrote for
// this run leads to a cluster on this machine that carries this run's marker.
func requireThrowawayCluster(ctx context.Context) (Env, error) {
	runID := os.Getenv("E2E_RUN_ID")
	if !runIDPattern.MatchString(runID) {
		return Env{}, errors.New("E2E_RUN_ID is not set: start the suite with tests/e2e/run-e2e-environment.sh (make e2e)")
	}
	kubeconfig := os.Getenv("E2E_KUBECONFIG")
	if err := checkKubeconfigPath(kubeconfig); err != nil {
		return Env{}, err
	}
	kubectl := func(args ...string) ([]byte, error) {
		ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
		defer cancel()
		// --cache-dir keeps kubectl's discovery cache out of ~/.kube/cache.
		full := append([]string{"--kubeconfig", kubeconfig, "--context", "kind-e2e-" + runID,
			"--cache-dir", filepath.Join(filepath.Dir(kubeconfig), "kube-cache")}, args...)
		out, err := exec.CommandContext(ctx, "kubectl", full...).Output()
		if err != nil {
			var exit *exec.ExitError
			if errors.As(err, &exit) {
				return nil, fmt.Errorf("kubectl %s: %s", strings.Join(args, " "), strings.TrimSpace(string(exit.Stderr)))
			}
			return nil, fmt.Errorf("kubectl %s: %w", strings.Join(args, " "), err)
		}
		return out, nil
	}
	server, err := kubectl("config", "view", "--minify", "-o", "jsonpath={.clusters[0].cluster.server}")
	if err != nil {
		return Env{}, fmt.Errorf("no context kind-e2e-%s in %s: %w", runID, kubeconfig, err)
	}
	parsed, err := url.Parse(string(server))
	if err != nil {
		return Env{}, fmt.Errorf("cluster address %q: %w", server, err)
	}
	if err := checkLoopback(parsed.Host); err != nil {
		return Env{}, fmt.Errorf("the cluster's API server: %w", err)
	}
	raw, err := kubectl("get", "configmap", "e2e-run-marker", "-n", "default", "-o", "json")
	if err != nil {
		return Env{}, fmt.Errorf("this cluster carries no run marker, so this run did not create it: %w", err)
	}
	var marker struct {
		Data map[string]string `json:"data"`
	}
	if err := json.Unmarshal(raw, &marker); err != nil {
		return Env{}, fmt.Errorf("run marker: %w", err)
	}
	return envFromMarker(runID, marker.Data)
}

// envFromMarker checks the marker against this run and keeps only loopback addresses.
func envFromMarker(runID string, data map[string]string) (Env, error) {
	if data["run-id"] != runID {
		return Env{}, fmt.Errorf("run marker says run %q, this run is %q", data["run-id"], runID)
	}
	env := Env{RunID: runID, endpoints: map[string]string{}}
	for key, addr := range data {
		name, isEndpoint := strings.CutPrefix(key, "endpoint.")
		if !isEndpoint {
			continue
		}
		if err := checkLoopback(addr); err != nil {
			return Env{}, fmt.Errorf("endpoint %s: %w", name, err)
		}
		env.endpoints[name] = addr
	}
	if len(env.endpoints) == 0 {
		return Env{}, errors.New("run marker names no endpoint")
	}
	return env, nil
}

// checkLoopback accepts only a literal loopback IP with a port: a host name
// could resolve anywhere.
func checkLoopback(hostport string) error {
	addr, err := netip.ParseAddrPort(hostport)
	if err != nil {
		return fmt.Errorf("%q is not a literal IP address and port", hostport)
	}
	if !addr.Addr().IsLoopback() || addr.Port() == 0 {
		return fmt.Errorf("%q is not on this machine (loopback only)", hostport)
	}
	return nil
}

// checkKubeconfigPath refuses the caller's own kubeconfig: the default file and
// anything KUBECONFIG names.
func checkKubeconfigPath(path string) error {
	if path == "" || !filepath.IsAbs(path) {
		return errors.New("E2E_KUBECONFIG is not set to an absolute path: start the suite with tests/e2e/run-e2e-environment.sh (make e2e)")
	}
	resolved, err := filepath.EvalSymlinks(path)
	if err != nil {
		return fmt.Errorf("E2E_KUBECONFIG: %w", err)
	}
	own := filepath.SplitList(os.Getenv("KUBECONFIG"))
	if home, err := os.UserHomeDir(); err == nil {
		own = append(own, filepath.Join(home, ".kube", "config"))
	}
	for _, candidate := range own {
		if candidate == "" {
			continue
		}
		if other, err := filepath.EvalSymlinks(candidate); err == nil && other == resolved {
			return fmt.Errorf("E2E_KUBECONFIG is the caller's own kubeconfig (%s); the suite uses only the file the script created for this run", path)
		}
	}
	return nil
}

// Addr returns the loopback address of a named endpoint of this run's cluster.
func (e Env) Addr(name string) (string, error) {
	addr, ok := e.endpoints[name]
	if !ok {
		return "", fmt.Errorf("this run's cluster has no endpoint %q (see E2E_ENDPOINTS in tests/e2e/e2e.conf)", name)
	}
	return addr, nil
}

// RequireThrowaway refuses any address that is not an endpoint of this run's
// cluster. Every direct connection (a database for seeding) passes through it.
func (e Env) RequireThrowaway(hostport string) error {
	for _, addr := range e.endpoints {
		if addr == hostport {
			return nil
		}
	}
	return fmt.Errorf("refusing %q: it is not an endpoint of this run's throwaway cluster", hostport)
}

// Client returns an HTTP client bound to one endpoint of this run's cluster.
func (e Env) Client(name string) (*Client, error) {
	addr, err := e.Addr(name)
	if err != nil {
		return nil, err
	}
	return newClient(&url.URL{Scheme: "http", Host: addr}), nil
}

// readOnlyBuild is false in the journey build: journeys create and delete their own data.
const readOnlyBuild = false
```

### `tests/e2e/main_test.go`

```go
//go:build e2e && !smoke

package e2e

import (
	"context"
	"fmt"
	"os"
	"testing"
)

// env is the only source of addresses in the journey build.
var env Env

func TestMain(m *testing.M) {
	var err error
	if env, err = requireThrowawayCluster(context.Background()); err != nil {
		fmt.Fprintf(os.Stderr, "REFUSED: end-to-end journeys run only against the throwaway cluster of their own run.\n  %v\n", err)
		os.Exit(1)
	}
	shutdown := setupTracing()
	code := m.Run()
	_ = shutdown(context.Background())
	os.Exit(code)
}
```

### `tests/e2e/client_test.go`

```go
//go:build e2e || smoke

package e2e

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"time"

	"go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp"
)

// Client talks to one base address and nothing else.
type Client struct {
	base   *url.URL
	http   *http.Client
	Header http.Header // sent with every request (a tenant, a token)
}

// bound refuses a request to any other host, and every write in the smoke build.
// It refuses before anything is sent.
type bound struct {
	host     string
	readOnly bool
	next     http.RoundTripper
}

func (b bound) RoundTrip(r *http.Request) (*http.Response, error) {
	if r.URL.Host != b.host {
		return nil, fmt.Errorf("refusing request to %s: this client is bound to %s", r.URL.Host, b.host)
	}
	if b.readOnly && r.Method != http.MethodGet && r.Method != http.MethodHead {
		return nil, fmt.Errorf("refusing %s %s: smoke tests are read-only", r.Method, r.URL.Path)
	}
	return b.next.RoundTrip(r)
}

// newClient is called after setupTracing: otelhttp reads the global propagator
// when the transport is built.
func newClient(base *url.URL) *Client {
	return &Client{
		base:   base,
		Header: http.Header{},
		http: &http.Client{
			Timeout:   15 * time.Second,
			Transport: bound{host: base.Host, readOnly: readOnlyBuild, next: otelhttp.NewTransport(http.DefaultTransport)},
		},
	}
}

// Do sends one request and decodes a JSON reply into out (nil to ignore it).
// target is a path on the base address; an absolute URL to another host is refused.
func (c *Client) Do(ctx context.Context, method, target string, in, out any) (int, error) {
	ref, err := url.Parse(target)
	if err != nil {
		return 0, err
	}
	var body io.Reader
	if in != nil {
		encoded, err := json.Marshal(in)
		if err != nil {
			return 0, err
		}
		body = bytes.NewReader(encoded)
	}
	req, err := http.NewRequestWithContext(ctx, method, c.base.ResolveReference(ref).String(), body)
	if err != nil {
		return 0, err
	}
	for key, values := range c.Header {
		req.Header[key] = values
	}
	if in != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()
	raw, err := io.ReadAll(resp.Body)
	if err != nil {
		return resp.StatusCode, err
	}
	if out != nil && len(raw) > 0 {
		if err := json.Unmarshal(raw, out); err != nil {
			return resp.StatusCode, fmt.Errorf("%s %s: status %d, body is not the expected JSON: %.200s", method, target, resp.StatusCode, raw)
		}
	}
	return resp.StatusCode, nil
}
```

### `tests/e2e/await_test.go`

```go
//go:build e2e || smoke

package e2e

import (
	"context"
	"testing"
	"time"
)

// eventually polls check until it returns nil or the deadline passes. It is the
// only way a test waits: no fixed sleep. On timeout it reports the last reason.
func eventually(t testing.TB, ctx context.Context, within time.Duration, what string, check func(context.Context) error) {
	t.Helper()
	ctx, cancel := context.WithTimeout(ctx, within)
	defer cancel()
	tick := time.NewTicker(200 * time.Millisecond)
	defer tick.Stop()
	var last error
	for {
		if last = check(ctx); last == nil {
			return
		}
		select {
		case <-ctx.Done():
			t.Fatalf("%s: not true within %s; last: %v", what, within, last)
		case <-tick.C:
		}
	}
}
```

### `tests/e2e/trace_test.go`

```go
//go:build e2e || smoke

package e2e

import (
	"context"
	"testing"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/propagation"
	sdktrace "go.opentelemetry.io/otel/sdk/trace"
)

// setupTracing registers an SDK tracer provider and the W3C propagator. Without
// the provider a span's trace id is all zeros; without the propagator no
// traceparent header is sent. Call it in TestMain before any client is built.
func setupTracing() (shutdown func(context.Context) error) {
	provider := sdktrace.NewTracerProvider()
	otel.SetTracerProvider(provider)
	otel.SetTextMapPropagator(propagation.TraceContext{})
	return provider.Shutdown
}

// startJourney starts the one span a test's requests travel under and returns
// its context and trace id. The span is ended when the test ends, and a failed
// test prints trace_id=<id>: the id every service on the path received.
func startJourney(t *testing.T) (context.Context, string) {
	t.Helper()
	ctx, span := otel.Tracer("e2e").Start(context.Background(), t.Name())
	if !span.SpanContext().IsValid() {
		t.Fatal("no valid trace id: setupTracing did not run before this test")
	}
	id := span.SpanContext().TraceID().String()
	t.Cleanup(func() {
		span.End()
		if t.Failed() {
			t.Logf("trace_id=%s", id)
		}
	})
	return ctx, id
}
```

### `tests/e2e/guard_selfcheck_test.go`

```go
//go:build e2e && !smoke

package e2e

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"
)

// These tests keep the safety guards honest on every run. Each one is a case
// that must be refused.

func TestGuard_ClientRefusesAnotherHost(t *testing.T) {
	var hits atomic.Int64
	elsewhere := httptest.NewServer(http.HandlerFunc(func(http.ResponseWriter, *http.Request) { hits.Add(1) }))
	defer elsewhere.Close()
	api, err := env.Client("api")
	if err != nil {
		t.Fatal(err)
	}
	_, err = api.Do(context.Background(), http.MethodPost, elsewhere.URL+"/anything", map[string]any{"x": 1}, nil)
	if err == nil || !strings.Contains(err.Error(), "refusing request") {
		t.Fatalf("a request to another host was not refused: %v", err)
	}
	if hits.Load() != 0 {
		t.Fatalf("the other host received %d request(s); the refusal must come before anything is sent", hits.Load())
	}
}

func TestGuard_SeedingRefusesAnAddressOutsideTheCluster(t *testing.T) {
	for _, addr := range []string{"db.staging.example:5432", "10.0.0.7:5432", "127.0.0.1:5432", "localhost:5432"} {
		if err := env.RequireThrowaway(addr); err == nil {
			t.Errorf("%s was accepted; only this run's own endpoints may be", addr)
		}
	}
	own, err := env.Addr("api")
	if err != nil {
		t.Fatal(err)
	}
	if err := env.RequireThrowaway(own); err != nil {
		t.Errorf("this run's own endpoint was refused: %v", err)
	}
}

func TestGuard_MarkerMustBeThisRunAndLoopback(t *testing.T) {
	cases := map[string]map[string]string{
		"another run's marker":   {"run-id": "someone-else", "endpoint.api": "127.0.0.1:30080"},
		"an address off machine": {"run-id": env.RunID, "endpoint.api": "10.20.30.40:443"},
		"a host name":            {"run-id": env.RunID, "endpoint.api": "api.staging.example:443"},
		"no endpoint":            {"run-id": env.RunID},
	}
	for name, data := range cases {
		if _, err := envFromMarker(env.RunID, data); err == nil {
			t.Errorf("%s was accepted", name)
		}
	}
}
```

### `tests/e2e/smoke_main_test.go`

```go
//go:build smoke

package e2e

import (
	"context"
	"flag"
	"fmt"
	"net/url"
	"os"
	"testing"
)

// The smoke build holds read-only tests only. It is the one selection that may
// be pointed at a deployed environment, which is why it cannot write: every
// client refuses anything but GET and HEAD, and the files that create or delete
// data are not compiled into it (they are tagged `e2e && !smoke`).
const readOnlyBuild = true

var (
	tenant = flag.String("tenant", "", "tenant the smoke run reads as (sent as X-Tenant)")
	smoke  *Client
)

func TestMain(m *testing.M) {
	flag.Parse()
	base, err := url.Parse(os.Getenv("E2E_SMOKE_URL"))
	if err != nil || base.Host == "" || (base.Scheme != "http" && base.Scheme != "https") {
		fmt.Fprintln(os.Stderr, "REFUSED: set E2E_SMOKE_URL to the base address the read-only smoke tests read from, for example http://127.0.0.1:8080")
		os.Exit(1)
	}
	shutdown := setupTracing()
	smoke = newClient(base)
	if *tenant != "" {
		smoke.Header.Set("X-Tenant", *tenant)
	}
	code := m.Run()
	_ = shutdown(context.Background())
	os.Exit(code)
}
```

## Write for the product

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

// ref gives a reference that belongs to one test of one run: the run id, the
// test name and a counter. The same run and test give the same references, so a
// failure can be found again in the logs; nothing is random.
func ref(t *testing.T) string {
	name := strings.NewReplacer("/", "-", "_", "-").Replace(strings.ToLower(t.Name()))
	return fmt.Sprintf("%s-%s-%d", env.RunID, name, refCounter.Add(1))
}

// booking is what the public API returns for a booking.
type booking struct {
	ID     string         `json:"id"`
	Status string         `json:"status"`
	Body   map[string]any `json:"body"`
}

// createBooking creates test data the way a user would, through the public API,
// and registers its removal at once, so a failed test cleans up too. The
// removal reports its own failure.
func createBooking(t *testing.T, ctx context.Context, api *Client, fields map[string]any) booking {
	t.Helper()
	var made booking
	status, err := api.Do(ctx, http.MethodPost, "/bookings", fields, &made)
	if err != nil || status != http.StatusCreated {
		t.Fatalf("create booking: status %d, err %v", status, err)
	}
	t.Cleanup(func() {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		status, err := api.Do(ctx, http.MethodDelete, "/bookings/"+made.ID, nil, nil)
		if err != nil || (status != http.StatusNoContent && status != http.StatusNotFound) {
			t.Errorf("cleanup of booking %s: status %d, err %v", made.ID, status, err)
		}
	})
	return made
}
```

### `tests/e2e/journey_booking_test.go`

```go
//go:build e2e && !smoke

package e2e

import (
	"context"
	"fmt"
	"net/http"
	"testing"
	"time"
)

// TestJourney_BookedSlotIsAllocated proves AC-US-4.1 and AC-US-4.2: an astronomer
// books an observing slot, and the scheduler allocates telescope time for it.
// Two deployed services and their database take part; the allocation arrives
// later, so the test polls for it.
func TestJourney_BookedSlotIsAllocated(t *testing.T) {
	ctx, _ := startJourney(t)
	api, err := env.Client("api")
	if err != nil {
		t.Fatal(err)
	}
	scheduler, err := env.Client("scheduler")
	if err != nil {
		t.Fatal(err)
	}

	made := createBooking(t, ctx, api, map[string]any{"reference": ref(t), "telescope": "north-dome", "night": "2026-12-03"})
	if made.Status != "pending" {
		t.Fatalf("new booking status = %q, want pending", made.Status)
	}

	var confirmed booking
	eventually(t, ctx, 20*time.Second, "booking "+made.ID+" confirmed", func(ctx context.Context) error {
		status, err := api.Do(ctx, http.MethodGet, "/bookings/"+made.ID, nil, &confirmed)
		if err != nil {
			return err
		}
		if status != http.StatusOK || confirmed.Status != "confirmed" {
			return fmt.Errorf("status %d, booking status %q", status, confirmed.Status)
		}
		return nil
	})

	allocationID, _ := confirmed.Body["downstream_id"].(string)
	var allocation booking
	status, err := scheduler.Do(ctx, http.MethodGet, "/allocations/"+allocationID, nil, &allocation)
	if err != nil || status != http.StatusOK {
		t.Fatalf("allocation %q: status %d, err %v", allocationID, status, err)
	}
	if allocation.Body["source_id"] != made.ID {
		t.Fatalf("allocation is for booking %v, want %s", allocation.Body["source_id"], made.ID)
	}
}

// TestJourney_CancelledBookingIsGone proves AC-US-5.1: a cancelled booking can no
// longer be read.
func TestJourney_CancelledBookingIsGone(t *testing.T) {
	ctx, _ := startJourney(t)
	api, err := env.Client("api")
	if err != nil {
		t.Fatal(err)
	}
	made := createBooking(t, ctx, api, map[string]any{"reference": ref(t), "telescope": "south-dome", "night": "2026-12-04"})
	if status, err := api.Do(ctx, http.MethodDelete, "/bookings/"+made.ID, nil, nil); err != nil || status != http.StatusNoContent {
		t.Fatalf("cancel: status %d, err %v", status, err)
	}
	if status, err := api.Do(ctx, http.MethodGet, "/bookings/"+made.ID, nil, nil); err != nil || status != http.StatusNotFound {
		t.Fatalf("read after cancel: status %d, err %v; want 404", status, err)
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

// TestSmoke_BookingsCanBeListed reads the booking list: the service is up, its
// database answers and the read path works. It creates nothing.
func TestSmoke_BookingsCanBeListed(t *testing.T) {
	ctx, _ := startJourney(t)
	var bookings []map[string]any
	status, err := smoke.Do(ctx, http.MethodGet, "/bookings", nil, &bookings)
	if err != nil || status != http.StatusOK {
		t.Fatalf("list bookings: status %d, err %v", status, err)
	}
}

// TestSmoke_WritesAreRefused keeps the read-only guard honest on every run.
func TestSmoke_WritesAreRefused(t *testing.T) {
	ctx, _ := startJourney(t)
	for _, method := range []string{http.MethodPost, http.MethodPut, http.MethodPatch, http.MethodDelete} { // smoke-refusal-check: each must be refused
		_, err := smoke.Do(ctx, method, "/bookings", map[string]any{"x": 1}, nil)
		if err == nil || !strings.Contains(err.Error(), "read-only") {
			t.Errorf("%s was not refused: %v", method, err)
		}
	}
}
```

## What to keep when changing these

- A journey starts with `startJourney(t)` and sends every request with the context it returns. A request built without that context carries no `traceparent`.
- Test data is created through the public API by a helper that registers its removal at once (`t.Cleanup`) and reports a failed removal. A product with no public way to create some state uses `./direct-database-seed.md`.
- A wait is `eventually(...)` with a deadline. There is no `time.Sleep` in the suite.
- A journey's comment names the acceptance criteria it proves (`AC-US-n.m`); the test report lists them.
- A smoke test only reads. The comment `smoke-refusal-check` on the one line that lists write methods tells the validator that those requests are there to be refused.
- A test is never skipped with `t.Skip`. An unstable test goes into `tests/e2e/quarantine.txt` with an issue and a deadline (`../references/retry-and-quarantine.md`).
