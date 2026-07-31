# Provisioning and the Stamp Model

Reference for `multi-tenancy-design`. Self-contained: the per-tenant provisioning
model for physical isolation — what a stamp is, how a new tenant is stamped, the
tenant lifecycle, the blast-radius argument for one GitOps agent per tenant, and
fleet operations. Grounded in this repo's stack (OpenTofu + Helm, GitOps
App-of-Apps, Kubernetes, per-tenant PostgreSQL and Redpanda) and the DataAsset
Management / Compliance / Reporting Bounded Contexts. Ties to `opentofu-module`,
`gitops-workflow`, and `environment-config`.

---

## What a Stamp Is

In the physical-isolation model, a **stamp** is a complete, dedicated per-tenant
instance of the entire platform. "Add a tenant" means "stamp a new instance," not
"insert a row." A stamp comprises:

- A Kubernetes namespace (or dedicated cluster / cloud account for the
  highest-sensitivity tenants) — `tenant-<id>`.
- All application services for every Bounded Context: DataAsset Management,
  Compliance, Reporting.
- A dedicated PostgreSQL instance (with Apache AGE where the graph projection is
  used), with its own credentials, connection pool, backup schedule, and
  encryption key.
- A dedicated Redpanda namespace or cluster for that tenant's event streams.
- A dedicated ingress with the tenant's subdomain (or a customer-controlled
  domain) and its own TLS.
- Its own OpenTelemetry/Prometheus/Tempo/Grafana scrape and trace scope so
  observability data is tenant-attributed and never commingled.

Every stamp is rendered from the **same versioned OpenTofu Module and Helm Chart**,
differing only in a **per-tenant values file**. That is the single most important
operational property: there is one source of desired state, and all per-tenant
variation is data in a values file, never a hand edit to a live environment.

```
# The per-tenant values file is the ONLY thing that varies between stamps.
tenant:
  id: acme
  displayName: "Acme Corp"
  region: eu-west-1          # data-residency pin — the stamp lives in-region
  tier: enterprise
database:
  instanceClass: db.r6g.xlarge
  storageGb: 500
  encryptionKeyArn: "arn:aws:kms:eu-west-1:...:key/acme-cmk"  # per-tenant key
broker:
  partitionsPerTopic: 12
observability:
  grafanaOrgId: 42
```

---

## How a New Tenant Is Stamped

Provisioning is code — an OpenTofu Module invoked by the Control Plane, plus a
Helm release, wired under a **per-tenant GitOps App-of-Apps root**. It is
idempotent, versioned, and auditable. It is never a runbook of manual steps.

```
Tenant onboarding request (Control Plane)
        │
        ▼
1. terraform apply  module.create_tenant  (OpenTofu Module)
     • create namespace tenant-<id> with default-deny NetworkPolicy
     • provision PostgreSQL instance + per-tenant KMS key + credentials
     • provision Redpanda namespace/cluster + topics + ACLs
     • create ingress + TLS for the tenant subdomain
     • write credentials to the tenant's Secrets Management scope
        │
        ▼
2. GitOps: commit tenants/<id>/ App-of-Apps root
     • the per-tenant root Application references the shared Helm Chart
       version pinned for this tenant, with the per-tenant values file
     • the tenant's OWN GitOps agent reconciles it (see blast radius below)
        │
        ▼
3. Helm release: all services deployed with the per-tenant values file
     • run database migrations against the tenant's instance
     • register the tenant in the tenant registry (Control Plane metadata only)
        │
        ▼
4. Health gate: confirm every service Ready, migrations applied, topics live
        │
        ▼
5. Tenant ready — notify onboarding
```

Because steps 1–3 are declarative and versioned, re-running them is a no-op when
the stamp already matches desired state — the definition of idempotent
provisioning. The Control Plane records the deployed Chart/Module version per
tenant in the tenant registry; it stores **metadata only** and never reads tenant
data (a Single-Owner + Delegate boundary — the stamp owns its data, the Control
Plane delegates).

---

## Tenant Lifecycle

A model that can only *create* tenants fails its first churn event and its first
GDPR erasure request. The lifecycle is designed up front as a state machine:

