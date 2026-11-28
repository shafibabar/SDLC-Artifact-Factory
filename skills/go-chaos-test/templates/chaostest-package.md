# The Chaos Test Support Package

Self-contained. Copy when the first chaos experiment is written. **Copy unchanged** into `internal/test/chaostest/` (the test-scaffolding folder, excluded from the coverage gate as a class, D048 2026-11-27). The module path in the imports is the lab's (`example.com/harbourpilot`); replace it with the product's. Nothing else changes.

Both files carry `//go:build chaos`, so `make ci`, `go vet ./...` and the coverage gate never compile them (W3-D10). Run on 2026-11-28 with Go 1.27.4 and `-race`: both tests pass; the package is used by every test in `./pattern-tests.md` and `./toxiproxy-setup.md`.

What it gives:

| Name | What it does | Rule it keeps |
|---|---|---|
| `FaultTransport` | An `http.RoundTripper` that injects a `Fault`: a status (a response with a **nil** error), a connection error (a nil response), a delay that ends with the request's context | Go's `RoundTripper` contract: safe for concurrent use, never modifies the request, closes the request body when it does not pass it on |
| `Dependency` | A stand-in for a service the product calls, with a settable fault, counting every arrival and every request whose context ended early | Counts are taken **at the dependency**, which is where "fails fast" and "no retry storm" are measured |
| `Invalid` | Ends a test with `CHAOS-INVALID: ...`; the runner turns that into the INVALID verdict | A fault never confirmed, or a steady state that did not hold, is never a pass |
| `Toxiproxy`, `AddToxic` | The run's Toxiproxy client from `E2E_ADDR_TOXIPROXY` (loopback only, `CHAOS-REFUSED` otherwise); a toxic added with every error checked, confirmed listed, removed on cleanup and its removal verified (`CHAOS-FAULT-LEFT` otherwise) | Every injection error checked; removal on every path, verified |

### `internal/test/chaostest/chaostest.go`

