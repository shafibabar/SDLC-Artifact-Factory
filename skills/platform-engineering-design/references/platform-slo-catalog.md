# Platform SLO Catalog

The platform team is a service provider to internal engineering teams. Like any service provider, the platform team is accountable for reliability and performance targets — not just for the services running on the platform, but for the platform capabilities themselves.

This catalog defines the platform's own SLIs and SLOs, reviewed monthly by the platform team and published to the engineering organisation.

---

## Why Platform-as-Product SLOs Matter

A platform without its own SLOs has no accountability surface. When CI is slow, when environments take days to provision, when the deployment pipeline goes down — these are platform reliability failures. Without defined SLOs, the platform team cannot distinguish a reliability incident from normal operations, cannot prioritise remediation, and cannot demonstrate improvement over time.

Platform SLOs operate alongside (not instead of) product service SLOs. The `sdlc-config.json` SLO section should include both.

---

## SLI/SLO Definitions

### CI Pipeline

| Field | Value |
|---|---|
| Capability | Continuous Integration — lint, test, build, container image push |
| SLI | P95 pipeline duration for successful runs |
| SLO | < 10 minutes |
| Measurement source | GitHub Actions job duration API; query `workflow_run` events with `conclusion: success` |
| Measurement cadence | Calculated daily; reviewed monthly |
| Error budget | 5% of runs may exceed 10 min (P95 target allows exactly this) |

**Why P95, not P50:** The median hides outliers. A 10-minute P95 means 95% of developer experiences are under 10 minutes — the 5% tail is worth monitoring separately.

**Failure response:**

| Duration | Response |
|---|---|
| P95 < 10 min | On track |
| P95 10–15 min | Investigate slow jobs; add to next sprint backlog |
| P95 > 15 min | Platform incident — root cause within 24 hours |

**Common causes of CI degradation:** large container image builds (add layer caching), test parallelism not configured (add `--parallel` flags), test data setup not isolated per test (integration test cleanup accumulating state).

---

### CD Pipeline (Deployment Pipeline Availability)

| Field | Value |
|---|---|
| Capability | Continuous Deployment — merge to main → deploy to staging → deploy to production |
| SLI | Availability: percentage of time the deployment pipeline can accept and process a merge event |
| SLO | > 99.5% availability (measured weekly) |
| Measurement source | Synthetic probe: trigger a no-op deploy to staging every 15 minutes; alert if the deploy does not complete within 5 minutes |
| Measurement cadence | Real-time (synthetic probe); reviewed monthly |
| Error budget | 0.5% downtime per week = ~21 minutes/week |

**99.5% SLO justification:** At 99.9% uptime (~45 min downtime/month), planned maintenance windows become impossible without burning the error budget. 99.5% gives ~3.5 hours/month for maintenance, sufficient for cluster upgrades and pipeline tooling updates.

**Failure response:**

| Availability | Response |
|---|---|
| > 99.5% | On track |
| 99.0–99.5% | Review error budget burn; identify root cause |
| < 99.0% | Platform incident — P1 until resolved |

---

### Environment Provisioning

| Field | Value |
|---|---|
| Capability | Creating a new environment (dev, staging, PR preview, or ephemeral test environment) |
| SLI | Time from environment creation request to a working, healthy environment where a service can be deployed |
| SLO | < 5 minutes for ephemeral/dev environments; < 15 minutes for staging |
| Measurement source | Instrument `make new-env` / `make pr-env` scripts with timestamps; log to platform observability stack |
| Measurement cadence | Per-request; P95 reviewed monthly |
| Error budget | 5% of requests may exceed the SLO |

**Definition of "working, healthy environment":** All platform services (DNS, ingress, secrets injection, service mesh) are running and the first deployment of a trivial hello-world service succeeds without errors.

**Common causes of slow provisioning:** Kubernetes node pool scale-out waiting for new nodes (pre-warm a small standby pool), OpenTofu apply waiting for cloud provider APIs (add explicit timeout and retry), image pull rate limiting (use a pull-through cache).

---

### Service Template Creation

| Field | Value |
|---|---|
| Capability | Creating a new service using the golden path (`make new-service NAME=x TEAM=y`) |
| SLI | Time from command invocation to the new service having a passing CI run and a working staging deployment |
| SLO | < 15 minutes |
| Measurement source | Instrument `make new-service` with start timestamp; capture first CI run completion timestamp from GitHub Actions webhook |
| Measurement cadence | Per-invocation; reviewed monthly |
| Error budget | 5% of invocations may exceed 15 min |

