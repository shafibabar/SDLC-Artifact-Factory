---
name: threat-modeling
description: >
  Teaches how to conduct structured threat modelling using the STRIDE framework
  and Attack Trees — identifying threats to the system's assets, evaluating
  their likelihood and impact, and producing a prioritised threat register with
  mitigations. Threat modelling is the first security artifact produced for any
  product and the input to all subsequent security design decisions. Used by the
  security-architect agent at the start of security work in the Design phase.
version: 1.0.0
phase: design
owner: security-architect
tags: [design, security, threat-modeling, stride, attack-trees, risk]
---

# Threat Modeling

## Purpose

Threat modeling is a structured approach to identifying security threats before they are built into the system. It answers four questions:
1. **What are we building?** — the system and its assets
2. **What can go wrong?** — the threats
3. **What are we going to do about it?** — the mitigations
4. **Did we do a good enough job?** — the validation

Threat modeling is conducted before implementation. Finding a threat during design costs the time to write a mitigation. Finding it in production costs a breach.

---

## STRIDE Framework

STRIDE (Microsoft) categorises threats by the type of attack:

| Letter | Threat | Violated property | Example |
|---|---|---|---|
| **S** | Spoofing | Authentication | An attacker impersonates a legitimate user by stealing their JWT |
| **T** | Tampering | Integrity | An attacker modifies an event payload in transit to change a file's classification |
| **R** | Repudiation | Non-Repudiation | A user denies performing an action that was not logged |
| **I** | Information Disclosure | Confidentiality | A misconfigured query returns another tenant's data |
| **D** | Denial of Service | Availability | An attacker floods the scan API, preventing legitimate users from scanning |
| **E** | Elevation of Privilege | Authorisation | A low-privilege user accesses an administrative endpoint due to a missing permission check |

For every significant component in the system (each service, each API endpoint, each data store, each integration), apply STRIDE systematically.

---

## Assets Inventory

Before identifying threats, identify what is worth protecting:

| Asset | Sensitivity | Why it matters |
|---|---|---|
| File contents (scanned files) | Critical | Contains customer PII, financial data, health records — must never leave the customer's infrastructure |
| Extracted entity data | Critical | PII extracted from files — same sensitivity as file contents |
| Compliance gap reports | High | Reveals the customer's compliance posture — competitive intelligence |
| Authentication credentials (JWTs, service account keys) | Critical | Compromise enables impersonation and unauthorised access |
| Encryption keys | Critical | Compromise enables decryption of all data at rest |
| Audit logs | High | Tampered audit logs undermine Non-Repudiation |
| Configuration and secrets | High | Database passwords, API keys — enable further compromise |
| Service-to-service credentials | High | mTLS certificates — compromise enables MITM within the cluster |

---

## STRIDE Threat Identification Process

For each trust boundary in the system (identified from the System Context and Container Diagrams):

1. List every data flow crossing the boundary
2. For each data flow, systematically apply all six STRIDE categories
3. For each identified threat, assess:
   - **Likelihood:** Low / Medium / High — how likely is this to be exploited?
   - **Impact:** Low / Medium / High / Critical — what is the consequence if exploited?
   - **Risk score:** Likelihood × Impact (3×3 matrix → 9-point scale)
4. For each threat with risk score ≥ Medium × Medium, define a mitigation

---

## STRIDE Application Example

**Component:** Classification Service API — `PATCH /v1/data-assets/{id}/classification`

| STRIDE | Threat | Likelihood | Impact | Risk | Mitigation |
|---|---|---|---|---|---|
| **S** | Attacker forges a JWT to classify assets as a different user | Medium | High | High | JWT signed with RS256; validated on every request; short expiry (1 hour) |
| **T** | Attacker intercepts the PATCH request and changes the classification level | Low | High | Medium | mTLS enforced by Linkerd between all services; TLS on ingress |
| **R** | A user denies classifying a file as Restricted | Medium | High | High | All classification actions written to append-only audit log with user identity and timestamp |
| **I** | A bug in the handler returns another tenant's asset | Low | Critical | High | Physical tenant isolation — separate deployment; request never routes to another tenant's service |
| **D** | Attacker sends 10,000 PATCH requests to exhaust the service | Medium | Medium | Medium | Rate limiting at API Gateway; per-user rate limits on write endpoints |
| **E** | A read-only user sends a PATCH request and it succeeds | Low | High | Medium | ABAC policy check on every write endpoint; enforced at handler middleware |

---

## Attack Trees

For the highest-risk threats (Critical or High × High), produce an Attack Tree — a structured breakdown of how an attacker could achieve the threat:

```
Goal: Access another tenant's file data (Information Disclosure — Critical)
│
├── Path 1: Compromise a JWT token
│   ├── Steal a JWT from client storage (XSS attack on the frontend)
│   ├── Intercept a JWT in transit (TLS downgrade attack)
│   └── Forge a JWT (weak signing key or algorithm confusion)
│
├── Path 2: Exploit a multi-tenancy bug
│   ├── Missing tenant context check in a query handler
│   ├── Shared database connection pool returning another tenant's connection
│   └── Event routing misconfiguration sending one tenant's events to another
│
└── Path 3: Compromise the infrastructure
    ├── Access to another tenant's Kubernetes namespace
    ├── Compromise of a shared control plane component
    └── Access to backup storage containing tenant data
```

Each leaf node is a specific attack. Each leaf node needs a specific mitigation or acceptance. The tree reveals which paths have the fewest defences and therefore which require the most attention.

---

## Threat Register Output

| ID | Component | STRIDE | Threat description | Likelihood | Impact | Risk | Mitigation | Status |
|---|---|---|---|---|---|---|---|---|
| THR-001 | Classification API | S | JWT forgery | Medium | High | High | RS256, short expiry, server-side revocation | Mitigated |
| THR-002 | Multi-tenancy | I | Cross-tenant data leak via query bug | Low | Critical | High | Physical isolation; no shared DB | Mitigated |
| ... | | | | | | | | |

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| All trust boundaries covered | STRIDE applied at every trust boundary from the Container Diagram | Only the external boundary analysed; internal boundaries skipped |
| Assets inventoried | All significant assets documented with sensitivity level | Threat model with no asset inventory |
| Attack Trees for critical threats | Every Critical or High×High threat has an Attack Tree | Critical threats documented as a single line with no decomposition |
| Mitigations testable | Every mitigation references a test that will verify it (security test, pen test, compliance check) | Mitigations with no verification plan |
| Residual risk acknowledged | Accepted risks are explicitly documented as accepted, with justification | Risks silently dropped from the register |

---

## Output Format

```markdown
---
artifact: threat-model
product: [product name]
version: 1.0.0
phase: design
created: [date]
owner: security-architect
---

# Threat Model: [Product Name]

## Assets Inventory
| Asset | Sensitivity | Description |
|---|---|---|

## Trust Boundaries
[List all trust boundaries from the Container Diagram]

## Threat Register
| ID | Component | STRIDE | Threat | Likelihood | Impact | Risk | Mitigation | Status |
|---|---|---|---|---|---|---|---|---|

## Attack Trees
[One tree per Critical / High×High threat]

## Accepted Risks
| Threat ID | Reason accepted | Review date |
|---|---|---|

## Mitigation Verification Plan
| Threat ID | Mitigation | Verification method | Test artifact |
|---|---|---|---|
```
