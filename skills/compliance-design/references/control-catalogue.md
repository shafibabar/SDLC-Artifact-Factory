# Control Catalogue — SOC 2, GDPR/CCPA, ISO 27001 decomposed for this repo

This catalogue decomposes the in-scope requirements into concrete, automatable
controls for this data-estate / compliance platform (Go + chi + pgx + Redpanda,
physical per-tenant isolation, Linkerd mTLS, OpenTelemetry/Prometheus/Tempo/
Grafana, GitHub Actions CI/CD). Each control names its **requirement** (a real,
standard clause), its **behaviour**, its **enforcement mode** (gate / monitor /
record), and the **automatable test** that `compliance-verification` implements.

> Accuracy rule: every requirement below is cited by its real, public,
> standard name. No control IDs are invented. SOC 2 Trust Service Criteria use
> the AICPA CC-series numbering; GDPR uses article numbers; CCPA/CPRA use
> §1798.x section numbers; ISO/IEC 27001 uses Annex A control numbers.

---

## SOC 2 Trust Service Criteria (Security, Availability, Confidentiality)

### CC6.1 — Logical access security

*Requirement (AICPA):* the entity implements logical access security software,
infrastructure, and architectures over protected information assets.

| Control | Behaviour | Mode | Automatable test |
|---|---|---|---|
| Endpoint authentication | Every API endpoint rejects an unauthenticated request | gate | Call each endpoint with no JWT → expect 401 |
| Token expiry bound | Access tokens expire within one hour | gate | Parse JWT, assert `exp - iat ≤ 3600` |
| Service-to-service mTLS | All meshed pod-to-pod calls use mTLS | gate | Linkerd edge report shows zero plaintext edges |
| ABAC on every request | Authorization decision evaluated per request | gate | Call with insufficient permission → expect 403 |

### CC6.2 / CC6.3 — Access provisioning and removal

*Requirement:* access is registered/authorized before granting, and removed
when no longer required.

| Control | Behaviour | Mode | Automatable test |
|---|---|---|---|
| Session revocation on termination | Terminating an account invalidates active sessions | gate | Terminate account, reuse prior JWT → expect 401 |
| No orphan credentials | Terminated users hold no active DB credentials | monitor | Scheduled query: no active credentials for terminated users |

### CC6.6 / CC6.7 — Boundary protection and transmission

| Control | Behaviour | Mode | Automatable test |
|---|---|---|---|
| Encryption in transit | External and internal traffic is TLS/mTLS | gate | Certificate validity check + Linkerd mTLS verification |
| Cross-tenant isolation | A request scoped to tenant A cannot read tenant B data | gate | Integration test: tenant-A JWT against tenant-B resource → 403/404 |

Cross-tenant isolation is the **highest-materiality** control in this product
(see `materiality-and-risk-selection.md`). Physical per-tenant isolation
provides the infrastructure layer; the ABAC tenant check is the independent
second layer — both are tested (defence in depth).

### CC7.2 / CC7.3 — System monitoring and evaluation

| Control | Behaviour | Mode | Automatable test |
|---|---|---|---|
| Audit trail on state change | Every domain state change writes a non-repudiable audit entry | gate | Perform action, assert audit entry with actor, event type, hash |
| Continuous control monitoring | Material controls observed to remain satisfied in production | monitor | Prometheus rule over OpenTelemetry signals alerts on drift |

### CC8.1 — Change management (Separation of Duties)

*Requirement:* the entity authorizes, designs, develops, tests, approves, and
implements changes to meet its objectives. The **Separation of Duties** control
below is the change-management control that satisfies CC8.1's approval
requirement — decomposed in full in its own section.

---

## Separation of Duties control — decomposed in full

Separation of Duties makes real the principle that **the change author does not
equal the change approver**. As a policy it is trivially violated; it becomes a
real control only when the pipeline enforces it mechanically and emits evidence.

**Behaviour.** For any promotion to `main`, the pipeline verifies that the PR
author identity and the approving reviewer identity are distinct, and that at
least one independent approval exists. The gate **fails the promotion job when
the approver identity equals the author identity**, and then emits a
Separation-of-Duties attestation to the evidence store.

**Enforcement mode:** `gate` — a failed SoD check blocks the merge to `main`.

**Grounding in this repo's flow.** The `feature/<n>-…` (or `issue-NNN-…`) → PR →
`main` branch flow already routes every change through a PR. SoD adds a required
status check on that PR.

