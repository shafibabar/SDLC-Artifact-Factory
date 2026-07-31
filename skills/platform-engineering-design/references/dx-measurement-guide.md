# DX Measurement Guide

Developer Experience (DX) measurement is how the platform team knows whether its investments are reducing cognitive load or just adding infrastructure. This guide explains how to instrument each of the four DX metrics, how to run a quarterly DX survey, and how to conduct an embedded-engineer session to gather qualitative friction data.

---

## The Four DX Metrics

### 1. Time-to-First-Deploy (TTFD)

**Definition:** The elapsed time from when a new engineer starts their first day to when they successfully deploy a service to a production (or production-equivalent staging) environment using the golden path, without assistance from a platform or senior engineer.

**Why it is the most important metric:** TTFD is a full-stack integration test of the golden path. It exercises documentation quality, tooling reliability, environment provisioning, CI/CD, permissions, and onboarding. A single number reveals the entire system's health from the perspective of a first-time user.

**Target:** ≤1 business day (8 hours). If >2 business days, the golden path has failed — the failure is the platform team's, not the new engineer's.

**How to measure:**

```
Instrument with a simple log entry — new engineer records:
- t₀: timestamp when they clone the repo or start the onboarding doc
- t₁: timestamp when the first successful deploy lands in the staging environment

TTFD = t₁ - t₀ (excluding sleep hours)
```

