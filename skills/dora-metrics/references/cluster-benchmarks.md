# DORA Cluster Benchmarks

This reference is self-contained. It contains the full DORA performer cluster table with exact thresholds derived from the Accelerate research (Forsgren, Humble, Kim, 2018), what each cluster means, and how to use cluster positioning in retrospectives.

---

## The Research Basis

The DORA cluster thresholds come from four years of annual State of DevOps survey data analyzed using confirmatory factor analysis and structural equation modeling. The analysis revealed that software delivery performance data does **not** form a bell curve — it forms statistically distinct clusters with multiplicative gaps between them. Incremental improvement at the Low end does not close the gap to High; the clusters represent genuinely different systems of practice, not points on a single continuous scale.

This is the key fact that makes the thresholds meaningful as a benchmark and dangerous as a target: you cannot game your way to High by optimizing individual metric values while leaving the underlying practices unchanged.

---

## Full Cluster Benchmark Table

| Metric | High Performer | Medium Performer | Low Performer |
|---|---|---|---|
| **Deployment Frequency** | Multiple deploys per day | Somewhere between once per week and once per month | Once per month or less (often quarterly) |
| **Lead Time for Changes** | Less than 1 hour (commit to production) | Between 1 day and 1 week | Between 1 month and 6 months |
| **Time to Restore Service (MTTR)** | Less than 1 hour (incident open to resolved) | Less than 1 day | Between 1 week and 1 month |
| **Change Failure Rate (CFR)** | 0–15% of deployments require remediation | 16–30% of deployments require remediation | 46–60% of deployments require remediation |

### Notes on Reading the Table

- The gap between Medium and Low CFR is 31–45% — a deliberate gap in the published research thresholds. Do not interpolate; the research identifies these three clusters, not a smooth spectrum.
- "Remediation" includes rollbacks, immediate hotfixes, and patches that are required to restore service after a deploy — not bug fixes planned for the next release cycle.
- Lead Time is measured from **merge to main** to **running in production** — it is a pipeline measurement, not a planning metric. It does not include the time to write or review the code.
- MTTR is measured from **alert fires** to **alert resolves** — it is a detection-plus-recovery time. Teams with poor alerting will undercount MTTR because they do not detect incidents promptly.

---

## What Each Cluster Means

### High Performer

Deploys multiple times per day, often tens of times. Lead times are under an hour because the test suite is fast, the build is automated, the pipeline gates are reliable, and there is no manual approval. Failures are rare because the small batch size means any problem is confined to a small change set — easier to identify and roll back. When incidents do occur, they are resolved in under an hour because runbooks are accurate, rollback automation works, and the team has practiced it recently.

**Enabling practices (Accelerate, Ch. 4):**
- Trunk-based development: branches live less than one day before merge, or developers push directly to trunk
- Comprehensive automated test suite that runs on every commit and is trusted enough that a green build means deploy-safe
- Deployment automation: no manual steps between merge and production
- Architecture loose coupling: deploying one service does not require coordinating with or redeploying other services

High performers exist in every industry and company size. The cluster is not a function of company age, team size, or technology choice — it is a function of practices.

### Medium Performer

Deploys weekly to monthly. Lead times of one to seven days indicate either a slow test suite, a manual approval gate (change management board, QA sign-off, release window), or branch-based development where features accumulate before integration. CFR of 16–30% means roughly one in four to six deploys requires remediation. MTTR under one day means incidents are eventually resolved same-day but not quickly.

Most teams begin here. Medium is sustainable but not competitive for a product that needs to iterate fast. The improvement path from Medium to High is primarily about removing manual approval gates and moving to trunk-based development — not adding more tests.

### Low Performer

Deploys monthly or quarterly. Lead times of one to six months mean features sit behind approval processes, long-lived feature branches, or manual environment provisioning for weeks or months before reaching production. CFR of 46–60% means roughly half of all deployments require immediate remediation — a sign that changes are large, the test suite is not trustworthy, or the deployment process is fragile. MTTR of one week to one month means incidents persist for days; the combination of infrequent deploys and poor MTTR indicates that recovery capability is rarely exercised.

Low performers are not failed organizations — they are teams where the organizational structure (change advisory boards, separated dev and ops, quarterly release trains) prevents the technical practices that produce High performance. Fixing metrics without fixing organizational structure does not move clusters.

---

## Using Cluster Position in Retrospectives

A quarterly delivery performance retrospective has one question: **which cluster are we in for each metric, and what moved since last quarter?**

### Step 1 — Compute the 28-day rolling values for each metric

Use the Grafana queries in `references/instrumentation-spec.md`. Record:

