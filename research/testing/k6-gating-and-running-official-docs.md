# k6 Official Documentation: gating a run and running it (exit codes, thresholds, outputs, Docker)
**Authors:** Grafana Labs (k6 documentation v2.4.x, the grafana/k6 repository at tag v2.4.0, the grafana/k6 Docker Hub repository)
**Domain:** Testing (load and performance)

Accessed 2026-11-28. Latest release v2.4.0, published 2026-11-12 (https://api.github.com/repos/grafana/k6/releases/latest). Licence: the repository's `LICENSE.md` is headed "GNU AFFERO GENERAL PUBLIC LICENSE, Version 3, 19 November 2007" (https://raw.githubusercontent.com/grafana/k6/v2.4.0/LICENSE.md); the README says "k6 is distributed under the AGPL-3.0 license" (https://raw.githubusercontent.com/grafana/k6/v2.4.0/README.md). Documentation was read as the v2.4.x Markdown sources in grafana/k6-docs at commit `2c843ea` (2026-11-19), which publish at `https://grafana.com/docs/k6/v2.4.x/<path>/`. This note adds only what `k6-official-docs.md` lacks or marks unverified.

Sources (`D/` = https://grafana.com/docs/k6/v2.4.x/, read from https://raw.githubusercontent.com/grafana/k6-docs/2c843ea3d5c3b355fd6ee8465a109ca69896eaa9/docs/sources/k6/v2.4.x/):
- [TH] D/using-k6/thresholds/
- [CK] D/using-k6/checks/
- [MR] D/using-k6/metrics/reference/
- [RC] D/javascript-api/k6-http/set-response-callback/ and [ES] D/javascript-api/k6-http/expected-statuses/
- [EX] D/javascript-api/k6-execution/
- [CA] D/using-k6/scenarios/executors/constant-arrival-rate/ and [RA] .../ramping-arrival-rate/
- [VA] D/using-k6/scenarios/concepts/arrival-rate-vu-allocation/
- [DI] D/using-k6/scenarios/concepts/dropped-iterations/
- [OC] D/using-k6/scenarios/concepts/open-vs-closed/
- [EOT] D/results-output/end-of-test/ and [CS] D/results-output/end-of-test/custom-summary/
- [RT] D/results-output/real-time/, [JS] .../real-time/json/, [OT] .../real-time/opentelemetry/, [PR] .../real-time/prometheus-remote-write/
- [OPT] D/using-k6/k6-options/reference/
- [TT] D/testing-guides/test-types/ and its six child pages
- [DP] D/examples/data-parameterization/, [SA] D/javascript-api/k6-data/sharedarray/, [OP] D/javascript-api/init-context/open/
- [LC] D/using-k6/test-lifecycle/
- [ENV] D/using-k6/environment-variables/
- [RUN] D/get-started/running-k6/ and [INS] D/set-up/install-k6/
- [LT] D/testing-guides/running-large-tests/
- [XC] https://raw.githubusercontent.com/grafana/k6/v2.4.0/errext/exitcodes/codes.go
- [SRC] https://raw.githubusercontent.com/grafana/k6/v2.4.0/internal/cmd/run.go, `internal/metrics/engine/engine.go`, `internal/cmd/test_load.go`, `internal/js/runner.go`, `errext/interrupt_error.go` under the same tag
- [REL] https://github.com/grafana/k6/releases/tag/v2.4.0 (body read through the releases API)
- [HUB] https://hub.docker.com/v2/repositories/grafana/k6/ (the repository description) and `.../tags/2.4.0`

## Core Concepts

**Exit codes**
- The documentation has no exit-code table. The thresholds page says only that a passing run "exits with an exit code `0`" and a failed threshold gives "a non-zero exit code" [TH].
- The codes are constants in the source [XC]: 97 `CloudTestRunFailed`, 98 `CloudFailedToGetProgress`, **99 `ThresholdsHaveFailed`**, 100 `SetupTimeout`, 101 `TeardownTimeout`, 102 `GenericTimeout`, 103 `ScriptStoppedFromRESTAPI`, 104 `InvalidConfig`, 105 `ExternalAbort`, 106 `CannotStartRESTAPI`, 107 `ScriptException`, 108 `ScriptAborted`, 109 `GoPanic`, 110 `MarkedAsFailed`.
- A threshold that fails at the end of a local `k6 run` is given `ThresholdsHaveFailed` (99) [SRC run.go]. A threshold with `abortOnFail` that stops the run early is given the same code, 99 [SRC engine.go].
- A signal ("test run was aborted because k6 received a '%s' signal") gives `ExternalAbort` (105), which the source comment says "should be considered aborted rather than a failure" [SRC run.go] [XC].
- A script that fails to load is given `ScriptException` (107) [SRC test_load.go]; a JavaScript exception raised while running a script function is wrapped in an error whose exit code is 107 [SRC runner.go].
- `exec.test.abort()` "aborts the test run with the exit code `108`" and does not prevent `teardown()`; `exec.test.fail()` "fails the test run with the exit code `110`" and lets iterations finish [EX].

**Thresholds**
- Short form: `metric: ['expr', ...]`. Long form: `metric: [{ threshold: 'expr', abortOnFail: true, delayAbortEval: '10s' }]`; `delayAbortEval` is a relative time string that delays the abort evaluation so samples can accumulate [TH].
- Expression: `<aggregation_method> <operator> <value>`. Counter: `count`, `rate`. Gauge: `value`. Rate: `rate`. Trend: `avg`, `min`, `max`, `med`, `p(N)` with N from 0.0 to 100 (`p(99.99)` is valid); Trend values are in milliseconds. An out-of-range percentile fails parsing before the test runs [TH].
- Custom metrics take the same forms: `Errors: ['count<100']` (Counter), `ContentSize: ['value<4000']` (Gauge), `ContentOK: ['rate>0.95']` (Rate), `RTT: ['p(99)<300','avg<200']` (Trend) [TH].
- Tagged sub-metrics: `'metric_name{tag_name:tag_value}': [...]`, for example `'http_req_duration{type:API}': ['p(95)<500']`; groups use `'group_duration{group:::name}'` [TH]. With `--scenario` selection k6 removes thresholds tagged for excluded scenarios and logs a warning [TH].
- Checks: "`checks` do not affect the exit status of k6" [TH]; a failed check "will not return a 'failed' exit status" [CK]. To fail the run, threshold the `checks` Rate metric: `checks: ['rate>0.9']`, or per tag `'checks{myTag:hola}': ['rate>0.9']` with the tag passed as the third argument of `check()` [TH]. The summary's `checks_total`, `checks_succeeded`, `checks_failed` are display values that "cannot be used in thresholds" [MR].
- `summaryTrendStats` (`--summary-trend-stats`, `K6_SUMMARY_TREND_STATS`) chooses the Trend statistics shown in the end-of-test summary; default `avg,min,med,max,p(90),p(95)`; accepts `count` and arbitrary `p(N)` [OPT].
- `--no-thresholds` disables threshold execution [OPT]; a gate must not pass it.

**HTTP metrics**
- `http_req_failed` is "the rate of failed requests according to setResponseCallback" [MR]. "By default requests with status codes between 200 and 399 are considered 'expected'" [RC], so 429 counts as failed.
- `http.setResponseCallback(http.expectedStatuses(...))` tags each request `expected_response` `"true"` or `"false"` and emits `http_req_failed` "with the reverse". `expectedStatuses` takes integers and `{min, max}` ranges in any number and order. Redirects are judged too. A per-request `responseCallback` in Params overrides it; define it once, not per request [RC] [ES].
- `http_req_duration` equals `http_req_sending + http_req_waiting + http_req_receiving`, "without the initial DNS lookup/connection times". `http_req_waiting` is time to first byte; `http_req_blocked` is time "waiting for a free TCP connection slot"; `http_req_connecting` is TCP connection time; `http_req_tls_handshaking` is TLS handshake time, a separate Trend [MR]. All `http_req_*` samples are timestamped at the end of the request [MR].

**Open and closed models**
- Arrival-rate options: `rate` (iterations started per `timeUnit`), `timeUnit` (default `"1s"`), `duration` or `stages`, `preAllocatedVUs` (required), `maxVUs` (defaults to `preAllocatedVUs`), `startRate` (default 0, ramping only). Iteration starts are spaced evenly; do not end an iteration with `sleep()` [CA] [RA].
- With insufficient VUs "k6 emits a `dropped_iterations` metric for each iteration that it can't run" [VA]; `dropped_iterations` is a Counter [MR]. Estimate: `preAllocatedVUs = [median_iteration_duration * rate] + constant_for_variance`. The page advises against `maxVUs` in most cases because allocating VUs mid-run "can overload the load generator and skew results" [VA].
- Closed model: "the target system's response time can influence the throughput of the test... this problem is known as coordinated omission"; the open model decouples iteration starts from iteration duration [OC].

**Results**
- `handleSummary(data)` runs at the end of the test and returns a map whose keys are `stdout`, `stderr` or a file path and whose values are strings or ArrayBuffers; exporting it suppresses the default summary unless `textSummary` from jslib is returned too [CS].
- `--summary-mode` exists: `compact` (default), `full`, `disabled`; `--no-summary` and the `legacy` mode were removed in v2.0.0 [EOT] [OPT].
- `--summary-export <file>`: "While this feature is not deprecated yet, we now discourage it"; use `handleSummary()` [OPT].
- `--out json=file.json` (or `.gz`) writes one JSON line per metric declaration and per sample point [JS].
- `--out opentelemetry` sends OTLP metrics; `K6_OTEL_EXPORTER_PROTOCOL` is `grpc` (default, endpoint `localhost:4317`) or `http/protobuf` (`localhost:4318`, path `/v1/metrics`); `K6_OTEL_GRPC_EXPORTER_INSECURE`, `K6_OTEL_METRIC_PREFIX`, `K6_OTEL_EXPORT_INTERVAL` (default `10s`). Trends become histograms; a Rate becomes one counter with a `condition` attribute (`zero`/`nonzero`). The page carries no experimental label [OT].
- `--out experimental-prometheus-rw`: still documented, with `K6_PROMETHEUS_RW_SERVER_URL`, `K6_PROMETHEUS_RW_TREND_STATS` (default `p(99)`), `K6_PROMETHEUS_RW_TREND_AS_NATIVE_HISTOGRAM`, `K6_PROMETHEUS_RW_PUSH_INTERVAL` (default `5s`), `K6_PROMETHEUS_RW_STALE_MARKERS` [PR]. v2.4.0 deprecates it and `influxdb`, "planned for removal in k6 v3", logging a warning, and recommends `opentelemetry` [REL]. The doc page itself does not mention the deprecation.

**Test types** [TT]
- Smoke: minimal load to verify the script and gather a baseline; a few VUs (more than 5 "could be considered a mini-load test"), seconds to a few minutes.
- Average-load: typical production load; ramp up, hold longer than the ramp, optional ramp down; 5 to 60 minutes.
- Stress: the average-load shape at a higher level, with a longer ramp; only after average-load tests.
- Soak: average load held for hours "and even days", to find leaks and degradation.
- Spike: very high load with little or no ramp and little or no plateau.
- Breakpoint: load rises gradually with no plateau until the system fails; `ramping-arrival-rate` is recommended; stop it manually or with an `abortOnFail` threshold; avoid in elastic cloud environments.

**Data, lifecycle, environment**
- `SharedArray(name, fn)` is built in the init context, runs `fn` once, shares memory across VUs, is read-only and returns a copy of each element [SA]. `open()` works only in the init context and otherwise keeps a copy per VU [OP]. Parameterised data "helps to prevent server-side caching from impacting your load test" [DP].
- `setup()` and `teardown()` run once per test and may call the full k6 API; `--no-setup` and `--no-teardown` skip them; setup data reaches `default` and `teardown` as a copy that VUs cannot mutate for each other [LC]. `setupTimeout` defaults to `60s` [OPT].
- `__ENV` exposes variables; `-e`/`--env NAME=value` is the recommended way to pass them and "does not configure options"; `K6_`-prefixed shell variables do [ENV].

**Running**
- Docker: `docker run --rm -i grafana/k6 run - <script.js` (the script is piped on stdin because the file is not inside the container) [RUN]; or mount: `docker run -it --rm -v <scriptdir>:/scripts -v <outputdir>:/jsonoutput grafana/k6 run --out json=/jsonoutput/r.json /scripts/script.js`, and "the docker user must have permission to write" to the output directory [JS].
- Image tags: `latest`, `master`, and `X.Y.Z` for every release with no `v` prefix [HUB]; the tag `2.4.0` exists [HUB tags].
- Load generator: keep at least 20% CPU idle, since at 100% "the result metrics [may] have a much larger response time than in reality"; memory is about 1 to 5 MB per VU for simple tests; keep memory below 90%; disable swap; one instance can run 30,000 to 40,000 VUs [LT].
- `discardResponseBodies: true` is "highly recommended"; set `responseType` on the requests whose body is needed [OPT] [LT]. Checks must tolerate a missing body under overload (`r.body` may not exist) [LT].

## Actionable Techniques

- Pin the version: `grafana/k6:2.4.0`, never `latest` [HUB].
- Treat exit 99 as "thresholds failed", 105 as "interrupted" and 107 to 110 as "the test itself is broken or was aborted"; do not collapse them into one "failed" [XC] [EX].
- Where 429 is intended shedding, call `http.setResponseCallback(http.expectedStatuses({ min: 200, max: 399 }, 429))` and gate on `http_req_failed` plus a separate custom Rate or Counter for 429s; the call form is from [ES], applying it to 429 is this note's inference.
- Gate latency on `'http_req_duration{expected_response:true}'` so fast error responses do not flatter the percentile (the sub-metric is shown in [TH] and [CS] output; the gating use is inference).
- Give every gating check a `checks` or `checks{tag:...}` threshold [TH].
- Threshold `dropped_iterations` (for example `count<1`) so a starved generator fails the run [DI] [VA].
- Write the machine-readable result from `handleSummary()`, not `--summary-export`; send metrics with `--out opentelemetry`, not `experimental-prometheus-rw` [CS] [OPT] [REL].

## Applies To

| Skill/Agent | Gap | What the source adds |
|---|---|---|
| go-load-test, python-load-test | Gate cannot give a true verdict: 429 counted as failure | Default 200 to 399; `expectedStatuses` form; `expected_response` tag |
| go-load-test, python-load-test | Checks cannot fail a run | `checks` Rate threshold, tagged form, display-only summary values |
| go-load-test, python-load-test | No pinned version; exit code unverified | v2.4.0, image tag `2.4.0`, exit 99 from source with the full code list |
| go-load-test, python-load-test | Deprecated output | Remote write deprecated in v2.4.0; OpenTelemetry output variables |
| go-load-test, python-load-test | Licence stated without a source | `LICENSE.md` text and README wording (AGPL-3.0) |

## Caveats

- Nothing was run. No k6 binary or image was executed; exit codes are read from source constants and call sites, not observed.
- Pages were read in full as raw Markdown from the k6-docs repository (not through a summarising fetch); `k6-options/reference` (93 KB) and `test-lifecycle` were read by section, and code samples were skimmed.
- Not stated in the documentation: any exit-code table; the exit code of a failed threshold (only "non-zero").
- Not stated, and not traced in the source: whether an exception thrown inside one VU iteration ends the run or only that iteration, and so whether such a run exits 107.
- Not stated: a `--network` flag in any k6 Docker example read; how a container reaches a service on the host or in a cluster.
- Not stated: whether a threshold on `p(99)` needs `p(99)` in `summaryTrendStats`; an example making 429 an expected status; whether TLS handshake time is inside or outside `http_req_duration` (the page excludes "DNS lookup/connection times" and lists the TLS metric separately).
- Not stated: a console warning text for insufficient VUs (the pages describe only the `dropped_iterations` metric); a stability label for the OpenTelemetry output; the content of the shared "experimental module" notice on the remote-write page (an include that was not read).
