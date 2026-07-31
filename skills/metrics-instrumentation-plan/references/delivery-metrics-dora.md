# Delivery Metrics — DORA Four: Complete Instrumentation Specification

Self-contained reference. No parent SKILL.md needed. Source: *Accelerate* (Forsgren, Humble, Kim), Ch. 2–3.

---

## What DORA Metrics Are (and Are Not)

DORA metrics measure *software delivery performance* — validated by four years of cross-industry survey data using confirmatory factor analysis and structural equation modelling. They are the third metric category, distinct from system metrics ("is the infrastructure healthy?") and product metrics ("is the product delivering value?"). The question they answer is: "Is the team delivering effectively?"

**They are not:**
- Application metrics — do not source them from OTel, Prometheus counters, or domain events
- SLO metrics — they do not measure service reliability
- Substitute for product metrics — high delivery performance does not guarantee product success

**They require:**
- Access to the GitHub Actions API (or equivalent CI system API)
- Access to the Alertmanager API
- Read access to the cd-pipeline GitOps environment repository commit log

**Owner:** platform-engineer (not data-engineer, not backend-engineer).

---

## Performance Cluster Benchmarks (Accelerate, Ch. 3)

Use these as target anchors in the metric definition table. Do not treat a single anomalous week as a cluster regression — the boundaries are directional.

| Metric | High performer | Medium performer | Low performer |
|---|---|---|---|
| Deployment Frequency | On demand (multiple/day or multiple/week) | Weekly to monthly | Monthly to quarterly |
| Lead Time for Changes | < 1 hour | 1 day to 1 week | 1 month to 6 months |
| MTTR | < 1 hour | < 1 day | 1 day to 1 week |
| Change Failure Rate | 0–15% | 16–30% | 31–60% |

**Correlated, not independent:** improving Deployment Frequency without improving test automation typically increases Change Failure Rate. All four move together; gaming one metric degrades another.

---

## Metric 1: Deployment Frequency

### Definition

How often the team deploys a service to production. Measured per service, per environment. The denominator is calendar week; the numerator is successful main-branch deployments.

### Instrumentation Source

GitHub Actions `workflow_run` events, filtered to:
- `conclusion = "success"`
- `head_branch = "main"` (or the production branch name)
- `event = "push"` or `event = "workflow_dispatch"` (not PR-triggered runs)

### Collection Approach

A scheduled GitHub Actions workflow runs nightly and POSTs the day's count to the Prometheus Pushgateway:

```yaml
# .github/workflows/dora-deployment-frequency.yml
name: DORA — Deployment Frequency Collector
on:
  schedule:
    - cron: '0 1 * * *'   # 01:00 UTC daily
  workflow_dispatch:

jobs:
  collect:
    runs-on: ubuntu-latest
    steps:
      - name: Count successful main-branch deployments (last 24h)
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          PUSHGATEWAY_URL: ${{ secrets.PROMETHEUS_PUSHGATEWAY_URL }}
          SERVICE_NAME: ${{ github.event.repository.name }}
        run: |
          COUNT=$(gh api \
            "/repos/${{ github.repository }}/actions/runs?branch=main&status=success&created=>$(date -d '24 hours ago' --utc +%Y-%m-%dT%H:%M:%SZ)" \
            --paginate --jq '[.workflow_runs[] | select(.conclusion=="success")] | length')
          echo "sdlc_deployment_frequency_total{service=\"$SERVICE_NAME\",env=\"production\"} $COUNT" \
            | curl --data-binary @- "$PUSHGATEWAY_URL/metrics/job/dora/instance/$SERVICE_NAME"
```

### Storage

Prometheus Pushgateway metric:

```
sdlc_deployment_frequency_total{service="<name>", env="production"} <count>
```

Grafana panels use this metric with a `sum_over_time` range query to produce weekly and monthly frequency charts.

### Grafana Annotation (alternative)

