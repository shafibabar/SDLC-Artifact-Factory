# Enterprise: Orchard Cooperative, an Exhausted Pool and a Signed Statement

A fruit-growers' cooperative runs a FastAPI service where its 140 member farms book intake slots at the packhouse during harvest week. The product is enterprise: the design's tenancy decision (`TEN-01`) puts every farm in one pooled deployment with the farm id in the token, so one farm's load reaches every other farm; a designated performance environment is approved. This example shows a run that is INVALID because the database pool was exhausted, why it is INVALID and not FAIL, the same run with an acquire timeout, the fix, and a verification on staging under the product owner's signed impact statement.

Run on 2026-11-28: k6 v2.4.0 (darwin arm64, checksum verified), GNU Make 3.81, macOS arm64, PostgreSQL 17.12 in a throwaway container on 127.0.0.1 (removed afterwards with its volume). **What stood in:** the designated environment was a lab FastAPI service (FastAPI 0.165.0, uvicorn 0.54.0, asyncpg 0.32.0, Python 3.15.2) started with `--workers 2 --limit-concurrency 400`, two processes in place of two replicas, each with its own asyncpg pool and in-memory token bucket (10 a second, burst 20) and the saturation module of `../templates/saturation-metrics.md`; every lookup ran a 100 ms query. Staging was the same lab service reached as `api.staging.localhost` (a name reserved for loopback), serving the statement's marker. Tokens came from a stand-in for `LOAD_TOKEN_CMD`. The product folder was built only from this skill's shipped files. GitHub Actions, a real staging and a long soak were not run.

## Input

| Source | Says |
|---|---|
| `NFR-PERF-07` (Must) | Harvest week, 07:00-09:00: 30 intake-slot lookups a second from 140 member farms; 40,000 slots in the season. P95 ≤ 300 ms |
| SLO record, rows `R-11`, `R-12` | Availability 99.5%, good event: not a 5xx. Latency: 95% under 300 ms |
| Tenancy decision `TEN-01` | Pooled: one deployment, the farm id in the token; the rate limit is per farm |
| Chart, Dockerfile | `replicaCount: 2`, one uvicorn process each, `--limit-concurrency 400`; asyncpg pool size from the service's settings |
| Designation | Approved by the product owner on 2026-11-28, expires 2027-01-31 |

### `tests/load/profile.json`

```json
{
  "product": "orchard-cooperative",
  "nfr": {
    "id": "NFR-PERF-07",
    "level": "Must",
    "environment": "Harvest week, 07:00-09:00: 30 intake-slot lookups a second from 140 member farms; 40,000 slots in the season"
  },
  "slo": {
    "availability": {
      "id": "R-11",
      "objective": 0.995,
      "good_statuses": [
        {
          "min": 200,
          "max": 499
        }
      ]
    },
    "latency": {
      "id": "R-12",
      "percentile": 95,
      "under_ms": 300
    }
  },
  "server": {
    "runtime": "uvicorn 0.54.0, one process per container (python-dockerfile)",
    "workers": 1,
    "replicas": 2,
    "limit_concurrency": 400,
    "source": "charts/intake/values-perf.yaml (replicaCount 2, LIMIT_CONCURRENCY 400)"
  },
  "limiter": {
    "per_subject_per_second": 20,
    "burst": 40,
    "per_process_per_second": 10,
    "per_process_burst": 20,
    "source": "python-middleware RateLimitMiddleware default (in memory, per process); one subject is one member farm"
  },
  "data": {
    "description": "40,000 intake slots for 8 test farms, loaded by the environment's seed job; lookups spread over 2,000 of them",
    "distinct_items": 2000,
    "decided_by": "product owner, 2026-11-28",
    "reason": "the NFR gives the season's volume; 2,000 slots keep PostgreSQL's cache from being what is measured"
  },
  "verdict": {
    "smoke": {
      "iterations": 10,
      "max_duration": "30s",
      "decided_by": "test-strategist",
      "reason": "enough to show the script, the tokens and the gate work"
    },
    "average-load": {
      "rate_per_second": 30,
      "ramp_up": "10s",
      "hold": "1m",
      "virtual_users": 60,
      "warm_up": "excluded",
      "decided_by": "product owner, 2026-11-28",
      "reason": "rate from NFR-PERF-07; one minute at peak (about 1,800 requests) was chosen for the first verdict and is to be reviewed"
    },
    "overload": {
      "rate_per_second": 60,
      "seconds": 20,
      "virtual_users": 30,
      "decided_by": "test-strategist",
      "reason": "three times what one farm gets from two processes"
    }
  }
}
```

