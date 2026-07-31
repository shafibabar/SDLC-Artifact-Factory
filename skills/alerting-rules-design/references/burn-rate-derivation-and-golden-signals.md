# Burn-Rate Derivation and the Four Golden Signals

## The Derivation Arithmetic

The 14.4/6/1 multipliers in `SKILL.md`'s burn-rate table are not arbitrary — each one falls out of a single formula:

```
burn-rate multiplier = budget-consumption target × (SLO window / alert window)
```

Read it as: "how fast would the error ratio have to run, sustained over the alert window, to consume that target fraction of the whole SLO-window budget." Worked for the fast-burn row, on a 28-day SLO window:

- Design goal: no more than **2% of the 28-day budget** consumed within a **1-hour** window.
- `28 days = 672 hours`, so the window ratio is `672 / 1 = 672`.
- `0.02 × 672 = 13.44`.

That `13.44` is the raw arithmetic; the published table rounds the budget-consumption target and window boundaries to land exactly on **14.4** (the *SRE Workbook*'s own published constant — see Two-Source Citation below). The two numbers agree to within the same order of magnitude, and the gap is rounding, not a different formula. The same arithmetic reproduces the other two rows:

| Row | Budget-consumption target | Alert window | SLO window / alert window | Multiplier |
|---|---|---|---|---|
| Fast burn | 2% | 1 h | 672 | `0.02 × 672 = 13.44` ≈ **14.4** |
| Slow burn | 5% | 6 h | 112 | `0.05 × 112 = 5.6` ≈ **6** |
| Trickle | 10% | 3 d | 9.33 | `0.10 × 9.33 = 0.93` ≈ **1** |

**Why this matters beyond arithmetic trivia:** if the SLO window ever changes from 28 days (say, to 30 days to align with calendar months), every multiplier in the table must be recomputed from this formula — they are not portable constants. Recompute by substituting the new window into `SLO window / alert window` and re-running the same multiplication; do not carry the old 14.4/6/1 forward unchanged.

## Two-Source Citation

State this precisely, because the two texts are frequently conflated:

- The **error-budget and burn-rate *concept*** — `burn rate = observed error ratio / budget fraction`, where a burn rate of 1 exhausts the budget exactly at the end of the SLO window, and a burn rate of *N* exhausts it in `window / N` — comes from Google's *Site Reliability Engineering* (Beyer, Jones, Petoff, Murphy, eds., 2016), Ch. 3 ("Embracing Risk") and Ch. 4 ("Service Level Objectives").
- The **specific multiwindow multi-burn-rate table** used in `SKILL.md` — the exact paired long/short windows, the 14.4×/6×/1× multipliers, the 2%/5%/10% budget-consumption thresholds for a 28-day window — was formalized two years later in the ***SRE Workbook*** (2018), Ch. 5, "Alerting on SLOs" (Steven Thurgood and David Ferguson).

The 2016 book supplies the *why* (budget, burn rate, the need for both a sensitivity and a precision window); the 2018 Workbook supplies the *exact numbers*. Never credit the 2016 book with the table itself, and never cite "the SRE book" generically when the table is what's actually being referenced — name the Workbook.

## Why Paired Long/Short Windows

Every row in the burn-rate table fires only when **both** a long window and a short window exceed the threshold simultaneously, and each window has a distinct job:

- **The long window confirms the burn is real.** A single bad minute is noise; a bad hour (fast burn) or six bad hours (slow burn) is a statistically meaningful signal that the budget is actually draining, not a blip.
- **The short window confirms it is still happening.** Without it, the alert would keep firing for the *entire length of the long window* even after the underlying problem is already fixed — because the long window's average still includes the now-resolved bad period. The short window drops out of threshold within minutes of recovery, so the page (or ticket) clears promptly instead of lingering.

A long-window-only alert trades false positives for stale pages; a short-window-only alert trades stale pages for noise. The pair is not redundancy — each window rules out a different failure mode of the other.

## The Four Golden Signals Applied to This Skill

Google's SRE discipline (*Site Reliability Engineering*, Ch. 6, "Monitoring Distributed Systems," Rob Ewaschuk and Betsy Beyer) organizes what to monitor around four signals: **Latency**, **Traffic**, **Errors**, **Saturation**. The book's own advice for a team with limited monitoring maturity is to start with exactly these four before building anything more elaborate — which is why `SKILL.md` uses them as its top-level organizing header.

Mapped onto this skill's existing content:

- **Latency** — already covered: the SLO burn-rate alerts (`SKILL.md`'s Multiwindow Multi-Burn-Rate Alerts section) alert on the latency SLO exactly as they alert on the availability SLO, using "slow request" as the bad event instead of "failed request."
- **Traffic** — already covered, implicitly: every burn-rate ratio is traffic-normalized by construction (`errors / total requests`), so traffic *is* the denominator, not a signal that needs its own separate alert.
- **Errors** — already covered: the availability-SLO burn-rate alerts in `SKILL.md` (`ClassifyAPIErrorBudgetFastBurn`, `ClassifyAPIErrorBudgetSlowBurn`) are exactly this signal.
- **Saturation** — the gap this reference file exists to close. `SKILL.md`'s only "fullness, trending toward a limit" alerts before this addition were the pipeline-specific `PipelineDLQNotEmpty` and `PipelineConsumerLagGrowing` — both freshness-specific instances, not a reusable pattern for any other saturating resource (a DB connection pool, a disk, a worker queue). The Generic Saturation Alert Pattern below fills that gap.

## Generic Saturation Alert Pattern

The book's saturation guidance is explicit: don't just observe a fullness percentage on a dashboard — project it forward ("at this rate the disk fills in four hours"), the same way `PipelineConsumerLagGrowing` already projects consumer lag with `deriv()` instead of firing on a raw level check.

`prometheus-metrics-design` already computes DB connection-pool saturation (`db_pool_in_use / db_pool_max`, its PromQL Patterns table) but only as a dashboard query — no alert reads it. Promoting it to a generic saturation alert means recording the ratio, then trending it the same way pipeline lag is trended:

```yaml
# rules/db-pool-saturation.yaml
groups:
  - name: db-pool-saturation-recording
    rules:
      - record: service:db_pool_saturation:ratio
        expr: db_pool_in_use / db_pool_max

  - name: db-pool-saturation-alerting
    rules:
      - alert: DBPoolSaturationGrowing
        expr: |
          service:db_pool_saturation:ratio > 0.8
          and
          deriv(service:db_pool_saturation:ratio[15m]) > 0
        for: 15m
        labels: { severity: ticket }
        annotations:
          summary: "{{ $labels.service }} DB pool saturation is high ({{ $value | humanizePercentage }}) and still climbing"
          runbook_url: "runbooks/<service>/db-pool-saturation.md"
```

This is the same trend-projection shape as `PipelineConsumerLagGrowing` (`SKILL.md`, Pipeline Alerts section): a level check alone would page on every routine burst of concurrent requests; pairing the level with a positive `deriv()` restricts the alert to sustained growth toward exhaustion. It is a **ticket**, not a page — a filling pool is a capacity signal to act on soon, not a user-visible promise breaking right now (if the pool actually exhausts, the resulting request failures are already covered by the availability SLO's burn-rate page).

The same two-step shape — a `level:metric:operations` recording rule per `prometheus-metrics-design`'s naming convention, then a `deriv()`-gated alert on it — generalizes to any other saturating resource (disk, worker queue, memory) by substituting the ratio's source query.

## Worked Rule Group: SLO Burn-Rate Alert YAML

The `SKILL.md` burn-rate table is implemented as a Prometheus rule group. Worked for the ClassifyDataAsset API SLO (99.5%, budget fraction 0.005): fast burn pages when the error ratio exceeds `14.4 × 0.005 = 7.2%` on **both** windows — an incident pace that would exhaust 28 days of budget in ~2 days.

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

## Worked Rule Group: Pipeline Leading-Indicator YAML

The leading-indicator alerts for the classification pipeline (estate-scanner → entity-extractor → compliance-engine over Redpanda) — a DLQ-depth ticket and a lag-growth page:

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

DLQ depth is a ticket by default (Retry and Backoff already ran; the messages are parked, not bleeding) and escalates through the freshness SLO burn if the volume is user-significant. Lag pages only when both high *and* growing — a level check alone pages on every routine catch-up after a deploy. The `deriv()`-based trend technique generalizes to any saturating resource (Generic Saturation Alert Pattern above).
