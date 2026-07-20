---
name: alerting-rules-design
description: >
  Teaches how to design Prometheus alerting rules and Alertmanager routing —
  symptom-based alerts over cause-based, multiwindow multi-burn-rate alerts on
  Service Level Objectives with the standard fast/slow burn table, the page
  versus ticket severity split, alert hygiene (every page actionable with a
  runbook link, deduplication, grouping, inhibition), pipeline alerts for DLQ
  depth and consumer lag, and the review discipline that prunes noise before it
  breeds pager fatigue. Used by the platform-engineer during Deploy.
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, observability, alerting, alertmanager, burn-rate, slo, on-call, runbook]
---

# Alerting Rules Design

## Purpose

Alerts are the contract between the system and the human on call: *interrupt me only when a user-visible promise is at risk, and tell me what to do about it*. A good alerting design pages rarely, pages accurately, and attaches a runbook to every page. A bad one trains its sole operator — Shafi's platform has exactly one — to ignore the pager, which is worse than having no alerts at all.

This skill enforces the alerts as Prometheus rule groups evaluated by each tenant's Prometheus and routed by Alertmanager (self-hosted, frugal: email and chat webhooks, no paid paging SaaS). The alerts are defined *on* the Service Level Objectives from `slo-definition`, computed from the recorded series in `prometheus-metrics-design`, and resolved using the procedures in `runbook-authoring`.

---

## Symptom-Based over Cause-Based

Alert on what users experience (the symptom), not on what might explain it (the cause). Causes are legion, mostly harmless in isolation, and visible on dashboards when needed; symptoms are few and always matter.

| | Symptom (alert) | Cause (dashboard, not a page) |
|---|---|---|
| API | error-budget burn on availability/latency SLO | CPU high, GC pauses, one pod restarting |
| Pipeline | freshness SLO burning; DataAssets not classified in time | one consumer rebalancing, broker leader election |
| Dependency | user-facing errors from timeouts | Circuit Breaker half-open, single connection reset |

Two deliberate exceptions, alerted as *leading indicators* because they are early symptoms of a promise about to break:

1. **Dead Letter Queue (DLQ) depth** — a message in the DLQ *is* a user-visible failure (that DataAsset will never classify without intervention) and the freshness SLI won't count it as late until the deadline passes.
2. **Sustained consumer lag growth** — a pipeline filling faster than it drains breaks the freshness SLO on a delay; the derivative of lag predicts the breach before the SLI reports it.

Everything else that is a cause — pod restarts, node pressure, mesh retries — belongs on Grafana dashboards and in runbook diagnostics, not in the pager.

---

## Severity: Page or Ticket

Two severities only. A middle tier ("warning") accumulates alerts nobody owns.

| Severity | Meaning | Test | Delivery |
|---|---|---|---|
| **page** | A human must act *now*; user-visible damage is accruing | Would you get up at 03:00 for this? Is there an action to take? | immediate webhook/chat, aggressive repeat |
| **ticket** | A human must act *soon*; budget or capacity erodes over days | Can it wait until working hours without a promise breaking? | email/issue, daily digest pace |

If an alert fails both tests, it is not an alert — delete it or move it to a dashboard.

---

## Multiwindow Multi-Burn-Rate Alerts on SLOs

The standard policy (from the multiwindow method declared in `slo-definition`): each alert fires only when the burn rate exceeds its threshold over a **long** window (evidence it is real) *and* a **short** window (evidence it is still happening — so alerts stop promptly after recovery).

The standard table, for a 28-day SLO window:

| Alert | Budget consumed to trigger | Burn rate | Long window | Short window | Severity |
|---|---|---|---|---|---|
| Fast burn | 2% of budget in 1 h | 14.4 | 1 h | 5 m | **page** |
| Slow burn | 5% of budget in 6 h | 6 | 6 h | 30 m | **page** |
| Trickle | 10% of budget in 3 d | 1 | 3 d | 6 h | ticket |

Worked for the ClassifyDataAsset API SLO (99.5%, budget fraction 0.005): fast burn pages when the error ratio exceeds `14.4 × 0.005 = 7.2%` on both windows — an incident pace that would exhaust 28 days of budget in ~2 days.

