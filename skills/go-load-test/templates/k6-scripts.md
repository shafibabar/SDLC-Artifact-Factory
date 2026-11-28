# k6 Scripts

Self-contained. Copy these files to `tests/load/` when setting up a product's load tests. `lib/gate.js` and the seven test-type scripts are copied unchanged; `journey.js` is the only file written per product. k6 scripts are JavaScript and know nothing about the service's language, so a Python service uses the same files. Run on 2026-11-28 with k6 v2.4.0 (darwin arm64 binary, checksum verified) against a lab Go service with a per-subject token bucket (10 a second, burst 20) on 127.0.0.1: every file below was extracted from this page and run as written, except that `soak.js` ran with its two-hour hold shortened to 20 seconds. No long soak was run.

Never start these with `k6 run`. They stop with `REFUSED` unless `run-load-test.sh` started them (run: exit status 107, no request sent).

## What each test type proves, and where it may run

| Script | Proves | Indicative tier (throwaway cluster) | Verdict tier (designated environment) |
|---|---|---|---|
| `smoke.js` | The script, the test identities and the gate work. Nothing about load | Yes, first | Yes, first |
| `average-load.js` | Verdict tier: the stated targets hold at the stated peak rate. Indicative tier: nothing about targets; one figure to compare with the previous run | Yes, at a small rate the profile records | Yes |
| `overload.js` | Past its limit the product sheds with 429 and `Retry-After` and accepts no more than the limiter allows; in the verdict tier also that accepted requests still meet the latency target | Yes: it tests a mechanism, not capacity | Yes |
| `stress.js` | Behaviour above the stated peak, at the level the profile records | Refused | Yes |
| `spike.js` | A sudden rise and whether the targets hold again straight after it | Refused | Yes |
| `soak.js` | Slow degradation (leaks, growing tables) over the length the profile records | Refused | Yes |
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

- **Refuses an unchecked target.** The runner passes a proof (a hash of a one-time value, the tier and the address). Without it the script throws before any request. The indicative tier also refuses any address that is not `http://127.0.0.1:<port>`.
- **Mirrors the SLI.** `http.setResponseCallback(http.expectedStatuses(...))` takes the profile's `good_statuses`, so `http_req_failed` counts exactly what the SLO counts as bad. k6's default counts every status outside 200 to 399 as failed, 429 included.
- **Keeps steady load inside the limiter.** `withinLimiter` divides the rate by the number of subjects and throws `PROFILE ERROR` when one subject would exceed its limit (run: 30 a second over one subject, exit 107).
- **Makes every rule able to fail the run.** Each rule is a threshold on a metric: `wrong_answer` (an answer that is neither the journey's nor a server error), `rate_limited` (a 429 where the profile promised none), `dropped_iterations`. No bare `check()`.
- **Judges latency only on answers the SLI counts as good**, and only on the hold phase when the profile says `"warm_up": "excluded"`. In the indicative tier the latency threshold is always true: the figure is recorded and the runner compares it with the previous run.
- **Writes the summary** the runner reads (`handleSummary`), with the gated percentile added to `summaryTrendStats`. A percentile that is only in a threshold is judged but missing from the summary (run).

## The product's journey

### `tests/load/journey.js`

```javascript
// tests/load/journey.js: the product's own requests. Replace the two functions with the journey the NFR row names.
import http from 'k6/http';
import { BASE_URL, item, steadyAnswer, overloadAnswer } from './lib/gate.js';

const as = (subject) => ({ headers: { Authorization: `Bearer ${subject.token}` } });

// One iteration of ordinary use, inside the stated demand. Pass the statuses the journey should get.
export function steady(subject, n) {
  const res = http.get(`${BASE_URL}/v1/items/${item(n)}`, as(subject));
  steadyAnswer(res, [200]);
}

// One request of the overload scenario: the usual answer, or 429 with Retry-After.
export function overload(subject, n) {
  const res = http.get(`${BASE_URL}/v1/items/${item(n)}`, as(subject));
  overloadAnswer(res, [200]);
}
```

Write one `steady` iteration per journey the NFR row names, with the mix the requirements state; where they state none, the mix is a judgement recorded in the profile. Vary the data (`item(n)`) so a cache is not what gets measured. A write (`POST`, `PATCH`, `DELETE`) is allowed: both tiers run only where bulk writes are permitted.

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

## What running showed

| Case | Result |
|---|---|
| Healthy service, 30 a second over 4 subjects | `average-load.js` exit 0: 0 failed of 300, p(95) 0.35 ms |
| Same service slowed to 150 ms (target 100 ms) | exit 99: `http_req_duration{expected_response:true,scenario:hold}` p(95) 152 ms |
| Same service answering 500 to one request in twenty | exit 99: `http_req_failed{scenario:hold}` rate 0.05 against `rate<0.005000` |
| `overload.js`, healthy: 40 a second on one subject for 10 seconds | exit 0: 119 accepted (at most 121 allowed), 281 answers 429, all with `Retry-After` |
| `overload.js`, limiter switched off | exit 99: `shed_total` 0, `accepted_total` 401 |
| `overload.js`, 429 without `Retry-After` | exit 99: `shed_correct` rate 0 |
| `overload.js`, no shedding and requests queuing | exit 99: accepted p(95) 833 ms; 142 iterations dropped, so the runner calls it INVALID |
| `breakpoint.js` against a service that serves 20 a second | Stopped itself after 10 seconds at about 22 a second, exit 99; the runner reports MEASURED |
| `average-load.js` with 2 virtual users against a 150 ms service | 197 iterations dropped, k6 warned `Insufficient VUs`; the runner calls it INVALID |

A Rate threshold with no samples passes (run: `shed_correct` with no 429 at all was "held"), which is why `shed_total` has its own `count>0`.
