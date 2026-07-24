---
name: alerting-rules-design
description: >
  Teaches how to design Prometheus alerting rules and Alertmanager routing —
  organized around the Four Golden Signals (latency, traffic, errors,
  saturation), symptom-based alerts over cause-based, multiwindow multi-burn-
  rate alerts on Service Level Objectives with the standard fast/slow burn
  table (and its correct two-source citation: error-budget concept from
  Google's SRE book, the specific multiplier table from the 2018 SRE
  Workbook), the page versus ticket severity split, alert hygiene (every page
  actionable with a runbook link, deduplication, grouping, inhibition, a toil
  check, and a postmortem-linkage check), pipeline alerts for DLQ depth and
  consumer lag, honest solo-operator escalation, and the review discipline
  that prunes noise before it breeds pager fatigue. Includes
  scripts/scaffold-alerting-rules-design.sh and
  scripts/validate-alerting-rules-design.sh. Deep derivation, saturation
  patterns, toil, and escalation content split across references/. Used by
  the platform-engineer during Deploy.
version: 2.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-20
tags: [deploy, observability, alerting, alertmanager, burn-rate, slo, on-call, runbook, toil, saturation]
related: [skill-authoring-standards, slo-definition, prometheus-metrics-design, runbook-authoring, health-check-design]
---

# Alerting Rules Design

## Purpose

Alerts are the contract between the system and the human on call: *interrupt me only when a user-visible promise is at risk, and tell me what to do about it*. A good alerting design pages rarely, pages accurately, and attaches a runbook to every page. A bad one trains its sole operator — Shafi's platform has exactly one — to ignore the pager, which is worse than having no alerts at all.

This skill enforces the alerts as Prometheus rule groups evaluated by each tenant's Prometheus and routed by Alertmanager (self-hosted, frugal: email and chat webhooks, no paid paging SaaS). The alerts are defined *on* the Service Level Objectives from `slo-definition`, computed from the recorded series in `prometheus-metrics-design`, and resolved using the procedures in `runbook-authoring`.

---

## The Four Golden Signals

Google's SRE discipline organizes monitoring around four signals — if you can only measure four things about a user-facing system, measure these (per `references/burn-rate-derivation-and-golden-signals.md`, grounded in the SRE book's Ch. 6):

| Signal | What it measures | Where it lives in this skill |
|---|---|---|
| **Latency** | How long requests take — successful and failed latency measured *separately* | SLO burn-rate alerts, below |
| **Traffic** | Demand on the system | Denominator of every burn-rate ratio |
| **Errors** | Rate of requests that fail, explicit or implicit | SLO burn-rate alerts, below |
| **Saturation** | How "full" the most constrained resource is, ideally trending toward exhaustion | Generic pattern in `references/burn-rate-derivation-and-golden-signals.md` — the pipeline's DLQ/lag alerts below are a domain-specific instance, not the general case |

Latency, Traffic, and Errors are already covered by the SLO burn-rate alerts below. Saturation has no generic treatment in this skill beyond the pipeline-specific DLQ/lag alerts — see the reference file for a resource-agnostic saturation pattern (DB pool, disk, worker queue) using the same trend-projection technique as `PipelineConsumerLagGrowing`.

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

**Citation, precisely:** the error-budget and burn-rate *concept* originates in Google's *Site Reliability Engineering* (Beyer/Jones/Petoff/Murphy, 2016, Ch. 3–4); the specific multiwindow table below — the exact multipliers, the paired long/short windows — was formalized two years later in the *SRE Workbook* (2018, Ch. 5, "Alerting on SLOs"). Full derivation arithmetic (why 14.4 and not some other number, and how to recompute the table if the SLO window ever changes): `references/burn-rate-derivation-and-golden-signals.md`.

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

DLQ depth is a ticket by default (Retry and Backoff already ran; the messages are parked, not bleeding) and escalates through the freshness SLO burn if the volume is user-significant. Lag pages only when both high *and* growing — a level check alone pages on every routine catch-up after a deploy. This `deriv()`-based trend technique generalizes to any saturating resource — see `references/burn-rate-derivation-and-golden-signals.md`'s generic saturation pattern.

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

Silences (with an author, a reason, and an expiry) cover planned maintenance — never edit a rule to quiet a known noisy period. A short `repeat_interval` is not an escalation policy — it re-pages the same person, it does not notify anyone else. For what "escalation" honestly means at a headcount of one, see `references/escalation-and-postmortem-linkage.md`.

---

## Alert Hygiene and Review Discipline

