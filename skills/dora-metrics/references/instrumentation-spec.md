# DORA Metrics — Instrumentation Specification

This reference is self-contained. It specifies exactly how each of the Four Key Metrics is instrumented in this platform stack (GitHub Actions + Alertmanager + Grafana + Prometheus). Use it when implementing the collection pipeline for a service's delivery performance dashboard.

---

## Stack Components Involved

| Component | Role in DORA instrumentation |
|---|---|
| GitHub Actions | Source of deployment events (workflow runs on main branch) |
| GitHub REST API | Query interface for workflow run timestamps and commit metadata |
| Alertmanager | Source of incident lifecycle events (FiredAt / ResolvedAt) |
| Prometheus | Time-series store for computed DORA metrics |
| Pushgateway | Bridge between CD pipeline steps and Prometheus (ephemeral job metrics) |
| Grafana | Query and dashboard layer; computes rates and ratios from stored series |

---

## Metric 1: Deployment Frequency

### Event Source

GitHub Actions workflow run events on the `main` branch of each service's repository. Specifically: a completed, successful run of the job named `deploy-production` (or equivalent per service's CD workflow file) on a workflow triggered by a `push` to `main`.

### Data Collection Method

**Option A — Push from CD pipeline (preferred):**

In the `deploy-production` job's final step, emit a Prometheus counter increment to the Pushgateway:

```bash
# Final step in .github/workflows/cd.yml, after successful production deploy
cat <<EOF | curl --data-binary @- "${PUSHGATEWAY_URL}/metrics/job/deployment_frequency/instance/${SERVICE_NAME}"
# TYPE deployment_total counter
# HELP deployment_total Total number of successful production deployments.
deployment_total{service="${SERVICE_NAME}",environment="production"} 1
EOF
```

Prometheus scrapes the Pushgateway on its normal scrape interval. The counter value increments by 1 per successful deploy; the deployment rate over a window is computed in Grafana.

**Option B — Pull from GitHub API (fallback for retrofitting):**

Query the GitHub Actions REST API for completed workflow runs:

```bash
gh api \
  "/repos/{owner}/{repo}/actions/workflows/cd.yml/runs?branch=main&status=success&per_page=100" \
  --jq '.workflow_runs[] | {id, created_at, updated_at}'
```

Use `updated_at` (job completion time) as the deployment timestamp. Script this into a Prometheus exporter that runs every 5 minutes and updates a gauge.

### Prometheus Series

```
deployment_total{service, environment}       # counter; increment per successful deploy
```

### Grafana Query — Deployment Frequency (per day, 28-day window)

```promql
increase(deployment_total{service="$service", environment="production"}[$__range]) / 28
```

Display as: deployments per day. Compare against High performer threshold (>1/day), Medium (1/week to 1/month = 0.03–0.14/day).

### Grafana Query — Raw Count (7-day)

```promql
increase(deployment_total{service="$service", environment="production"}[7d])
```

---

## Metric 2: Lead Time for Changes

### Event Source

Two timestamps from the same GitHub Actions workflow run:

1. **Commit merged timestamp:** The `pushed_at` field of the `push` event that triggered the workflow, or the commit's `committer.date` from the GitHub Commits API. This is when the PR merge commit landed on `main`.
2. **Deploy completed timestamp:** The `updated_at` field of the `deploy-production` workflow run (when the final job step completed successfully).

### Calculation

```
lead_time_seconds = deploy_completed_at_unix - commit_merged_at_unix
```

### Data Collection Method

In the `deploy-production` job's final step, after confirming a successful production deploy, compute and push the lead time:

```bash
# Get the commit timestamp for the HEAD commit that triggered this run
COMMIT_TS=$(gh api /repos/${GITHUB_REPOSITORY}/commits/${GITHUB_SHA} \
  --jq '.commit.committer.date' | date -d - +%s)

# Current time is deploy complete time
DEPLOY_TS=$(date +%s)

LEAD_TIME=$((DEPLOY_TS - COMMIT_TS))

cat <<EOF | curl --data-binary @- "${PUSHGATEWAY_URL}/metrics/job/lead_time/instance/${SERVICE_NAME}"
# TYPE deployment_lead_time_seconds gauge
# HELP deployment_lead_time_seconds Lead time for changes in seconds (commit to production).
deployment_lead_time_seconds{service="${SERVICE_NAME}",environment="production"} ${LEAD_TIME}
EOF
```

