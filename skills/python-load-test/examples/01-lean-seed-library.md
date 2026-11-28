# Lean: Seed Library, the Indicative Tier Only

A community seed library runs one FastAPI service where members look up which seed packets are on the shelf. The product is lean: one service, one database, a short NFR table, and **no approved performance environment**. This example shows what lean still gets (the indicative tier, every night), what it must not claim, a night going red on a slower build, and what happens when someone asks for a verdict.

Run on 2026-11-28: k6 v2.4.0 (darwin arm64, checksum verified), GNU Make 3.81, macOS arm64, against a lab FastAPI service (FastAPI 0.165.0, uvicorn 0.54.0, Python 3.15.2, one process, a per-subject token bucket of 10 a second, burst 20) on 127.0.0.1. The product folder was built only from this skill's shipped files. **What stood in:** the kind cluster was replaced by a stand-in `kubectl` that served the run marker of a cluster run `night-1` (and so on) with `endpoint.api=127.0.0.1:18090`, and the three suite lines were run as the end-to-end script runs them. A FastAPI chart in a real kind cluster was not run; nothing was run on GitHub Actions.

## Input

| Source | Says |
|---|---|
| `NFR-PERF-01` (short form, Must only) | Environment: Saturday 10:00-12:00 swap morning, 6 packet lookups a second from 300 members; 4,000 seed packets. Response measure: P95 ≤ 500 ms (Must) |
| SLO record, rows `R-01`, `R-02` | Availability 99%, good event: not a 5xx. Latency: 95% under 500 ms |
| Server | One uvicorn process per container (`python-dockerfile`), one replica, no `--limit-concurrency` |
| Rate limit | The `python-middleware` default, 10 a second per subject, burst 20, in memory |
| Designation record | None. The product owner has not approved a performance environment |

## The profile: an `indicative` block and nothing else

### `tests/load/profile.json`

```json
{
  "product": "seed-library",
  "nfr": {
    "id": "NFR-PERF-01",
    "level": "Must",
    "environment": "Saturday 10:00-12:00 swap morning: 6 packet lookups a second from 300 members; 4,000 seed packets"
  },
  "slo": {
    "availability": {
      "id": "R-01",
      "objective": 0.99,
      "good_statuses": [
        {
          "min": 200,
          "max": 499
        }
      ]
    },
    "latency": {
      "id": "R-02",
      "percentile": 95,
      "under_ms": 500
    }
  },
  "server": {
    "runtime": "uvicorn 0.54.0, one process per container (python-dockerfile)",
    "workers": 1,
    "replicas": 1,
    "limit_concurrency": null,
    "source": "Dockerfile ENTRYPOINT (no --workers, no --limit-concurrency); charts/seeds/values.yaml replicaCount 1, also in the e2e values"
  },
  "limiter": {
    "per_subject_per_second": 10,
    "burst": 20,
    "per_process_per_second": 10,
    "per_process_burst": 20,
    "source": "python-middleware RateLimitMiddleware default (in memory, per process), not overridden"
  },
  "data": {
    "description": "200 seed packets created through the public API by the suite's setup; lookups spread over all 200",
    "distinct_items": 200,
    "decided_by": "test-strategist",
    "reason": "the throwaway cluster starts empty; 200 is enough to keep one row from being what is measured"
  },
  "indicative": {
    "smoke": {
      "iterations": 10,
      "max_duration": "30s",
      "decided_by": "test-strategist",
      "reason": "enough to show the script, the identities and the gate work"
    },
    "average-load": {
      "rate_per_second": 4,
      "ramp_up": "5s",
      "hold": "20s",
      "virtual_users": 10,
      "warm_up": "excluded",
      "tolerance_percent": 30,
      "decided_by": "product owner, 2026-11-28",
      "reason": "a small rate the nightly runner can offer; 30% is the change worth a look, not a target"
    },
    "overload": {
      "rate_per_second": 30,
      "seconds": 10,
      "virtual_users": 20,
      "decided_by": "test-strategist",
      "reason": "three times what one subject gets from the one process, long enough to empty the burst"
    }
  }
}
```

