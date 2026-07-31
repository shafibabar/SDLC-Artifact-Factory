# Security Control Matrix — Template, Worked Example, and Governance Triad

Reference for `security-architecture`. The body defines the matrix's columns and its STRIDE source
in brief. This file is the full template, the per-layer control catalogue, a worked matrix for the
DataAsset flow, and the Automated Governance component triad (Investments Unlimited's DevOps
Automated Governance Reference Architecture).

---

## Column definitions

The Security Control Matrix is the artifact this skill produces. Every row is one control answering
one modeled threat.

| Column | Holds | Source |
|---|---|---|
| **Threat (STRIDE cell)** | The specific threat, cited to its DFD element + STRIDE letter | `threat-modeling` grid |
| **Control** | The concrete mechanism that mitigates it | STRIDE property→mitigation map |
| **Layer** | Which defense-in-depth layer the control lives in (1–6) | layer catalogue below |
| **Enforcement mode** | `gate` / `monitor` / `record` — what happens on failure | materiality (Investments Unlimited) |
| **Invariant** | Which stated invariant this control preserves | `references/design-principles.md` |
| **Blast radius** | What is reachable if this control alone fails | failure-domain analysis |
| **Containing failure domain** | The independent domain that still contains it | failure-domain analysis |

A control mitigating no listed threat is decoration; a filled STRIDE cell with no control is an
unmet requirement; a control with no invariant cannot be reviewed for removal.

### The STRIDE property → control lane map (the Control column's principled source)

| STRIDE letter | Violated property | Control lane in this repo |
|---|---|---|
| **S**poofing | Authentication | Linkerd mTLS peer identity; JWT `sub` validation |
| **T**ampering | Integrity | `pgx` parameterized writes; signed events; Transactional Outbox |
| **R**epudiation | Non-Repudiation | append-only audit log; hash chain; OpenTelemetry spans |
| **I**nformation disclosure | Confidentiality | Encryption at rest/in transit; ABAC filtering; PII never persisted raw |
| **D**enial of service | Availability | rate limits; Redpanda backpressure; Circuit Breaker |
| **E**levation of privilege | Authorization | `AccessPolicy.Evaluate` (ABAC); per-tenant scoping |

### Enforcement mode (materiality)

Not every control deserves a hard gate — weight by the *materiality* of the risk it addresses.

- **`gate`** — blocks promotion / the pipeline on failure. Reserved for material risks: cross-tenant
  isolation, encryption-at-rest, Separation of Duties, no untenanted queries.
- **`monitor`** — raises an alert on drift but does not block (Continuous Control Monitoring).
- **`record`** — emits evidence only.

Add the enforcement mode per control so the matrix states *what happens when it fails*, not merely
that it is tested. A high-severity modeled threat should force a `gate`-mode control — this is how a
threat's severity gets a concrete downstream consequence in the pipeline.

---

## The six defense-in-depth layers — control catalogue

Reference tables for the Layer column. Every control carries a stated verification method.

### Layer 1 — Infrastructure

| Control | Implementation | Verification |
|---|---|---|
| Physical tenant isolation | Separate Kubernetes namespace (or cluster) per tenant | Namespace separation verified in provisioning IaC |
| IaC-only changes | All changes via OpenTofu; no manual console changes | Audit logs show only IaC-sourced changes |
| Cloud account segmentation | Production in a dedicated account, separate from staging | AWS Organizations / Azure Management Groups |
| Immutable infrastructure | No SSH to production nodes; changes deploy new images | No SSH keys on production nodes |

### Layer 2 — Network

| Control | Implementation | Verification |
|---|---|---|
| Default-deny NetworkPolicy | Kubernetes NetworkPolicy blocks all non-permitted traffic | `kubectl get networkpolicy` shows deny-all baseline |
| Ingress TLS | TLS terminated at ingress; no plaintext HTTP | Certificate present; HTTP redirects to HTTPS |
| Namespace isolation | No network path between tenant namespaces | Cross-namespace connection attempt times out |