For teams that prefer annotating Grafana dashboards rather than Pushgateway metrics: every successful deployment workflow can POST a Grafana annotation via the Grafana HTTP API (`POST /api/annotations`) with `tags: ["deployment", service_name]`. The annotation timeline chart provides visual Deployment Frequency without a Pushgateway.

---

## Metric 2: Lead Time for Changes

### Definition

The elapsed time from the oldest commit in a merged PR first being authored to the point when that commit is running in production. This is the canonical *Accelerate* definition: it measures the full pipeline from a developer writing code to a customer receiving it.

### Formula

```
Lead Time = deploy_complete_timestamp − first_commit_authored_date
```

Where:
- `first_commit_authored_date` = the earliest `authored_date` among all commits in the PR (via GitHub commit API, walking from the PR merge commit's parents)
- `deploy_complete_timestamp` = the timestamp of the cd-pipeline's environment-repo promotion PR merge into the target environment branch (the GitOps reconciliation complete event, per `cd-pipeline`'s promotion flow)

### Instrumentation Source

Two API calls per deployment:

1. **GitHub commit API** — given the merge commit SHA of the feature PR on `main`, walk the parent commit graph to collect all `authored_date` values; take the minimum.
2. **cd-pipeline promotion PR** — the merge timestamp of the GitOps environment-repo PR that promotes the immutable image digest to the target environment.

### Collection Approach

A PostToolUse hook or a cd-pipeline step that fires after the promotion PR merges:

```python
import requests
from datetime import datetime, timezone

def compute_lead_time(
    repo: str,            # "org/service-repo"
    feature_pr_merge_sha: str,
    promotion_merge_ts: datetime,
    gh_token: str,
) -> float:
    """Returns lead time in seconds."""
    headers = {"Authorization": f"Bearer {gh_token}"}
    # Walk commits reachable from the merge commit but not from main before the PR
    commits_url = f"https://api.github.com/repos/{repo}/commits"
    commits = requests.get(
        commits_url,
        headers=headers,
        params={"sha": feature_pr_merge_sha, "per_page": 100},
    ).json()
    authored_dates = [
        datetime.fromisoformat(c["commit"]["author"]["date"].replace("Z", "+00:00"))
        for c in commits
    ]
    oldest = min(authored_dates)
    return (promotion_merge_ts - oldest).total_seconds()
```

### Storage

```sql
-- Table: delivery_metrics_daily
CREATE TABLE delivery_metrics_daily (
    id              BIGSERIAL PRIMARY KEY,
    service         TEXT NOT NULL,
    env             TEXT NOT NULL,
    measured_date   DATE NOT NULL,
    metric          TEXT NOT NULL,   -- 'lead_time_seconds', 'change_failure_rate'
    value           NUMERIC NOT NULL,
    recorded_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ON delivery_metrics_daily (service, env, metric, measured_date);
```

Lead time per deployment is stored as `metric = 'lead_time_seconds'`. Grafana reads P50/P95 with `PERCENTILE_CONT` queries over the rolling 30-day window.

### Prometheus (complementary)

Optionally expose as a Prometheus histogram via Pushgateway:

```
sdlc_lead_time_seconds_bucket{service="<name>", env="production", le="3600"} <count>
sdlc_lead_time_seconds_bucket{service="<name>", env="production", le="86400"} <count>
sdlc_lead_time_seconds_bucket{service="<name>", env="production", le="+Inf"} <count>
```

---

## Metric 3: MTTR (Mean Time to Restore)

### Definition

The elapsed time from when a production incident alert first fired to when it was resolved and closed. Measured as a histogram (P50, P95) per service, not as a single mean — the mean is misleading because incident duration distributions are heavy-tailed.

### Formula

```
MTTR for one incident = alert_resolved_timestamp − alert_fired_timestamp
```

Aggregate as `alertmanager_alert_duration_seconds` histogram buckets.

### Instrumentation Source