```yaml
# rules/slo-burn-classify-api.yaml
groups:
  - name: slo-burn-classify-api
    rules:
      - alert: ClassifyAPIErrorBudgetFastBurn
        expr: |
          service:http_request_errors:ratio_rate1h{service="compliance-engine"}  > (14.4 * 0.005)
          and
          service:http_request_errors:ratio_rate5m{service="compliance-engine"}  > (14.4 * 0.005)
        labels: { severity: page, slo: classify-api-availability }
        annotations:
          summary: "ClassifyDataAsset API burning error budget at 14.4x — gone in ~2 days"
          runbook_url: "runbooks/compliance-engine/classify-api-error-burn.md"
      - alert: ClassifyAPIErrorBudgetSlowBurn
        expr: |
          service:http_request_errors:ratio_rate6h{service="compliance-engine"}  > (6 * 0.005)
          and
          service:http_request_errors:ratio_rate30m{service="compliance-engine"} > (6 * 0.005)
        labels: { severity: page, slo: classify-api-availability }
        annotations:
          summary: "ClassifyDataAsset API burning error budget at 6x — gone in ~5 days"
          runbook_url: "runbooks/compliance-engine/classify-api-error-burn.md"
```

Each window used (`rate5m`, `rate30m`, `rate1h`, `rate6h`) is a recording rule from `prometheus-metrics-design` — burn-rate alerts read pre-computed series, they do not run raw histogram queries. The latency SLO alerts identically, with "slow request" as the bad event; the pipeline freshness SLO alerts on the ratio of DataAssets missing the 15-minute deadline.

---

## Pipeline Alerts — DLQ and Consumer Lag

The leading-indicator alerts for the classification pipeline (estate-scanner → entity-extractor → compliance-engine over Redpanda):

```yaml
groups:
  - name: pipeline-leading-indicators
    rules:
      - alert: PipelineDLQNotEmpty
        expr: sum by (service, topic) (pipeline_dlq_depth) > 0
        for: 15m
        labels: { severity: ticket }
        annotations:
          summary: "{{ $labels.service }} has {{ $value }} messages in the DLQ on {{ $labels.topic }}"
          runbook_url: "runbooks/pipeline/dlq-drain.md"
      - alert: PipelineConsumerLagGrowing
        expr: |
          max by (service, topic) (pipeline_consumer_lag) > 1000
          and
          deriv(service:pipeline_consumer_lag:max[15m]) > 0
        for: 15m
        labels: { severity: page }
        annotations:
          summary: "{{ $labels.service }} lag on {{ $labels.topic }} is high and still growing — freshness SLO at risk"
          runbook_url: "runbooks/pipeline/consumer-lag.md"
```

DLQ depth is a ticket by default (Retry and Backoff already ran; the messages are parked, not bleeding) and escalates through the freshness SLO burn if the volume is user-significant. Lag pages only when both high *and* growing — a level check alone pages on every routine catch-up after a deploy.

---

## Alertmanager — Routing, Grouping, Inhibition

One Alertmanager per tenant stack, mirroring the per-tenant Prometheus topology. Grouping collapses simultaneous firings into one notification; inhibition silences the alerts a bigger alert explains; routes split page from ticket.

```yaml
# alertmanager.yml
route:
  receiver: tickets
  group_by: [alertname, service]
  group_wait: 30s          # collect a burst into one notification
  group_interval: 5m
  repeat_interval: 12h
  routes:
    - matchers: [severity="page"]
      receiver: oncall
      repeat_interval: 4h  # pages re-fire until resolved or silenced

inhibit_rules:
  - source_matchers: [alertname="TenantStackDown"]   # the whole stack is down —
    target_matchers: [severity=~"page|ticket"]        # silence every per-service alert
    equal: [tenant]
  - source_matchers: [severity="page"]                # a page inhibits its own ticket-level echo
    target_matchers: [severity="ticket"]
    equal: [service, slo]

receivers:
  - name: oncall
    webhook_configs:
      - url: "http://alert-bridge/chat"   # self-hosted chat webhook — no paid paging SaaS
  - name: tickets
    email_configs:
      - to: "ops@<product>.example"
```

