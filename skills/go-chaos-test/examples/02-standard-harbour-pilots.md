# Standard: Harbour Pilots, the Lab That Was Run

Self-contained. Read for the whole procedure on a standard product, with every pattern present, both ways, and with real Toxiproxy and Chaos Mesh in the throwaway cluster. Everything here was run on 2026-11-28 on macOS arm64 (Docker 29.9.3, Go 1.27.4, gobreaker v2.4.0, backoff v7.0.3, x/sync v0.25.0, Toxiproxy v2.13.0, kind v0.33.0 with `kindest/node:v1.37.0`, Helm v4.3.2, kubectl v1.36.1, Chaos Mesh 2.8.8).

## Input

Harbour Pilots schedules marine pilots onto ships. Its `harbour` service answers `GET /v1/tide-window?berth=` by calling the internal `tides` service. SLO-TIDE-01: the share of tide-window requests answered 200 in under 800 ms, objective 99 %. `integration-design` puts the call on the "internal, hot path" row. A second piece of code, `roster.Move`, moves a pilot between two boats' rosters under two locks. Two replicas, readiness probe.

## Step 1: what the product implements

| Downstream | Pattern | Present? | Settings | integration-design |
|---|---|---|---|---|
| tides | Circuit breaker | yes | trips at 5 consecutive failed calls, 10 s window, 5 s reset, 1 probe | same |
| tides | Retry | yes | 3 attempts, full jitter, 100 ms doubling to 5 s, transient only | same |
| tides | Timeout | yes | 300 ms per attempt, caller's deadline passed down | same |
| tides | Bulkhead | yes | 8 in flight, its own pool | one pool per downstream |
| tides | Fallback | yes | last good window, `X-Degraded: stale` | observable fallback |
| service | Load shedding | yes | 503 + `Retry-After` over 64 in flight | SRE: fail early and cheaply |
| roster | Lock order | yes | lower roster ID first | (go-concurrency-patterns) |

## The product's code (the lab)

These are the product's files the experiments were run against; a real product has its own. 
### `go.mod`

```text
module example.com/harbourpilot

go 1.27.4

require (
	github.com/Shopify/toxiproxy/v2 v2.13.0
	github.com/cenkalti/backoff/v7 v7.0.3
	github.com/sony/gobreaker/v2 v2.4.0
	golang.org/x/sync v0.25.0
)

require github.com/stretchr/testify v1.11.1 // indirect
```

### `internal/tides/client.go`

