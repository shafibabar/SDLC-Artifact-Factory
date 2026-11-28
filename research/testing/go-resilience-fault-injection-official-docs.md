# Go Resilience and Fault Injection: RoundTripper, context deadlines, gobreaker, semaphore, backoff, Pod Security
**Authors:** The Go project (pkg.go.dev, golang/go source); Sony (sony/gobreaker); The Go Authors (golang.org/x/sync); Cenk Altı (cenkalti/backoff); The Kubernetes Authors (kubernetes.io)
**Domain:** Testing (chaos and resilience, Go)

Accessed 2026-11-28. Go standard library at go1.27.4 (pkg.go.dev header; source at tag `go1.27.4`), BSD-style licence. `github.com/sony/gobreaker/v2` v2.4.0 (published 2026-01-01; latest in the module proxy list), MIT. `golang.org/x/sync` v0.25.0 (published 2026-10-15; highest in the proxy list), BSD-3-Clause. `github.com/cenkalti/backoff/v7` v7.0.3 (published 2026-11-01; latest v7 in the proxy list), MIT; v5.0.3 (2025-07-23) is the last v5. Kubernetes docs: the current docs, version selector topped by v1.37.

Sources:
- [RT] `net/http` client.go at go1.27.4, https://raw.githubusercontent.com/golang/go/go1.27.4/src/net/http/client.go (RoundTripper, Client.Timeout); https://pkg.go.dev/net/http
- [REQ] request.go at go1.27.4, https://raw.githubusercontent.com/golang/go/go1.27.4/src/net/http/request.go
- [CTX] https://pkg.go.dev/context
- [HT] https://pkg.go.dev/net/http/httptest
- [GB] https://pkg.go.dev/github.com/sony/gobreaker/v2, README https://raw.githubusercontent.com/sony/gobreaker/master/README.md, source https://raw.githubusercontent.com/sony/gobreaker/v2.4.0/v2/gobreaker.go
- [SEM] https://pkg.go.dev/golang.org/x/sync/semaphore
- [BO] https://pkg.go.dev/github.com/cenkalti/backoff/v7@v7.0.3 and https://pkg.go.dev/github.com/cenkalti/backoff/v5
- [PSS] https://kubernetes.io/docs/concepts/security/pod-security-standards/ ; [PSA] https://kubernetes.io/docs/concepts/security/pod-security-admission/

## Core Concepts

**RoundTripper: the basis for a fault-injecting transport**
- "A RoundTripper must be safe for concurrent use by multiple goroutines" [RT].
- "RoundTrip must return err == nil if it obtained a response, regardless of the response's HTTP status code. A non-nil err should be reserved for failure to obtain a response" [RT]. An injected 503 is therefore a response with nil error; an injected connection failure is a nil response with an error.
- "RoundTrip should not modify the request, except for consuming and closing the Request's Body" [RT]; to change it, clone it (`Request.Clone`) [REQ].
- "RoundTrip must always close the body, including on errors" [RT], so an injector that short-circuits must still close `req.Body` when non-nil.
- `Client.Timeout` covers "connection time, any redirects, and reading the response body"; the Client cancels the transport "as if the Request's Context ended"; new RoundTrippers "should use the Request's Context for cancellation" [RT]. An injected delay must therefore select on `req.Context().Done()`, or it outlives the caller's deadline.

**Context deadlines and propagation**
- "Incoming requests to a server should create a Context, and outgoing calls to servers should accept a Context"; pass it first, never store it in a struct, never pass nil [CTX].
- `WithTimeout`: "Canceling this context releases resources associated with it", so call cancel when the work completes [CTX].
- "If the parent's deadline is already earlier than d, WithDeadline(parent, d) is semantically equivalent to parent": a child cannot extend its parent's deadline [CTX].
- `Err` returns `Canceled` for explicit cancel and `DeadlineExceeded` when the deadline passes; `WithTimeoutCause` and `Cause` record a reason [CTX].
- `NewRequestWithContext`: "For an outgoing client request, the context controls the entire lifetime of a request and its response: obtaining a connection, sending the request, and reading the response headers and body" [REQ]. For an incoming request the context is canceled "when the client's connection closes ... or when the ServeHTTP method returns" [REQ].

**httptest.Server as a faulty upstream**
- `NewServer` listens on loopback; `URL` is `http://address:port`; `Client()` returns a client configured for it; `Close` "blocks until all outstanding requests on this server have completed"; `CloseClientConnections` closes open connections; `Config` and `EnableHTTP2` must be set before `Start` [HT].

**gobreaker v2**
- Generic API: `NewCircuitBreaker[T](st Settings) *CircuitBreaker[T]`, `Execute(func() (T, error)) (T, error)`, `State() State`, `Counts() Counts`, `Name()`; also `TwoStepCircuitBreaker[T]` with `Allow() (done func(err error), err error)` [GB].
- `Settings`: `MaxRequests` (half-open allowance; 0 means 1), `Interval` (closed-state count reset; 0 never resets), `BucketPeriod` (rolling window; 0 fixed window), `Timeout` (open duration; 0 means 60 s), `ReadyToTrip(Counts) bool` (default: `ConsecutiveFailures > 5`), `OnStateChange`, `IsSuccessful`, `IsExcluded` (e.g. context cancellations neither success nor failure) [GB].
- States `StateClosed`, `StateHalfOpen`, `StateOpen`; `State.String()` [GB].
- Transitions from source: in half-open, `ConsecutiveSuccesses >= maxRequests` closes it; any half-open failure reopens it; open rejects with `ErrOpenState` ("circuit breaker is open"); half-open beyond `MaxRequests` rejects with `ErrTooManyRequests` ("too many requests") [GB].

