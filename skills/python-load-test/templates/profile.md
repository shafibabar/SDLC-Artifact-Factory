# The Load Profile of a Python Service

Self-contained. Copy and fill when deriving a load test from a Python product's requirements, and whenever an NFR row, an SLO, the rate limit, the number of workers or the number of replicas changes. `tests/load/profile.json` is the one place a load test's numbers live: the k6 scripts read it, the runner refuses it when a number has no owner, `../scripts/check-python-profile.sh` checks the Python part, and the report prints it. The values below are the standard example's (`../examples/02-standard-harbour-berths.md`, a marina's berth-availability service) and were the ones run for this skill.

It is `go-load-test`'s profile with one block added and one block derived differently:

- **`server`** (Python only): how many uvicorn processes answer. `python-dockerfile` runs one uvicorn process per container and scales with replicas, so `workers` is normally 1 and `replicas` is the chart's count in the environment under test. The runner ignores this block; the profile check reads it.
- **`limiter`**: `python-middleware`'s rate limiter keeps its buckets in memory, **one set per process**. A subject's requests are spread over every process, so the limit one subject meets is the per-process rate times workers times replicas. The shared k6 gate reads `per_subject_per_second` and `burst` as that total; `per_process_per_second` and `per_process_burst` record what one process enforces.

### `tests/load/profile.json`

```json
{
  "product": "harbour-berths",
  "nfr": {
    "id": "NFR-PERF-02",
    "level": "Must",
    "environment": "Summer Friday 16:00-19:00 arrivals: 30 berth-availability lookups a second from 2,500 boat owners and 3 harbour offices; 1,200 berths over 3 marinas"
  },
  "slo": {
    "availability": {
      "id": "R-03",
      "objective": 0.995,
      "good_statuses": [
        {
          "min": 200,
          "max": 499
        }
      ]
    },
    "latency": {
      "id": "R-04",
      "percentile": 95,
      "under_ms": 250
    }
  },
  "server": {
    "runtime": "uvicorn 0.54.0, one process per container (python-dockerfile)",
    "workers": 1,
    "replicas": 2,
    "limit_concurrency": 200,
    "source": "charts/berths/values-perf.yaml (replicaCount 2, LIMIT_CONCURRENCY 200); the e2e values file sets the same"
  },
  "limiter": {
    "per_subject_per_second": 20,
    "burst": 40,
    "per_process_per_second": 10,
    "per_process_burst": 20,
    "source": "python-middleware RateLimitMiddleware default (in memory, per process), not overridden"
  },
  "data": {
    "description": "1,200 berths over 3 marinas, loaded by the environment's own seed job, as NFR-PERF-02 states; lookups spread over all of them",
    "distinct_items": 1200,
    "decided_by": "product owner, 2026-11-28",
    "reason": "the NFR gives the volume; reading every berth keeps a cache from being what is measured"
  },
  "indicative": {
    "smoke": {
      "iterations": 10,
      "max_duration": "30s",
      "decided_by": "test-strategist",
      "reason": "enough to show the script, the identities and the gate work"
    },
    "average-load": {
      "rate_per_second": 8,
      "ramp_up": "5s",
      "hold": "30s",
      "virtual_users": 20,
      "warm_up": "excluded",
      "tolerance_percent": 30,
      "decided_by": "product owner, 2026-11-28",
      "reason": "a rate a shared runner can offer without saturating; 30% is the change worth a look, not a target"
    },
    "overload": {
      "rate_per_second": 60,
      "seconds": 10,
      "virtual_users": 30,
      "decided_by": "test-strategist",
      "reason": "three times the 20 a second one subject gets from two processes, long enough to empty both bursts"
    }
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
      "ramp_up": "20s",
      "hold": "2m",
      "virtual_users": 40,
      "warm_up": "excluded",
      "decided_by": "product owner, 2026-11-28",
      "reason": "rate from NFR-PERF-02; no source gives a run length or a sample size, so two minutes at peak (about 3,600 requests) was chosen and is to be reviewed"
    },
    "stress": {
      "rate_per_second": 45,
      "ramp_up": "30s",
      "hold": "2m",
      "virtual_users": 60,
      "warm_up": "excluded",
      "decided_by": "product owner, 2026-11-28",
      "reason": "half as much again as the stated peak; no source fixes a margin"
    },
    "soak": {
      "rate_per_second": 30,
      "ramp_up": "20s",
      "hold": "3h",
      "virtual_users": 40,
      "warm_up": "excluded",
      "decided_by": "product owner, 2026-11-28",
      "reason": "the length of one Friday arrival window"
    },
    "spike": {
      "rate_per_second": 45,
      "ramp_up": "2s",
      "stay": "20s",
      "recovery_rate_per_second": 30,
      "recovery_starts": "30s",
      "hold": "1m",
      "virtual_users": 80,
      "warm_up": "excluded",
      "decided_by": "product owner, 2026-11-28",
      "reason": "a ferry unloading its berth requests at once; targets are judged on the minute after it"
    },
    "breakpoint": {
      "start_rate_per_second": 10,
      "rate_per_second": 50,
      "climb": "2m",
      "settle": "10s",
      "virtual_users": 120,
      "decided_by": "product owner, 2026-11-28",
      "reason": "up to the most five test subjects may send while each stays within one process's limit"
    },
    "overload": {
      "rate_per_second": 60,
      "seconds": 30,
      "virtual_users": 30,
      "decided_by": "test-strategist",
      "reason": "three times what one subject gets from two processes"
    }
  }
}
```