```go
// Package tides is the lab product's client for the tide-tables service: the
// resilience patterns integration-design asks of a hot-path internal call
// (bulkhead, circuit breaker, retry with full jitter, per-attempt timeout).
package tides

import (
	"context"
	"errors"
	"fmt"
	"io"
	"math/rand/v2"
	"net/http"
	"net/url"
	"time"

	"github.com/cenkalti/backoff/v7"
	"github.com/sony/gobreaker/v2"
	"golang.org/x/sync/semaphore"
)

// ErrUnavailable is every way the tide tables can be unavailable to a caller:
// the breaker is open, the bulkhead is full, or the attempts ran out.
var ErrUnavailable = errors.New("tides: unavailable")

// StatusError is a permanent answer (4xx other than 429): never retried.
type StatusError struct{ Code int }

func (e *StatusError) Error() string { return fmt.Sprintf("tides: status %d", e.Code) }

type Config struct {
	BaseURL         string
	Transport       http.RoundTripper
	AttemptTimeout  time.Duration
	MaxAttempts     uint
	InitialBackoff  time.Duration
	MaxBackoff      time.Duration
	BreakerFailures uint32
	BreakerWindow   time.Duration
	BreakerReset    time.Duration
	MaxConcurrent   int64
}

// DefaultConfig: integration-design's "internal, hot path" row (5 consecutive
// failures, 10 s window, 5 s reset; 3 attempts, 100 ms doubling, 5 s cap).
func DefaultConfig(baseURL string) Config {
	return Config{BaseURL: baseURL, Transport: http.DefaultTransport, AttemptTimeout: 300 * time.Millisecond,
		MaxAttempts: 3, InitialBackoff: 100 * time.Millisecond, MaxBackoff: 5 * time.Second,
		BreakerFailures: 5, BreakerWindow: 10 * time.Second, BreakerReset: 5 * time.Second, MaxConcurrent: 8}
}

type Client struct {
	cfg     Config
	http    *http.Client
	breaker *gobreaker.CircuitBreaker[[]byte]
	slots   *semaphore.Weighted
}

func New(cfg Config) *Client {
	permanent := func(err error) bool { var s *StatusError; return errors.As(err, &s) }
	return &Client{
		cfg:  cfg,
		http: &http.Client{Transport: cfg.Transport},
		breaker: gobreaker.NewCircuitBreaker[[]byte](gobreaker.Settings{
			Name:        "tides",
			MaxRequests: 1,
			Interval:    cfg.BreakerWindow,
			Timeout:     cfg.BreakerReset,
			ReadyToTrip: func(c gobreaker.Counts) bool { return c.ConsecutiveFailures >= cfg.BreakerFailures },
			// A permanent answer means the service is up; the caller's own cancellation says nothing about it.
			IsSuccessful: func(err error) bool { return err == nil || permanent(err) },
			IsExcluded:   func(err error) bool { return errors.Is(err, context.Canceled) },
		}),
		slots: semaphore.NewWeighted(cfg.MaxConcurrent),
	}
}

func (c *Client) Config() Config { return c.cfg }

// BreakerState is "closed", "open" or "half-open"; it is also exported as a metric.
func (c *Client) BreakerState() string { return c.breaker.State().String() }

// Window returns the tide window for a berth.
func (c *Client) Window(ctx context.Context, berth string) ([]byte, error) {
	if !c.slots.TryAcquire(1) {
		return nil, fmt.Errorf("%w: bulkhead full", ErrUnavailable)
	}
	defer c.slots.Release(1)
	body, err := c.breaker.Execute(func() ([]byte, error) {
		return backoff.Retry(ctx, func() ([]byte, error) { return c.attempt(ctx, berth) },
			backoff.WithMaxTries(c.cfg.MaxAttempts),
			backoff.WithBackOff(&fullJitter{initial: c.cfg.InitialBackoff, max: c.cfg.MaxBackoff}),
			backoff.WithMaxElapsedTime(0))
	})
	switch {
	case err == nil:
		return body, nil
	case errors.Is(err, gobreaker.ErrOpenState), errors.Is(err, gobreaker.ErrTooManyRequests):
		return nil, fmt.Errorf("%w: %v", ErrUnavailable, err)
	case ctx.Err() != nil: // the caller gave up; an attempt timing out is the dependency's failure
		return nil, err
	default:
		var s *StatusError
		if errors.As(err, &s) {
			return nil, s
		}
		return nil, fmt.Errorf("%w: %w", ErrUnavailable, err)
	}
}

func (c *Client) attempt(ctx context.Context, berth string) ([]byte, error) {
	actx, cancel := context.WithTimeout(ctx, c.cfg.AttemptTimeout)
	defer cancel()
	req, err := http.NewRequestWithContext(actx, http.MethodGet, c.cfg.BaseURL+"/windows?berth="+url.QueryEscape(berth), nil)
	if err != nil {
		return nil, backoff.Permanent(err)
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	switch {
	case err != nil:
		return nil, err
	case resp.StatusCode >= 500 || resp.StatusCode == http.StatusTooManyRequests:
		return nil, fmt.Errorf("tides: transient status %d", resp.StatusCode)
	case resp.StatusCode >= 400:
		return nil, backoff.Permanent(&StatusError{Code: resp.StatusCode})
	}
	return body, nil
}

// fullJitter waits a random time between 0 and the doubling cap (integration-design: full jitter).
type fullJitter struct{ initial, max, cap time.Duration }

func (b *fullJitter) Reset() { b.cap = b.initial }
func (b *fullJitter) NextBackOff() time.Duration {
	d := time.Duration(rand.Int64N(int64(b.cap) + 1))
	if b.cap = 2 * b.cap; b.cap > b.max {
		b.cap = b.max
	}
	return d
}
```

### `internal/web/handler.go`

