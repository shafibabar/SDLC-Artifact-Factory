---
name: compliance-verification
description: >
  Verify compliance controls through automation — turn each designed control into
  an automated test that produces a signed, digest-pinned attestation (not a flat
  JSON blob), add an explicit control-gate stage that signature-verifies the required
  attestation set before promotion, and wire Continuous Control Monitoring onto the
  observability stack so a control that stops holding in production between deploys
  raises an alert and a fresh attestation. Covers the control→test→attestation→gate
  chain, attestation vs. isolated evidence, the immutable evidence ledger, the
  point-in-time vs. continuous distinction, and the completeness criterion for
  verification. Used during Quality and continuously in production for SOC 2 Type II
  operating effectiveness (also GDPR, ISO 27001).
version: 2.0.0
phase: quality
owner: security-engineer
created: 2026-06-25
tags: [quality, compliance, soc2, attestation, control-gate, continuous-control-monitoring, evidence, audit, go]
related: [compliance-design, security-implementation, security-architecture, threat-modeling, privacy-design, glossary-management, methodology-review]
---

# Compliance Verification

## Purpose

Compliance verification confirms that the controls designed in `compliance-design` actually operate — and keep operating. It produces the evidence auditors, customers, and regulators inspect. The organizing frame is **Compliance-as-Code**: every control is codified as an automated test, every test emits machine-collected evidence, and the audit trail assembles itself as a byproduct of delivery rather than being reconstructed from screenshots weeks before an assessment.

Verification is not a one-time activity. A CI test that passed last Tuesday says nothing about whether encryption-at-rest is still enabled today. SOC 2 Type II assesses **operating effectiveness over a period** — so verification runs both at deploy (point-in-time gate) and continuously in production (drift monitoring).

---

## The control → test → attestation → gate chain

Every in-scope control travels the same four-link chain. A verification effort is complete only when every link exists for every control.

```
Control (from compliance-design)
   │  what must be true, and its enforcement mode (gate / monitor / record)
   ▼
Automated test          ← Go integration test, IaC policy check, or Prometheus rule
   │  executes the control; produces a PASS/FAIL result
   ▼
Attestation             ← signed, digest-pinned, composable statement of the result
   │  appended to the immutable evidence ledger
   ▼
Control gate            ← explicit pipeline stage: verifies the required attestation
                          set for this commit, then permits or blocks promotion
```

The four repeating questions per control (the Automated Governance decomposition): *what is the control, what evidence proves it, where is that evidence stored immutably, and what gate enforces it.* The old Control Coverage Matrix answered the first three; the attestation and the explicit gate answer the fourth.

---

## Attestation vs. flat isolated evidence

The single most important upgrade over a bag of test-result JSON files is the **attestation** as the evidence primitive.

| | Flat evidence record | Attestation |
|---|---|---|
| What it is | A test-pass boolean plus some metadata | A signed statement: "control X held for artifact Y (pinned by digest) at time T by process P" |
| Provenance | Bolted on (fields anyone can write) | Intrinsic — subject digest, producer identity, signature |
| Composability | Isolated files an auditor reads one by one | Chains across build/test/scan/deploy stages into one per-release governance narrative |
| Trust | "Trust this JSON" | Signature-verifiable against a known signing identity |

An attestation pins its **subject by content digest** (image digest, commit SHA) — that pin is what lets attestations from different stages compose into one verifiable chain for a single release. Adopt the in-toto / SLSA attestation shape rather than a bespoke JSON. Full format, fields, composition, ledger design, and Go/CI emission: **`references/attestation-and-evidence.md`**.

---

## The explicit control-gate stage

Do not scatter `assert` / `--exit-code 1` across ad-hoc jobs. Add one dedicated **control-gate** pipeline stage that:

1. Queries the evidence ledger for the required attestation set for *this* commit/digest.
2. Verifies each attestation's signature against the expected signing identity.
3. Confirms every `gate`-mode control has a PASS attestation (and every accepted-risk exception is signed).
4. Permits or blocks promotion — a single auditable decision point whose own verdict is itself attested.

A control gate consumes evidence; it does not re-run checks. That is what distinguishes it from a generic "CI gate." Full stage design, GitHub Actions wiring, and the missing/invalid-attestation blocking behavior: **`references/control-gate-and-ccm.md`**.

---

## Continuous Control Monitoring (past the deploy boundary)

Point-in-time verification proves the control passed *at deploy*. **Continuous Control Monitoring (CCM)** proves it *remains* satisfied in production. Express a subset of controls as SLIs over the OpenTelemetry / Prometheus signals already collected — encryption-at-rest still on, mTLS coverage complete, no untenanted queries, retention windows honored. Drift raises an alert **and** generates a fresh timestamped attestation, so the ledger records the operating-effectiveness story continuously.

| | Point-in-time (CI gate) | Continuous Control Monitoring |
|---|---|---|
| When | Every deploy | Continuously in production |
| Answers | "Did the control pass at deploy?" | "Does the control still hold right now?" |
| Mechanism | Go test / IaC policy check | Prometheus rule over OTel signals |
| On failure | Blocks promotion | Alert + fresh drift attestation |
| SOC 2 Type II | Necessary, not sufficient | The operating-effectiveness dimension |

