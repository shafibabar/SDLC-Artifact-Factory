# Observing the Product During a Run

Self-contained. Read when a report needs the product's own measurements (shedding, saturation, throttling, memory, asynchronous work), when writing a query for a run, or when someone proposes sending k6's metrics to a monitoring system. Queries marked "run" were evaluated on a throwaway Prometheus v3.16.0 scraping a lab service on 2026-11-28; the rest follow the Prometheus, Kubernetes and cAdvisor documentation and were not run.

## Read only, and only the environment's own monitoring

- Read from the Prometheus that belongs to the environment under test. In the throwaway cluster that exists only if the monitoring chart is one of the releases; where it is not, the report says "not read".
- **Push nothing.** No k6 metrics into another system's Prometheus, no annotations on shared dashboards. The earlier design did both to staging. k6's `experimental-prometheus-rw` and `influxdb` outputs are also deprecated since v2.4.0 (removal planned for v3). k6's results stay in files: the summary and the runner's result file. The validator fails `--out` to anything but a file and any call to an annotations or remote-write endpoint.
- A read-only dashboard over the environment's own data is fine and is not the record. The record is the report.

## Pin every query to the run

The runner's result file holds `started` and `ended` (UTC). Evaluate each query at the end with a range equal to the run's length: `time=<ended>` on `/api/v1/query` and `[<length>s]` in the expression, or `@ <ended as a Unix time>` inside it.

Run: a 6-second burst of 900 job requests, with other requests to the same service before and after it. `increase(...[10m])` at "now" counted 55 answers with status 200 that belonged to the other traffic; the same query pinned to the run's end with the run's length counted 0. A fixed window such as `[2h]` counts whatever else hit the product.

`increase` and `rate` extrapolate to the edges of the range. Over a few scrape intervals that is a rough estimate (run: 883 shed answers reported where the service counted 798, with a 1-second scrape over 6 seconds). Short runs give short ranges: say so beside the figure.

## The right function for the metric type

| Metric type | Use | Never |
|---|---|---|
| Counter (`_total`, and a histogram's `_bucket`, `_count`, `_sum`) | `rate()`, `increase()`, then aggregate | Aggregating before `rate()`: a restart is then not detected |
| Gauge (`pipeline_consumer_lag`, `db_pool_in_use`, `container_memory_working_set_bytes`, a queue depth) | `max_over_time()` for the peak, `delta()` for the change across the run, the value at the end | `increase()` or `rate()` |
| Histogram | `histogram_quantile(q, sum by (le) (rate(..._bucket[<length>s])))`; the answer is only as fine as the bucket it falls in | Averaging quantiles across instances |

Run: `increase()` on a gauge is not rejected. Prometheus answered `0` with only an informational note ("metric might not be a counter"); `max_over_time()` on the same gauge gave the real peak, 10. The earlier text applied `increase()` to a queue-depth gauge and would have reported a healthy pipeline. Metric names come from `prometheus-metrics-design`; do not invent a second name for the same signal.

## What to read

| Question | Signal | Query shape |
|---|---|---|
| Did the product shed during the overload check? | The request counter by status | `sum by (code) (increase(<requests_total>[<length>s]))` at the end: 429 present, 5xx absent |
| Was a pool or queue saturated? | The gauge against its limit | `max_over_time(<in_use>[<length>s]) / <max>` |
| Was the product throttled? | cAdvisor's counters | `increase(container_cpu_cfs_throttled_periods_total[<length>s]) / increase(container_cpu_cfs_periods_total[<length>s])` (the ratio is an inference from the metric descriptions). Kubernetes v1.37 deprecates the kubelet's cAdvisor-based container metrics; check the names the cluster still serves |
| Did memory grow through a soak? | Working set (a gauge) | `delta(container_memory_working_set_bytes[<length>s])` and `max_over_time(...)`. A plateau is healthy; steady growth is a leak or an unbounded queue |
| Did it recover? | Error ratio and latency after the load stopped | The same queries pinned to a window after `ended` |

Record utilisation, queue length, in-flight requests and errors by cause beside latency (SRE). CPU that stays busy while little is completed can be livelock, not saturation (Cox-Buday): compare with completed work.

## Asynchronous work

A k6 request cannot wait for a pipeline to finish. For a freshness or correctness SLO on asynchronous work:

1. Offer the load with k6 as usual (the requests that enqueue the work).
2. Wait, by polling with a deadline, until the lag gauge is back at its level from before the run. No fixed sleep.
3. Read the SLI from the environment's Prometheus over the window from `started` to the end of the drain: freshness as `histogram_quantile` or as the share of the histogram at or under the deadline bucket; correctness as a ratio of **counters by outcome** (`increase(<processed_total>{outcome="ok"}[...]) / increase(<processed_total>[...])`), never from a dead-letter depth gauge.
4. Put the figures in the report's "The product's own measurements" section, each with its query and window.

This skill ships no script for step 3: the metric names are the product's. That part was not run.

## Boundary with `go-chaos-test`

This skill shows what the product does when its own request volume is the stress. `go-chaos-test` injects one fault (a slow dependency, a killed Pod) at ordinary volume. A product can pass one and fail the other; neither replaces the other.
