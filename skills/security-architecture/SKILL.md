---
name: security-architecture
description: >
  Teaches how to produce a Security Architecture document — the synthesis of all
  security design decisions into a single coherent view covering defence-in-depth
  layers, security controls per architecture layer (network, workload, application,
  data), the security control matrix mapped to threat model mitigations, and how
  security architecture connects to the NFR specification's security requirements.
  Produced by the security-architect agent after threat modeling and Zero Trust
  design are complete.
version: 1.1.0
phase: design
owner: security-architect
created: 2026-06-25
tags: [design, security, security-architecture, defence-in-depth, controls, nfr]
---

# Security Architecture

## Purpose

The Security Architecture document synthesises all security design decisions into a single view. Where the threat model identifies what can go wrong and the zero-trust-design skill defines the identity and encryption foundations, the Security Architecture shows how all controls work together across layers to provide defence in depth.

Defence in depth means that no single control failure results in a complete breach. Multiple independent controls protect each asset. An attacker who defeats one control encounters another.

---

## Defence-in-Depth Layers

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 6: Data                                              │
│  Encryption at rest (AES-256), per-tenant keys,             │
│  backup encryption, audit log integrity                     │
├─────────────────────────────────────────────────────────────┤
│  Layer 5: Application                                       │
│  ABAC policy enforcement, input validation, output          │
│  encoding, OWASP Top 10 + API Security Top 10 controls,     │
│  dependency scanning                                        │
├─────────────────────────────────────────────────────────────┤
│  Layer 4: Workload                                          │
│  Non-root containers, read-only filesystems, security       │
│  contexts, resource limits, image scanning                  │
├─────────────────────────────────────────────────────────────┤
│  Layer 3: Service-to-Service                                │
│  mTLS (Linkerd), deny-by-default Linkerd policies,          │
│  Principle of Least Privilege for service accounts          │
├─────────────────────────────────────────────────────────────┤
│  Layer 2: Network                                           │
│  Kubernetes NetworkPolicy (deny-all default),               │
│  Namespace isolation, ingress TLS termination               │
├─────────────────────────────────────────────────────────────┤
│  Layer 1: Infrastructure                                    │
│  Physical tenant isolation, VPC/VNET isolation,             │
│  cloud account boundaries, IaC-only changes                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Security Controls Per Layer

### Layer 1: Infrastructure

| Control | Implementation | Verification |
|---|---|---|
| Physical tenant isolation | Separate Kubernetes namespace (or cluster) per tenant | Namespace separation verified in provisioning IaC |
| IaC-only changes | All infrastructure changes via OpenTofu; no manual console changes | CloudTrail / audit logs show only IaC-sourced changes |
| Cloud account segmentation | Production in a dedicated cloud account; separate from staging | AWS Organizations / Azure Management Groups |
| Immutable infrastructure | No SSH access to production nodes; changes deploy new images | No SSH keys on production nodes |

### Layer 2: Network

| Control | Implementation | Verification |
|---|---|---|
| Default-deny NetworkPolicy | Kubernetes NetworkPolicy blocks all traffic not explicitly permitted | `kubectl get networkpolicy` shows deny-all baseline |
| Ingress TLS | TLS terminated at ingress controller; no plaintext HTTP | TLS certificate present; HTTP redirects to HTTPS |
| Namespace isolation | No network path between tenant namespaces | Network test: attempt cross-namespace connection; expect timeout |

### Layer 3: Service-to-Service

| Control | Implementation | Verification |
|---|---|---|
| mTLS | Linkerd service mesh; automatic certificate issuance and rotation | `linkerd viz edges` shows all connections encrypted |
| Deny-by-default service policy | Linkerd ServerAuthorization resources; only named callers permitted | Attempt call from unauthorised service; expect 403 |
| Short-lived service credentials | Linkerd certificates rotated every 24 hours | Certificate expiry < 24 hours confirmed in Linkerd dashboard |

### Layer 4: Workload

| Control | Implementation | Verification |
|---|---|---|
| Non-root containers | `runAsNonRoot: true` in all pod SecurityContexts | `kubectl get pod -o json | jq '.spec.securityContext'` |
| Read-only root filesystem | `readOnlyRootFilesystem: true` where possible | Pod spec audit |
| No privilege escalation | `allowPrivilegeEscalation: false` | Pod spec audit |
| Resource limits | CPU and memory limits on all containers | `kubectl describe pod` shows limits |
| Image scanning | Trivy scan in CI; no HIGH or CRITICAL CVEs in production images | CI pipeline gate |
| Signed images | Container images signed with Cosign; verified at admission | Admission webhook rejects unsigned images |

### Layer 5: Application