Track per-new-hire. Review trend monthly. A single outlier (e.g., a specific team's setup is broken) points to a platform gap worth addressing immediately.

**Failure signals by band:**

| TTFD | Diagnosis |
|---|---|
| < 4 hours | Excellent golden path; automated onboarding is working |
| 4–8 hours | Acceptable; look for one or two friction points to eliminate |
| 8–24 hours | Documentation gaps or manual provisioning steps are blocking |
| 1–2 days | Serious golden path failure — one or more steps require platform team involvement |
| > 2 days | Golden path is broken; treat as a P1 platform incident |

**Instrument in CI:** The first successful pipeline run triggered by a new user's commit in a new service repo auto-logs the timestamp. Compare against the user's account creation timestamp in your identity provider.

---

### 2. Self-Service Coverage (SSC)

**Definition:** The percentage of common platform operations a developer can accomplish without filing a support ticket, sending a Slack message to the platform team, or scheduling a pairing session.

**Target:** ≥90%. If a team has 10 common platform operations and 2 of them require a ticket, SSC is 80% — a failure state.

**How to define "common platform operations":**

Build the list from your ticketing system. Run this query monthly:

```
Last 90 days of requests to the platform team → categorise by operation type → 
rank by frequency → top 10 operations = "common platform operations"
```

Review the list quarterly. Operations that drop off the top 10 are likely self-service now; new entrants to the top 10 are gaps in the self-service layer.

**How to measure:**

```
SSC = (operations in top-10 list that have a self-service path) / (total operations in top-10 list) × 100
```

A "self-service path" exists if and only if: (a) there is documented, working golden-path tooling for the operation AND (b) the documentation can be followed in under 30 minutes by a developer who has not done it before.

**Tracking cadence:** Monthly. Publish SSC in the platform team's monthly review.

**Common operations checklist — these should all be self-service:**

- [ ] Create a new service from template
- [ ] Create a new database (dev + staging environments)
- [ ] Create a new environment (e.g., a PR environment for review)
- [ ] Add a new secret to the secrets manager
- [ ] Trigger a production deployment
- [ ] Access production logs
- [ ] Create a new integration with an external API (credentials, firewall rules)
- [ ] Roll back a broken deployment
- [ ] Run a database migration
- [ ] Provision a new team's CI/CD pipeline

If any of these requires a ticket, the SSC target is not met.

---

### 3. Out-of-Band Exception Tracking

**Definition:** An out-of-band exception is a request to deviate from the golden path — to use a different database, a different framework, a different deployment mechanism, a different environment shape.

**Why track it:** Rising exceptions are a leading indicator that the golden path does not cover real needs. Declining exceptions indicate the golden path is trusted. This is the platform team's equivalent of a product's feature request backlog — every exception is a feature request in disguise.

**Target:** Declining trend. Not zero — some exceptions are legitimate and the golden path should accommodate them eventually.

**How to track:**

```
Create a dedicated channel or ticket label: "golden-path-exception"
Every formal exception request gets a ticket with:
  - Requesting team
  - Operation type
  - What the golden path does not cover
  - Approved/denied + reasoning
  - Whether this exception will become a golden-path improvement
```

**Monthly analysis:**

1. Count total exceptions requested in the period
2. Group by operation type
3. Identify operations with ≥3 exceptions in the period — each is a golden path gap, not a special case
4. For each gap: add to the platform roadmap with priority proportional to frequency

**Conversion rate:** Track what percentage of exceptions become golden-path improvements within 2 quarters. Target: ≥50%. If the platform team is acknowledging gaps but not closing them, adoption will stall.

---

### 4. Platform Adoption Rate (PAR)

**Definition:** The percentage of services and teams that use the golden path for at least one core platform capability (CI/CD, environment provisioning, or observability).

**Target:** Growing trend. Absolute target depends on platform maturity; a reasonable goal is 80% of services within 12 months of the golden path becoming available.

**How to measure:**

```
PAR = (services using the golden path for ≥1 core capability) / (total services in the organisation) × 100
```

Track at both service and team level. A team that uses the platform for CI/CD but not for environment provisioning counts as partial adoption — track which capabilities are adopted and which are not.

**Cohort analysis:** Group services by when they were created. New services (created after the golden path was available) should have higher adoption than legacy services (pre-golden-path). A low adoption rate among new services is a critical failure — developers are actively choosing to go off-path.

---

## Quarterly DX Survey

Run a 3-question anonymous survey every quarter. Keep it to 3 questions — longer surveys get abandoned.

**Survey questions:**

```
1. "How easy was it to use the platform to accomplish your goal this quarter?"
   (1 = very difficult, 5 = very easy)
   
2. "What was the most confusing part of using the platform this quarter?"
   (Free text — required)
   
3. "What was the most important capability missing from the platform this quarter?"
   (Free text — required)
```

**Distribution:** All engineers who used any platform capability in the quarter. Use your identity provider's group membership or CI/CD access logs to identify the cohort.

**Analysis and publication:**

- Calculate mean and median for question 1; track trend quarter-over-quarter
- Cluster free-text responses for questions 2 and 3 into themes (≤5 themes per question)
- Publish full results (anonymised) to the entire engineering organisation
- Include in the platform team's quarterly review: "we heard X, we will address it by Y"

**Target score:** Question 1 mean ≥4.0. Below 3.5 is a platform crisis requiring immediate attention.

---

## Embedded-Engineer Session

An embedded-engineer session is the most actionable qualitative DX research technique. A platform engineer spends one sprint (2 weeks) embedded in a product team, doing their work alongside them without offering platform help — just observing and noting friction.

**What to observe:**

| Friction Type | What to Log |
|---|---|
| Documentation gaps | "Had to ask Slack because docs were unclear or missing" |
| Provisioning friction | "Waited X hours for Y to be set up" |
| Error opacity | "Error message didn't tell us what to do; took N hours to debug" |
| Off-path deviation | "Chose not to use the golden path because of Z" |
| Undocumented workaround | "Everyone on the team uses this workaround; not written anywhere" |

**Output:** After the sprint, produce a friction report with:

1. Ranked list of friction points (by frequency and severity)
2. For each friction point: is this a documentation gap, a tooling gap, or a golden-path gap?
3. Recommended actions with effort estimates

**Cadence:** One embedded session per quarter, rotating across product teams. Prioritise teams that score lowest on the quarterly DX survey.

**Rule for action:** Any friction point observed ≥3 times during one embedded session is a platform gap, not an outlier — add it to the platform roadmap.

---

## Dashboard: Platform DX Health

Publish a live platform DX dashboard visible to the entire engineering organisation. Include:

| Metric | Current | Target | Trend |
|---|---|---|---|
| Time-to-First-Deploy (last cohort) | — | ≤1 day | — |
| Self-Service Coverage | — | ≥90% | — |
| Out-of-Band Exceptions (this quarter) | — | Declining | — |
| Platform Adoption Rate | — | ≥80% | — |
| Quarterly DX Survey Score | — | ≥4.0 | — |

Update monthly. The dashboard is the platform team's public accountability surface — it replaces the "trust us, things are getting better" narrative with data.
