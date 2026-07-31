# Golden Path Design

A golden path is a well-lit, opinionated, supported route through a problem space. It is the platform's recommended way to accomplish a task — the path that is significantly easier than any alternative, backed by documentation, tooling, and platform team support. It is not the only allowed route.

This guide explains how to design a golden path from scratch, how to validate it with customers, how to track deviation as a feedback signal, and how to iterate the path as developer needs evolve.

---

## The TVP Question

Before designing any golden path, answer the TVP question:

> *"What is the smallest set of platform capabilities that removes the largest friction from developers building on this platform?"*

Answer this question through customer research, not platform team intuition. The platform team will overestimate the value of technically sophisticated capabilities and underestimate the value of simple, reliable ones.

**Research method:**

```
For each product team:
  Interview 1–2 engineers with this exact prompt:
  "Walk me through the last time you deployed a service to production.
   What went wrong? What took the most time? What did you have to ask someone for?"

Collect answers across all teams.
Rank by frequency and severity.
Top 3 pain points = initial golden paths.
```

Do not start building until you have talked to at least 3 teams. Exceptions: if you are a solo operator or very early stage, the TVP question still applies — it just has a sample size of 1.

---

## Designing a Golden Path: Step by Step

### Step 1 — Define the problem the golden path solves

Be specific. "Deploying a service" is too broad. "Deploying a new Go microservice to staging Kubernetes using the existing Helm chart template" is a specific, testable golden path.

Write the golden path problem statement in the form:

```
As a [role], I need to [specific task], so that [outcome].
```

Example:
```
As a backend engineer, I need to create a new Go microservice with CI, 
staging deployment, and observability configured, so that I can start
writing product code within an hour of starting work.
```

### Step 2 — Map the current (off-golden-path) state

Before designing the golden path, document what engineers actually do today — every manual step, every ticket they file, every Slack message they send. This is the baseline the golden path must beat.

Use a simple table:

| Step | Who does it | How long | Dependencies |
|---|---|---|---|
| Create GitHub repo | Engineer | 5 min | GitHub org access |
| Configure CI | Engineer — copy from another repo | 30 min | Understanding of existing CI setup |
| Get Kubernetes namespace | File platform ticket | 1–2 days | Platform team availability |
| Configure Helm chart | Engineer — from scratch | 2 hours | Helm knowledge |
| First production deploy | Platform team involvement | 4+ hours | Multiple approvals |

Total in this example: ~3 days. The golden path must reduce this to under 1 hour.

### Step 3 — Design the golden path

Design constraints for a good golden path:

1. **Single entry point:** The developer issues one command or opens one URL to start the golden path. Everything downstream is automated or templated.
2. **≤2 decisions for the developer:** The golden path can ask the developer for a service name and which team owns it. It should not ask about Kubernetes resource limits, Helm chart versions, or CI configuration — those are platform defaults.
3. **Self-service throughout:** No step in the golden path requires a support ticket or platform team involvement in the common case.
4. **Idempotent:** Running the golden path twice produces the same result as running it once — no manual cleanup needed.
5. **Tested:** There is an automated test of the golden path itself (not just the underlying components). If the golden path breaks, the platform team knows within minutes, not weeks.

**Worked example for this repo — new Go service golden path:**

```
make new-service NAME=my-service TEAM=platform

What it does (all automated):
1. Creates GitHub repo from template (org/templates/go-service)
2. Configures GitHub Actions CI (lint, test, build, push to registry)
3. Creates Kubernetes namespace in staging (via OpenTofu PR to environments/ repo)
4. Creates Helm release in staging (values from template, no HCL needed)
5. Configures OpenTelemetry collector (traces, metrics, logs — from platform defaults)
6. Creates Backstage service record (owner, repo, runbook link)

Output:
- Repo URL
- Staging deployment URL
- Grafana dashboard URL (auto-created from service template)
- Estimated cost: $X/month (from cluster resource defaults)

Time to first working service: < 15 minutes
```

### Step 4 — Validate the golden path

Before declaring the golden path "done," run it with a real developer who has not been involved in building it.

**Validation protocol:**

```
1. Give the developer the golden path entry point (a URL or a make command)
2. Give them the problem statement ("create a new Go service called 'invoice-processor' owned by the billing team")
3. Do not answer any questions or offer any help
4. Observe: where do they hesitate? where do they fail? where do they ask questions?
5. Record time to completion
6. Debrief: what was confusing? what was missing?
```

A golden path passes validation if:
- The developer completes it without assistance in under 2x the target time
- They do not have to read more than 2 pages of documentation
- Every error message they encounter tells them what to do (not just what failed)

### Step 5 — Publish and market the golden path