## Where each value comes from

| Field | Source | If the source is silent |
|---|---|---|
| `nfr.id`, `nfr.level`, `nfr.environment` | The NFR row (`nfr-specification`): its id, which response measure is tested, its Environment cell copied | Stop: with no stated target there is no verdict. Ask for the requirement; do not invent one |
| `slo.availability` | The SLO record (`slo-definition`): row id, objective, and the SLI's good answers as status ranges. "Not a 5xx" is `[{"min": 200, "max": 499}]`. uvicorn's own 503 is a 5xx: it is never added to the good statuses by the test | As above |
| `slo.latency` | The SLO row, or the NFR's response measure: percentile and limit in milliseconds | As above |
| `server.workers`, `server.replicas` | The Dockerfile's `ENTRYPOINT` (`--workers`, or `$WEB_CONCURRENCY`, which uvicorn reads when `--workers` is absent) and the chart's replica count **in the environment under test**. The throwaway cluster's values file sets the same numbers, or the overload ceiling is wrong in one of the tiers | Read the deployed configuration; never assume one |
| `server.limit_concurrency` | uvicorn's `--limit-concurrency`, per process; `null` when it is not set (uvicorn's default: no limit). Under Gunicorn it is not supported | As above |
| `limiter.per_process_*` | The product's rate-limit configuration. `python-middleware` defaults to 10 a second per subject, burst 20, counted in each process | Read the deployed configuration |
| `limiter.per_subject_per_second`, `limiter.burst` | Derived: the per-process values times `workers` times `replicas`. `check-python-profile.sh` fails any other figure | Never chosen |
| `rate_per_second` of `verdict.average-load` | The NFR's Environment cell (the peak, not a daily average) | A stated number of users does not give a rate: the product owner decides the rate and the entry says so |
| `hold`, `ramp_up`, `virtual_users`, `warm_up` | Judgement. k6 suggests a ramp of 5 to 15 percent of the run and a hold at least five times the ramp, and estimates virtual users as median iteration time times rate, plus a margin | The person in `decided_by` chooses; `reason` says why |
| `stress`, `spike` rates; `soak` length | Judgement: k6 says there is "no fixed percentage" above average for a stress test | As above |
| `data` | The NFR's Environment cell for volume; how many distinct items the test touches is a judgement | As above |
| `indicative.*` | Judgement: a rate the nightly runner can offer, and `tolerance_percent` | Leave `tolerance_percent` out and the comparison is reported without gating |

Every entry of `indicative` and `verdict` carries `decided_by` and `reason`; the runner exits 2 with `PROFILE ERROR` when one is missing or a placeholder. A lean product may have only the `indicative` block until its performance environment is approved.

## The number of test subjects

Steady load is spread over enough subjects that **each stays within one process's rate**, not only within the total: a subject's requests can all land on one process, whose bucket then answers 429 (run: four workers took a subject's requests unevenly, 219 accepted where four even processes would have taken up to 400). `check-python-profile.sh --subjects <n>` names the least number for every rate in the profile; `LOAD_SUBJECT_COUNT` in the Makefile sets it (`./make-targets.md`). For the profile above: 3 for 30 a second, 5 for 45 and 50 a second.

The check, run on the profile above: `server: 1 worker(s) x 2 replica(s) = 2 process(es)`, `one subject is answered 429 only above about 20/s (burst 40)`, `check-python-profile: 0 FAIL, 0 WARN` with `--subjects 5`; with `--subjects 4`, three FAIL lines (stress and spike at 45 and breakpoint at 50 a second each need 5) and exit 1.