```go
//go:build chaos

// Package chaostest is test support for chaos experiments, compiled only with
// -tags chaos: a fault-injecting http.RoundTripper, a stand-in dependency that
// counts what reaches it, Toxiproxy helpers that check every error and verify
// removal, and the INVALID and REFUSED markers run-chaos-experiment.sh reads.
package chaostest

import (
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	toxiproxy "github.com/Shopify/toxiproxy/v2/client"
)

// Invalid ends the test as INVALID: the experiment proved nothing (the fault
// never took effect, or the steady state did not hold before it).
func Invalid(t testing.TB, format string, args ...any) {
	t.Helper()
	t.Fatalf("CHAOS-INVALID: "+format, args...)
}

// Fault is one injected misbehaviour. Status > 0 answers that status; Err
// fails the round trip (transport only); Delay waits first, or until the
// request's context ends.
type Fault struct {
	Status int
	Err    error
	Delay  time.Duration
}

// FaultTransport wraps a RoundTripper and injects the current Fault. It keeps
// the RoundTripper contract: safe for concurrent use, never modifies the
// request, closes the request body whenever it does not pass the request on,
// returns a nil error with every response (an injected 503 included), and ends
// an injected delay when the request's context ends.
type FaultTransport struct {
	Next     http.RoundTripper
	mu       sync.Mutex
	fault    *Fault
	injected atomic.Int64
	calls    atomic.Int64
}

func (f *FaultTransport) Set(fault Fault) { f.mu.Lock(); f.fault = &fault; f.mu.Unlock() }
func (f *FaultTransport) Clear()          { f.mu.Lock(); f.fault = nil; f.mu.Unlock() }

// Injected counts round trips that met a fault; Calls counts every round trip.
func (f *FaultTransport) Injected() int64 { return f.injected.Load() }
func (f *FaultTransport) Calls() int64    { return f.calls.Load() }

func (f *FaultTransport) RoundTrip(req *http.Request) (*http.Response, error) {
	f.calls.Add(1)
	next := f.Next
	if next == nil {
		next = http.DefaultTransport
	}
	f.mu.Lock()
	fault := f.fault
	f.mu.Unlock()
	if fault == nil {
		return next.RoundTrip(req)
	}
	f.injected.Add(1)
	if fault.Delay > 0 {
		timer := time.NewTimer(fault.Delay)
		defer timer.Stop()
		select {
		case <-req.Context().Done():
			closeBody(req)
			return nil, req.Context().Err()
		case <-timer.C:
		}
	}
	switch {
	case fault.Err != nil:
		closeBody(req)
		return nil, fault.Err
	case fault.Status > 0:
		closeBody(req)
		body := "injected fault"
		return &http.Response{
			StatusCode: fault.Status, Status: fmt.Sprintf("%d %s", fault.Status, http.StatusText(fault.Status)),
			Proto: "HTTP/1.1", ProtoMajor: 1, ProtoMinor: 1,
			Header:        http.Header{"Content-Type": {"text/plain; charset=utf-8"}},
			Body:          io.NopCloser(strings.NewReader(body)),
			ContentLength: int64(len(body)), Request: req,
		}, nil
	}
	return next.RoundTrip(req)
}

func closeBody(req *http.Request) {
	if req.Body != nil {
		_ = req.Body.Close()
	}
}

// RequireInjected marks the experiment INVALID when the fault never met a request.
func RequireInjected(t testing.TB, f *FaultTransport) {
	t.Helper()
	if f.Injected() == 0 {
		Invalid(t, "the fault was never injected: no request met it")
	}
}

// Dependency is a stand-in for a service the product calls. It answers with
// the handler while no fault is set, and records when each request arrived
// and when a request's context ended before it was answered.
type Dependency struct {
	*httptest.Server
	mu        sync.Mutex
	fault     *Fault
	arrivals  []time.Time
	cancelled []time.Time
}

func NewDependency(t testing.TB, healthy http.HandlerFunc) *Dependency {
	t.Helper()
	d := &Dependency{}
	d.Server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		d.mu.Lock()
		d.arrivals = append(d.arrivals, time.Now())
		fault := d.fault
		d.mu.Unlock()
		if fault != nil && fault.Delay > 0 {
			timer := time.NewTimer(fault.Delay)
			defer timer.Stop()
			select {
			case <-r.Context().Done():
				d.mu.Lock()
				d.cancelled = append(d.cancelled, time.Now())
				d.mu.Unlock()
				return
			case <-timer.C:
			}
		}
		if fault != nil && fault.Status > 0 {
			http.Error(w, "injected fault", fault.Status)
			return
		}
		healthy(w, r)
	}))
	t.Cleanup(func() { d.Clear(); d.CloseClientConnections(); d.Close() })
	return d
}

func (d *Dependency) Set(fault Fault) { d.mu.Lock(); d.fault = &fault; d.mu.Unlock() }
func (d *Dependency) Clear()          { d.mu.Lock(); d.fault = nil; d.mu.Unlock() }

// Arrivals returns when each request reached the dependency, in order.
func (d *Dependency) Arrivals() []time.Time {
	d.mu.Lock()
	defer d.mu.Unlock()
	return append([]time.Time(nil), d.arrivals...)
}

// Calls is the number of requests that reached the dependency.
func (d *Dependency) Calls() int { return len(d.Arrivals()) }

// Cancelled returns when requests' contexts ended before they were answered.
func (d *Dependency) Cancelled() []time.Time {
	d.mu.Lock()
	defer d.mu.Unlock()
	return append([]time.Time(nil), d.cancelled...)
}

// Toxiproxy returns a client for the Toxiproxy API of this run's throwaway
// cluster: E2E_ADDR_TOXIPROXY, published on loopback by run-e2e-environment.sh.
// Anything else is refused before a toxic is added.
func Toxiproxy(t testing.TB) *toxiproxy.Client {
	t.Helper()
	addr := os.Getenv("E2E_ADDR_TOXIPROXY")
	host, _, err := net.SplitHostPort(addr)
	if os.Getenv("E2E_RUN_ID") == "" || err != nil || host != "127.0.0.1" {
		t.Fatalf("CHAOS-REFUSED: E2E_RUN_ID and a loopback E2E_ADDR_TOXIPROXY are set only inside this run's environment (got %q)", addr)
	}
	return toxiproxy.NewClient("http://" + addr)
}

// AddToxic adds a toxic and checks every step: the proxy exists, the toxic was
// accepted, and the proxy now lists it. Any failure is INVALID: no fault was
// injected. It returns the removal, which also runs on cleanup, so a failing
// test leaves no fault behind; either way the removal is verified.
func AddToxic(t testing.TB, client *toxiproxy.Client, proxyName, name, typeName, stream string, attrs toxiproxy.Attributes) (remove func()) {
	t.Helper()
	proxy, err := client.Proxy(proxyName)
	if err != nil {
		Invalid(t, "proxy %q: %v (no fault was injected)", proxyName, err)
	}
	if _, err := proxy.AddToxic(name, typeName, stream, 1.0, attrs); err != nil {
		Invalid(t, "adding toxic %q to %q: %v (no fault was injected)", name, proxyName, err)
	}
	var once sync.Once
	remove = func() { once.Do(func() { removeToxic(t, client, proxyName, name) }) }
	t.Cleanup(remove)
	if !listed(t, proxy, name) {
		Invalid(t, "toxic %q was accepted but %q does not list it", name, proxyName)
	}
	return remove
}

func removeToxic(t testing.TB, client *toxiproxy.Client, proxyName, name string) {
	proxy, err := client.Proxy(proxyName)
	if err != nil {
		t.Errorf("CHAOS-FAULT-LEFT: cannot read proxy %q to remove toxic %q: %v", proxyName, name, err)
		return
	}
	if err := proxy.RemoveToxic(name); err != nil {
		t.Errorf("CHAOS-FAULT-LEFT: removing toxic %q from %q: %v", name, proxyName, err)
	}
	if listed(t, proxy, name) {
		t.Errorf("CHAOS-FAULT-LEFT: toxic %q is still listed on %q after removal", name, proxyName)
	}
}

func listed(t testing.TB, proxy *toxiproxy.Proxy, name string) bool {
	toxics, err := proxy.Toxics()
	if err != nil {
		t.Errorf("listing toxics of %q: %v", proxy.Name, err)
		return true // unknown counts as present: never claim a removal that was not seen
	}
	for _, toxic := range toxics {
		if toxic.Name == name {
			return true
		}
	}
	return false
}
```

