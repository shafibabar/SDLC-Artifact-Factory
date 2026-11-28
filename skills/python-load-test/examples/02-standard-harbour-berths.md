# Standard: Harbour Berths, Two Processes and a Verdict

A marina group's FastAPI service answers berth availability for three marinas. The product is standard and the product owner has approved a designated performance environment: two replicas, one uvicorn process each. This example shows the Python mistake this skill exists to catch (a rate limit copied from one process), the check that stops it before any load, what the overload check would have said without the check, and the verdict once the profile is right.

Run on 2026-11-28: k6 v2.4.0 (darwin arm64, checksum verified), GNU Make 3.81, macOS arm64. **What stood in:** the designated environment was a lab FastAPI service (FastAPI 0.165.0, uvicorn 0.54.0, Python 3.15.2) on 127.0.0.1 started with `--workers 2 --limit-concurrency 200`, two processes in place of two replicas, each with its own in-memory token bucket of 10 a second, burst 20; it served the designation marker. Tokens came from a stand-in for `LOAD_TOKEN_CMD`. The product folder was built only from this skill's shipped files; the profile is the one in `../templates/profile.md`. The three-hour soak, stress, spike and breakpoint runs and GitHub Actions were not run.

## Input

| Source | Says |
|---|---|
| `NFR-PERF-02` (Must) | Summer Friday 16:00-19:00 arrivals: 30 berth-availability lookups a second; 1,200 berths over 3 marinas. P95 ≤ 250 ms |
| SLO record, rows `R-03`, `R-04` | Availability 99.5%, good event: not a 5xx. Latency: 95% under 250 ms |
| Chart, Dockerfile | `replicaCount: 2` in the performance values, one uvicorn process per container, `--limit-concurrency 200` |
| Rate limit | `python-middleware` default, 10 a second per subject, burst 20, per process |
| Designation | Approved by the product owner on 2026-11-28, expires 2026-12-28 |

### `tests/load/designation.json`

```json
{
  "designation_id": "perf-harbour-berths-2026-11",
  "product": "harbour-berths",
  "base_url": "http://127.0.0.1:18090",
  "approved_by": "Product owner",
  "approved_on": "2026-11-28",
  "expires_on": "2026-12-28",
  "sizing": "2 replicas, one uvicorn process each (python-dockerfile), 1 CPU and 512 Mi each; --limit-concurrency 200; PostgreSQL 2 CPU and 4 Gi: the sizing NFR-PERF-02 is stated for",
  "data": "1,200 berths over 3 marinas, loaded by the environment's seed job; no copy of customer data",
  "generator": "one runner of 4 CPU inside the environment's network",
  "test_types": [
    "smoke",
    "average-load",
    "stress",
    "soak",
    "spike",
    "breakpoint",
    "overload"
  ],
  "token_max_minutes": 180
}
```

### `tests/load/journey.js`

```javascript
// tests/load/journey.js: the product's own requests : berth availability for one berth (NFR-PERF-02).
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
  const res = http.get(`${BASE_URL}/v1/berths/${item(n)}`, as(subject));
  sortServerError(res);
  steadyAnswer(res, [200]);
}

// One request of the overload scenario: the usual answer, or 429 with Retry-After.
export function overload(subject, n) {
  const res = http.get(`${BASE_URL}/v1/berths/${item(n)}`, as(subject));
  sortServerError(res);
  overloadAnswer(res, [200]);
}
```

## First attempt: the limit copied from `python-middleware`

The first profile said `"per_subject_per_second": 10, "burst": 20`, the middleware's defaults. `make load-verdict` ran `load-validate` first, and the profile check stopped it before any request (make exit 2):

```text
FAIL limiter.per_subject_per_second is 10, but 10 per process x 1 worker(s) x 2 replica(s) is 20: a subject's requests are spread over every process
FAIL limiter.burst is 20, but 20 per process x 1 worker(s) x 2 replica(s) is 40: a subject's requests are spread over every process
check-python-profile: 2 FAIL, 0 WARN
```

To show what the check prevents, the runner was started directly with that profile for the overload check (60 a second on one subject for 30 seconds): **FAIL** (runner exit 1), `crossed: accepted_total: count<=321`, with 638 accepted and 1,163 answered 429. The service was right; the test's ceiling assumed one process. Reported as a passing service or a failing one, it would have been wrong either way.

## The verdict with the profile of `../templates/profile.md`

Per subject 20 a second and burst 40 (10 and 20 times two processes); `LOAD_SUBJECT_COUNT=5` from the Makefile, so the 30 a second of average load is 6 a second per subject, inside one process's 10. `make load-verdict` (exit 0, 2 minutes 51 seconds):

| Test type | Verdict | Requests | Result |
|---|---|---|---|
| smoke | PASS | 10 | p(95) 0.52 ms |
| average-load | PASS | 3,900 (3,601 in the hold) | p(95) 2.36 ms on good answers against 250; `http_req_failed{scenario:hold}` 0; no 429; 0 dropped |
| overload | PASS | 1,800 | 637 accepted (at most 641 = 20 × 30 + 40 + 1), 1,163 answered 429, all with `Retry-After`; accepted p(95) 2.26 ms |

`sort-server-errors.sh` on the three k6 summaries: every column 0 (no uvicorn 503 with the limit at 200 and at most 40 virtual users per run). The generator used under 9% of its 10 CPUs in every run.

The report (`write-load-report.sh` on the three result files) says the verdict holds "for the environment, sizing and data recorded below", prints the designation's sizing with its two replicas, and lists what the run does not prove: the rolling SLO window, anything larger than the designated sizing, and faults injected on purpose and the speed of a single function (the chaos-test and performance-test skills of the product's language). The agent added the "Python service under load" section (two processes, `--limit-concurrency 200` each, 429 above about 20 a second for one subject, the error split) and "The product's own measurements" ("not read: the stand-in had no Prometheus"), and put it to the product owner.

## What the reply said

> Verdict tier, in the designated performance environment `perf-harbour-berths-2026-11` (approved by the product owner, expires 2026-12-28): **PASS** for smoke, average load and overload. Targets come from `NFR-PERF-02` (30 lookups a second, P95 ≤ 250 ms, Must) and SLO rows `R-03` and `R-04`; the run length, virtual users, warm-up exclusion and the five test subjects are judgement calls recorded in the profile. The service runs two replicas of one uvicorn process each, and its rate limiter counts per process, so one subject meets 429 only above about 20 a second: the first profile assumed 10 and the profile check refused it before any load was sent. Steady load used the open arrival-rate model with each subject inside one process's limit, so no 429 occurred there; in the overload check 1,163 of 1,800 requests were correctly answered 429 with `Retry-After`. No 503 from uvicorn's concurrency limit, no iteration dropped, nothing retried, tokens issued for the run only. The result holds for this sizing and this run's length, not for the 28-day window. Stress, spike, breakpoint, the three-hour soak and the GitHub Actions workflow were not run; the environment was a lab stand-in. The report is ready for your approval.
