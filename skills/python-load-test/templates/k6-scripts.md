# k6 Scripts for a Python Service

Self-contained. Copy these files to `tests/load/` when setting up a Python product's load tests. k6 scripts are JavaScript and drive the service over HTTP from outside, so they know nothing of FastAPI, uvicorn or the GIL: `lib/gate.js` and the seven test-type scripts are the same files `go-load-test` ships, copied unchanged, and a test (`tests/scripts/python-load-copies.test.sh`) fails when the two skills' copies differ. `journey.js` is the only file written per product; the one below adds the Python sorting of server errors. A product with Go and Python services has **one** `tests/load/` folder and one load suite: one `journey.js` holds the journeys of both.

Run on 2026-11-28 with k6 v2.4.0 (darwin arm64 binary, checksum verified) against a lab FastAPI service (FastAPI 0.165.0, uvicorn 0.54.0, Python 3.15.2) with a per-subject token bucket of 10 a second, burst 20, counted per process, on 127.0.0.1: every file below was extracted from this page and run as written through `../scripts/run-load-test.sh`. Long soaks were not run.

Never start these with `k6 run`. They stop with `REFUSED` unless the runner started them (run: exit status 107, no request sent).

## What each test type proves, and where it may run

| Script | Proves | Indicative tier (throwaway cluster) | Verdict tier (designated environment) |
|---|---|---|---|
| `smoke.js` | The script, the test identities and the gate work. Nothing about load | Yes, first | Yes, first |
| `average-load.js` | Verdict tier: the stated targets hold at the stated peak rate. Indicative tier: nothing about targets; one figure to compare with the previous run | Yes, at a small rate the profile records | Yes |
| `overload.js` | Past its limit the service sheds with 429 and `Retry-After` and accepts no more than the limiter allows; in the verdict tier also that accepted requests still meet the latency target | Yes: it tests a mechanism, not capacity | Yes |
| `stress.js` | Behaviour above the stated peak, at the level the profile records | Refused | Yes |
| `spike.js` | A sudden rise and whether the targets hold again straight after it | Refused | Yes |
| `soak.js` | Slow degradation (leaks, growing tables, a pool that never gives connections back) over the length the profile records | Refused | Yes |
| `breakpoint.js` | The rate at which a target is first missed, for the recorded sizing. A measurement, never a gate | Refused | Yes, where the environment does not scale itself up |

The runner enforces the two right-hand columns. The designation record narrows the last one further.

## The shared module

### `tests/load/lib/gate.js`

```javascript
// tests/load/lib/gate.js: shared by every load script. Do not change per product.
// It refuses a target the runner did not check, reads the profile derived from
// the NFR and SLO rows, builds thresholds that mirror the SLI, and writes the summary.
import http from 'k6/http';
import crypto from 'k6/crypto';
import { Counter, Rate, Trend } from 'k6/metrics';
import { SharedArray } from 'k6/data';

export const profile = JSON.parse(open('../profile.json'));
export const TIER = __ENV.LOAD_TIER || '';
export const BASE_URL = __ENV.LOAD_BASE_URL || '';

// The runner (run-load-test.sh) checks the target, then passes a proof of it.
// Started any other way, the script stops here, before a single request.
const proof = crypto.sha256(`${__ENV.LOAD_NONCE}|${TIER}|${BASE_URL}`, 'hex');
if (!__ENV.LOAD_NONCE || __ENV.LOAD_TARGET_PROOF !== proof) {
  throw new Error('REFUSED: the target was not checked. Start load tests with run-load-test.sh (make load-indicative, make load-verdict), never with k6 run.');
}
if (TIER === 'indicative' && !/^http:\/\/127\.0\.0\.1:\d+$/.test(BASE_URL)) {
  throw new Error(`REFUSED: the indicative tier runs only in the run's own throwaway cluster on 127.0.0.1, not ${BASE_URL}`);
}
if (TIER !== 'indicative' && TIER !== 'verdict') {
  throw new Error(`REFUSED: unknown tier "${TIER}"`);
}

export const subjects = new SharedArray('subjects', () => JSON.parse(open(__ENV.LOAD_SUBJECTS_FILE)));
const slo = profile.slo;

// What the SLI counts as good is what k6 counts as not failed (default: only 200-399).
http.setResponseCallback(http.expectedStatuses(...slo.availability.good_statuses));