A golden path that no one knows about is not a golden path — it is a prototype. After validation:

1. Add the golden path as the first item in the service catalog
2. Add it to the engineering team onboarding checklist
3. Demo it at a company all-hands or engineering meetup
4. Write a short post-mortem of what the old process looked like vs. what the golden path enables

Adoption does not happen automatically. The platform team must actively market its golden paths.

---

## Out-of-Band Exception Tracking as Golden Path Feedback

Every exception request from the golden path is a feature request. Track them:

```
Exception request template:
  Team: [team name]
  Operation: [what they are trying to do]
  Why off-path: [what the golden path does not cover]
  Urgency: [blocking deployment / will unblock in N days / nice-to-have]
  Decision: [approved with conditions / denied / golden path improvement requested]
```

**Exception threshold:** If 3 or more teams request the same exception in a quarter, the golden path has a gap. Add the gap to the platform roadmap.

**Do not deny exceptions lightly.** An exception that is denied without a golden path alternative creates an invisible workaround — engineers will go off-path anyway, without visibility to the platform team. Approve the exception, learn from it, then close the gap.

---

## Worked Examples of Golden Paths in This Repo

### Golden Path 1: Local Development Environment

**Problem:** Engineers need a local Kubernetes environment with real services running to develop and test against.

**Entry point:**

```bash
make local-up
```

**What it does:**

1. Checks prerequisites (Docker, kind, helm, kubectl — installs if missing via `./scripts/bootstrap-dev-env.sh`)
2. Creates a local kind cluster
3. Installs Linkerd service mesh
4. Deploys all services defined in `docker-compose.dev.yaml`
5. Runs database migrations
6. Seeds development fixtures
7. Outputs service URLs and local dashboard URL

**Time to working environment:** < 10 minutes on first run, < 2 minutes on subsequent runs.

**Validation:** `make local-smoke-test` runs against the local environment and confirms all services are healthy.

**Off-path signal:** An engineer who asks "how do I run the service locally?" has not found this golden path — the documentation is missing from onboarding, or the `make local-up` target is not working.

---

### Golden Path 2: Helm Chart for a New Service

**Problem:** Engineers need to deploy their service to Kubernetes without writing raw Kubernetes YAML.

**Entry point:**

```bash
make helm-init SERVICE=my-service TEAM=platform
```

**What it does:**

1. Copies the Helm chart template from `assets/helm-chart-template/`
2. Substitutes service name, team name, and default values (replicas, resource limits, health check paths)
3. Creates `helm/my-service/Chart.yaml`, `values.yaml`, `values.staging.yaml`, `values.production.yaml`
4. Adds the service to the CI/CD pipeline template

**Developer decisions required:** Service name + team name. No Kubernetes knowledge needed.

**Off-path signal:** A PR that adds raw Kubernetes YAML files (not under `helm/`) indicates the Helm golden path was not used.

---

### Golden Path 3: OpenTofu Module for a New Database

**Problem:** Engineers need a new PostgreSQL database provisioned in dev and staging without writing OpenTofu HCL.

**Entry point:**

```yaml
# In environments/staging/databases.yaml — a YAML file, not HCL
databases:
  - name: invoice-processor-db
    owner: billing-team
    size: small          # maps to platform-defined resource preset
    environment: staging
```

**What it does:**

1. Platform's CI pipeline detects the new YAML entry
2. Generates the OpenTofu HCL from the YAML template (via `scripts/generate-db-tofu.sh`)
3. Opens a Terraform plan PR for platform team approval
4. On merge: provisions the database, creates credentials in Vault, injects credentials into the service's Kubernetes secret

**Developer knowledge required:** YAML syntax + the three fields above. No HCL or Terraform knowledge.

**Off-path signal:** A PR that directly modifies `.tf` files under `environments/` without a corresponding `databases.yaml` entry indicates the self-service YAML path was not used — likely because an engineer needed a database option not in the platform's YAML schema (a gap to address).

---

## Iterating the Golden Path

A golden path is a product with a roadmap, not a one-time build. Iteration signals:

| Signal | Action |
|---|---|
| Exception requests for the same operation ≥3 times | Add to golden path in next sprint |
| New engineer TTFD > 2 days | Run embedded session to find specific friction point |
| Error message reported as confusing | Rewrite error message before adding new features |
| Golden path test fails in CI | Treat as a P1 incident; platform team fixes before anything else |
| Quarterly DX survey score drops | Run embedded session with lowest-scoring team immediately |

**Versioning the golden path:** When the golden path changes in a breaking way (different command, different output, different required inputs), announce the change to all teams with at least 2 weeks notice and maintain the old path in parallel for 1 sprint during migration.