| Metric | Current 28-day value | Cluster | Change from last quarter |
|---|---|---|---|
| Deployment Frequency | X deploys/day | High / Medium / Low | ↑ / ↓ / → |
| Lead Time | X minutes | High / Medium / Low | ↑ / ↓ / → |
| MTTR | X minutes | High / Medium / Low | ↑ / ↓ / → |
| CFR | X% | High / Medium / Low | ↑ / ↓ / → |

### Step 2 — Identify the lagging metric

If all four metrics are in the same cluster, the system is internally consistent. If one metric is in a lower cluster than the others, that metric is the diagnostic entry point. Typical patterns:

| Pattern | Likely diagnosis |
|---|---|
| Low Deployment Frequency, Low Lead Time cluster; Medium/High on CFR and MTTR | Manual approval gate or large batch size; not a test quality problem |
| High Deployment Frequency; High CFR | Test automation is insufficient — deploys are fast but not safe |
| Low MTTR cluster; other metrics Medium or High | Runbooks are missing or wrong; rollback automation is not working; alerting is slow to detect |
| High CFR + High MTTR together | Architecture coupling — a deploy of one service breaks another; recovery requires coordinating multiple services |

### Step 3 — Choose one improvement target

Do not attempt to improve all four metrics simultaneously. The Accelerate research shows that improving the practices underlying the lagging metric tends to improve the correlated metrics as a side effect. Choose the single metric furthest from the High cluster; design one specific practice change with a 90-day outcome goal.

**Example improvement targets:**

| Metric lagging | Practice change | 90-day outcome goal |
|---|---|---|
| Deployment Frequency in Low cluster | Decompose all backlog items to ship in ≤ 5 days of implementation; enforce trunk-based dev (no branch older than 1 day) | Deployment Frequency moves to Medium (1+/week) |
| Lead Time in Medium cluster | Audit and remove all manual approval gates from the CD pipeline; parallelize test stages | Lead Time drops below 1 hour (High cluster) |
| CFR above 30% | Enforce a full regression test run on every PR; add contract tests for every service boundary | CFR drops below 15% (High cluster) within two release cycles |
| MTTR above 1 day | Validate runbooks monthly via tabletop drill; implement and test automated rollback trigger for P1 alerts | MTTR drops below 1 hour (High cluster) |

---

## Cluster vs. Individual Week Anomalies

The Accelerate research's own caveat: the cluster thresholds are direction indicators, not hard weekly targets. A single week of zero deploys because of a company holiday is not a Low performer signal. A single week with two rollbacks is not evidence of a Low cluster. Assess cluster position over a rolling 28-day window, and validate the trend over at least two quarters before treating a cluster change as meaningful.

Use the 28-day window for cluster assignment. Use the 7-day window for alert thresholds (see SKILL.md: CFR >30% over 7 days triggers an alert — this is a safety gate, not a cluster assignment).

---

## Baseline Before Benchmarking

Before comparing against the cluster thresholds, establish a service-specific baseline. A service that has never been instrumented has no trustworthy DORA metrics, and the instrumentation itself introduces measurement artifacts:

- The first four weeks of MTTR measurement are noisy because not all alerts are correctly labeled or have clean `FiredAt` / `ResolvedAt` pairs.
- Deployment Frequency may appear artificially low if the Pushgateway counter resets (ephemeral job metrics are cleared when the job exits; use a persistent counter in a dedicated exporter for high-frequency services).
- Change Failure Rate is zero until the first rollback, then spikes — give it at least one quarter of data before reading it as a trend.

Establish a three-month baseline, then begin cluster comparison. The first retrospective is calibration, not assessment.

---

## The Elite Performer Gap (Post-2021 Research Update)

The 2021 State of DevOps Report added a fourth cluster: **Elite Performers**, defined as deploying on-demand (multiple times per day with no constraint on frequency), lead time under one hour, MTTR under one hour, and CFR at 0–15%. This is the same CFR band as High, but the Deployment Frequency for Elite is qualitatively different — there is no batch constraint, deploys happen as commits arrive. For the purposes of this skill, the High/Medium/Low three-cluster model from the original Accelerate research is the practical working benchmark. Elite is the ceiling; treat High as the operational goal.

---

## Reference Thresholds Quick Card

Clip this for the quarterly retrospective worksheet:

```
DORA Cluster Quick Reference (Accelerate, 2018)

Deployment Frequency:
  High   = multiple/day
  Medium = 1/week – 1/month
  Low    = ≤ 1/month

Lead Time for Changes:
  High   = < 1 hour
  Medium = 1 day – 1 week
  Low    = 1 month – 6 months

Time to Restore Service (MTTR):
  High   = < 1 hour
  Medium = < 1 day
  Low    = 1 week – 1 month

Change Failure Rate:
  High   = 0–15%
  Medium = 16–30%
  Low    = 46–60%
  (Gap 31–45% is not a named cluster — it falls between Medium and Low)
```
