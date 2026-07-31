# Delivery Performance Dashboard

This reference is self-contained. It specifies the Grafana dashboard layout for tracking all four DORA metrics as a companion to the service's SLO dashboard. Use it when creating or reviewing the `dora-dashboard.json` Grafana dashboard in the monitoring configuration.

---

## Design Principles

The delivery performance dashboard is a **trend and cluster dashboard**, not a real-time operations dashboard. It answers: "Is our delivery performance improving or degrading, and which DORA cluster are we in?" It is reviewed at the quarterly retrospective, checked weekly as a hygiene habit, and never paged on directly (with two exceptions — see Alert Annotations below).

Key design constraints:

1. **Complement, don't replace, the SLO dashboard.** The SLO dashboard (`alerting-rules-design`) shows what users experience right now. This dashboard shows how safely and quickly the team is changing the system. Both are open during an incident retrospective; neither supersedes the other.
2. **28-day window as the default time range.** DORA metrics are inherently trend metrics. A 1-hour or 1-day window is meaningless for Deployment Frequency or Lead Time. Set the dashboard's default time range to `now-28d` to `now`.
3. **Cluster band annotations on every panel.** Every panel must show the High/Medium/Low cluster thresholds as reference lines so the current value is immediately interpretable without consulting the benchmark table.
4. **Color encoding matches cluster, not traffic-light convention.** Red/yellow/green for "bad/warning/good" is ambiguous across dashboards. Use the cluster bands: the panel value fills the cluster color for its current band (High = blue, Medium = amber, Low = red), not a fixed color by metric name.

---

## Dashboard Row Layout

### Row 1: Summary — Cluster Scorecard

A single stat row at the top with four panels, one per metric. Each shows the current 28-day value and a color band indicating the cluster.

| Panel | Query | Unit | Cluster thresholds (ref lines) |
|---|---|---|---|
| Deployment Frequency | `dora:deployment_frequency:per_day_7d` | deploys/day | High ≥1/day; Medium 0.14–1/day; Low <0.14/day |
| Lead Time for Changes | `dora:lead_time_minutes:avg28d` | minutes | High <60; Medium 60–10,080 (1 wk); Low >10,080 |
| MTTR (mean) | `dora:mttr_minutes:avg28d` | minutes | High <60; Medium 60–1,440 (1 day); Low >1,440 |
| Change Failure Rate | `dora:change_failure_rate:pct28d` | % | High <15; Medium 15–30; Low >46 |

Each Stat panel uses:
- `Thresholds` in Grafana set to the cluster boundary values.
- `Color mode: background` so the entire panel background reflects the cluster.
- `Text size: auto` so the value is the dominant element.

### Row 2: Deployment Frequency — Trend

**Purpose:** Show how often the team is deploying over time; detect slowdowns.

**Panel type:** Time-series graph (bar chart, one bar per day)

**Query:**

```promql
increase(deployment_total{service="$service", environment="production"}[1d])
```

**Annotations:**
- Horizontal reference line at `1` (High cluster minimum: 1 deploy/day)
- Horizontal reference line at `0.14` (approximately 1/week, the Medium lower bound)

**Variable:** `$service` — drop-down listing all services from label values of `deployment_total`.

**Interpretation guide (panel description):**
> Bars below 0.14/day indicate a monthly or less deployment cadence (Low cluster). Bars consistently above 1/day indicate High performer territory. Gaps of multiple days are normal; trends over weeks matter more than individual days.

### Row 3: Lead Time for Changes — Trend

**Purpose:** Show how fast the pipeline moves from merge to production.

**Panel type:** Time-series graph (line, points on each deploy)

**Query:**

```promql
deployment_lead_time_seconds{service="$service", environment="production"} / 60
```

This shows a point for every deploy (the gauge value at the time of each push). If the service uses a recording rule, use `dora:lead_time_minutes:avg28d` as an overlapping average line.

**Annotations:**
- Horizontal reference line at `60` minutes (High/Medium boundary)
- Horizontal reference line at `1440` minutes = 1 day (Medium lower boundary for a 1-week target)
- Horizontal reference line at `10080` minutes = 1 week (Medium/Low boundary)

**Color threshold:**
- Green: < 60 min
- Amber: 60 – 10,080 min
- Red: > 10,080 min

**Panel description:**
> Each point represents one production deployment. Lead time is measured from the merge commit timestamp to the deploy completion timestamp. Reference lines show the High (<1 hour), Medium (up to 1 week), and Low (over 1 week) cluster boundaries.

### Row 4: Time to Restore Service (MTTR) — Trend

**Purpose:** Show how quickly the team resolves production incidents over time.

**Panel type:** Time-series graph (point per incident, rolling mean line overlay)

**Primary query (individual incidents):**

```promql
incident_restore_duration_seconds{service="$service"} / 60
```

**Overlay query (rolling 28-day mean):**

```promql
dora:mttr_minutes:avg28d{service="$service"}
```

**Annotations:**
- Horizontal reference line at `60` minutes (High cluster ceiling)
- Horizontal reference line at `1440` minutes = 1 day (Medium cluster ceiling)

**Alert annotation:**
Add an annotation query that marks the panel when the MTTR alert fires:

```promql
ALERTS{alertname="HighMTTR", service="$service", alertstate="firing"}
```