| Control | Implementation | Verification |
|---|---|---|
| JWT authentication | Every API endpoint validates JWT; health checks excluded | Test matrix: call endpoints with no token, expired token, invalid signature |
| ABAC enforcement | Policy evaluated in Application layer for every Command and Query | Unit tests for every policy rule; integration tests for boundary cases |
| Input validation | Structural validation at API handler; business validation at Aggregate | Table-driven unit tests for all validation paths |
| SQL injection prevention | pgx parameterised queries only; no string concatenation in SQL | Code review; SAST scan |
| Output encoding | JSON responses encoded by `encoding/json`; no manual string construction | Code review |
| Dependency scanning | `govulncheck` and Dependabot in CI | Weekly scan report |

### Layer 6: Data

| Control | Implementation | Verification |
|---|---|---|
| Encryption at rest | PostgreSQL on encrypted filesystem; backups encrypted before upload | Storage encryption verified in IaC; backup encryption verified in restore test |
| Per-tenant encryption keys | Separate KMS key per tenant; key access policy scoped to tenant services | KMS key policy audit |
| Audit log integrity | Append-only audit log table; tamper detection via hash chain | Tamper test: attempt DELETE on audit log; expect failure |
| Data residency enforcement | Physical isolation ensures data never leaves the declared boundary | Architecture review; network egress policy |

---

## Security Control Matrix (Threat → Control Mapping)

| Threat ID | Threat | Controls that mitigate it | Layer |
|---|---|---|---|
| THR-001 | JWT forgery | RS256 signing with algorithm pinning (reject `alg` substitution), short expiry, issuer + audience validation | Application |
| THR-002 | Cross-tenant data leak | Physical namespace isolation, ABAC tenant check | Infrastructure + Application |
| THR-003 | Service impersonation | mTLS, Linkerd deny-by-default, workload identity | Service-to-Service |
| THR-004 | Secret compromise | Vault dynamic secrets, short-lived credentials, no env var secrets | Application + Workload |
| THR-005 | Privileged container escape | Non-root, read-only FS, no privilege escalation | Workload |
| THR-006 | Audit log tampering | Append-only table, hash chain, separate audit user | Data |

---

## Security NFR Traceability

Every security NFR from the NFR specification must map to at least one control in this document:

| NFR ID | NFR Description | Implementing Control | Layer |
|---|---|---|---|
| NFR-SEC-001 | All API endpoints require JWT | JWT middleware at API handler | Application |
| NFR-SEC-002 | mTLS for all service-to-service | Linkerd service mesh | Service-to-Service |
| NFR-SEC-003 | AES-256 encryption at rest | Encrypted filesystem + KMS | Data |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| All six layers addressed | Controls documented for every defence-in-depth layer | Missing layers with no controls |
| Threat → control mapping | Every threat in the threat register maps to at least one control | Threats with no implementing control |
| NFR traceability | Every security NFR maps to a control | Security NFRs with no implementation |
| Verification method | Every control has a stated verification test | Controls with no way to verify they work |
| Defence in depth | Every critical asset has controls at multiple layers | Single-layer defence for critical assets |
| Residual risks explicit | Unmitigated threats listed with acceptance rationale | Gaps silently omitted from the document |

---

## Anti-Patterns

- **Single-layer trust.** "The network is isolated, so the application check is redundant." Every control in this document assumes the layers around it will fail. Physical tenant isolation does not remove the ABAC tenant check; mTLS does not remove JWT validation.
- **Controls without verification.** A control that cannot be tested is a hope, not a control. "Encryption at rest is enabled" means nothing without the IaC assertion and the restore test that prove it.
- **Copy-paste security architecture.** Importing a generic control catalogue without mapping it to this product's threat register. The Security Control Matrix exists to force the question "which threat does this control mitigate?" — a control mitigating no listed threat is either missing its threat or is decoration.
- **Perimeter thinking.** Concentrating controls at Layers 1-2 and treating everything inside as trusted. This contradicts Zero Trust Architecture: the interior layers (workload, application, data) carry their own full set of controls.
- **NFRs and controls drifting apart.** Security NFRs written in Discovery that no control implements, or controls added ad hoc with no NFR or threat justifying them. The two traceability tables must close in both directions.
- **Hiding residual risk.** Presenting the architecture as fully mitigated when specific threats are accepted, deferred, or partially covered. Residual risks are documented with an owner and rationale — an auditor finding an undocumented gap is far worse than one finding an accepted risk.

---

## Output Format

```markdown
---
name: security-architecture
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: security-architect
---

# Security Architecture

## Defence-in-Depth Layers
[Layer diagram]

## Controls Per Layer
[Tables per layer]

## Security Control Matrix
| Threat ID | Controls | Layer |
|---|---|---|

## Security NFR Traceability
| NFR ID | Control | Layer | Verification |
|---|---|---|---|

## Residual Risks
[Threats or NFRs with incomplete mitigation — with acceptance rationale]
```
