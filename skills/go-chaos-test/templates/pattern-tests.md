# Pattern Experiments in Go

Self-contained. Use when writing the experiment for a circuit breaker, retry, timeout, bulkhead, degradation, load shedding or lock order. **Write these for the product**: they are the lab's tests, run on 2026-11-28 (Go 1.27.4, gobreaker v2.4.0, backoff v7.0.3, x/sync v0.25.0, `-race`), each passing on the correct product and failing on a broken copy (messages in `../references/patterns-and-assertions.md`). Keep every assertion; rename the package, the client and its methods to the product's. The module path in the imports is the lab's (`example.com/harbourpilot`); replace it with the product's. Nothing else changes.

## What the product must expose

The tests read, never invent, the product's settings, and observe its breaker. The lab product (its code is in `../examples/02-standard-harbour-pilots.md`) exposes, per downstream client:

- `DefaultConfig(baseURL)` returning the configured threshold (`BreakerFailures`), window, reset (`BreakerReset`), attempts (`MaxAttempts`), first backoff (`InitialBackoff`), attempt timeout (`AttemptTimeout`) and pool size (`MaxConcurrent`);
- `BreakerState()` returning `closed`, `open` or `half-open` (the same value `integration-design` asks to be exported as a metric);
- one error value for every way the dependency is unavailable (`ErrUnavailable`), and the caller's own `context.DeadlineExceeded` passed through unchanged.

Where the product lacks one of these, that is the first finding: a breaker whose state cannot be observed cannot be proven, and a pattern that is not there is named as **missing** (`../references/patterns-and-assertions.md`). Do not write the pattern into the test.

### `internal/tides/client_chaos_test.go`