CCM is why SOC 2 Type II needs more than a point-in-time check. Prometheus rules, the drift→alert→attestation loop, and the control-as-SLI mapping: **`references/control-gate-and-ccm.md`**.

---

## The completeness criterion

Coverage must be *demonstrated*, not asserted. Borrowing threat modeling's fourth question ("did we do a good job?"), verification is complete only when all three hold:

1. **The control set still matches the built system** — no new endpoint, store, or data flow exists without a control (the analog of "the DFD still matches the system").
2. **Every in-scope control has an automated test and an attestation** — STRIDE-style, applied to *every* element, not just the interesting ones. No control is verified by documentation alone.
3. **Every control has a PASS attestation or a signed, dated accepted-risk exception** — every filled cell has a mitigation or an explicit risk acceptance.

This checklist is what separates a real verification from a spot check. Worked example and the full report template: **`references/verification-report-template.md`**.

---

## Verification modes (what feeds the chain)

| Mode | Cadence | Produces |
|---|---|---|
| Automated compliance tests (Go integration) | Every CI run | Control test attestations (CC6.1 auth, CC6.3 tenant isolation, GDPR Art.30 audit completeness) |
| Infrastructure compliance scan (OPA over OpenTofu plan) | Every deploy | IaC control attestations (encryption-at-rest, no public exposure) |
| Vulnerability scan (`govulncheck`, `trivy`, dependency audit) | Weekly + on dependency update | Scan attestations; HIGH/CRITICAL blocks |
| Penetration test (third-party) | Annually + after major change | Signed pentest report; cross-tenant access is the top scope item |
| Continuous Control Monitoring (Prometheus over OTel) | Continuous | Drift attestations |

Test patterns (the Go tests behind each control) and pentest scope live in **`references/attestation-and-evidence.md`** and **`references/verification-report-template.md`**.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Control coverage | Every control from `compliance-design` has a test **and** an attestation | Controls verified only by documentation |
| Attestation, not flat JSON | Evidence is digest-pinned, signed, composable | Isolated test-result JSON with no provenance |
| Explicit control gate | One gate stage verifies the required attestation set before promotion | Scattered `--exit-code 1` with no single decision point |
| Continuous monitoring | `gate`/`monitor` controls have Prometheus rules; drift alerts + attests | Verification is point-in-time only |
| Immutable ledger | Append-only store with object lock; FAIL attestations retained | Mutable storage; failures deleted |
| Completeness demonstrated | The three-part criterion is checked and recorded | Coverage asserted, not demonstrated |
| Evidence assembly | Audit package assembles by query in < 1 day | Weeks of manual collection |

---

## Anti-Patterns

- **Flat evidence with no provenance.** A JSON file that says PASS but does not pin the artifact digest, signing identity, and producer is not an attestation — an auditor cannot tell which build and environment it verified. See `references/attestation-and-evidence.md`.
- **Implicit gate.** `assert` / `--exit-code 1` scattered across jobs with no single stage that verifies the required attestation set. Coverage gaps and skipped checks become invisible.
- **Point-in-time only.** Verifying at deploy and never again. SOC 2 Type II assesses whether the control *operated over the period* — CCM is not optional for it.
- **Verification without design linkage.** Testing whatever was convenient, with no traceability to a control ID. Every test carries its control ID so gaps are visible.
- **Passing by exclusion.** Quietly dropping a failing endpoint from the registry so the suite goes green. The registry is generated from `openapi.yaml`; exclusions are an explicit, reviewed allowlist.
- **Confirming existence to the wrong tenant.** Asserting 403 (not 404) on cross-tenant access tells tenant B that tenant A's resource exists. Cross-tenant requests must be indistinguishable from requests for nonexistent resources.
- **Scan-and-shelve.** Running scans on schedule but never gating on results. A report nobody reads is not a control.
- **Treating FAIL attestations as embarrassing.** Deleting failed evidence. A FAIL → remediation → passing re-run chain in the append-only ledger is exactly the operating-effectiveness story a Type II auditor wants.

---

## References

- `references/attestation-and-evidence.md` — the attestation format (what it pins: artifact digest, control id, signing identity, timestamp), how attestations compose into a per-release evidence chain, the immutable append-only ledger, and Go/CI emission (SLSA / in-toto-style) with signature verification.
- `references/control-gate-and-ccm.md` — the explicit control-gate pipeline stage (consumes and verifies the required attestation set, blocks on missing/invalid); Continuous Control Monitoring wired onto Prometheus / OpenTelemetry (a control as a monitored SLI; drift → alert + fresh attestation); the point-in-time vs. continuous distinction and why SOC 2 Type II needs continuous.
- `references/verification-report-template.md` — the compliance verification report format, the completeness checklist adapted for control coverage, and a worked example of one SOC 2 control (CC6.3 tenant isolation) end to end.
