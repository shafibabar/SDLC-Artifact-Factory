# Skill: core/risk-register

## Purpose
Produce and maintain the Risk Register — the living document that tracks strategic, operational, compliance, and technical risks to the product. Each risk has an owner, a likelihood/impact rating, and a mitigation plan. Used by stakeholders to make informed decisions about risk tolerance.

## Inputs
- `artifacts/design/security/threat-model.md` → technical/security risks
- `artifacts/design/security/compliance-design.md` → compliance risks
- `artifacts/strategy/okrs.md` → strategic risks
- `sdlc-config.json` → deployment targets, compliance frameworks
- **Argument optional:** `--update` to add new risk entries

## Output
**File:** `artifacts/core/risk-register.md`
**Registers in manifest:** yes

## Risk Categories
| Category | Examples |
|----------|---------|
| **Strategic** | Market timing, competitor action, regulatory change |
| **Operational** | Key-person dependency, vendor lock-in, capacity |
| **Compliance** | Framework audit failure, regulatory fine, data breach notification |
| **Technical** | Architecture debt, dependency vulnerability, scaling limits |
| **Security** | Threat model residual risks (drawn from threat-model.md) |

## Risk Rating
- **Likelihood**: 1 (Rare) → 5 (Almost Certain)
- **Impact**: 1 (Negligible) → 5 (Critical)
- **Risk Score**: Likelihood × Impact
- **Threshold**: Score ≥ 15 = HIGH; 8–14 = MEDIUM; 1–7 = LOW

## Artifact Template

```markdown
# Risk Register
**Product:** {product_name}
**Phase:** Core (living document — updated through all phases)
**Artifact:** Risk Register
**Version:** {N} (increment on each update)
**Date:** {date}
**Owner:** {product owner}
**Status:** Active

---

## Register

| ID | Category | Risk | Likelihood | Impact | Score | Level | Mitigation | Owner | Status |
|----|---------|------|-----------|--------|-------|-------|-----------|-------|--------|
| R-01 | Compliance | GDPR audit failure before Right to Erasure is implemented | 3 | 4 | 12 | MEDIUM | Prioritise erasure workflow in Implement phase; track in compliance-design.md | PM | OPEN |
| R-02 | Technical | Worker Node connectivity loss causes tenant scan failures without visibility | 3 | 3 | 9 | MEDIUM | Heartbeat monitoring + alert; CE-03 chaos test verifies detection | Tech Lead | MITIGATED |
| R-03 | Strategic | Competitor releases comparable product before MVP | 2 | 4 | 8 | MEDIUM | Accelerate scan coverage feature (Q2 OKR); GTM focus on compliance-first positioning | PM | OPEN |
| R-04 | Security | Cross-tenant data access via misconfigured RLS policy | 2 | 5 | 10 | MEDIUM | RLS enabled + ABAC + tenant isolation E2E tests (ST-ISO-01 through ST-ISO-05) | Tech Lead | MITIGATED |
| R-05 | Operational | Single platform engineer creates key-person dependency | 3 | 3 | 9 | MEDIUM | Infrastructure-as-Code reduces dependency; runbooks enable others to operate | PM | OPEN |
| R-06 | Compliance | SOC 2 Type II audit requires 6+ months of evidence collection | 4 | 3 | 12 | MEDIUM | Audit logging from day 1; compliance-as-code tests generate evidence automatically | PM | OPEN |

---

## HIGH Risks (Score ≥ 15)
{None currently — escalate immediately if any risk reaches this threshold}

---

## Review Schedule
- Weekly: PM reviews open MEDIUM and HIGH risks
- Monthly: Risk register reviewed with stakeholders
- Phase advance: New risks identified from phase review surfaced here

---

## Closed Risks

| ID | Risk | Closed date | Resolution |
|----|------|-------------|-----------|
| — | — | — | — |
```

## Quality Checks
- [ ] Every risk has a numeric likelihood, impact, and score (not just "high"/"medium")
- [ ] Every risk has a named owner
- [ ] Security risks are drawn from threat-model.md residual risks (not invented)
- [ ] Compliance risks reference the compliance-design.md gaps
- [ ] Review schedule is specified
- [ ] Closed risks table is present (even if empty)