### Layer 3 — Service-to-Service

| Control | Implementation | Verification |
|---|---|---|
| mTLS | Linkerd; automatic certificate issuance and rotation | `linkerd viz edges` shows all connections encrypted |
| Deny-by-default service policy | Linkerd `ServerAuthorization`; only named callers permitted | Unauthorized caller attempt → 403 |
| Short-lived service credentials | Linkerd certs rotated frequently | Cert expiry within rotation interval, confirmed in dashboard |

> Layer 3 is **transport identity only** — it proves *who* connects. The authorization *decision*
> is Layer 5, never here. (See `references/zero-trust-and-mesh.md`.)

### Layer 4 — Workload

| Control | Implementation | Verification |
|---|---|---|
| Non-root containers | `runAsNonRoot: true` in all pod SecurityContexts | Pod spec audit |
| Read-only root filesystem | `readOnlyRootFilesystem: true` where possible | Pod spec audit |
| No privilege escalation | `allowPrivilegeEscalation: false` | Pod spec audit |
| Resource limits | CPU + memory limits on all containers | `kubectl describe pod` shows limits |
| Image scanning | Trivy in CI; no HIGH/CRITICAL CVEs in prod images | CI pipeline gate |
| Signed images | Cosign-signed; verified at admission | Admission webhook rejects unsigned images |

### Layer 5 — Application

| Control | Implementation | Verification |
|---|---|---|
| JWT authentication | Every endpoint validates JWT; health checks excluded | Test matrix: no token / expired / bad signature |
| **ABAC enforcement (the authZ decision)** | Policy evaluated in the application for every Command and Query | Unit test per policy rule; integration test for boundary cases |
| Input validation | Structural validation at handler; business validation at Aggregate | Table-driven unit tests for all paths |
| SQL injection prevention | `pgx` parameterized queries only; no string concatenation | Code review; SAST |
| Output encoding | Responses encoded by `encoding/json` | Code review |
| Dependency scanning | `govulncheck` + Dependabot in CI | Weekly scan report |

### Layer 6 — Data

| Control | Implementation | Verification |
|---|---|---|
| Encryption at rest | PostgreSQL on encrypted filesystem; backups encrypted before upload | IaC assertion + restore test |
| Per-tenant encryption keys | Separate KMS key per tenant, scoped to tenant services | KMS key policy audit |
| Audit log integrity | Append-only table; tamper detection via hash chain | DELETE on audit log fails |
| Data residency enforcement | Physical isolation keeps data inside the declared boundary | Architecture review; egress policy |

---

## Worked matrix — DataAsset ingestion → classification flow

Threats generated by STRIDE-per-element over the DataAsset flow (external Drive/S3 entity →
ingestion process → Redpanda topic → classification process → PostgreSQL store). Each row is one
filled STRIDE cell carried forward.

| Threat (element · STRIDE) | Control | Layer | Enforcement | Invariant | Blast radius if control fails | Containing failure domain |
|---|---|---|---|---|---|---|
| Ingestion API caller · **S**poofing | JWT `sub` validation + Linkerd mTLS peer identity | 5 + 3 | gate | INV-1 | requests processed under a forged identity | per-tenant namespace |
| Classification proc · **E**oP (cross-tenant read) | ABAC `Evaluate` tenant check | 5 | gate | INV-1 | one tenant's classified DataAssets readable | physical namespace isolation |
| PostgreSQL store · **T**ampering | `pgx` parameterized writes; INSERT-only audit role | 5 + 6 | gate | INV-3 | injected/altered rows in the estate | append-only audit + hash chain |
| Redpanda topic · **I**nfo disclosure | encryption in transit (mTLS); PII never persisted raw | 3 + 6 | gate | INV-4 | source entities exposed on the wire/at rest | `ExtractedEntitySummary` type (no raw-text path) |
| Audit log · **R**epudiation | append-only table + hash chain; OTel spans | 6 | monitor | INV-3 | deniability of a privileged action | separate INSERT-only DB role |
| Ingestion worker · **D**oS | rate limits; Redpanda backpressure; Circuit Breaker | 5 | monitor | — | ingestion pipeline saturated for one tenant | per-tenant resource quota |
| Drive/S3 external entity · **S**poofing | scoped, time-boxed, revocable OAuth grant | 1 | gate | INV (least-priv) | one customer's source docs at the third party | token scope + revocation path |
| Secret handling · **I**nfo disclosure | `Secret` redaction type; no env-var secrets; TLS | 5 | gate | INV-2 | a leaked plaintext credential | short-lived credential + revocation |