export const wrongAnswer = new Rate('wrong_answer'); // neither the journey's answer nor an SLI failure
export const rateLimited = new Counter('rate_limited'); // 429 where the profile promised to stay inside the limiter
export const shedTotal = new Counter('shed_total'); // overload: 429 answers
export const shedCorrect = new Rate('shed_correct'); // overload: a 429 carries Retry-After
export const overloadWrong = new Rate('overload_wrong_answer'); // overload: neither accepted nor shed
export const acceptedTotal = new Counter('accepted_total'); // overload: accepted answers
export const acceptedDuration = new Trend('accepted_duration', true);

export function shape(type) {
  const entry = (profile[TIER] || {})[type];
  if (!entry) throw new Error(`PROFILE ERROR: profile.json has no "${TIER}"."${type}" entry: this test type is not planned for this tier`);
  return entry;
}

// Steady load must stay inside the limiter for each subject, or 429 answers are the test's own doing.
export function withinLimiter(type) {
  const s = shape(type);
  const each = s.rate_per_second / subjects.length;
  if (each > profile.limiter.per_subject_per_second) {
    throw new Error(`PROFILE ERROR: ${s.rate_per_second}/s over ${subjects.length} subject(s) is ${each.toFixed(2)}/s each, above the limiter's ${profile.limiter.per_subject_per_second}/s per subject. Add subjects.`);
  }
  return s;
}

const pct = `p(${slo.latency.percentile})`;
const scope = (s) => (s.warm_up === 'excluded' ? ',scenario:hold' : '');
export const item = (n) => n % profile.data.distinct_items; // spread requests so a cache is not what gets measured

// Thresholds for load inside the stated demand. The indicative tier gates on
// answers and validity only: its latency is compared with the previous run by the runner.
export function steadyThresholds(type) {
  const s = shape(type);
  const sub = s.warm_up === 'excluded' ? '{scenario:hold}' : '';
  const t = {
    [`http_req_failed${sub}`]: [`rate<${(1 - slo.availability.objective).toFixed(6)}`],
    wrong_answer: ['rate==0'],
    rate_limited: ['count==0'],
    dropped_iterations: ['count==0'],
  };
  if (TIER === 'verdict') t[`http_req_duration{expected_response:true${scope(s)}}`] = [`${pct}<${slo.latency.under_ms}`];
  else t[`http_req_duration{expected_response:true${scope(s)}}`] = ['max>=0']; // always true: keeps the figure in the summary; the runner compares it
  return t;
}

export function rampAndHold(type) {
  const s = withinLimiter(type);
  return {
    ramp: { executor: 'ramping-arrival-rate', startRate: 0, timeUnit: '1s', preAllocatedVUs: s.virtual_users,
      stages: [{ duration: s.ramp_up, target: s.rate_per_second }], gracefulStop: '0s' },
    hold: { executor: 'constant-arrival-rate', rate: s.rate_per_second, timeUnit: '1s', duration: s.hold,
      preAllocatedVUs: s.virtual_users, startTime: s.ramp_up },
  };
}

export const trendStats = ['count', 'min', 'med', 'avg', 'p(90)', 'p(95)', 'p(99)', pct, 'max'];

export function subjectFor(n) {
  return subjects[n % subjects.length];
}

// Records one answer of a journey step inside the stated demand.
export function steadyAnswer(res, expected) {
  if (res.status === 429) rateLimited.add(1);
  wrongAnswer.add(!(expected.includes(res.status) || res.status >= 500 || res.status === 0));
}

// Records one answer of the overload scenario: accepted, or shed with Retry-After. Anything else is wrong.
export function overloadAnswer(res, expected) {
  const shed = res.status === 429;
  const accepted = expected.includes(res.status);
  overloadWrong.add(!(shed || accepted));
  if (shed) {
    shedTotal.add(1);
    shedCorrect.add(res.headers['Retry-After'] !== undefined);
  }
  if (accepted) {
    acceptedTotal.add(1);
    acceptedDuration.add(res.timings.duration);
  }
}

