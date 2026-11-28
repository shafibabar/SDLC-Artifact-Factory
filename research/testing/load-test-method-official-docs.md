# Load-Test Method from Primary Sources: profiles, open workloads, percentiles and overload
**Authors:** Betsy Beyer, Chris Jones, Jennifer Petoff, Niall Richard Murphy (eds.), *Site Reliability Engineering* (O'Reilly, 2016) and Beyer et al. (eds.), *The Site Reliability Workbook* (O'Reilly, 2018), both as published free by Google at sre.google; Gil Tene (wrk2 README; HdrHistogram README with Michael Barker and Matt Warren); Grafana Labs (k6 testing guides)
**Domain:** Testing (load and performance method)

Accessed 2026-11-28. The SRE books carry no version; the pages were read as served that day. wrk2: `master` at commit `44a94c1` (2019-09-24), no releases, Apache-2.0 (https://raw.githubusercontent.com/giltene/wrk2/master/LICENSE). HdrHistogram: `master` at commit `de84b0a` (2024-05-30), latest release HdrHistogram-2.2.2 (2024-05-30), public domain (CC0) and also BSD 2-Clause (https://raw.githubusercontent.com/HdrHistogram/HdrHistogram/HdrHistogram-2.2.2/LICENSE.txt). k6 guides: the v2.4.x documentation (k6 v2.4.0, 2026-11-12).

Sources:
- [SLO] SRE book ch. 4 "Service Level Objectives", https://sre.google/sre-book/service-level-objectives/
- [TR] SRE book ch. 17 "Testing for Reliability", https://sre.google/sre-book/testing-reliability/
- [HO] SRE book ch. 21 "Handling Overload", https://sre.google/sre-book/handling-overload/
- [CF] SRE book ch. 22 "Addressing Cascading Failures", https://sre.google/sre-book/addressing-cascading-failures/
- [RPL] SRE book ch. 27 "Reliable Product Launches at Scale", https://sre.google/sre-book/reliable-product-launches/
- [WML] SRE Workbook ch. 11 "Managing Load", https://sre.google/workbook/managing-load/
- [W2] wrk2 README, https://raw.githubusercontent.com/giltene/wrk2/master/README.md
- [HDR] HdrHistogram README, https://raw.githubusercontent.com/HdrHistogram/HdrHistogram/master/README.md
- [KT] k6 test types and child pages, https://grafana.com/docs/k6/v2.4.x/testing-guides/test-types/ (`load-testing/`, `stress-testing/`)
- [KC] k6 "Calculate concurrent users for load tests", https://grafana.com/docs/k6/v2.4.x/testing-guides/calculate-concurrent-users/
- [KV] k6 "Arrival-rate VU allocation", https://grafana.com/docs/k6/v2.4.x/using-k6/scenarios/concepts/arrival-rate-vu-allocation/
- [KO] k6 "Open and closed models", https://grafana.com/docs/k6/v2.4.x/using-k6/scenarios/concepts/open-vs-closed/
- [KD] k6 "Data parameterization", https://grafana.com/docs/k6/v2.4.x/examples/data-parameterization/

## Core Concepts

**From stated targets to a profile**
- Concurrency from traffic data: "Concurrent users = Hourly sessions * Average session duration (in seconds) / 3600" [KC].
- Use hourly, not daily or monthly, figures: "Daily averages can mask significant traffic variations"; the page's example site averages 0.08 concurrent users over a month and 25.3 in its peak hour [KC].
- Base the test on the peak: "Identify peak hours... Calculate concurrent users during these peaks... Add a margin to ensure you can handle higher traffic levels"; also run "tests that exceed your highest historical traffic by a safety margin". No size is given for the margin [KC].
- An average-load test needs "the specific number of users and the typical throughput per process in the system", taken from production monitoring or, failing that, "the business must provide these estimations" [KT load-testing].
- Shape: ramp up for "between 5% and 15% of the total test duration", hold "at least five times longer than the ramp-up", ramp down for about as long as the ramp up or less [KT load-testing].
- Stress level: "there's no fixed percentage"; some testers use 50 to 100 percent above average, some situations are two or three times average [KT stress-testing].
- A requests-per-second target is expressed directly as an arrival rate; the virtual users it needs are estimated as `preAllocatedVUs = [median_iteration_duration * rate] + constant_for_variance` [KV].
- A measured average hides bursts: a system serving 200 requests/s in even seconds and 0 in odd ones "has the same average load as one that serves a constant 100 requests/s, but has an instantaneous load that is twice as large" [SLO].
- Capacity from a breaking point: "if every cluster's breaking point is 5,000 QPS... and the service's peak load is 19,000 QPS, then approximately six clusters are needed to run the service at N + 2" [CF].
- Peaks are hard to forecast: launch spikes have been "up to 15 times higher than initially estimated", and one service "received 25 times its normal peak traffic" [RPL]. "A growth in usage [that] wasn't accompanied by an adjustment to capacity" is a named trigger of cascading failure [CF].
- Requests per second is a weak capacity unit: "Different queries can have vastly different resource requirements... A better solution is to measure capacity directly in available resources" such as CPU [HO].

**Open versus closed workload**
- A closed loop, where "each connection will only begin to send a request after receiving a response", makes "the load generator [coordinate] with the server to avoid measurement during high latency periods". This is Coordinated Omission, through which "most of the high latency artifacts exhibited by the measured server will be ignored" [W2].
- wrk2's remedy is constant throughput plus measuring "from the time the transmission *should* have occurred according to the constant throughput configured for the run", so a stall is charged to every request it delayed [W2].
- The same correction can be applied after the fact when the intended interval is known: HdrHistogram's `recordValueWithExpectedInterval()` adds "an appropriate number of additional values, linearly decreasing in steps of expectedIntervalBetweenValueSamples" [HDR].
- Size of the error: a system sampled every 10 ms that answers in 1 ms for 100 s and then stalls for 100 s shows "~99.99% of results at 1 msec or below" uncorrected; corrected, "only ~50% of results will be at 1 msec or below" [HDR].
- k6 states the same effect for its closed executors and implements the open model in its two arrival-rate executors [KO].

**Percentiles, run length, sample size, warm-up**
- "Most metrics are better thought of as distributions rather than averages... A simple average can obscure these tail latencies"; in the book's example "5% of requests are 20 times slower" while the typical request takes about 50 ms [SLO].
- "A high-order percentile, such as the 99th or 99.9th, shows you a plausible worst-case value, while using the 50th percentile... emphasizes the typical case"; tail effects are "exacerbated at high load by queuing effects" [SLO].
- Latency data is skewed, so "we cannot assume that the mean and the median are the same—or even close to each other" [SLO].
- An SLO names its aggregation interval, for example "99% (averaged over 1 minute) of Get RPC calls will complete in less than 100 ms" [SLO].
- Run length: wrk2 gives "accurate 99.9999%'ile when run long enough"; its calibration period is 10 seconds, "so runs shorter than 10-20 seconds may not present useful information" [W2]. No source read gives a minimum request count for a stable 99th or 99.9th percentile: not stated.
- Warm-up: "Processes are often slower at responding to requests immediately after starting" (connection setup, just-in-time compilation, cold caches); "when adding load to a cluster, slowly increase the load. The initially small request rate warms up the cache" [CF]. Services are also "much slower when they are not loaded" because of CPU, JIT and data caches [RPL]. A ramp-up "gives your system time to warm up or auto-scale" [KT load-testing]. Whether warm-up samples should be excluded from the measured percentile: not stated.
- "Because of caching effects, gradually ramping up load may yield different results than immediately increasing to expected load levels. Therefore, consider testing both gradual and impulse load patterns" [CF].

**Overload behaviour a load test should confirm**
- "Load test the server's capacity limits, and test the failure mode for overload. This is the most important exercise you should conduct in order to prevent server overload" [CF].
- "Load test components until they break." Past the limit a component "should ideally start serving errors or degraded results in response to additional load, but not significantly reduce the rate at which it successfully handles requests"; a susceptible one "will start crashing or serving a very high rate of errors" [CF].
- Recovery is part of the test: does the component leave degraded mode "without human intervention", and "how much does the load need to drop in order for the system to stabilize?" [CF].
- Load shedding: "return an HTTP 503 (service unavailable) to any incoming request when there are more than a given number of client requests in flight"; "fail early and cheaply" [CF]. Graceful degradation serves cheaper, lower-quality results, and "the code path you never use is the code path that (often) doesn't work" [CF] [HO].
- Queues: "Queued requests consume memory and increase latency"; with a queue 10 times the thread count and 100 ms per request, a request on a full queue takes 1.1 seconds. For steady traffic keep the queue small relative to the thread pool, "50% or less" [CF].
- Retries: a naive retry turns 100 QPS of overload into growing load; "always use randomized exponential backoff", "limit retries per request", "consider having a server-wide retry budget" (the example is 60 retries per minute per process). Three retries at each of three layers give "64 attempts (4^3) on the database" [CF].
- Google's budgets: "a per-request retry budget of up to three attempts" and a per-client budget where a request is retried only while retries stay below 10% of requests; worst-case growth is then "somewhere just below 3X". Only "the layer immediately above the layer that is rejecting" retries; otherwise an "overloaded; don't retry" error is returned [HO].
- Deadlines: servers "spend resources handling requests that will exceed their deadlines on the client"; with deadline propagation "the tree of RPCs emanating from an initial request will all have the same absolute deadline", and each stage checks the time left before doing more work [CF].
- Correctness under load: for a stateful or caching service the test "should track state between multiple interactions and check correctness at high load, which is often where subtle concurrency bugs hit" [CF].
- Client behaviour counts: after one outage a client moved to "jitter and truncated exponential backoff", and the provider "instituted qualification and load testing practices" for slow backends; both "realized they should measure load as close to the client as possible" [WML].

**Signals to watch**
- CPU exhaustion makes "all requests become slower" and shows as more in-flight requests, "excessively long queue lengths", thread starvation, failed health checks and missed deadlines [CF].
- Metrics that should decide shedding: "CPU usage, latency, queue length, number of threads used" [CF].
- Utilisation is "the current CPU rate divided by the total CPUs reserved for the task", sometimes with memory; the "executor load average" counts active threads and rejects once they exceed the processors available [HO].
- Do not count on spare CPU from the machine: "depending upon this slack CPU as your safety net is dangerous" [CF].
- Separate overload rejections from other errors: "return a specific status when overloaded" and "separate retriable and nonretriable error conditions" [CF].

**Environment, components and data**
- "Unless you test in a realistic environment, it's very hard to predict exactly which resource will be exhausted" [CF].
- "Individual components may have different breaking points, so load test each component separately" [CF].
- Synthetic limits "may not be adequately reflected by synthetic load test traffic"; a failure test "in a small slice of production" is more realistic "at the risk of causing user-visible pain", and needs spare capacity ready [CF].
- A performance test is a system test that checks a system "doesn't become incrementally slower without anyone noticing"; a stress test finds limits such as "how many queries a second can be sent to an application server before it becomes overloaded" [TR].
- "It is very hard to predict from first principles how a service will react to overload... load testing is required for most launches"; the launch workload mix "could be substantially different from steady state, throwing off load test results" [RPL].
- Varied request data "helps to prevent server-side caching from impacting your load test" [KD]; a cold cache makes "100% of requests" costly where a warm one has few misses [CF].

## Actionable Techniques

- Derive the rate from the peak hour, add a stated margin, and record the margin as an assumption because no source fixes one [KC] [RPL].
- Express a requests-per-second target as an open, constant-rate workload and report corrected latency; never read a high percentile from a closed loop that stalled [W2] [HDR] [KO].
- Gate on percentiles with a stated window, not on the mean [SLO].
- Run two extra profiles beyond steady state: an impulse to the target, and a push past the limit followed by a return to nominal load, asserting that successful throughput holds and that the system recovers unaided [CF].
- Count overload rejections (503 or 429) separately from other errors, and assert a bound on retry volume against the 10% and three-attempt budgets [HO] (using these as test bounds is this note's inference).
- Record utilisation, queue length, in-flight requests and errors by cause alongside latency [CF] [HO].

## Applies To

| Skill/Agent | Gap | What the source adds |
|---|---|---|
| go-load-test, python-load-test | No route from stated targets to a profile | Concurrency formula, peak-hour basis, ramp and hold proportions, the VU estimate, N + 2 from a breaking point |
| go-load-test, python-load-test | Overload checks that cannot fail | What "good" looks like past the limit: goodput holds, cheap rejections, bounded retries, unaided recovery |
| go-load-test, python-load-test | Nothing on sample size or warm-up | Warm-up causes and ramping; wrk2's 10 to 20 second floor; the absence of any sample-count rule |

## Caveats

- Nothing was run. No load generator, histogram library or service was executed.
- The sre.google pages were fetched as HTML and reduced to text locally, then read by section and by keyword search, not end to end; figures and footnotes were not read. The two READMEs and the k6 pages were read as raw Markdown.
- Not stated in any source read: a minimum number of requests or run length for a stable 99th or 99.9th percentile (beyond wrk2's 10 to 20 seconds); whether to discard warm-up samples; a numeric growth headroom or safety margin; a rule for converting concurrent users into requests per second; how much test data a load test needs.
- Not stated: a direct SRE-book judgement on testing at production scale against a smaller copy; the nearest statements are "realistic environment" and the production-slice failure test [CF].
- Not stated in the chapters read: CPU throttling as a named signal (the book speaks of CPU utilisation and starvation); see `load-test-environment-official-docs.md`.
- Not read: SRE book ch. 20 "Load Balancing in the Datacenter" beyond a keyword search that found nothing on load testing; Workbook ch. 17 "Identifying and Recovering from Overload".
- wrk2 and HdrHistogram are cited at an unpinned `master`; the commits above fix what was read.