### `tests/load/designation.json`

```json
{
  "designation_id": "perf-orchard-intake-2026-11",
  "product": "orchard-cooperative",
  "base_url": "http://127.0.0.1:18090",
  "approved_by": "Product owner",
  "approved_on": "2026-11-28",
  "expires_on": "2027-01-31",
  "sizing": "2 replicas, one uvicorn process each, 1 CPU and 1 Gi each; asyncpg pool max_size per process as the run records; PostgreSQL 4 CPU and 16 Gi: the sizing NFR-PERF-07 is stated for",
  "data": "40,000 intake slots for 8 test farms in the pooled tenancy the design states (TEN-01), loaded by the environment's seed job; no member's real data",
  "generator": "one runner of 4 CPU inside the environment's network",
  "test_types": [
    "smoke",
    "average-load",
    "overload"
  ],
  "token_max_minutes": 60
}
```

### `tests/load/journey.js`

```javascript
// tests/load/journey.js: the product's own requests : a member farm looking up an intake slot (NFR-PERF-07).
import http from 'k6/http';
import { Counter } from 'k6/metrics';
import { BASE_URL, item, steadyAnswer, overloadAnswer } from './lib/gate.js';

// Server errors told apart for the report. They change no verdict: every 5xx and every request
// without an answer already counts against the SLI in http_req_failed, and in the overload check
// anything but the usual answer or 429 is a wrong answer.
const serverShed = new Counter('server_shed'); // uvicorn's own 503 at --limit-concurrency: the application never saw the request
const appServerError = new Counter('app_server_error'); // any other 5xx: the application's own answer, or a proxy's
const noAnswer = new Counter('no_answer'); // status 0: refused, reset or timed out, as when a worker process is killed

export function sortServerError(res) {
  if (res.status === 0) noAnswer.add(1);
  else if (res.status === 503 && res.body === 'Service Unavailable' && /^text\/plain/.test(res.headers['Content-Type'] || '')) serverShed.add(1);
  else if (res.status >= 500) appServerError.add(1);
}

const as = (subject) => ({ headers: { Authorization: `Bearer ${subject.token}` } });

// One iteration of ordinary use, inside the stated demand. Pass the statuses the journey should get.
export function steady(subject, n) {
  const res = http.get(`${BASE_URL}/v1/intake-slots/${item(n)}`, as(subject));
  sortServerError(res);
  steadyAnswer(res, [200]);
}

// One request of the overload scenario: the usual answer, or 429 with Retry-After.
export function overload(subject, n) {
  const res = http.get(`${BASE_URL}/v1/intake-slots/${item(n)}`, as(subject));
  sortServerError(res);
  overloadAnswer(res, [200]);
}
```

Eight test farms (`LOAD_SUBJECT_COUNT=8`): 30 a second is 3.75 a second per farm, inside one process's 10. `check-python-profile.sh ... --subjects 8`: `0 FAIL, 0 WARN`; `validate-python-load-tests.sh .`: 0 FAIL, 0 WARN.

## Run 1: pool of 1 per process, `acquire()` without a timeout

**INVALID** (runner exit 4; k6 exit 99):

```text
681 iterations were dropped: the generator did not offer the stated load (too few virtual users, or the target slowed until they ran out)
also crossed: dropped_iterations: count==0
also crossed: http_req_duration{expected_response:true,scenario:hold}: p(95)<300
```

