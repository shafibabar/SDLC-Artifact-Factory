# k6 Official Documentation
**Authors:** Grafana Labs (official k6 documentation and the grafana/k6 repository)
**Domain:** Testing (load and performance)

Accessed 2026-11-25. Latest release shown: v2.4.0 (page shows "12 Nov" with no year; 2026 is inferred) (https://github.com/grafana/k6/releases, https://github.com/grafana/k6/releases/tag/v2.4.0). The "latest" documentation pages read state no version number.

## Core Concepts

- **Scenarios** sit under `options.scenarios`; each names an `executor` and may set `startTime` (default `0s`), `gracefulStop` (default `30s`), `exec`, `env`, `tags`. They run in parallel unless start times differ. Executors: `shared-iterations`, `per-vu-iterations`, `constant-vus`, `ramping-vus`, `constant-arrival-rate`, `ramping-arrival-rate`. (https://grafana.com/docs/k6/latest/using-k6/scenarios/)
- **Closed model:** a VU starts the next iteration only when the previous one ends, so a slow target lowers the arrival rate (coordinated omission). **Open model:** iteration starts are independent of response time; the two arrival-rate executors implement it. (https://grafana.com/docs/k6/latest/using-k6/scenarios/concepts/open-vs-closed/)
- **`constant-arrival-rate`:** requires `rate`, `duration`, `preAllocatedVUs`; `timeUnit` defaults to `1s`; `maxVUs` defaults to `preAllocatedVUs`. Do not end an iteration with `sleep()`. (https://grafana.com/docs/k6/latest/using-k6/scenarios/executors/constant-arrival-rate/)
- **`ramping-arrival-rate`:** `startRate` (default 0), `stages` of `target` and `duration`, `preAllocatedVUs`, optional `maxVUs`. (https://grafana.com/docs/k6/latest/using-k6/scenarios/executors/ramping-arrival-rate/)
- **Dropped iterations:** with arrival-rate executors they occur when no VU is free; early drops usually mean too few VUs, later drops can mean the system under test is slowing. With iteration executors they mean `maxDuration` expired. `dropped_iterations` can carry a threshold. (https://grafana.com/docs/k6/latest/using-k6/scenarios/concepts/dropped-iterations/)
- **Thresholds** are the pass/fail criteria. Expressions such as `p(95)<200`; aggregations depend on metric type (`count`/`rate`, `value`, `rate`, `avg`/`min`/`max`/`med`/`p(N)`). Any failure gives a non-zero exit. Long form adds `abortOnFail` and `delayAbortEval`. Tag filters (`metric{tag:value}`) target subsets. Repeating a metric key silently discards the earlier entry. (https://grafana.com/docs/k6/latest/using-k6/thresholds/)
- **Checks do not affect exit status**; add a threshold on `checks` (optionally tagged). (https://grafana.com/docs/k6/latest/using-k6/thresholds/)
- **Failed requests:** by default only status 200-399 is expected; anything else counts in `http_req_failed`. `http.expectedStatuses` changes this globally (`http.setResponseCallback`) or per request (`responseCallback`); a `null` callback disables the metric. (https://grafana.com/docs/k6/latest/javascript-api/k6-http/set-response-callback/)
- **Metrics:** `http_req_duration` is sending + waiting + receiving, excluding DNS and connection setup. `checks` is a rate. (https://grafana.com/docs/k6/latest/using-k6/metrics/reference/)
- **Lifecycle:** init (once per VU, no HTTP), `setup()` (once, default timeout 60s), VU code, `teardown()` (once). Setup data must be JSON-serializable. If `setup()` throws, `teardown()` is not called. Behaviour on other aborts is not described there. (https://grafana.com/docs/k6/latest/using-k6/test-lifecycle/)
- **Test types:** smoke (low load, seconds to minutes), average-load and stress (5-60 minutes), soak (hours, average load), spike (very high, few minutes), breakpoint (rises until failure). Start with smoke. (https://grafana.com/docs/k6/latest/testing-guides/test-types/)
- **`-e`/`--env`** only provides variables to the script; `-e K6_ITERATIONS=120` does not set options. Exported `K6_` shell variables do. (https://grafana.com/docs/k6/latest/using-k6/environment-variables/, https://grafana.com/docs/k6/latest/using-k6/k6-options/reference/)
- **Prometheus remote write:** `-o experimental-prometheus-rw`, `K6_PROMETHEUS_RW_SERVER_URL` (default `http://localhost:9090/api/v1/write`); Prometheus 2.x needs `--web.enable-remote-write-receiver`. Trend stats default to `p(99)` without native histograms. Names are `k6_`-prefixed; counters end `_total`, rates `_rate`. (https://grafana.com/docs/k6/latest/results-output/real-time/prometheus-remote-write/)
- **Deprecation:** v2.4.0 deprecates `experimental-prometheus-rw` and `influxdb` outputs (removal planned for v3; they warn) and recommends the `opentelemetry` output. (https://github.com/grafana/k6/releases/tag/v2.4.0)
- **v2.0.0 breaking changes** include removal of the `externally-controlled` executor, the `pause`/`resume`/`scale`/`status`/`login` commands, `--no-summary`, and legacy summary mode; the HTTP API no longer starts by default. Cloud threshold aborts exit `99`; other cloud aborts exit `97`. (https://github.com/grafana/k6/releases/tag/v2.0.0)

## Actionable Techniques

- Express rate targets with an arrival-rate executor; size `preAllocatedVUs`/`maxVUs` and threshold `dropped_iterations` so a starved generator cannot pass. (dropped-iterations page above)
- Give every gating `check()` a `checks{...}` threshold.
- Where 429 is intended shedding, declare it expected on that request or tag and count it in a separate metric; k6 will not do this by default. The separate-metric design is this note's inference.
- Gate with tagged thresholds per journey or endpoint.
- Create data in `setup()` with its own error handling, since a setup failure skips teardown.
- For new metric export work, evaluate the `opentelemetry` output first.

## Applies To

| Skill/Agent | Gap (from Wave 3 audit) | What the docs add |
|---|---|---|
| go-load-test | W3B-8 to 13 | 429 default, checks gating, executor models, remote write |
| python-load-test | W3C-31, 34; decision C-4 | Native open model, shared scenarios |
| ci-pipeline | exit-code gating | Thresholds drive the exit status |

## Candidate New Skills/Agents

None. Decision W3-D17 gives k6 scenarios one owning skill.

## Key Terminology

Scenario, Executor, Virtual User, Open Model, Closed Model, Coordinated Omission, Dropped Iteration, Threshold, Check (all from the pages above).

## Caveats

- Documentation URLs are `latest` and move.
- [unverified] The exit code of a local `k6 run` threshold failure being exactly 99: the thresholds page says only non-zero; 99 was confirmed only in the cloud-related v2.0.0 note.
- [unverified] Load-generator hardware sizing, seed-data volume and warm-up guidance were not researched.

## Answers to audit questions

| Question (batch ID) | Answer | Status |
|---|---|---|
| W3B-8: does k6 count 429 as failed? | Yes by default; override with `expectedStatuses` (set-response-callback page) | Confirmed |
| W3B-10: do `check()` failures fail a run without a threshold? | No (thresholds page) | Confirmed |
| W3B-9, W3C-31, C-4: which executors are open-model? | The arrival-rate pair; `ramping-vus` is VU-based and falls outside it (open-vs-closed, scenarios pages) | Confirmed (the locust claim itself is outside this source) |
| W3B-13: does `--env` set output settings? | The docs say it only passes script variables; outputs are not named explicitly | Confirmed by inference |
| W3B-13: must the remote-write receiver be enabled? | Yes on Prometheus 2.x, by flag; Prometheus 3.x flag not stated | Confirmed for 2.x |
| go-load-test: generator VU starvation shows as `dropped_iterations` | Yes, though later drops can also mean a slow target (dropped-iterations page) | Confirmed |