Breaker, retry, timeout and bulkhead. `callCtx` bounds every call so a retry with no bound fails the test instead of hanging it (seen without it: the run hung).
```go
//go:build chaos

// Chaos experiments for the tides client: each proves one resilience pattern
// by its defined behaviour (integration-design §3 to §5), measured by time and
// counted at the dependency. Run only through run-chaos-experiment.sh.
package tides_test

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"sync"
	"testing"
	"time"

	"example.com/harbourpilot/internal/test/chaostest"
	"example.com/harbourpilot/internal/tides"
)

// failFast is how long a call may take when it must not wait on the dependency.
const failFast = 20 * time.Millisecond

func healthy(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, `{"berth":%q,"opens":"06:10"}`, r.URL.Query().Get("berth"))
}

func newClient(t *testing.T, dep *chaostest.Dependency) (*tides.Client, tides.Config) {
	t.Helper()
	cfg := tides.DefaultConfig(dep.URL) // the product's own configured thresholds, never numbers chosen by the test
	c := tides.New(cfg)
	if _, err := c.Window(context.Background(), "steady"); err != nil {
		chaostest.Invalid(t, "steady state did not hold before the fault: %v", err)
	}
	return c, cfg
}

// callCtx bounds one call, so a retry with no bound fails the experiment instead of hanging it.
func callCtx(t *testing.T) context.Context {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	t.Cleanup(cancel)
	return ctx
}

func expectState(t *testing.T, c *tides.Client, want, when string) {
	t.Helper()
	if got := c.BreakerState(); got != want {
		t.Fatalf("%s: breaker is %s, want %s", when, got, want)
	}
}

func waitState(t *testing.T, c *tides.Client, want string, limit time.Duration) time.Time {
	t.Helper()
	deadline := time.Now().Add(limit)
	for time.Now().Before(deadline) {
		if c.BreakerState() == want {
			return time.Now()
		}
		time.Sleep(10 * time.Millisecond) // poll interval inside a deadline
	}
	t.Fatalf("breaker did not become %s within %v (it is %s)", want, limit, c.BreakerState())
	return time.Time{}
}

// EXPERIMENT  breaker-transitions
// HYPOTHESIS  After BreakerFailures consecutive failed calls the breaker opens; while open
//
//	every call fails fast and none reaches the dependency; after BreakerReset it is
//	half-open and admits one probe; a failed probe reopens it; a good probe closes it.
func TestChaos_BreakerTransitions(t *testing.T) {
	dep := chaostest.NewDependency(t, healthy)
	c, cfg := newClient(t, dep)
	ctx, cancel := context.WithTimeout(context.Background(), 3*cfg.BreakerReset+10*time.Second)
	defer cancel()
	expectState(t, c, "closed", "steady state")

	dep.Set(chaostest.Fault{Status: http.StatusServiceUnavailable})
	for i := uint32(1); i < cfg.BreakerFailures; i++ {
		if _, err := c.Window(ctx, "B1"); err == nil {
			chaostest.Invalid(t, "call %d succeeded: the fault is not active", i)
		}
		expectState(t, c, "closed", fmt.Sprintf("after %d of %d failures", i, cfg.BreakerFailures))
	}
	if _, err := c.Window(ctx, "B1"); err == nil {
		chaostest.Invalid(t, "the threshold call succeeded: the fault is not active")
	}
	expectState(t, c, "open", fmt.Sprintf("after %d consecutive failures", cfg.BreakerFailures))
	openedAt := time.Now()

	before := dep.Calls()
	for i := 0; i < 20; i++ {
		start := time.Now()
		_, err := c.Window(ctx, "B1")
		if !errors.Is(err, tides.ErrUnavailable) {
			t.Fatalf("open breaker: call %d returned %v, want tides.ErrUnavailable", i, err)
		}
		if took := time.Since(start); took > failFast {
			t.Fatalf("open breaker: call %d took %v, more than %v: it did not fail fast", i, took, failFast)
		}
	}
	if got := dep.Calls() - before; got != 0 {
		t.Fatalf("open breaker let %d calls reach the dependency, want 0", got)
	}

	halfOpenAt := waitState(t, c, "half-open", cfg.BreakerReset+time.Second)
	if early := cfg.BreakerReset - halfOpenAt.Sub(openedAt); early > 50*time.Millisecond {
		t.Fatalf("breaker half-opened %v before its reset of %v", early, cfg.BreakerReset)
	}

	// Half-open admits one probe: with the dependency slow, the other callers fail fast.
	dep.Set(chaostest.Fault{Status: http.StatusServiceUnavailable, Delay: 100 * time.Millisecond})
	var wg sync.WaitGroup
	var mu sync.Mutex
	rejectedFast := 0
	for i := 0; i < 5; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			start := time.Now()
			_, err := c.Window(ctx, "B1")
			if errors.Is(err, tides.ErrUnavailable) && time.Since(start) < failFast {
				mu.Lock()
				rejectedFast++
				mu.Unlock()
			}
		}()
	}
	wg.Wait()
	if rejectedFast != 4 {
		t.Fatalf("half-open: %d of 5 concurrent callers were rejected fast, want 4 (one probe)", rejectedFast)
	}
	expectState(t, c, "open", "after a failed half-open probe")

	waitState(t, c, "half-open", cfg.BreakerReset+time.Second)
	dep.Clear()
	if _, err := c.Window(ctx, "B1"); err != nil {
		t.Fatalf("half-open probe against a healthy dependency failed: %v", err)
	}
	expectState(t, c, "closed", "after a good half-open probe")
}

// EXPERIMENT  retry-bounded
// HYPOTHESIS  A transient failure is tried MaxAttempts times, no more; each wait is a random
//
//	share of a doubling cap (full jitter); a permanent answer is not retried; the
//	caller's deadline stops the retries; while the dependency stays down the open
//	breaker caps what reaches it, however many callers keep asking.
func TestChaos_RetryIsBoundedJitteredAndStopsAtTheDeadline(t *testing.T) {
	var firstGaps []time.Duration
	for run := 0; run < 10; run++ {
		dep := chaostest.NewDependency(t, healthy)
		c, cfg := newClient(t, dep)
		dep.Set(chaostest.Fault{Status: http.StatusServiceUnavailable})
		base := dep.Calls()
		if _, err := c.Window(callCtx(t), "B1"); err == nil {
			chaostest.Invalid(t, "the call succeeded: the fault is not active")
		}
		arrivals := dep.Arrivals()[base:]
		if len(arrivals) != int(cfg.MaxAttempts) {
			t.Fatalf("run %d: the dependency received %d attempts for one call, want exactly %d", run, len(arrivals), cfg.MaxAttempts)
		}
		limit := cfg.InitialBackoff
		for i := 1; i < len(arrivals); i++ {
			if gap := arrivals[i].Sub(arrivals[i-1]); gap > limit+30*time.Millisecond {
				t.Fatalf("run %d: wait before attempt %d was %v, more than its cap %v", run, i+1, gap, limit)
			}
			limit *= 2
		}
		firstGaps = append(firstGaps, arrivals[1].Sub(arrivals[0]))
	}
	lo, hi := firstGaps[0], firstGaps[0]
	for _, g := range firstGaps {
		lo, hi = min(lo, g), max(hi, g)
	}
	if hi-lo < 5*time.Millisecond {
		t.Fatalf("the first wait was %v to %v over 10 calls: no jitter", lo, hi)
	}

	dep := chaostest.NewDependency(t, healthy)
	c, cfg := newClient(t, dep)
	dep.Set(chaostest.Fault{Status: http.StatusNotFound})
	base := dep.Calls()
	if _, err := c.Window(callCtx(t), "nowhere"); err == nil || dep.Calls()-base != 1 {
		t.Fatalf("a permanent 404 reached the dependency %d times (err %v), want once", dep.Calls()-base, err)
	}

	dep.Set(chaostest.Fault{Status: http.StatusServiceUnavailable, Delay: cfg.AttemptTimeout * 2 / 3})
	dctx, cancel := context.WithTimeout(context.Background(), cfg.AttemptTimeout)
	defer cancel()
	start := time.Now()
	_, err := c.Window(dctx, "B1")
	if !errors.Is(err, context.DeadlineExceeded) || time.Since(start) > cfg.AttemptTimeout+50*time.Millisecond {
		t.Fatalf("retries did not stop at the caller's deadline: %v after %v", err, time.Since(start))
	}

	storm := chaostest.NewDependency(t, healthy)
	sc, scfg := newClient(t, storm)
	storm.Set(chaostest.Fault{Status: http.StatusServiceUnavailable})
	base = storm.Calls()
	for i := 0; i < 50; i++ {
		_, _ = sc.Window(callCtx(t), "B1")
	}
	if got, most := storm.Calls()-base, int(scfg.BreakerFailures*uint32(scfg.MaxAttempts)); got > most {
		t.Fatalf("50 callers sent %d attempts to a dependency that stayed down, more than %d: a retry storm", got, most)
	}
}

// EXPERIMENT  timeout-propagates
// HYPOTHESIS  The caller's deadline reaches the dependency call: the call returns by the
//
//	deadline with context.DeadlineExceeded and the dependency sees its request end.
func TestChaos_DeadlinePropagatesToTheDependency(t *testing.T) {
	dep := chaostest.NewDependency(t, healthy)
	c, cfg := newClient(t, dep)
	dep.Set(chaostest.Fault{Delay: 10 * time.Second})
	deadline := cfg.AttemptTimeout / 2
	ctx, cancel := context.WithTimeout(context.Background(), deadline)
	defer cancel()
	start := time.Now()
	_, err := c.Window(ctx, "B1")
	took := time.Since(start)
	if !errors.Is(err, context.DeadlineExceeded) {
		t.Fatalf("got %v, want context.DeadlineExceeded", err)
	}
	if took > deadline+50*time.Millisecond {
		t.Fatalf("the call returned after %v, past the caller's %v deadline", took, deadline)
	}
	waitUntil(t, time.Second, func() bool { return len(dep.Cancelled()) > 0 })
	if seen := dep.Cancelled()[0].Sub(start); seen > deadline+100*time.Millisecond {
		t.Fatalf("the dependency saw the request end after %v, not at the caller's %v deadline", seen, deadline)
	}
}

// EXPERIMENT  bulkhead-isolates
// HYPOTHESIS  With every slot of one downstream's pool held by slow calls, a further call to
//
//	it fails fast, and a call to another downstream is served.
func TestChaos_SaturatedPoolDoesNotExhaustAnother(t *testing.T) {
	slow := chaostest.NewDependency(t, healthy)
	a, cfg := newClient(t, slow)
	other := chaostest.NewDependency(t, healthy)
	b, _ := newClient(t, other)

	slow.Set(chaostest.Fault{Delay: cfg.AttemptTimeout * 2 / 3})
	var wg sync.WaitGroup
	for i := int64(0); i < cfg.MaxConcurrent; i++ {
		wg.Add(1)
		go func() { defer wg.Done(); _, _ = a.Window(context.Background(), "B1") }()
	}
	defer wg.Wait()
	waitUntil(t, time.Second, func() bool { return slow.Calls() >= int(cfg.MaxConcurrent)+1 })

	start := time.Now()
	if _, err := a.Window(context.Background(), "B1"); !errors.Is(err, tides.ErrUnavailable) || time.Since(start) > failFast {
		t.Fatalf("a full pool must refuse at once; got %v after %v", err, time.Since(start))
	}
	start = time.Now()
	if _, err := b.Window(context.Background(), "B2"); err != nil || time.Since(start) > 100*time.Millisecond {
		t.Fatalf("another downstream's pool was exhausted too: %v after %v", err, time.Since(start))
	}
}

func waitUntil(t *testing.T, limit time.Duration, ok func() bool) {
	t.Helper()
	deadline := time.Now().Add(limit)
	for !ok() {
		if time.Now().After(deadline) {
			t.Fatalf("condition not met within %v", limit)
		}
		time.Sleep(5 * time.Millisecond) // poll interval inside a deadline
	}
}
```