```yaml
# .github/workflows/separation-of-duties.yml (illustrative)
name: separation-of-duties
on:
  pull_request_review:
    types: [submitted]
jobs:
  sod-gate:
    runs-on: ubuntu-latest
    steps:
      - name: Enforce author != approver
        uses: actions/github-script@v7
        with:
          script: |
            const author = context.payload.pull_request.user.login;
            const reviews = await github.rest.pulls.listReviews({
              owner: context.repo.owner, repo: context.repo.repo,
              pull_number: context.payload.pull_request.number,
            });
            const approvers = reviews.data
              .filter(r => r.state === 'APPROVED')
              .map(r => r.user.login);
            const independent = approvers.filter(a => a !== author);
            if (independent.length === 0) {
              core.setFailed(
                `Separation of Duties: no independent approver. ` +
                `Author ${author} cannot approve their own change.`);
            }
```

**Attestation emitted (record side of the gate).** On pass, the pipeline appends
a signed attestation to the append-only evidence store (S3 with object lock).
The attestation shape follows in-toto/SLSA rather than a bespoke JSON:

```go
// SoDAttestation is appended to the immutable evidence ledger on a passing gate.
type SoDAttestation struct {
    ControlID  string    `json:"control_id"`  // "SOC2-CC8.1-SoD"
    Subject    string    `json:"subject"`     // commit SHA promoted
    Predicate  string    `json:"predicate"`   // "author != approver; independent approval present"
    Author     string    `json:"author"`      // PR author login
    Approver   string    `json:"approver"`    // independent approver login
    Producer   string    `json:"producer"`    // "github-actions/separation-of-duties"
    Timestamp  time.Time `json:"timestamp"`
}
```

The FAIL case is retained alongside PASS in the ledger — a blocked promotion
followed by a re-request from an independent approver and a passing re-run is
exactly the operating-effectiveness story a SOC 2 Type II auditor wants.

---

## GDPR

### Article 32 — Security of processing

| Control | Behaviour | Mode | Automatable test |
|---|---|---|---|
| Encryption at rest | All PostgreSQL storage is encrypted | gate | Assert `storage_encrypted = true` in the OpenTofu plan |
| Encryption in transit | All data flows are TLS/mTLS | gate | Certificate + Linkerd mTLS verification |
| Audit retention | Audit log retained for the required period | monitor | Query: oldest audit entry ≥ required retention |

### Article 5 — Principles (purpose limitation, minimisation, storage limitation)

| Control | Behaviour | Mode | Automatable test |
|---|---|---|---|
| Purpose limitation | A query under one purpose cannot read a column tagged another | monitor | pgx access-layer test: foreign-purpose read → denied |
| Structural minimisation | Raw file contents are never persisted — only entity types + counts | gate | Assert the findings type has no raw-text field / constructor path |
| Storage limitation | PII partitions carry a retention TTL and are dropped on schedule | monitor | Assert scheduled partition-drop ran and was audited |

Minimisation and purpose-limitation *controls* are designed by `privacy-design`
(the PII lifecycle and the structural-minimisation type); compliance-design maps
them to Article 5 and evidences them. The structural-minimisation control gates
because raw-PII persistence is a material, irreversible privacy failure.

### Article 30 — Records of processing

| Control | Behaviour | Mode | Automatable test |
|---|---|---|---|
| Processing register | The processing register is generated from code, not hand-kept | record | Assert register artifact is produced by the pipeline |

---

## CCPA / CPRA

CCPA/CPRA obligations largely restate the same FIPPs as GDPR under §1798.x
sections. Map to the FIPP first (see `coverage-matrix-template.md`), then to
both regimes — one control usually satisfies both.

| Control | Behaviour | Mode | Section |
|---|---|---|---|
| Purpose disclosure / limitation | Data used only for the disclosed business purpose | monitor | §1798.100(b) |
| Deletion right | A verified deletion request provably drops the subject's data | gate | §1798.105 |
| No sale without opt-out | Data flows carry no third-party sale path | record | §1798.120 |

---

## ISO/IEC 27001 Annex A

| Requirement | Control | Behaviour | Mode | Automatable test |
|---|---|---|---|---|
| A.9.4.1 Information access restriction | ABAC enforcement | Access restricted per policy on all resources | gate | ABAC test across all resource types → 403 without permission |
| A.10.1 Cryptographic controls | Key + encryption posture | Encryption at rest and in transit enforced | gate | OpenTofu plan + certificate checks |
| A.12.4 Logging and monitoring | Audit + observability | Events logged, monitored, retained | monitor | Audit-entry test + Prometheus retention rule |
| A.16.1 Incident management | Incident evidence | Security events raise alerts and produce evidence | monitor | Alert-fires test on synthetic event |

---

## How a catalogue entry becomes a matrix row

Each entry above supplies six of the Coverage Matrix columns directly:
Control, Requirement ref, Enforcement mode, Materiality (from
`materiality-and-risk-selection.md`), Test, and Evidence type. The FIPP column
is filled for the privacy controls (Article 5 / CCPA) from the mapping table in
`coverage-matrix-template.md`. Status is `Designed` once the test is named.