export function handleSummary(data) {
  const out = { tier: TIER, type: __ENV.LOAD_TYPE, base_url: BASE_URL, subjects: subjects.length, metrics: data.metrics,
    duration_ms: data.state.testRunDurationMs };
  return { [__ENV.LOAD_SUMMARY]: JSON.stringify(out, null, 1), stdout: `k6 summary written to ${__ENV.LOAD_SUMMARY}\n` };
}
```

What it does, each part run:

- **Refuses an unchecked target.** The runner passes a proof (a hash of a one-time value, the tier and the address); without it the script throws before any request. The indicative tier also refuses any address that is not `http://127.0.0.1:<port>`.
- **Mirrors the SLI.** `http.setResponseCallback(http.expectedStatuses(...))` takes the profile's `good_statuses`, so `http_req_failed` counts exactly what the SLO counts as bad. k6's default counts every status outside 200 to 399 as failed, 429 included.
- **Keeps steady load inside the limiter.** `withinLimiter` divides the rate by the number of subjects and throws `PROFILE ERROR` when one subject would exceed the profile's `per_subject_per_second` (run: 24 a second over one subject, exit 107, verdict INVALID). For Python that figure is the per-process rate times workers times replicas; `../scripts/check-python-profile.sh` adds the stricter Python rule that each subject stays within one process's rate (`../references/targets-to-profile.md`).
- **Makes every rule able to fail the run.** Each rule is a threshold on a metric: `wrong_answer`, `rate_limited`, `dropped_iterations`. No bare `check()`.
- **Judges latency only on answers the SLI counts as good**, and only on the hold phase when the profile says `"warm_up": "excluded"`. In the indicative tier the latency threshold is always true: the runner compares the figure with the previous run.
- **Writes the summary** the runner reads (`handleSummary`), with every metric in it, the Python counters below included.

## The product's journey

### `tests/load/journey.js`

```javascript
// tests/load/journey.js: the product's own requests to a FastAPI service. Replace the two functions with the journey the NFR row names.
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
  const res = http.get(`${BASE_URL}/v1/items/${item(n)}`, as(subject));
  sortServerError(res);
  steadyAnswer(res, [200]);
}

// One request of the overload scenario: the usual answer, or 429 with Retry-After.
export function overload(subject, n) {
  const res = http.get(`${BASE_URL}/v1/items/${item(n)}`, as(subject));
  sortServerError(res);
  overloadAnswer(res, [200]);
}
```

Write one `steady` iteration per journey the NFR row names, with the mix the requirements state; where they state none, the mix is a judgement recorded in the profile. Vary the data (`item(n)`) so a cache is not what gets measured. Call `sortServerError` on every answer.

**Why `sortServerError`.** A FastAPI service can answer 5xx from three different places, and each needs a different fix:

| Seen by k6 | Where it came from | Run |
|---|---|---|
| 503, body exactly `Service Unavailable`, `Content-Type: text/plain` | uvicorn itself, at `--limit-concurrency`: the request never reached the application, so the application's own request counter does not count it | 252 of 324 requests at 24 a second with the limit at 10; the application counted 74 answers, all 200 |
| Any other 5xx | The application (here a 503 with a JSON body when the database pool timed out), or a proxy in front of it | 70 of 320, all counted by the application's own metric as 503 |
| Status 0 | No HTTP answer: refused, reset or timed out | Not seen: a worker killed in the middle of a run was restarted by uvicorn and the run showed no failed request; whether k6 resent on a new connection or no connection was on that worker was not determined |

k6 does not show the `Connection: close` header uvicorn sends with its 503 (run: the header list held `Date`, `Server`, `Content-Type`, `Content-Length` only), so the body and content type are what identify it. None of the three counters changes a verdict: every 5xx and every request without an answer already counts against the SLI in `http_req_failed`, and in the overload check anything but the usual answer or 429 is `overload_wrong_answer`. `../scripts/sort-server-errors.sh` prints the split for the report.

## One script per test type

### `tests/load/smoke.js`

```javascript
// tests/load/smoke.js: a handful of iterations. Proves the script, the data and the gate work; says nothing about load.
import exec from 'k6/execution';
import { shape, trendStats, subjectFor } from './lib/gate.js';
import { steady } from './journey.js';
export { handleSummary } from './lib/gate.js';

const s = shape('smoke');
export const options = {
  scenarios: { smoke: { executor: 'shared-iterations', vus: 1, iterations: s.iterations, maxDuration: s.max_duration } },
  thresholds: {
    http_req_failed: ['rate==0'],
    wrong_answer: ['rate==0'],
    rate_limited: ['count==0'],
    iterations: [`count==${s.iterations}`], // an iteration that throws still exits 0; a missing one does not
  },
  summaryTrendStats: trendStats,
};

export default function () {
  const n = exec.scenario.iterationInTest;
  steady(subjectFor(n), n);
}
```