### `internal/test/chaostest/transport_chaos_test.go`

```go
//go:build chaos

package chaostest_test

import (
	"context"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"example.com/harbourpilot/internal/test/chaostest"
)

type closeRecorder struct {
	io.Reader
	closed bool
}

func (c *closeRecorder) Close() error { c.closed = true; return nil }

func TestFaultTransport_KeepsTheRoundTripperContract(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte("real")) }))
	defer upstream.Close()
	ft := &chaostest.FaultTransport{}

	ft.Set(chaostest.Fault{Status: http.StatusServiceUnavailable})
	body := &closeRecorder{Reader: strings.NewReader("payload")}
	req, _ := http.NewRequest(http.MethodPost, upstream.URL, body)
	resp, err := ft.RoundTrip(req)
	if err != nil || resp == nil || resp.StatusCode != http.StatusServiceUnavailable {
		t.Fatalf("an injected 503 is a response with a nil error; got %v, %v", resp, err)
	}
	_ = resp.Body.Close()
	if !body.closed {
		t.Fatal("the request body was not closed when the request was not passed on")
	}

	boom := errors.New("connection reset by fault")
	ft.Set(chaostest.Fault{Err: boom})
	if resp, err := ft.RoundTrip(httptest.NewRequest(http.MethodGet, upstream.URL, nil)); resp != nil || !errors.Is(err, boom) {
		t.Fatalf("an injected connection failure is a nil response with the error; got %v, %v", resp, err)
	}

	ft.Set(chaostest.Fault{Delay: 5 * time.Second})
	ctx, cancel := context.WithTimeout(context.Background(), 50*time.Millisecond)
	defer cancel()
	req, _ = http.NewRequestWithContext(ctx, http.MethodGet, upstream.URL, nil)
	start := time.Now()
	if _, err := ft.RoundTrip(req); !errors.Is(err, context.DeadlineExceeded) || time.Since(start) > time.Second {
		t.Fatalf("an injected delay must end with the request's context; got %v after %v", err, time.Since(start))
	}

	ft.Clear()
	resp, err = ft.RoundTrip(httptest.NewRequest(http.MethodGet, upstream.URL, nil))
	if err != nil || resp.StatusCode != http.StatusOK {
		t.Fatalf("with no fault the request passes through; got %v, %v", resp, err)
	}
	_ = resp.Body.Close()
	if ft.Injected() != 3 || ft.Calls() != 4 {
		t.Fatalf("injected %d of %d calls, want 3 of 4", ft.Injected(), ft.Calls())
	}
}

func TestFaultTransport_IsSafeForConcurrentUse(t *testing.T) {
	ft := &chaostest.FaultTransport{}
	var wg sync.WaitGroup
	for i := 0; i < 50; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			if i%2 == 0 {
				ft.Set(chaostest.Fault{Status: http.StatusBadGateway})
			} else {
				ft.Set(chaostest.Fault{Err: errors.New("x")})
			}
			if resp, err := ft.RoundTrip(httptest.NewRequest(http.MethodGet, "http://127.0.0.1:9/", nil)); err == nil {
				_ = resp.Body.Close()
			}
		}(i)
	}
	wg.Wait()
	if ft.Injected() != 50 {
		t.Fatalf("injected %d, want 50", ft.Injected())
	}
}
```

What was run with it (2026-11-28): with a misspelt toxic type the 2.1.0 pattern (`_, _ = proxy.AddToxic(...)`) **passed** a "degrades when the tide tables are slow" test against a product with no fallback, because Toxiproxy answered `HTTP 400: invalid toxic type` and nothing was injected; `AddToxic` here ended the same test with `CHAOS-INVALID: adding toxic "tides-latency" to "tides": AddToxic: HTTP 400: invalid toxic type (no fault was injected)`.