Note: this pushes the most recent lead time as a gauge. To compute averages over a window, use a histogram instead and store observations:

```bash
# Push as a histogram observation (requires a custom exporter or recording rule)
# Alternatively: store as a gauge and compute the rolling average in Grafana
```

### Prometheus Series

```
deployment_lead_time_seconds{service, environment}   # gauge; seconds; updated per deploy
```

For averaging over many deploys, a summary or histogram is more accurate. For a 1-engineer solo-operator context, the gauge (last observation) is sufficient for trend tracking; add a histogram when multiple deploys per day make the single-observation gauge misleading.

### Grafana Query — Average Lead Time (last 28 days)

Since the gauge holds the most recent value, use a recording rule that captures each observation:

```promql
# Recording rule (add to prometheus/rules/dora.yml):
- record: deployment_lead_time_seconds_avg28d
  expr: avg_over_time(deployment_lead_time_seconds{environment="production"}[28d])
```

Display as: minutes (divide by 60). Compare against High performer threshold (<60 minutes = <3,600 seconds).

### Grafana Query — Human-Readable Threshold Annotation

Annotate the panel with reference lines at:
- 3,600 seconds (1 hour) — High/Medium performer boundary
- 86,400 seconds (1 day) — upper Medium boundary
- 604,800 seconds (1 week) — Medium/Low boundary

---

## Metric 3: Time to Restore Service (MTTR)

### Event Source

Alertmanager incident lifecycle for every alert that fires and resolves against a production service. Each Alertmanager alert carries:

- `StartsAt` — when Alertmanager first fired the alert.
- `EndsAt` — when Alertmanager resolved the alert (either by the condition clearing, or by silence expiry).

For MTTR, the relevant alerts are those representing real user-facing incidents — alerts with `severity="critical"` or `severity="warning"` that resulted in on-call action. Maintenance windows silenced from the start are excluded.

### Data Collection Method

**Option A — Alertmanager webhook receiver (preferred):**

Configure Alertmanager to POST alert lifecycle events to a small webhook that computes and stores restore duration:

```yaml
# alertmanager.yml (receiver addition)
receivers:
  - name: dora-mttr
    webhook_configs:
      - url: 'http://dora-exporter.monitoring.svc.cluster.local/alert'
        send_resolved: true
```

The `dora-exporter` service receives the resolved webhook, computes `EndsAt - StartsAt` in seconds, and increments a histogram:

```python
# Pseudocode for dora-exporter webhook handler
def on_alert_resolved(alert):
    if alert['status'] == 'resolved' and alert['labels']['severity'] in ('critical', 'warning'):
        service = alert['labels']['service']
        restore_seconds = (parse_iso(alert['endsAt']) - parse_iso(alert['startsAt'])).total_seconds()
        incident_restore_histogram.observe(restore_seconds, {'service': service})
        incident_restore_total.inc({'service': service})
```

**Option B — Alertmanager API polling (simpler, lower fidelity):**

Query the Alertmanager silence and alert history API periodically:

```bash
# List recently resolved alerts
curl http://alertmanager.monitoring.svc.cluster.local/api/v2/alerts?silenced=false&inhibited=false
```

Parse `startsAt` / `endsAt` pairs; compute duration; push to Pushgateway.

### Prometheus Series

```
incident_restore_duration_seconds_bucket{service, severity, le}    # histogram
incident_restore_duration_seconds_count{service, severity}
incident_restore_duration_seconds_sum{service, severity}
```

### Grafana Query — MTTR (mean, 28-day window)

```promql
rate(incident_restore_duration_seconds_sum{service="$service"}[28d])
/
rate(incident_restore_duration_seconds_count{service="$service"}[28d])
/ 60
```

Display as: minutes. Compare against High performer threshold (<60 minutes).

### Grafana Query — P95 Restore Time

```promql
histogram_quantile(0.95,
  rate(incident_restore_duration_seconds_bucket{service="$service"}[28d])
) / 60
```

---

## Metric 4: Change Failure Rate

### Event Source

Two counters in the same CD pipeline, both on the `main` branch:

1. **`deployment_total`** — incremented on every successful production deploy (see Metric 1).
2. **`change_failure_total`** — incremented when a `git revert` of a production promotion commit is merged to `main`. The `cd-pipeline` skill prescribes `git revert <promotion-commit-sha>` as the standard rollback mechanism; that revert merge is the rollback event.

