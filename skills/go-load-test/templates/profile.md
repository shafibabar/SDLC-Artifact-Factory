# The Load Profile

Self-contained. Copy and fill when deriving a load test from a product's requirements, and whenever an NFR row, an SLO or the rate limit changes. `tests/load/profile.json` is the one place a load test's numbers live: the scripts read it, the runner refuses it when a number has no owner, and the report prints it. The values below are the standard example's (a parcel-locker service) and were the ones run for this skill.

### `tests/load/profile.json`

```json
{
  "product": "parcel-lockers",
  "nfr": {
    "id": "NFR-PERF-01",
    "level": "Must",
    "environment": "Weekday 17:00-19:00 pickup peak: 24 pickup-code lookups a second from 9,000 couriers and customers; 200,000 open parcels"
  },
  "slo": {
    "availability": {
      "id": "R-01",
      "objective": 0.995,
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
      "under_ms": 300
    }
  },
  "limiter": {
    "per_subject_per_second": 10,
    "burst": 20,
    "source": "go-middleware RateLimit default; charts/lockers/values.yaml rateLimit"
  },
  "data": {
    "description": "200,000 open parcels loaded by the environment's own seed job, as NFR-PERF-01 states; lookups spread over 500 of them",
    "distinct_items": 500,
    "decided_by": "product owner, 2026-11-28",
    "reason": "the NFR gives the volume; how many of them the test reads is a judgement"
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
      "rate_per_second": 40,
      "seconds": 10,
      "virtual_users": 20,
      "decided_by": "test-strategist",
      "reason": "four times the limit, long enough to empty the burst"
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
      "rate_per_second": 24,
      "ramp_up": "20s",
      "hold": "2m",
      "virtual_users": 40,
      "warm_up": "excluded",
      "decided_by": "product owner, 2026-11-28",
      "reason": "rate from NFR-PERF-01; no source gives a run length or a sample size, so two minutes at peak (about 2,900 requests) was chosen and is to be reviewed"
    },
    "stress": {
      "rate_per_second": 36,
      "ramp_up": "30s",
      "hold": "2m",
      "virtual_users": 60,
      "warm_up": "excluded",
      "decided_by": "product owner, 2026-11-28",
      "reason": "half as much again as the stated peak; no source fixes a margin"
    },
    "soak": {
      "rate_per_second": 24,
      "ramp_up": "20s",
      "hold": "2h",
      "virtual_users": 40,
      "warm_up": "excluded",
      "decided_by": "product owner, 2026-11-28",
      "reason": "the length of one evening peak"
    },
    "spike": {
      "rate_per_second": 38,
      "ramp_up": "2s",
      "stay": "20s",
      "recovery_rate_per_second": 24,
      "recovery_starts": "30s",
      "hold": "1m",
      "virtual_users": 80,
      "warm_up": "excluded",
      "decided_by": "product owner, 2026-11-28",
      "reason": "a courier depot arriving at once; targets are judged on the minute after it"
    },
    "breakpoint": {
      "start_rate_per_second": 10,
      "rate_per_second": 40,
      "climb": "2m",
      "settle": "10s",
      "virtual_users": 120,
      "decided_by": "product owner, 2026-11-28",
      "reason": "up to the most four test subjects may send; a higher ceiling needs more subjects"
    },
    "overload": {
      "rate_per_second": 40,
      "seconds": 30,
      "virtual_users": 20,
      "decided_by": "test-strategist",
      "reason": "four times the limit"
    }
  }
}
```

## Where each value comes from

| Field | Source | If the source is silent |
|---|---|---|
| `nfr.id`, `nfr.level`, `nfr.environment` | The NFR row (`nfr-specification`): its id, which response measure is tested (Must, Plan or Stretch), its Environment cell copied | Stop: with no stated target there is no verdict. Ask for the requirement; do not invent one |
| `slo.availability` | The SLO record (`slo-definition`): row id, objective, and the SLI's definition of a good answer as status ranges. "Not a 5xx" is `[{"min": 200, "max": 499}]` | As above |
| `slo.latency` | The SLO row, or the NFR's response measure: percentile and limit in milliseconds | As above |
| `limiter` | The product's rate-limit configuration. `go-middleware` defaults to 10 a second per subject, burst 20 | Read the deployed configuration |
| `rate_per_second` of `verdict.average-load` | The NFR's Environment cell (the peak, not a daily average) | A stated number of users does not give a rate: no source has a conversion rule. The product owner decides the rate and the entry says so |
| `hold`, `ramp_up`, `virtual_users`, `warm_up` | Judgement. k6 suggests a ramp of 5 to 15 percent of the run and a hold at least five times the ramp, and estimates virtual users as median iteration time times rate, plus a margin. No source gives a run length or a sample size for a stable high percentile | The person in `decided_by` chooses; `reason` says why |
| `stress`, `spike` rates; `soak` length | Judgement: k6 says there is "no fixed percentage" above average for a stress test | As above |
| `data` | The NFR's Environment cell for volume; how many distinct items the test touches is a judgement | As above |
| `indicative.*` | Judgement: a rate the nightly runner can offer, and `tolerance_percent`, the change from the previous run that turns the nightly run red | Leave `tolerance_percent` out and the comparison is reported without gating |

Every entry of `indicative` and `verdict` carries `decided_by` and `reason`; the runner exits 2 with `PROFILE ERROR` when one is missing or a placeholder. A test type with no entry is not planned for that tier and cannot be started. A lean product may have only the `indicative` block until its performance environment is approved.

`warm_up` is `"excluded"` (targets judged on the hold phase only) or `"included"`. The sources say a ramp warms caches and connections; none says whether to discard those samples, so the choice is recorded.