Every filled STRIDE cell has a mitigating control; every control cites the invariant it preserves
and the domain that contains it if it fails. Rows with no `gate` control that guard a material risk
are the review flags.

---

## Security-sensitivity map (orthogonal axis)

Tag each Bounded Context for security-sensitivity *independently* of its Core/Supporting/Generic
classification, and flag divergences — a `Generic` subdomain rated high-sensitivity gets the same
scrutiny as a Core one.

| Subdomain | Core / Supporting / Generic | Security-sensitivity | Divergence flag |
|---|---|---|---|
| DataAsset classification | Core | High | aligned |
| PII entity extraction | Core | High | aligned |
| Authentication / token issuer | Generic | **High** | **flag — Generic but high-sensitivity** |
| Reporting / dashboards | Supporting | Medium | aligned |
| Notification delivery | Generic | Low | aligned |

---

## The Automated Governance component triad

Governance is a first-class architecture concern with named, deployable components — not a reporting
afterthought. The reference architecture: pipeline stages emit **attestations**, an **evidence
store** collects them immutably, and **control gates** consult them to make an automated go/no-go
decision before promotion.

```
[attestation-producer]  →  [evidence-store]  →  [control-gate]
 CI stages emit signed,     append-only,          consumes the required
 digest-pinned attestations  tamper-evident ledger  attestation set, verifies
 (build/test/scan/deploy)    (S3 + object lock)     signatures, permits/blocks
```

### Attestation — the evidence primitive

An **attestation** is a signed, machine-generated, *composable* statement: "control X was satisfied
for artifact Y (pinned by digest/commit) at time T by process P." More than a test-pass boolean —
its provenance (which build, which commit, which environment, which signing identity) is intrinsic,
and attestations from many stages **chain** into one verifiable release narrative. Adopt the
in-toto / SLSA attestation shape rather than a bespoke JSON.

```go
type Attestation struct {
    ControlID string    // e.g. "cross-tenant-isolation"
    Subject   string    // artifact digest / commit SHA it attests about
    Predicate string    // what was checked and the result
    Producer  string    // pipeline stage + signing identity
    Timestamp time.Time
    // signed with Cosign, appended to the immutable store
}
```

### Control-gate — Separation of Duties enforced in code

The classic control "the person who writes the change cannot be the person who approves its release"
is real only when the **pipeline mechanically enforces it**. Add a required GitHub Actions check
that reads the PR author and approving-reviewer identities and **fails the promotion when they are
equal** (or when no independent approval exists), emitting an SoD attestation. This turns SoD from a
convention into an evidenced, mechanically enforced control — grounded in this repo's
branch → PR → `main` flow.

### Continuous Control Monitoring

Point-in-time verification (passed *at deploy*) says nothing about whether encryption-at-rest is
still enabled today. Express a subset of controls (encryption-at-rest on, mTLS coverage complete, no
untenanted queries) as Prometheus rules over OpenTelemetry signals, with drift raising an alert and
generating a fresh timestamped attestation — closing the gap between "passed at deploy" and "still
holds in production" that SOC 2 Type II operating-effectiveness actually assesses.

### The evidence store as the audit deliverable

Append-only S3 with object lock; queryable by control and commit. Retain FAIL attestations alongside
PASS ones — the remediation-then-pass chain *is* the operating-effectiveness story an auditor wants.
Evidence assembly becomes a query, not a multi-week scramble.