```
  provision ──▶ active ──▶ suspended ──▶ active
                  │            │
                  │            └──▶ deprovision ──▶ destroyed
                  └──────────────▶ deprovision ──▶ destroyed
```

| State | Meaning | What happens |
|---|---|---|
| **provision** | Stamp being created | OpenTofu + Helm apply, migrations, health gate |
| **active** | Serving the tenant | Normal operation; included in upgrade waves |
| **suspended** | Access frozen (non-payment, security hold) | Ingress disabled, workloads scaled to zero; data retained; no data loss |
| **data export** | Contractual handover | Tenant's data exported in an agreed format before destruction; part of both offboarding and DSAR fulfilment |
| **deprovision** | Offboarding | Destroy the stamp's infrastructure, expire or hand over backups per contract, revoke keys |
| **destroyed** | Gone | A **destruction attestation** is produced — proof for the customer and for the SOC 2 audit trail that the data is gone |

Deprovisioning is the same OpenTofu Module in reverse (`terraform destroy` scoped
to the tenant), so offboarding is as automated, versioned, and auditable as
onboarding — never a manual teardown that leaves orphaned resources or unexpired
backups.

---

## One GitOps Agent Per Tenant — the Blast-Radius Argument

The whole point of physical isolation is a one-tenant blast radius. A single,
fleet-wide GitOps agent reconciling every tenant's stamp would reintroduce a
shared component whose compromise or malfunction reaches every tenant —
undoing the isolation at the delivery layer.

Therefore: **one GitOps agent (one App-of-Apps root) per tenant.** A
reconciliation fault, a bad sync, or a compromised agent is contained to the one
tenant it manages. This mirrors the cross-layer consistency principle: isolation
must hold at the delivery/GitOps layer too, not only at runtime. It also makes
**per-tenant rollback** trivial — a failed upgrade rolls back one tenant's root
without touching the rest of the fleet.

---

## Fleet Operations

Infrastructure-per-tenant turns one deployment into a fleet. The design must state
how the fleet is operated, or the isolation model collapses under its own weight.

- **Single source of desired state.** Every stamp renders from the same Chart and
  Module versions; the per-tenant values file is the only variation. Hand-edited
  tenant environments are configuration **drift** — GitOps reconciliation detects
  drift and treats it as an incident, not a customisation channel (the *snowflake
  tenant* anti-pattern). See `environment-config` for how per-tenant values are
  structured and validated.
- **Bounded version skew.** Upgrades roll out in waves: one designated **canary
  tenant** (internal or consenting) → a small wave → the fleet. The tenant registry
  records each tenant's deployed version. The maximum supported skew is declared
  (e.g. N and N−1) because event schemas and API contracts must stay compatible
  across the skew window — migrations stay backward-compatible within it, which is
  also what makes per-tenant rollback safe.
- **Never big-bang.** Deploying a new version to all tenants at once turns a bad
  release into an every-customer incident and throws away the blast-radius benefit
  the whole model was built to buy.
- **Cost attribution built in.** Each tenant namespace/account is tagged for cost
  reporting from day one; physical isolation makes per-tenant cost directly
  visible — use it to price tiers and to spot anomalies (a tenant whose ingest
  cost suddenly spikes).
- **Per-tenant observability.** Because each stamp scopes its own
  OTel/Prometheus/Tempo/Grafana data, an SLO breach or a trace is already
  tenant-attributed — no cross-tenant log aggregation is needed, and none is
  permitted (a shared observability store aggregating raw tenant data is
  isolation theatre, the same failure mode as a shared reporting database).

---

## Ties to Other Skills

- **`opentofu-module`** — the create-tenant / destroy-tenant modules are authored
  under that skill's module conventions (idempotent, versioned, input-validated).
  This skill decides *that* provisioning is a module and *what* it must create;
  `opentofu-module` decides *how* the module is written.
- **`gitops-workflow`** — the per-tenant App-of-Apps root and one-agent-per-tenant
  pattern are GitOps mechanics; this skill supplies the blast-radius requirement
  that drives them.
- **`environment-config`** — the per-tenant values file structure, precedence, and
  validation live there; this skill establishes that all per-tenant variation must
  be values-file data, never a live-environment edit.
- **`event-driven-patterns`** — the bounded version-skew window exists because
  event schemas must stay compatible across it; schema evolution rules live there.