### `tests/load/average-load.js`

```javascript
// tests/load/average-load.js: the stated peak demand, open model. Verdict tier: the targets. Indicative tier: a small rate, compared with the last run.
import exec from 'k6/execution';
import { rampAndHold, steadyThresholds, trendStats, subjectFor } from './lib/gate.js';
import { steady } from './journey.js';
export { handleSummary } from './lib/gate.js';

export const options = {
  scenarios: rampAndHold('average-load'),
  thresholds: steadyThresholds('average-load'),
  summaryTrendStats: trendStats,
};

export default function () {
  const n = exec.scenario.iterationInTest;
  steady(subjectFor(n), n);
}
```

### `tests/load/overload.js`

```javascript
// tests/load/overload.js: one subject is driven above its limit on purpose. Here 429 with Retry-After is the right answer;
// the failures are anything else, no shedding at all, more accepted than the limiter allows, or (verdict tier) accepted requests missing the latency target.
import exec from 'k6/execution';
import { TIER, profile, shape, subjects, trendStats } from './lib/gate.js';
import { overload } from './journey.js';
export { handleSummary } from './lib/gate.js';

const s = shape('overload');
const lim = profile.limiter;
if (s.rate_per_second <= lim.per_subject_per_second) {
  throw new Error(`PROFILE ERROR: overload at ${s.rate_per_second}/s does not exceed the limiter's ${lim.per_subject_per_second}/s per subject`);
}
const seconds = s.seconds;
const mostAccepted = Math.ceil(lim.per_subject_per_second * seconds + lim.burst) + 1;
export const options = {
  scenarios: { overload: { executor: 'constant-arrival-rate', rate: s.rate_per_second, timeUnit: '1s', duration: `${seconds}s`,
    preAllocatedVUs: s.virtual_users } },
  thresholds: {
    overload_wrong_answer: ['rate==0'],
    shed_total: ['count>0'],
    shed_correct: ['rate==1'],
    accepted_total: ['count>0', `count<=${mostAccepted}`],
    accepted_duration: [TIER === 'verdict' ? `p(${profile.slo.latency.percentile})<${profile.slo.latency.under_ms}` : 'max>=0'], // the indicative tier judges no latency target
    dropped_iterations: ['count==0'],
  },
  summaryTrendStats: trendStats,
};

export default function () {
  overload(subjects[0], exec.scenario.iterationInTest);
}
```

### `tests/load/stress.js`

```javascript
// tests/load/stress.js: above the stated peak, at the level the profile records. Designated environment only.
import exec from 'k6/execution';
import { rampAndHold, steadyThresholds, trendStats, subjectFor } from './lib/gate.js';
import { steady } from './journey.js';
export { handleSummary } from './lib/gate.js';

export const options = {
  scenarios: rampAndHold('stress'),
  thresholds: steadyThresholds('stress'),
  summaryTrendStats: trendStats,
};

export default function () {
  const n = exec.scenario.iterationInTest;
  steady(subjectFor(n), n);
}
```

### `tests/load/soak.js`

```javascript
// tests/load/soak.js: the stated demand held for the length the profile records, to show leaks and slow degradation. Designated environment only.
import exec from 'k6/execution';
import { rampAndHold, steadyThresholds, trendStats, subjectFor } from './lib/gate.js';
import { steady } from './journey.js';
export { handleSummary } from './lib/gate.js';

export const options = {
  scenarios: rampAndHold('soak'),
  thresholds: steadyThresholds('soak'),
  summaryTrendStats: trendStats,
};

export default function () {
  const n = exec.scenario.iterationInTest;
  steady(subjectFor(n), n);
}
```

### `tests/load/spike.js`

```javascript
// tests/load/spike.js: a sudden rise to the spike rate, a short stay, and back; then the stated demand again to show recovery. Designated environment only.
import exec from 'k6/execution';
import { withinLimiter, shape, steadyThresholds, trendStats, subjectFor } from './lib/gate.js';
import { steady } from './journey.js';
export { handleSummary } from './lib/gate.js';