```go
// Package web is the lab product's HTTP surface: the tide window for a berth,
// a degraded answer from the last good value when the tide tables are
// unavailable, and load shedding when too many requests are in flight.
package web

import (
	"context"
	"errors"
	"net/http"
	"sync"
	"sync/atomic"
	"time"

	"example.com/harbourpilot/internal/tides"
)

type Windows interface {
	Window(ctx context.Context, berth string) ([]byte, error)
}

type Handler struct {
	tides    Windows
	mu       sync.Mutex
	lastGood map[string][]byte
}

func NewHandler(t Windows) *Handler { return &Handler{tides: t, lastGood: map[string][]byte{}} }

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	berth := r.URL.Query().Get("berth")
	ctx, cancel := context.WithTimeout(r.Context(), 600*time.Millisecond)
	defer cancel()
	body, err := h.tides.Window(ctx, berth)
	if err == nil {
		h.mu.Lock()
		h.lastGood[berth] = body
		h.mu.Unlock()
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write(body)
		return
	}
	var status *tides.StatusError
	if errors.As(err, &status) {
		http.Error(w, "unknown berth", http.StatusNotFound)
		return
	}
	h.mu.Lock()
	stale, ok := h.lastGood[berth]
	h.mu.Unlock()
	if !ok {
		w.Header().Set("Retry-After", "5")
		http.Error(w, "tide tables unavailable", http.StatusServiceUnavailable)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("X-Degraded", "stale")
	_, _ = w.Write(stale)
}

// Shed answers 503 at once when more than limit requests are already in flight.
func Shed(limit int64, next http.Handler) http.Handler {
	var inFlight atomic.Int64
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if inFlight.Add(1) > limit {
			inFlight.Add(-1)
			w.Header().Set("Retry-After", "1")
			http.Error(w, "overloaded", http.StatusServiceUnavailable)
			return
		}
		defer inFlight.Add(-1)
		next.ServeHTTP(w, r)
	})
}
```

### `internal/roster/roster.go`

```go
// Package roster moves pilots between two boats' rosters. The shipped lock
// order: always lock the roster with the lower ID first.
package roster

import (
	"errors"
	"sync"
)

type Roster struct {
	ID     int
	mu     sync.Mutex
	pilots map[string]bool
}

func New(id int, pilots ...string) *Roster {
	r := &Roster{ID: id, pilots: map[string]bool{}}
	for _, p := range pilots {
		r.pilots[p] = true
	}
	return r
}

// betweenLocks is nil in every shipped build; a chaos build sets it (hook_chaos.go).
var betweenLocks func()

var ErrNotOnRoster = errors.New("roster: pilot not on roster")

func Move(from, to *Roster, pilot string) error {
	first, second := from, to
	if to.ID < from.ID {
		first, second = to, from
	}
	first.mu.Lock()
	defer first.mu.Unlock()
	if betweenLocks != nil {
		betweenLocks()
	}
	second.mu.Lock()
	defer second.mu.Unlock()
	if !from.pilots[pilot] {
		return ErrNotOnRoster
	}
	delete(from.pilots, pilot)
	to.pilots[pilot] = true
	return nil
}

func (r *Roster) Count() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return len(r.pilots)
}
```

### `cmd/harbour/main.go`

```go
// The lab binary: "product" serves the tide window through the tides client;
// "tides" is the stand-in tide-tables service it depends on.
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"example.com/harbourpilot/internal/tides"
	"example.com/harbourpilot/internal/web"
)

func main() {
	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8080"
	}
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { _, _ = w.Write([]byte("ok")) })
	switch os.Getenv("MODE") {
	case "tides":
		mux.HandleFunc("/windows", func(w http.ResponseWriter, r *http.Request) {
			fmt.Fprintf(w, `{"berth":%q,"opens":"06:10","closes":"08:40"}`, r.URL.Query().Get("berth"))
		})
	default:
		client := tides.New(tides.DefaultConfig(os.Getenv("TIDES_URL")))
		mux.Handle("/v1/tide-window", web.Shed(64, web.NewHandler(client)))
	}
	srv := &http.Server{Addr: addr, Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	log.Fatal(srv.ListenAndServe())
}
```

### `build/harbour.Dockerfile`

```text
FROM scratch
COPY harbour /harbour
USER 65532:65532
ENTRYPOINT ["/harbour"]
```

### `deploy/harbour/Chart.yaml`

```yaml
apiVersion: v2
name: harbour
version: 0.1.0
```

### `deploy/harbour/values.yaml`

```yaml
mode: product
replicas: 1
image: harbour:e2e
env: {}
nodePort: 0
```