Alertmanager `/api/v2/alerts` — Alertmanager records both the firing time (`startsAt`) and the resolved time (`endsAt`) for every alert. No custom instrumentation needed if Alertmanager is already deployed (it is, by default in the OTel + Prometheus + Grafana stack defined in CLAUDE.md tech stack defaults).

### Collection Approach

A Prometheus recording rule computes the histogram from Alertmanager metrics. Alertmanager natively exposes:

```
alertmanager_alerts{state="firing"} — gauge, current count
alertmanager_alert_groups — gauge
```

For per-incident duration, use the Alertmanager Webhook receiver to POST resolved alerts to a collector service that computes `endsAt − startsAt` and pushes a histogram observation:

```go
// Alertmanager webhook receiver handler (Go, net/http + chi)
func HandleAlertWebhook(w http.ResponseWriter, r *http.Request) {
    var payload alertmanager.WebhookMessage
    if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
        http.Error(w, "bad request", http.StatusBadRequest)
        return
    }
    for _, alert := range payload.Alerts {
        if alert.Status == "resolved" {
            duration := alert.EndsAt.Sub(alert.StartsAt).Seconds()
            alertDurationHistogram.WithLabelValues(
                alert.Labels["service"],
                alert.Labels["severity"],
            ).Observe(duration)
        }
    }
    w.WriteHeader(http.StatusOK)
}
```

### Storage

Prometheus histogram metric (registered in the collector service):

```go
var alertDurationHistogram = prometheus.NewHistogramVec(
    prometheus.HistogramOpts{
        Name:    "alertmanager_alert_duration_seconds",
        Help:    "Duration from alert firing to resolution, in seconds",
        Buckets: []float64{300, 900, 1800, 3600, 7200, 14400, 28800, 86400},
        // 5m, 15m, 30m, 1h, 2h, 4h, 8h, 24h
    },
    []string{"service", "severity"},
)
```

Grafana panels:

```promql
# P50 MTTR per service, last 30 days
histogram_quantile(0.50, sum(rate(alertmanager_alert_duration_seconds_bucket[30d])) by (le, service))

# P95 MTTR per service, last 30 days
histogram_quantile(0.95, sum(rate(alertmanager_alert_duration_seconds_bucket[30d])) by (le, service))
```

### Alert on MTTR Degradation

```yaml
# Prometheus alert rule
- alert: MTTRDegrading
  expr: >
    histogram_quantile(0.95,
      sum(rate(alertmanager_alert_duration_seconds_bucket[7d])) by (le, service)
    ) > 14400
  for: 0m
  labels:
    severity: warning
  annotations:
    summary: "P95 MTTR for {{ $labels.service }} exceeds 4 hours over last 7 days"
```

---

## Metric 4: Change Failure Rate

### Definition

The percentage of production deployments (promotions) that caused a service degradation and required a rollback within the same deployment window. The denominator is all promotion commits; the numerator is promotion commits that triggered a rollback (`git revert` of a promotion commit, as prescribed by `cd-pipeline`).

### Formula

```
Change Failure Rate = (count of [ROLLBACK] commits in window) / (count of all promotion commits in window) × 100
```

### Convention

The `cd-pipeline` skill prescribes `git revert` as the rollback action. To make Change Failure Rate computable from the commit log, every rollback commit in the environment repository **must** include `[ROLLBACK]` in the commit message subject line. This is a convention enforced by the cd-pipeline's rollback runbook — not a code gate.

Example rollback commit message:

```
[ROLLBACK] revert: promote data-extractor v1.4.2 → v1.4.1

Reason: elevated error rate in extraction confidence scoring.
Reverts: abc123def
```

### Instrumentation Source

The cd-pipeline GitOps environment repository commit log. No CI API call needed — this is a `git log` query:

