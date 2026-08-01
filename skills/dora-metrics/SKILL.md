---
name: dora-metrics
description: >
  Teaches the Four Key Metrics (DORA) — Deployment Frequency, Lead Time for Changes, Time to Restore Service (MTTR), and Change Failure Rate — their operational definitions, instrumentation sources in this platform stack, High/Medium/Low performer cluster thresholds from the Accelerate research, the delivery performance dashboard design, and how to act on trended metrics. Used by the platform-engineer to measure delivery performance alongside SLOs.
version: 1.0.0
phase: deploy
owner: platform-engineer
created: 2026-07-31
tags: ["deploy","metrics","dora","deployment-frequency","lead-time","mttr","change-failure-rate","delivery-performance"]
produces: delivery-performance-configuration
domain: platform
status: stable
---

# DORA Metrics

## Purpose

Software delivery performance has two axes. The first — reliability — is covered by `slo-definition`. The second — delivery velocity and stability — is covered here. Without both axes, "are we shipping safely?" has no answer.

The Four Key Metrics (DORA) are the empirically validated, cross-industry benchmark set for delivery performance (Accelerate, Forsgren/Humble/Kim, 2018). Four years of survey data and psychometric factor analysis confirm that these four metrics form a coherent construct — and that this construct predicts organizational performance (profitability, market share, customer satisfaction). They belong on every service alongside its SLO dashboard.

The counterintuitive Accelerate finding that governs how to use these metrics: **high performers deploy more often and fail less simultaneously.** Tempo and stability reinforce each other. Any attempt to trade one metric against another (deploy less to reduce failures) contradicts the research and is wrong.

---

## The Four Metrics — Operational Definitions

Each metric is defined here as a measurable ratio or duration, not as a category name.

### 1. Deployment Frequency

**What it is:** How often the team successfully deploys to production — counted as promotions of an immutable image digest to the production environment per unit time (day, week, or month).

**What it measures:** Batch size and feedback loop speed. Small, frequent deploys bound blast radius and shorten the time between a code change and the signal that it is (or is not) working. A team that deploys once a quarter is shipping month-sized batches; a failure condemns a month of work.

**Measurement source in this stack:** GitHub Actions workflow run events on the main branch of each service's CD pipeline, specifically the `deploy-production` job completion event. One successful workflow run to production = one deployment. Count per rolling 7-day and 28-day windows.

### 2. Lead Time for Changes

**What it is:** The elapsed clock time from the moment a commit is merged to the main branch to the moment that commit is running in the production environment.

**What it measures:** Pipeline throughput and test cycle time. If this number is six hours, something between merge and production is slow — a long-running test suite, a manual approval gate, a slow container build, or a queue in the CD system. The clock starts at the merge commit timestamp and stops at the `deploy-production` job completion timestamp.

**Measurement source in this stack:** Two timestamps joined from GitHub Actions: (a) the `push` event timestamp on the main branch (commit merged), and (b) the `deploy-production` job `completed_at` field in the same workflow run triggered by that push. Store both in a Prometheus Gauge series `deployment_lead_time_seconds{service, environment}` emitted by the CD pipeline's final step.

### 3. Time to Restore Service (MTTR)

**What it is:** The elapsed clock time from the moment a production incident begins (alert fires) to the moment service is restored (alert resolves). Mean Time to Restore averages this over all incidents in the window.

**What it measures:** Recovery capability — the combination of detection speed, runbook quality, rollback automation, and on-call responsiveness. A long MTTR means either the problem went undetected for too long, or fixing it once detected was slow, or both.

**Measurement source in this stack:** Alertmanager incident lifecycle. Alert `FiredAt` timestamp (when Alertmanager sends the firing alert) to alert `ResolvedAt` timestamp (when Alertmanager sends the resolved notification). Store duration as `incident_restore_duration_seconds{service, severity}` via the `alerting-rules-design` pipeline. Average across incidents for MTTR.

### 4. Change Failure Rate

**What it is:** The percentage of deployments to production that cause a service degradation requiring remediation — a rollback, hotfix, or immediate patch — out of all deployments in the window.

**What it measures:** Change safety. A team that deploys ten times per week with two rollbacks has a 20% CFR. The denominator is all deployments, not just the ones that caused incidents. Hotfixes that avoid a rollback still count as failures — the change broke something.