### `internal/web/handler_chaos_test.go`

Graceful degradation and load shedding, asserted on the answer the SLI counts (SLO-TIDE-01 in the lab; use the product's SLO id and threshold).
```go
//go:build chaos

package web_test

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"sync"
	"testing"
	"time"

	"example.com/harbourpilot/internal/test/chaostest"
	"example.com/harbourpilot/internal/tides"
	"example.com/harbourpilot/internal/web"
)

// The SLI exactly as the SLO record defines it (SLO-TIDE-01): the share of tide-window
// requests answered 200 in under 800 ms. Every assertion below is on what it counts.
const sliUnder = 800 * time.Millisecond

func good(status int, took time.Duration) bool { return status == http.StatusOK && took < sliUnder }

func get(h http.Handler, berth string) (*httptest.ResponseRecorder, time.Duration) {
	rec := httptest.NewRecorder()
	start := time.Now()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/v1/tide-window?berth="+berth, nil))
	return rec, time.Since(start)
}

func healthy(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, `{"berth":%q,"opens":"06:10"}`, r.URL.Query().Get("berth"))
}

// EXPERIMENT  degrade-to-last-good
// HYPOTHESIS  With the tide tables failing, a berth asked for before is still answered 200
//
//	under 800 ms, marked X-Degraded: stale, so the SLI holds; a berth never seen
//	gets 503 with Retry-After, which the SLI counts as bad.
func TestChaos_DegradesWithinTheSLI(t *testing.T) {
	dep := chaostest.NewDependency(t, healthy)
	h := web.NewHandler(tides.New(tides.DefaultConfig(dep.URL)))
	if rec, took := get(h, "B1"); !good(rec.Code, took) || rec.Header().Get("X-Degraded") != "" {
		chaostest.Invalid(t, "steady state did not hold before the fault: %d in %v", rec.Code, took)
	}

	dep.Set(chaostest.Fault{Status: http.StatusServiceUnavailable})
	for i := 0; i < 20; i++ {
		rec, took := get(h, "B1")
		if !good(rec.Code, took) {
			t.Fatalf("request %d under the fault: %d in %v, which the SLI counts as bad", i, rec.Code, took)
		}
		if rec.Header().Get("X-Degraded") != "stale" {
			t.Fatalf("request %d: a degraded answer must say so (X-Degraded: stale)", i)
		}
	}
	if dep.Calls() < 2 {
		chaostest.Invalid(t, "the fault never met a request")
	}
	rec, _ := get(h, "never-seen")
	if rec.Code != http.StatusServiceUnavailable || rec.Header().Get("Retry-After") == "" {
		t.Fatalf("no last good value: got %d, want 503 with Retry-After", rec.Code)
	}
}

// EXPERIMENT  shed-load
// HYPOTHESIS  With the in-flight limit reached by slow requests, a further request is
//
//	answered 503 with Retry-After at once, and the admitted ones still finish 200.
func TestChaos_ShedsLoadFast(t *testing.T) {
	const limit = 4
	dep := chaostest.NewDependency(t, healthy)
	h := web.Shed(limit, web.NewHandler(tides.New(tides.DefaultConfig(dep.URL))))
	if rec, took := get(h, "B1"); !good(rec.Code, took) {
		chaostest.Invalid(t, "steady state did not hold before the fault: %d in %v", rec.Code, took)
	}
	dep.Set(chaostest.Fault{Delay: 200 * time.Millisecond})
	var wg sync.WaitGroup
	codes := make(chan int, limit)
	for i := 0; i < limit; i++ {
		wg.Add(1)
		go func() { defer wg.Done(); rec, _ := get(h, "B1"); codes <- rec.Code }()
	}
	deadline := time.Now().Add(time.Second)
	for dep.Calls() < 1+limit && time.Now().Before(deadline) {
		time.Sleep(5 * time.Millisecond) // poll interval inside a deadline
	}
	rec, took := get(h, "B1")
	if rec.Code != http.StatusServiceUnavailable || rec.Header().Get("Retry-After") == "" || took > 20*time.Millisecond {
		t.Fatalf("over the limit: %d in %v, want 503 with Retry-After at once", rec.Code, took)
	}
	wg.Wait()
	close(codes)
	for code := range codes {
		if code != http.StatusOK {
			t.Fatalf("an admitted request ended %d, want 200", code)
		}
	}
}
```

### `internal/roster/hook_chaos.go`

The build-tagged hook: it exists only in a chaos build. The shipped `Move` calls `betweenLocks` only when it is set, which never happens outside a chaos build.
```go
//go:build chaos

package roster

// SetBetweenLocks runs f between the two lock acquisitions of Move, widening
// the window in which an inverted lock order deadlocks, so the experiment
// meets it within seconds. It exists only in a chaos build.
func SetBetweenLocks(f func()) { betweenLocks = f }
```

### `internal/roster/roster_chaos_test.go`

Lock order under contention, through the shipped `Move`. On a stall it writes a goroutine dump into `$E2E_RESULTS_DIR` (or the test log) for `go-concurrency-patterns`' runbook.
```go
//go:build chaos

package roster_test

import (
	"bytes"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"runtime/pprof"
	"sync"
	"sync/atomic"
	"testing"
	"time"

	"example.com/harbourpilot/internal/roster"
)

// EXPERIMENT  lock-order-under-contention
// HYPOTHESIS  Pilots moved in both directions between two rosters at once, with the window
//
//	between the two locks widened, all complete: the shipped lock order (lower
//	roster ID first) never deadlocks. A partial deadlock shows as moves that stop
//	while the goroutine count stays flat and the CPU idles; a livelock as moves that
//	stop while the CPU stays pegged. Neither go test -race nor the runtime's
//	deadlock detector reports either.
func TestChaos_LockOrderHoldsUnderContention(t *testing.T) {
	const workers, rounds, stall = 8, 200, 2 * time.Second
	roster.SetBetweenLocks(func() { runtime.Gosched(); time.Sleep(50 * time.Microsecond) })
	a, b := roster.New(1), roster.New(2)
	for i := 0; i < workers; i++ {
		if err := roster.Move(roster.New(100+i, fmt.Sprint("p", i)), pick(i, a, b), fmt.Sprint("p", i)); err != nil {
			t.Fatalf("seeding: %v", err)
		}
	}
	baseline := runtime.NumGoroutine()
	var moves atomic.Int64
	var wg sync.WaitGroup
	for i := 0; i < workers; i++ {
		wg.Add(1)
		go func(i int) { // half the workers go a→b→a, half b→a→b: opposite orders at once
			defer wg.Done()
			from, to := pick(i, a, b), pick(i+1, a, b)
			for r := 0; r < rounds; r++ {
				if err := roster.Move(from, to, fmt.Sprint("p", i)); err != nil {
					t.Errorf("worker %d: %v", i, err)
					return
				}
				from, to = to, from
				moves.Add(1)
			}
		}(i)
	}
	done := make(chan struct{})
	go func() { wg.Wait(); close(done) }()

	last, lastChange := int64(-1), time.Now()
	for {
		select {
		case <-done:
			roster.SetBetweenLocks(nil)
			if got := a.Count() + b.Count(); got != workers {
				t.Fatalf("%d pilots on the rosters after the moves, want %d", got, workers)
			}
			return
		case <-time.After(100 * time.Millisecond): // sampling interval of the detector
		}
		if now := moves.Load(); now != last {
			last, lastChange = now, time.Now()
			continue
		}
		if time.Since(lastChange) >= stall {
			dump := dumpGoroutines(t)
			t.Fatalf("partial deadlock: no move completed for %v (%d of %d done); %d goroutines flat above the %d before; goroutine dump: %s",
				stall, last, workers*rounds, runtime.NumGoroutine()-baseline, baseline, dump)
		}
	}
}

func pick(i int, a, b *roster.Roster) *roster.Roster {
	if i%2 == 0 {
		return a
	}
	return b
}

// dumpGoroutines keeps every goroutine's stack for go-concurrency-patterns' runbook:
// in the run's results folder inside the environment run, else in the test log.
func dumpGoroutines(t *testing.T) string {
	var buf bytes.Buffer
	if err := pprof.Lookup("goroutine").WriteTo(&buf, 2); err != nil {
		return "not taken: " + err.Error()
	}
	if dir := os.Getenv("E2E_RESULTS_DIR"); dir != "" {
		path := filepath.Join(dir, "chaos-goroutines-"+t.Name()+".txt")
		if err := os.WriteFile(path, buf.Bytes(), 0o644); err == nil {
			return path
		}
	}
	t.Log(buf.String())
	return "in the test log above"
}
```

## Running them

Never directly: through the runner, as the `go-test` experiment of `./experiment-definition.md`, so the run marker is checked, `-count=1` is enforced (a cached pass is not a run), `CHAOS-INVALID` becomes INVALID and nothing retries. `go test -tags chaos -count=1 ./internal/...` by hand is for writing them, not for evidence.