```bash
#!/bin/bash
# compute-change-failure-rate.sh
# Usage: ./compute-change-failure-rate.sh <env-repo-path> <service> <days>
ENV_REPO="$1"
SERVICE="$2"
DAYS="${3:-30}"

cd "$ENV_REPO"

TOTAL=$(git log --oneline \
  --since="${DAYS} days ago" \
  --grep="promote ${SERVICE}" \
  | wc -l)

ROLLBACKS=$(git log --oneline \
  --since="${DAYS} days ago" \
  --grep="\[ROLLBACK\].*${SERVICE}" \
  | wc -l)

if [ "$TOTAL" -eq 0 ]; then
  echo "0.00"
else
  echo "scale=4; ($ROLLBACKS / $TOTAL) * 100" | bc
fi
```

### Storage

Write daily to `delivery_metrics_daily` (same table as Lead Time):

```sql
INSERT INTO delivery_metrics_daily (service, env, measured_date, metric, value)
VALUES ('data-extractor', 'production', CURRENT_DATE, 'change_failure_rate_pct', 4.35);
```

### Grafana Panel

```sql
-- 30-day rolling Change Failure Rate per service
SELECT
  service,
  AVG(value) AS change_failure_rate_pct
FROM delivery_metrics_daily
WHERE
  metric = 'change_failure_rate_pct'
  AND measured_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY service
ORDER BY change_failure_rate_pct DESC;
```

---

## Delivery Performance Dashboard Layout

The Grafana delivery performance dashboard (distinct from the SLO dashboard) should display all four DORA metrics together — they are correlated, and seeing them side by side surfaces the trade-offs:

```
┌─────────────────────────────────────────────────────────────────┐
│  Delivery Performance — [Service Name]           [30d / 90d]   │
├──────────────────┬──────────────────┬──────────────────────────┤
│ Deploy Frequency │ Lead Time P50    │ MTTR P50 / P95           │
│ [stat tile]      │ [stat tile]      │ [stat tiles]             │
├──────────────────┴──────────────────┴──────────────────────────┤
│ Deployment Frequency over time [bar chart, weekly bins]        │
├─────────────────────────────────────────────────────────────────┤
│ Lead Time distribution [histogram]                             │
├──────────────────────────────┬──────────────────────────────────┤
│ MTTR distribution [histogram]│ Change Failure Rate [gauge/bar] │
└──────────────────────────────┴──────────────────────────────────┘
```

Background color the stat tiles using Accelerate cluster thresholds (green = High, yellow = Medium, red = Low).

---

## DORA Quarterly Retrospective Protocol

Run once per quarter. The question is not "what went wrong" but "which metric moved, in which direction, and why."

1. Pull all four DORA metrics trended over the quarter from the delivery performance dashboard.
2. Identify the metric with the most adverse movement.
3. For Deployment Frequency decline: check branch lifetime (are branches older than 1 day before merge? — per Accelerate, this is the trunk-based development signal).
4. For Lead Time increase: check PR review cycle time and test suite duration as the two largest contributors.
5. For MTTR increase: check whether runbooks exist for the incident categories that took longest to resolve.
6. For Change Failure Rate increase: check whether test coverage dropped before the failing deployments (per Accelerate, Ch. 2, the four metrics move together — CFR increase without frequency increase signals a test automation gap).

Outputs of the retrospective: one concrete action per metric that regressed, assigned to a named owner, with a target date.

---

## Integration with cd-pipeline and ci-pipeline

- **`cd-pipeline`** generates the raw data for Change Failure Rate (via rollback commits) and Lead Time (via promotion PR merge timestamp). The platform-engineer sets up the nightly collection job; `cd-pipeline` needs no modification — only the rollback commit message convention.
- **`ci-pipeline`** generates the raw data for Deployment Frequency (via successful workflow_run events on main). The Deployment Frequency collector workflow (above) runs as a separate workflow in the same repository — it does not modify the CI pipeline's job graph.
- **MTTR** is sourced from Alertmanager, which is already deployed in the observability stack (`opentelemetry-instrumentation`). The Alertmanager webhook receiver is a small standalone service (< 100 lines of Go) deployed alongside the collector.

These four collection points are the only infrastructure additions needed to instrument the DORA four.