**Measurement source in this stack:** Git revert commits on the main branch against a promotion commit (`git revert <digest-promotion-commit-sha>`). Rollback events / total promotion commits in the window. The `cd-pipeline` skill already prescribes `git revert` as the rollback mechanism; that revert commit is the event. Emit a `change_failure_total{service}` counter on each revert; compute `change_failure_rate = change_failure_total / deployment_total` in Grafana.

---

## DORA Performer Clusters

The Accelerate research identifies three statistically distinct clusters — not a bell curve. The gap between clusters is multiplicative.

| Metric | High performer | Medium performer | Low performer |
|---|---|---|---|
| Deployment Frequency | Multiple times/day | 1/week to 1/month | 1/month or less |
| Lead Time for Changes | Under 1 hour | 1 day to 1 week | 1 month to 6 months |
| Time to Restore (MTTR) | Under 1 hour | Under 1 day | 1 week to 1 month |
| Change Failure Rate | 0–15% | 16–30% | 46–60% |

Full cluster table with what each cluster means for retrospectives: `references/cluster-benchmarks.md`.

---

## How the Metrics Relate to Each Other

The four metrics are correlated, not independent levers. They move together in a high-performing team because they share common drivers (test automation quality, deployment automation maturity, architecture looseness). Attempting to optimize one metric in isolation typically degrades another:

- Force-deploying more often without improving test gates → Change Failure Rate rises.
- Cutting deploys to "be safer" → Lead Time grows; MTTR grows (less deploy practice, rustier rollback path).
- Adding manual approval gates to reduce failures → Lead Time spikes; Deployment Frequency falls.

Use the cluster table for diagnosis, not for individual-metric gaming. A team in the Low cluster on one metric is almost certainly in the Low or Medium cluster on the others.

---

## Acting on the Metrics — Alert vs. Investigate

Two categories of change trigger different responses:

**Alert (same response as an SLO burn rate crossing a threshold):**
- MTTR exceeds 24 hours on any P1/P2 incident — the recovery system has failed at the current incident.
- Change Failure Rate exceeds 30% over a rolling 7-day window — more than one in three deploys is rolling back; feature work must pause.

**Investigate (retrospective, not incident):**
- Deployment Frequency drops below the service's own baseline by 50% over a rolling 28 days — batch size is growing or pipeline health is declining.
- Lead Time for Changes increases by more than 2× over a rolling 28-day trend — something in the pipeline has degraded.
- Change Failure Rate crosses into a higher cluster band on a quarterly trend review.

Run a quarterly delivery performance retrospective: "which metric moved, in which direction, and why?" — not "what went wrong." The question is a trend question, not an incident question.

---

## Relationship to Other Skills

This skill produces a second measurement axis alongside `slo-definition`. Neither replaces the other:

- `slo-definition` measures **what users experience** (availability, latency, freshness, correctness).
- This skill measures **how safely and quickly the team changes the system** (frequency, speed, recovery, failure rate).

A team can have perfect SLOs and poor DORA metrics (deploys rarely, recovers slowly but service is stable between incidents). A team can have excellent DORA metrics and poor SLOs (deploys constantly, breaks users constantly). Both dimensions must be tracked.

Instrumentation specifics per metric in this stack: `references/instrumentation-spec.md`.
Grafana dashboard layout for all four metrics: `references/delivery-performance-dashboard.md`.

---

## Output Format

Produces the Delivery Performance Configuration appended to `sdlc-config.json`:

```yaml
delivery_performance:
  service: <service-name>
  deployment_frequency:
    source: github_actions_workflow
    workflow: deploy-production
    window_days: [7, 28]
  lead_time:
    start_event: push_to_main_sha
    end_event: deploy_production_completed_at
    metric: deployment_lead_time_seconds
  mttr:
    source: alertmanager
    fired_label: FiredAt
    resolved_label: ResolvedAt
    metric: incident_restore_duration_seconds
  change_failure_rate:
    rollback_event: git_revert_on_main
    counter: change_failure_total
    denominator: deployment_total
  alert_thresholds:
    mttr_p1_hours: 24
    cfr_7d_pct: 30
  review_cadence: quarterly
```