Silences (with an author, a reason, and an expiry) cover planned maintenance — never edit a rule to quiet a known noisy period.

---

## Alert Hygiene and Review Discipline

- **Every page carries `runbook_url`** — an existing, tested `runbook-authoring` document. A page without a runbook is a page that wakes someone up to start researching.
- **Every page is actionable** — if the response to an alert is "watch it", it is a dashboard panel, not an alert.
- **No duplicate coverage** — one condition, one alert. The SLO burn alert covers error symptoms; do not also alert on raw 5xx rate, mesh success rate, and per-pod error counts for the same failure. (Deployment-level up/down is `health-check-design`'s probe domain — Kubernetes restarts pods; alerting covers what restarts cannot fix.)
- **Monthly alert review** (with the SLO review in `slo-definition`), for every alert that fired: did a human act? Pages with no action are demoted or deleted; incidents with no page get a new symptom alert or a tightened SLO; alerts that flapped get longer `for:` or better windows.
- **Prune ruthlessly.** The target state is a pager that is silent for weeks and then only ever right. Every surviving alert must re-justify itself at review.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Symptom-based | Alerts on SLO burn and user-visible symptoms | Pages on CPU, restarts, GC, single errors |
| Burn-rate structure | Multiwindow multi-burn-rate per the standard table | Static error-rate thresholds; single-window alerts |
| Severity split | Two severities; page passes the 03:00 test | "Warning" tier nobody owns; unactionable pages |
| Runbooks | Every page has a live `runbook_url` | Pages with no procedure attached |
| Pipeline coverage | DLQ depth + lag-growth alerts wired | Async pipeline covered only by sync-API alerts |
| Alertmanager | Grouping, inhibition, page/ticket routes configured | Notification storms; stack-down triggering 50 pages |
| Recorded inputs | Alert expressions read recording rules | Raw histogram math evaluated per alert per interval |
| Review | Monthly review; fired-but-unactioned alerts pruned | Alert list only ever grows |
| Frugality | Self-hosted Alertmanager, webhook/email delivery | Paid paging SaaS at MVP scale |

---

## Anti-Patterns

- **Cause-based paging** — "CPU > 80%" pages on every busy hour and misses the outage that happens at 40% CPU. If users aren't affected, the pager stays quiet.
- **Static error-rate thresholds** — "error rate > 1%" is simultaneously too twitchy (one bad minute at low traffic) and too slow (0.9% forever silently exhausts the budget). Burn rate measures what matters: budget survival.
- **Single-window burn alerts** — long-window-only keeps firing for hours after recovery; short-window-only pages on noise. Always the pair.
- **Alert-per-metric coverage** — one incident, nine alerts, and triage starts with archaeology. One symptom, one alert; causes live in the runbook's diagnostic queries.
- **Pages without runbooks** — the on-call response becomes improvisation at 03:00, and the fix is whatever was tried last time. No runbook, no page.
- **Silencing by deletion or threshold-bumping** — quieting a noisy alert by raising its threshold until it never fires leaves dead coverage that looks alive. Fix the alert or delete it honestly at review.
- **Paging the DLQ on every message** — the Dead Letter Queue exists to park poison messages calmly after retries; a page per message reinvents the failure it was built to absorb. Ticket on depth, page on SLO impact.

---

## Output Format

Produces the alerting design document plus deployable rule and routing files:

```markdown
---
name: alerting-rules-design-<product>
product: <product-name>
version: 1.0.0
phase: deploy
created: <date>
owner: platform-engineer
---

# Alerting Rules Design — <Product>

## Alert Inventory
| Alert | Symptom / SLO protected | Severity | Windows / burn rate | Runbook |

## Burn-Rate Policy Applied
| SLO | Fast burn (page) | Slow burn (page) | Trickle (ticket) |

## Pipeline Leading Indicators
| Alert | Condition | Severity | Rationale |

## Routing and Inhibition
[Route tree, grouping keys, inhibition rules, receivers]

## Review Log
| Date | Alert | Fired count | Actioned? | Decision (keep/tune/delete) |

## Configuration Files
- prometheus/rules/slo-burn-*.yaml
- prometheus/rules/pipeline-leading-indicators.yaml
- alertmanager/alertmanager.yml
```