**Why this capability has its own SLO:** The service template golden path is the primary onboarding experience. Slow template creation directly increases TTFD (Time-to-First-Deploy) and signals a broken golden path.

---

### Secret Provisioning

| Field | Value |
|---|---|
| Capability | Adding a new secret to the secrets manager and making it available to a running service |
| SLI | Time from developer creating a secret via the self-service golden path to the secret being available in the service's environment |
| SLO | < 2 minutes for development/staging environments; < 5 minutes for production |
| Measurement source | Synthetic probe: create a test secret, measure time to injection in the canary service pod |
| Measurement cadence | Hourly synthetic probe; reviewed monthly |
| Error budget | 1% of injections may exceed the SLO |

---

### Observability Pipeline

| Field | Value |
|---|---|
| Capability | Traces, metrics, and logs from a service being queryable in Grafana/Tempo after generation |
| SLI | End-to-end latency from trace/log generation to visibility in Grafana |
| SLO | P95 end-to-end latency < 60 seconds |
| Measurement source | Synthetic service generates a tagged trace every minute; downstream Grafana query checks for the trace; measures round-trip time |
| Measurement cadence | Per-synthetic-trace; P95 reviewed monthly |
| Error budget | 5% of traces may exceed 60 seconds |

---

## Platform Error Budget Policy

The platform error budget policy governs what the platform team does when its error budget is burning too fast.

| Budget Remaining | Action |
|---|---|
| >50% | Normal operations; roadmap features continue |
| 25–50% | Review burn rate; identify root cause; reduce risky changes |
| 10–25% | Pause non-critical feature work; focus on reliability improvements |
| <10% | Freeze all changes except reliability fixes; conduct post-mortem |

**Error budget review:** Monthly at the platform team's review meeting. If any capability's error budget drops below 25%, a reliability improvement task is added to the next sprint regardless of roadmap priority.

---

## Platform SLO Dashboard

Publish a monthly platform SLO report to the engineering organisation. Format:

```
Platform SLO Report — [Month Year]

CI Pipeline (P95 duration target: <10 min)
  Current P95: X min
  SLO met: YES / NO
  Error budget remaining: X%

CD Pipeline (availability target: >99.5%)
  Current availability: X.X%
  SLO met: YES / NO
  Error budget remaining: X%

Environment Provisioning (P95 target: <5 min ephemeral, <15 min staging)
  Current P95 (ephemeral): X min
  Current P95 (staging): X min
  SLO met: YES / NO

Service Template Creation (P95 target: <15 min)
  Current P95: X min
  SLO met: YES / NO

Secret Provisioning (P95 target: <2 min staging, <5 min production)
  Current P95 (staging): X min
  Current P95 (production): X min
  SLO met: YES / NO

Observability Pipeline (P95 target: <60 sec)
  Current P95: X sec
  SLO met: YES / NO
```

---

## Platform SLOs in sdlc-config.json

Platform SLOs are defined alongside product service SLOs in `sdlc-config.json`. Example schema extension:

```json
{
  "platform_slos": {
    "ci_pipeline_p95_minutes": 10,
    "cd_pipeline_availability_percent": 99.5,
    "env_provisioning_ephemeral_minutes": 5,
    "env_provisioning_staging_minutes": 15,
    "service_template_creation_minutes": 15,
    "secret_provisioning_staging_minutes": 2,
    "secret_provisioning_production_minutes": 5,
    "observability_pipeline_p95_seconds": 60
  }
}
```

These values drive the platform team's monthly review and are displayed in the platform DX dashboard alongside the four DX metrics.

---

## Relationship to DORA Metrics

Platform SLOs are infrastructure-layer metrics. DORA metrics (Deployment Frequency, Lead Time for Changes, MTTR, Change Failure Rate) are measured at the product service layer. Both are required:

| Metric Category | What it measures | Owned by |
|---|---|---|
| Platform SLOs | Platform capability reliability | Platform team |
| DORA metrics | Product delivery performance | Product + platform teams jointly |
| DX metrics (TTFD, SSC, etc.) | Developer experience of the platform | Platform team |

A platform that meets its SLOs and delivers good DX but does not improve DORA metrics is building the wrong golden paths — the infrastructure is reliable but not the bottleneck. A platform that improves DORA metrics without meeting its SLOs is getting lucky — reliability will eventually degrade the DORA gains.