### Detecting Rollback Events

A production rollback is a commit to `main` whose message matches the pattern:

```
Revert "Promote <service-name>:<digest> to production"
```

Detect in CI via the commit message of each push to `main`:

```bash
# .github/workflows/ci.yml — step added to the main-branch gate
COMMIT_MSG=$(git log -1 --format="%s")
if echo "$COMMIT_MSG" | grep -qE '^Revert "Promote .+ to production"'; then
  SERVICE=$(echo "$COMMIT_MSG" | grep -oP '(?<=Revert "Promote )[^:]+')
  cat <<EOF | curl --data-binary @- "${PUSHGATEWAY_URL}/metrics/job/change_failure/instance/${SERVICE}"
# TYPE change_failure_total counter
# HELP change_failure_total Total number of production deployments that required a rollback.
change_failure_total{service="${SERVICE}",environment="production"} 1
EOF
fi
```

### Prometheus Series

```
change_failure_total{service, environment}    # counter; increment per rollback
deployment_total{service, environment}        # counter; already defined above
```

### Grafana Query — Change Failure Rate (28-day rolling)

```promql
increase(change_failure_total{service="$service", environment="production"}[28d])
/
increase(deployment_total{service="$service", environment="production"}[28d])
* 100
```

Display as: percentage. Compare against thresholds: ≤15% (High), 16–30% (Medium), ≥46% (Low).

### Grafana Query — 7-day CFR (for alert threshold)

```promql
increase(change_failure_total{service="$service", environment="production"}[7d])
/
increase(deployment_total{service="$service", environment="production"}[7d])
* 100
```

Alert rule (add to `alerting-rules-design`):

```yaml
- alert: HighChangeFailureRate
  expr: |
    (
      increase(change_failure_total{environment="production"}[7d])
      /
      increase(deployment_total{environment="production"}[7d])
    ) * 100 > 30
  for: 0m
  labels:
    severity: warning
  annotations:
    summary: "CFR {{ $value | printf \"%.1f\" }}% for {{ $labels.service }} exceeds Medium-cluster boundary (30%)"
    description: "More than 30% of production deployments in the last 7 days required a rollback. Feature work should pause while the root cause is investigated."
```

---

## Prometheus Recording Rules — DORA Summary

Add this file as `prometheus/rules/dora.yml` in the environment repository:

```yaml
groups:
  - name: dora_metrics
    interval: 5m
    rules:
      # Lead time: rolling 28-day average in minutes
      - record: dora:lead_time_minutes:avg28d
        expr: avg_over_time(deployment_lead_time_seconds[28d]) / 60

      # MTTR: rolling 28-day mean in minutes
      - record: dora:mttr_minutes:avg28d
        expr: |
          rate(incident_restore_duration_seconds_sum[28d])
          /
          rate(incident_restore_duration_seconds_count[28d])
          / 60

      # Deployment frequency: per-day rate over rolling 7 days
      - record: dora:deployment_frequency:per_day_7d
        expr: increase(deployment_total{environment="production"}[7d]) / 7

      # Change failure rate: rolling 28-day percentage
      - record: dora:change_failure_rate:pct28d
        expr: |
          (
            increase(change_failure_total{environment="production"}[28d])
            /
            increase(deployment_total{environment="production"}[28d])
          ) * 100
```

---

## Data Retention

DORA metrics are trend metrics, not real-time signals. Configure Prometheus to retain the raw DORA counters and gauges for at least 90 days (vs. the default 15 days for most metrics). Set this in `prometheus.yml`:

```yaml
global:
  evaluation_interval: 1m

storage:
  tsdb:
    retention.time: 90d
```

The recording rules (`dora:*`) can be stored in Thanos or any long-term storage layer if the quarterly retrospective requires 12-month trend views.

---

## Rollout Order

Instrument metrics in this order; each step is independently valuable:

1. **Deployment Frequency** — simplest; one counter in the CD job's final step. Immediately tells you batch size.
2. **Lead Time for Changes** — two timestamps already available in GitHub Actions; requires only the math to join them.
3. **Change Failure Rate** — requires the rollback convention (`git revert "Promote..."`) to be consistently followed. Enforce via a PR title lint rule.
4. **MTTR** — requires the Alertmanager webhook receiver or polling script. Most complex; valuable only once the service has real production incidents to measure.