### `deploy/harbour/templates/all.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
  labels: {app: {{ .Release.Name }}, app.kubernetes.io/instance: {{ .Release.Name }}}
spec:
  replicas: {{ .Values.replicas }}
  selector: {matchLabels: {app: {{ .Release.Name }}}}
  template:
    metadata:
      labels: {app: {{ .Release.Name }}}
    spec:
      containers:
        - name: app
          image: {{ .Values.image }}
          imagePullPolicy: Never
          env:
            - {name: MODE, value: {{ .Values.mode | quote }}}
            {{- range $k, $v := .Values.env }}
            - {name: {{ $k }}, value: {{ $v | quote }}}
            {{- end }}
          ports: [{containerPort: 8080}]
          readinessProbe: {httpGet: {path: /healthz, port: 8080}, periodSeconds: 2}
          resources: {requests: {cpu: 50m, memory: 32Mi}, limits: {cpu: 500m, memory: 64Mi}}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}
spec:
  type: {{ if .Values.nodePort }}NodePort{{ else }}ClusterIP{{ end }}
  selector: {app: {{ .Release.Name }}}
  ports:
    - port: 8080
      targetPort: 8080
      {{- if .Values.nodePort }}
      nodePort: {{ .Values.nodePort }}
      {{- end }}
```

The chaos files are exactly those of `../templates/` (test support, pattern tests, Toxiproxy chart and values, Chaos Mesh values and manifests, experiment definitions, `chaos-e2e.conf`, `chaos-suites.conf`, `e2e.conf`, `Makefile`, workflow), with the two scripts copied unchanged.

## Output: the run

`make chaos`, run on the files extracted from this skill's templates and this example (one throwaway cluster, under 10 minutes from build to deletion, exit 0):

| Experiment | Verdict | What the runner said |
|---|---|---|
| patterns-in-process (all Go tests, `-race` off) | PASS | every pattern assertion held; Toxiproxy reset, no toxics left |
| degrade-on-tides-latency (Toxiproxy, 2 s) | PASS | SLI 1.000 before, 1.000 during (107 requests, all 107 marked `X-Degraded`), recovered |
| pod-kill-harbour (PodChaos, one of two pods) | PASS | SLI 1.000 before and during (146 requests), recovered |
| network-partition-tides (NetworkChaos, 100 % loss to tides) | PASS | SLI 1.000 during (103 requests, all marked `X-Degraded`: the cut reached the path); removal verified |

## Each pattern, both ways

| Pattern | Correct product | Broken copy | Message |
|---|---|---|---|
| Breaker | PASS | `ReadyToTrip` never true | `after 5 consecutive failures: breaker is closed, want open` |
| Breaker, 2.1.0 test | PASS | same broken breaker | **PASS**: the false pass, reproduced |
| Retry | PASS | no attempt cap | `run 0: the dependency received 9 attempts for one call, want exactly 3` |
| Timeout | PASS | attempt on `context.Background()`, 2 s | `the call returned after 2.002448292s, past the caller's 150ms deadline` |
| Bulkhead | PASS | one shared pool | `another downstream's pool was exhausted too` |
| Degradation | PASS | no fallback | `request 0 under the fault: 503 in 144ms, which the SLI counts as bad`; deployed: abort at SLI 0.000 |
| Shedding | PASS | no limit | `over the limit: 200 in 201ms, want 503 with Retry-After at once` |
| Lock order | PASS | inverted order | `partial deadlock: no move completed for 2s (0 of 1600 done); 9 goroutines flat above the 2 before` |
| Toxic error | INVALID (checked) | `_, _ = AddToxic` with a misspelt type | the unchecked test **passed** on a product with no fallback |

Also seen in the throwaway cluster: an old manifest with `spec.scheduler` rejected (`unknown field "spec.scheduler"`); the runner refused another run id and the caller's own kubeconfig; a 1.2 s `NetworkChaos` delay on harbour itself aborted at an SLI of 0.000 and the object was gone afterwards; `SIGINT` during that fault gave exit 130 with the object deleted and verified; a `Schedule` created child PodChaos objects and deleting it removed them all.

## What the report says it does not prove

One node, one region, no broker; one replica killed, not two; no livelock experiment; the workflow not run on GitHub Actions.