- **Every page carries `runbook_url`** — an existing, tested `runbook-authoring` document. A page without a runbook is a page that wakes someone up to start researching.
- **Every page is actionable** — if the response to an alert is "watch it", it is a dashboard panel, not an alert.
- **No duplicate coverage** — one condition, one alert. The SLO burn alert covers error symptoms; do not also alert on raw 5xx rate, mesh success rate, and per-pod error counts for the same failure. (Deployment-level up/down is `health-check-design`'s probe domain — Kubernetes restarts pods; alerting covers what restarts cannot fix.)
- **Toil check** — for every alert that fired: did resolving it again require the same manual steps as last time, and if this is now the third-plus repetition, should it be automated instead of paged? Full toil definition and the personal-sustainability framing of Google's 50%-ceiling policy (this repo has no team to hand a misbehaving service back to): `references/toil-and-review-discipline.md`.
- **Postmortem-linkage check** — does this alert's fired-and-actioned history have an open postmortem with unresolved action items? This skill does not author postmortems (a candidate `postmortem-authoring` skill is noted, not built, in the research behind this rebuild); it only checks for one at review time. See `references/escalation-and-postmortem-linkage.md`.
- **Pager-load heuristic** — a week producing more than a small, fixed number of real pages is itself a trigger for an unscheduled hygiene pass, not something to wait on until the monthly cadence. Full heuristic: `references/toil-and-review-discipline.md`.
- **Monthly alert review** (with the SLO review in `slo-definition`), for every alert that fired: did a human act? Pages with no action are demoted or deleted; incidents with no page get a new symptom alert or a tightened SLO; alerts that flapped get longer `for:` or better windows.
- **Prune ruthlessly.** The target state is a pager that is silent for weeks and then only ever right. Every surviving alert must re-justify itself at review.

---

## Scripts

Per `skill-authoring-standards`, this skill owns two deterministic scripts — neither decides whether an alerting design is *correct*, only whether the design document is structurally complete.

| Script | Does | Run when |
|---|---|---|
| `scripts/scaffold-alerting-rules-design.sh <product>` | Copies `assets/alerting-rules-design-template.md`, fills in product/date/owner metadata, writes a new alerting design doc | Starting alerting design for a product |
| `scripts/validate-alerting-rules-design.sh <path>` | Checks required frontmatter, presence of all Output Format sections, a Review Log with a toil column, and at least one page-severity and one ticket-severity alert in the Alert Inventory | Before treating the design as ready for the Deploy phase gate |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Four Golden Signals coverage | Latency/Traffic/Errors via SLO burn, plus a generic Saturation pattern for non-pipeline resources | Saturation left as dashboard-only, or not addressed at all |
| Symptom-based | Alerts on SLO burn and user-visible symptoms | Pages on CPU, restarts, GC, single errors |
| Burn-rate structure | Multiwindow multi-burn-rate per the standard table, cited to its correct two sources | Static error-rate thresholds; single-window alerts; unattributed numbers |
| Severity split | Two severities; page passes the 03:00 test | "Warning" tier nobody owns; unactionable pages |
| Runbooks | Every page has a live `runbook_url` | Pages with no procedure attached |
| Pipeline coverage | DLQ depth + lag-growth alerts wired | Async pipeline covered only by sync-API alerts |
| Alertmanager | Grouping, inhibition, page/ticket routes configured | Notification storms; stack-down triggering 50 pages |
| Recorded inputs | Alert expressions read recording rules | Raw histogram math evaluated per alert per interval |
| Toil tracked | Review asks whether a repeat manual fix should be automated | Review only asks keep/tune/delete |
| Escalation honestly scoped | Unacknowledged-page handling stated for a solo operator, not borrowed from a team model | `repeat_interval` alone presented as an escalation policy |
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
- **Mistaking `repeat_interval` for escalation** — a shorter repeat interval re-pages the same unresponsive person more often; it notifies no one else and answers nothing about what happens if the page is never acknowledged.
- **Toil-blind pruning** — deleting or tuning a noisy alert without asking whether the manual fix it demanded is itself the real problem worth automating away.

---

## Output Format

Produces the alerting design document plus deployable rule and routing files. Fill-in-and-go: `assets/alerting-rules-design-template.md` (or generate it directly via `scripts/scaffold-alerting-rules-design.sh`). Mechanical completeness check: `scripts/validate-alerting-rules-design.sh`.

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
| Date | Alert | Fired count | Actioned? | Toil (repeat manual fix?) | Decision (keep/tune/delete/automate) |

## Configuration Files
- prometheus/rules/slo-burn-*.yaml
- prometheus/rules/pipeline-leading-indicators.yaml
- alertmanager/alertmanager.yml
```

---

## References — Which File Do You Need?

| If you're asking... | Go to |
|---|---|
| "Why 14.4 and not some other number?" / "Which book is the burn-rate table actually from?" / "How do I alert on saturation for something other than the pipeline?" | `references/burn-rate-derivation-and-golden-signals.md` |
| "What is toil, formally?" / "How much manual effort is too much for one operator?" / "When should an unscheduled alert-hygiene pass happen?" | `references/toil-and-review-discipline.md` |
| "What happens if a page goes unacknowledged?" / "Does this skill own postmortems?" / "How does alerting connect to incident review?" | `references/escalation-and-postmortem-linkage.md` |