**Panel description:**
> Each point represents one resolved incident. The rolling mean line shows the 28-day MTTR trend. The High performer threshold is 1 hour; the Medium threshold is 1 day. Incidents with restore time above the red line indicate the recovery system (runbooks, rollback automation, on-call response) needs improvement.

**Data gap handling:** If no incidents occurred in the window, this panel will be empty. This is a positive signal — annotate the panel with "No incidents in this window" using a Grafana `No data` state display.

### Row 5: Change Failure Rate — Trend

**Purpose:** Show what fraction of deployments required rollback over time.

**Panel type:** Time-series graph (line, rolling window)

**Primary query (rolling 28-day CFR):**

```promql
(
  increase(change_failure_total{service="$service", environment="production"}[28d])
  /
  increase(deployment_total{service="$service", environment="production"}[28d])
) * 100
```

**Secondary query (rolling 7-day CFR for alert comparison):**

```promql
(
  increase(change_failure_total{service="$service", environment="production"}[7d])
  /
  increase(deployment_total{service="$service", environment="production"}[7d])
) * 100
```

Display the 7-day line as a dashed secondary series on the same panel.

**Annotations:**
- Horizontal reference line at `15%` (High/Medium boundary)
- Horizontal reference line at `30%` (Medium cluster upper bound and alert threshold)
- Horizontal reference line at `46%` (Low cluster entry — CFR gap 31–45% is between clusters)

**Alert annotation:**

```promql
ALERTS{alertname="HighChangeFailureRate", service="$service", alertstate="firing"}
```

**Panel description:**
> The solid line shows the rolling 28-day Change Failure Rate. The dashed line shows the 7-day CFR (the alert threshold). A CFR above 30% over 7 days triggers an alert and should pause feature work. The 28-day trend is the cluster placement metric; use the 7-day line for operational decisions.

---

## Dashboard Variables

Define these Grafana variables at the dashboard level:

| Variable | Type | Query | Label |
|---|---|---|---|
| `$service` | Query | `label_values(deployment_total{environment="production"}, service)` | Service |
| `$environment` | Custom | `production,staging` | Environment |

The dashboard defaults to `$environment=production` and `$service=<first service>`.

---

## Dashboard Metadata

```json
{
  "title": "Delivery Performance — DORA Metrics",
  "tags": ["dora", "delivery", "deploy", "platform"],
  "timezone": "browser",
  "time": {
    "from": "now-28d",
    "to": "now"
  },
  "refresh": "1h",
  "uid": "dora-delivery-performance",
  "version": 1,
  "description": "Four Key Metrics (DORA) companion to the SLO dashboard. Shows Deployment Frequency, Lead Time for Changes, MTTR, and Change Failure Rate with High/Medium/Low performer cluster thresholds."
}
```

Store as `monitoring/grafana/dashboards/dora-delivery-performance.json` in the environment repository (alongside the SLO dashboard JSON).

---

## Alert Annotations

Two alerts from `references/instrumentation-spec.md` are surfaced as panel annotations on this dashboard:

1. **HighChangeFailureRate** — annotates Row 5 (CFR panel) when the 7-day CFR exceeds 30%. This alert fires when feature deploys should pause; the annotation makes the trigger visible in context.
2. **HighMTTR** — annotate Row 4 (MTTR panel) if you add an alert on MTTR exceeding 24 hours for a P1 incident (recommended but optional at MVP — MTTR data quality must be solid before an alert on it is trustworthy).

Do not add panel alerts on Deployment Frequency or Lead Time. These metrics are investigated, not paged on (see SKILL.md: "Investigate (retrospective, not incident)" section).

---

## SLO Dashboard Integration

The delivery performance dashboard links to the SLO dashboard via a Grafana dashboard link:

```json
{
  "links": [
    {
      "title": "SLO Dashboard",
      "url": "/d/slo-service-reliability/service-level-objectives",
      "type": "link",
      "icon": "external link"
    }
  ]
}
```

Add the reciprocal link on the SLO dashboard pointing back to the DORA dashboard. This makes both measurement axes one click away during an incident retrospective.

---

## Provisioning the Dashboard

The dashboard JSON file is deployed via Grafana's dashboard provisioning mechanism (a ConfigMap or Helm chart value, depending on the deployment model):

```yaml
# monitoring/grafana/provisioning/dashboards/dora.yaml
apiVersion: 1
providers:
  - name: dora-metrics
    type: file
    options:
      path: /etc/grafana/dashboards/dora
    updateIntervalSeconds: 60
    allowUiUpdates: false
```

Mount the dashboard JSON into the Grafana pod via the same Helm values file that mounts the SLO dashboard. Both dashboards are read-only in production (allowUiUpdates: false); edits go through the environment repository's GitOps pipeline.

---

## Quarterly Retrospective Snapshot Protocol

At each quarterly retrospective:

1. Open the dashboard with time range `now-90d` to `now` (override the default 28-day window) to see the quarter.
2. Export a PNG snapshot of each row for the retrospective document: Grafana Share → Snapshot → Download PNG.
3. Record current cluster position per metric in the retrospective document (use the quick-card in `references/cluster-benchmarks.md`).
4. Identify one practice change per the retrospective guidance in `references/cluster-benchmarks.md`.
5. Reset the dashboard time range to the default `now-28d` after the retrospective.

The retrospective document is a dated Markdown file in the `retrospectives/` directory of the product repository. It is not a DORA artifact produced by the plugin; it is a team-authored record that cites the dashboard snapshots as evidence.