1,238 requests, **no error at all**, p(95) 3,407 ms. Every read of `/metrics` during the hold showed `db_pool_in_use 1.0` against `db_pool_max 1.0` (35 of 38 reads; a scrape is answered by one process, which is enough to see it), and `event_loop_lag_seconds` stayed under 5 ms: the event loop was free, every request was waiting for a connection. The run is INVALID rather than FAIL because the stated 30 a second was never offered: the 60 virtual users were all waiting, so 681 planned requests were never sent, and the latency describes a lighter test than the NFR's. It is not evidence for or against the service. The finding went to the service's owner: the pool is too small for the stated demand, and `acquire()` has no timeout (`python-service-layer`'s unit of work), so exhaustion shows only as latency.

## Run 2: the same pool, with the service's `acquire(timeout=0.2)`

**FAIL** (runner exit 1): `http_req_failed{scenario:hold}` and the latency threshold crossed; 1,942 requests, no iteration dropped, p(95) 305 ms. `sort-server-errors.sh`: of 742 answers the SLI counted as failed, 0 were uvicorn's own 503 and **742 were the application's** (its 503 for an exhausted pool). The timeout turned silent waiting into errors the SLI counts and bounded the latency; it did not add capacity. The value 0.2 s was the service team's choice for this run, not this skill's.

## Run 3: pool of 4 per process, timeout kept

`make load-verdict` (exit 0):

| Test type | Verdict | Requests | Result |
|---|---|---|---|
| smoke | PASS | 10 | p(95) 116 ms |
| average-load | PASS | 1,947 (1,801 in the hold) | p(95) 115 ms against 300; no failure, no 429, 0 dropped |
| overload | PASS | 1,200 | 438 accepted (at most 441 = 20 × 20 + 40 + 1), 762 answered 429 with `Retry-After`; accepted p(95) 115 ms |

`db_pool_in_use` read 1 or 2 (once 3) against `db_pool_max 4` per process during the hold. The report records the pool size with the sizing: the verdict holds for two processes with four connections each, not for any other shape.

## Verification on staging under a signed impact statement

Before the harvest-week release the product owner wanted to know the lookup still answered on staging after the pool change. Staging is shared and is not the designated environment, so the test refuses it on a designation alone; the product owner signed this statement:

### `tests/load/statements/verify-intake-staging-2026-12.json`

```json
{
  "statement_id": "verify-intake-staging-2026-12",
  "product": "orchard-cooperative",
  "base_url": "http://api.staging.localhost:18090",
  "purpose": "verify that the intake-slot lookup answers on staging after the pool change, before the harvest-week release",
  "test_type": "smoke",
  "profile_limit": {
    "rate_per_second": 10,
    "peak_rate_per_second": 10,
    "duration_seconds": 30
  },
  "data_written": "none: the journey only looks intake slots up",
  "data_removal": "nothing to remove",
  "impact": {
    "other_users": "none expected: ten lookups, about one second of load",
    "other_teams": "packhouse-app team, told on 2026-11-28",
    "dependent_systems": "staging PostgreSQL: ten read queries",
    "third_parties": "none: the weighbridge feed on staging is a stand-in",
    "cost": "none: staging is already running"
  },
  "how_to_stop": "Ctrl-C in the runner's terminal; k6 stops within a second",
  "watched_by": "test-strategist at the terminal",
  "window_start": "2026-11-28T08:00:00Z",
  "window_end": "2026-11-28T11:00:00Z",
  "marker": "served",
  "token_max_minutes": 30,
  "approved_by": "Product owner",
  "approved_on": "2026-11-28",
  "expires_on": "2026-11-29"
}
```

`make load-verify STATEMENT=tests/load/statements/verify-intake-staging-2026-12.json TYPE=smoke` (exit 0): the runner checked every field, the sign-off, the expiry, the window, that the smoke run's 10 requests stay within the statement's limits, and that staging served `statement_id` `verify-intake-staging-2026-12` at its marker; then **PASS**, printed as "Verification under impact statement verify-intake-staging-2026-12: a result about http://api.staging.localhost:18090 at this time, not a capacity verdict." The report records the statement field by field and verbatim.

## What the reply said

> Verdict tier, designated performance environment `perf-orchard-intake-2026-11` (approved by the product owner, expires 2027-01-31), targets from `NFR-PERF-07` (30 lookups a second, P95 ≤ 300 ms, Must) and SLO rows `R-11` and `R-12`. The first run was **INVALID**, not a fail: the database pool (one connection per process) was exhausted and `acquire()` had no timeout, so requests waited instead of failing, the 60 virtual users ran out and 681 planned requests were never sent; the stated load was never offered, so the numbers describe a lighter test. With the service's 0.2 s acquire timeout the same pool gave a **FAIL** (742 application 503s, none from uvicorn's own concurrency limit). With four connections per process the verdict **passed**: p(95) 115 ms, no failures, and in the overload check 762 of 1,200 requests were correctly answered 429 with `Retry-After` (one farm meets 429 above about 20 a second: 10 per process times two processes). Each run is a new result; none was retried. The open arrival-rate model was used throughout, over eight test farms as the pooled tenancy design makes the farm the unit of the limit. The staging run was a **verification** under your signed impact statement (smoke, 10 requests, inside its window), a result about staging at that time, not a capacity verdict. Tokens were issued per run; nothing is stored. The pool size and the timeout are the service team's decisions. Run against lab stand-ins; a real designated environment, real staging, a soak and GitHub Actions were not run. The report is ready for your approval.