const s = withinLimiter('spike');
const after = shape('spike').recovery_rate_per_second;
export const options = {
  scenarios: {
    spike: { executor: 'ramping-arrival-rate', startRate: after, timeUnit: '1s', preAllocatedVUs: s.virtual_users, gracefulStop: '0s',
      stages: [{ duration: s.ramp_up, target: s.rate_per_second }, { duration: s.stay, target: s.rate_per_second }, { duration: s.ramp_up, target: after }] },
    hold: { executor: 'constant-arrival-rate', rate: after, timeUnit: '1s', duration: s.hold, preAllocatedVUs: s.virtual_users,
      startTime: s.recovery_starts },
  },
  thresholds: steadyThresholds('spike'), // with warm_up "excluded" the targets are judged on the recovery (scenario "hold")
  summaryTrendStats: trendStats,
};

export default function () {
  const n = exec.scenario.iterationInTest;
  steady(subjectFor(n), n);
}
```

### `tests/load/breakpoint.js`

```javascript
// tests/load/breakpoint.js: the rate climbs until a target is missed, then the run stops itself. Designated environment only.
// It ends with exit status 99 by design: the result is the rate reached, which the runner reports. It is never a release gate.
import exec from 'k6/execution';
import { Gauge } from 'k6/metrics';
import { profile, withinLimiter, trendStats, subjectFor } from './lib/gate.js';
import { steady } from './journey.js';
export { handleSummary } from './lib/gate.js';

const s = withinLimiter('breakpoint'); // rate_per_second is the ceiling the climb may reach
const slo = profile.slo;
const stop = (expr) => [{ threshold: expr, abortOnFail: true, delayAbortEval: s.settle }];
const offered = new Gauge('offered_rate');
export const options = {
  scenarios: { climb: { executor: 'ramping-arrival-rate', startRate: s.start_rate_per_second, timeUnit: '1s',
    preAllocatedVUs: s.virtual_users, stages: [{ duration: s.climb, target: s.rate_per_second }] } },
  thresholds: {
    http_req_failed: stop(`rate<${(1 - slo.availability.objective).toFixed(6)}`),
    'http_req_duration{expected_response:true}': stop(`p(${slo.latency.percentile})<${slo.latency.under_ms}`),
    dropped_iterations: stop('count==0'),
    wrong_answer: ['rate==0'],
  },
  summaryTrendStats: trendStats,
};

export default function () {
  const n = exec.scenario.iterationInTest;
  const progress = exec.scenario.progress;
  offered.add(s.start_rate_per_second + (s.rate_per_second - s.start_rate_per_second) * progress);
  steady(subjectFor(n), n);
}
```

## What running showed against the FastAPI lab service

| Case | Result |
|---|---|
| Healthy, one worker: smoke, average load at 24 a second over 4 subjects, overload at 40 a second on one subject | Each PASS (runner exit 0); overload: 120 accepted (at most 121 allowed), 281 answered 429, all with `Retry-After` |
| `--limit-concurrency 10`, 50 ms per request, average load at 24 a second | FAIL (exit 1): `http_req_failed{scenario:hold}` rate 0.78; all 252 failures were uvicorn's own 503 |
| The same limit, overload check | FAIL (exit 1): `overload_wrong_answer` crossed; 223 answers were uvicorn's 503 before the limiter could answer 429 |
| The same service with `--limit-concurrency 100` | PASS (exit 0) |
| Four workers, profile still saying 10 a second per subject | Overload FAIL (exit 1): `accepted_total` 219 against at most 121: each worker has its own buckets |
| Four workers, profile at 40 a second and burst 80 (10 and 20 times four), overload at 160 a second | PASS: 358 accepted (at most 481), 1,243 answered 429 |
| asyncpg pool of 2, 100 ms queries, 24 a second, `acquire()` without a timeout | INVALID (exit 4): no error at all, p(95) 2,189 ms, 35 iterations dropped; the pool showed 2 open and 0 idle the whole run |
| The same with `acquire(timeout=0.2)` | FAIL (exit 1): 70 answers 503 from the application, p(95) 311 ms; no iteration dropped |
| A blocking 500 ms call inside `async def`, five times during average load | FAIL (exit 1): p(95) 388 ms against 300; the event-loop lag probe read 0.47 to 0.50 s at each stall and about 2 ms otherwise |