**Bulkhead with x/sync/semaphore**
- "Weighted provides a way to bound concurrent access to a resource"; `NewWeighted(n)` panics on negative n [SEM].
- `Acquire(ctx, n)` blocks until resources are available or ctx is done; on failure it returns `ctx.Err()` and leaves the semaphore unchanged. `TryAcquire(n)` does not block and returns false on failure. `Release(n)` releases weight n [SEM].

**Retries with backoff**
- The Go standard library offers no retry-with-backoff helper: not stated in any page read.
- backoff v7.0.3: `Retry[T](ctx, operation Operation[T], opts ...RetryOption) (T, error)` with `WithBackOff`, `WithMaxTries`, `WithMaxElapsedTime` (default 15 min), `WithNotify` [BO].
- `WithMaxTries` "limits the total number of attempts, not retries": `WithMaxTries(1)` runs once [BO].
- "ctx bounds the retry loop: its cancellation or deadline stops further attempts and interrupts the wait between them" [BO].
- `Permanent(err)` stops immediately; `RetryAfter` sets the next wait; failures return `*RetryError` with `LastErr` and `Cause` (`ErrPermanent`, `ErrExhausted`, `ErrMaxElapsedTime`, or the context cause) [BO].
- `ExponentialBackOff`: `InitialInterval` 500 ms, `RandomizationFactor` 0.5, `Multiplier` 1.5, `MaxInterval` 60 s; jitter is `RetryInterval * (random value in range [1 - RandomizationFactor, 1 + RandomizationFactor])`; MaxInterval caps RetryInterval, not the randomised value; "Implementation is not thread-safe" [BO].
- `WithMaxRetries` and `WithContext` (v4 names) do not exist in v5 or v7 [BO].
- A retry budget (a ratio of retries to requests) is not offered by backoff: not stated in its docs.

**Pod Security Standards**
- Levels: Privileged "Unrestricted policy ... allows for known privilege escalations"; Baseline "prevents known privilege escalations"; Restricted "Heavily restricted policy, following current Pod hardening best practices" [PSS].
- Baseline forbids `securityContext.privileged: true`, `hostNetwork`/`hostPID`/`hostIPC`, any `hostPath` volume, and added capabilities beyond a short list (`AUDIT_WRITE, CHOWN, DAC_OVERRIDE, FOWNER, FSETID, KILL, MKNOD, NET_BIND_SERVICE, SETFCAP, SETGID, SETPCAP, SETUID, SYS_CHROOT`) [PSS]. Chaos Mesh's daemon violates all four, so its namespace must be `privileged`.
- Labels: `pod-security.kubernetes.io/<MODE>: <LEVEL>` with MODE `enforce` (reject), `audit` (audit annotation), `warn` (user warning); optional `pod-security.kubernetes.io/<MODE>-version`; stable since v1.25 [PSA].

## Actionable Techniques

- Write the fault injector as a RoundTripper wrapping `http.DefaultTransport`: no request mutation, close the body on short-circuit, return injected statuses with nil error, and honour `req.Context()` during injected delay [RT].
- Assert deadline propagation by giving the caller a `WithTimeout` context and checking `errors.Is(err, context.DeadlineExceeded)` and elapsed time [CTX] [REQ].
- Assert breaker transitions with `OnStateChange` or `State()`: closed to open after the threshold, `ErrOpenState` without calling the upstream, half-open after `Timeout`, closed after `MaxRequests` successes [GB].
- Assert a bulkhead with `TryAcquire` returning false at the limit while another semaphore still admits work [SEM].
- Count attempts with `WithNotify` and bound them with `WithMaxTries`; use a fresh `ExponentialBackOff` per call because it is not thread-safe [BO].

## Applies To

| Skill/Agent | Gap | What the source adds |
|---|---|---|
| go-chaos-test | Fault transport that breaks the contract | Concurrency, no-mutation, body-close and nil-error-on-response rules |
| go-chaos-test | Breaker tests that cannot fail | Exact defaults, transitions and error values of gobreaker v2.4.0 |
| go-chaos-test | Retry code on removed APIs | backoff v7 `Retry` options; `WithMaxRetries`/`WithContext` gone |
| go-chaos-test, python-chaos-test | Privileged daemon unexplained | PSS levels and enforce labels |

## Caveats

- Nothing was run. No Go code, test or cluster was executed or installed.
- Pages were read through a fetch tool that summarises and quotes in short segments; pkg.go.dev's `net/http` page was too long to read whole, so RoundTripper and request docs were read from the source at the tag.
- pkg.go.dev flagged every module page with "not in the latest version of its module"; the module proxy lists were used to confirm latest versions.
- Not stated: whether `semaphore.Acquire` can succeed when ctx is already done; whether `Release` beyond the held weight panics; a standard-library retry helper; any retry-budget primitive; the Restricted level's full control list (not read).