One process, so the subject's total is the per-process figure. `check-python-profile.sh tests/load/profile.json --subjects 5` (the Makefile's `LOAD_SUBJECT_COUNT`): `server: 1 worker(s) x 1 replica(s) = 1 process(es)`, `one subject is answered 429 only above about 10/s (burst 20)`, `0 FAIL, 0 WARN`. `validate-python-load-tests.sh .`: 14 files checked, 0 FAIL, 0 WARN.

## The journey

### `tests/load/journey.js`

```javascript
// tests/load/journey.js: the product's own requests : looking up a seed packet (NFR-PERF-01).
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
  const res = http.get(`${BASE_URL}/v1/seed-packets/${item(n)}`, as(subject));
  sortServerError(res);
  steadyAnswer(res, [200]);
}

// One request of the overload scenario: the usual answer, or 429 with Retry-After.
export function overload(subject, n) {
  const res = http.get(`${BASE_URL}/v1/seed-packets/${item(n)}`, as(subject));
  sortServerError(res);
  overloadAnswer(res, [200]);
}
```

Every other file of `tests/load/` is copied unchanged from `../templates/`.

## Three nights

| Night | Build | smoke | average-load (p(95) on good answers, hold only) | overload | Line exits |
|---|---|---|---|---|---|
| `night-1` | as released | INDICATIVE PASS, 10 requests | INDICATIVE PASS, 90 requests, 2.69 ms; "no previous result to compare with" | INDICATIVE PASS: 119 accepted (at most 121), 181 answered 429 with `Retry-After` | 0, 0, 0 |
| `night-2` | the same, with `night-1`'s result as the baseline | INDICATIVE PASS | INDICATIVE PASS, 2.55 ms: "within tolerance" (-5.3%) | INDICATIVE PASS | 0, 0, 0 |
| `night-3` | a change that added 8 ms to every lookup | INDICATIVE PASS | **FAIL**: `p(95) rose 369.2% against the previous run (2.69 ms to 12.64 ms), more than the 30% the profile allows` (k6 itself exited 0) | INDICATIVE PASS | 0, **1**, 0 |

The night's suite run was red because one line exited 1, and the runner's verdict, not k6's exit status, made it so: k6 exited 0, because the indicative tier judges no latency target. `write-load-report.sh` on the three result files of `night-3` drafted a report whose summary reads "Indicative load check for seed-library ...: smoke INDICATIVE PASS, average-load FAIL, overload INDICATIVE PASS. Proves nothing about capacity." and whose verdict section carries the indicative paragraph word for word.

## "Can we run a verdict before the swap morning?"

`make load-verdict` was run. `load-validate` passed, and then the runner stopped before any request: `PROFILE ERROR in tests/load/profile.json: verdict.smoke: this test type is not planned for this tier` (make exit 2). With a `verdict.smoke` entry added to a copy of the profile, the runner refused instead: `REFUSED: cannot read the designation record tests/load/designation.json ... No request of the test was sent.` (make exit 2). Either way no load went anywhere.

## What the reply said

> Indicative tier only, in the throwaway cluster of the nightly run: last night's average-load line **failed** because p(95) rose 369.2% against the previous passing night (2.69 ms to 12.64 ms), more than the 30% tolerance the product owner set; smoke and the overload check passed (119 accepted, 181 correctly answered 429 with `Retry-After`). This tier **proves nothing about capacity** and says nothing about whether `NFR-PERF-01` (6 lookups a second, P95 ≤ 500 ms) or SLO rows `R-01` and `R-02` are met: a verdict needs a designated performance environment approved by you, and the test refuses to run one without it (it did: no designation, no request sent). It will not run on shared staging or production without your signed statement of exactly where and with what impact. The indicative rate, run length and tolerance are judgement calls recorded in the profile. The load used the open arrival-rate model; nothing was retried; the indicative tier stores no credential. The change that added 8 ms is the thing to look at. Run with k6 v2.4.0 against a lab stand-in with a stand-in cluster marker; a real kind cluster and GitHub Actions were not run.
