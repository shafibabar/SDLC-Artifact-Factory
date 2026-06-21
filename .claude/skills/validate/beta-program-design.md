# Skill: validate/beta-program-design

## Purpose
Produce the Beta Program Design — the specification of how the product will be made available to a limited set of early adopters before general availability. Defines selection criteria, onboarding, monitoring, success metrics, and graduation criteria for GA.

## Inputs
- `artifacts/strategy/gtm.md` (target segment)
- `artifacts/ideate/personas/`
- `artifacts/strategy/north-star.md` (North Star Metric — beta validates it)
- `artifacts/validate/uat-plan.md` (UAT participants may become beta users)

## Output
**File:** `artifacts/validate/beta-program.md`
**Registers in manifest:** yes

## Beta Program Rules (enforced)
- Beta is not open access. Every beta participant is individually onboarded.
- Beta users have a direct feedback channel (not just a generic form).
- Beta usage is monitored: each beta tenant has observability, and issues are triaged within 24 hours.
- Beta graduation criteria are defined before the program opens — not after.
- Data sovereignty commitments apply to beta users with the same strength as GA users.

## Artifact Template

```markdown
# Beta Program Design
**Product:** {product_name}
**Phase:** Validate
**Artifact:** Beta Program Design
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Beta Program Overview

**Purpose:** Validate product-market fit with a curated set of early adopters before GA. Collect product feedback, identify integration edge cases, and validate the North Star Metric hypothesis with real usage data.

**Beta window:** {start date} → {end date} (target: 8 weeks)
**Beta tenant limit:** 5–10 organisations (manageable for high-touch support)
**Beta tier:** Free during beta; converts to Paid on GA

---

## Beta Participant Selection Criteria

**Ideal beta participant:**
- Matches the primary persona (Compliance Officer with audit deadline pressure)
- Has active compliance obligations (GDPR or SOC 2 in scope)
- Willing to provide structured feedback (1-hour interview at week 2 and week 6)
- Has at least one Google Drive or S3 bucket to connect
- Not a competitor

**Disqualified:**
- Competitors
- Participants who will not provide feedback
- Organisations requiring HIPAA compliance (not in MVP scope)

---

## Beta Onboarding Process

| Step | Responsible | Duration | Deliverable |
|------|-------------|---------|------------|
| 1. Application review | PM | 1 day | Acceptance email or decline |
| 2. Beta agreement signed | Legal + Participant | 3 days | Signed NDA + beta terms |
| 3. Tenant provisioned | Platform Engineering | 30 minutes | Tenant ID + credentials |
| 4. Onboarding call | PM + Tech Lead | 60 minutes | Connected storage location + first scan |
| 5. Slack channel created | PM | 5 minutes | Dedicated #{org-name}-beta channel |
| 6. Week 1 check-in | PM | 30 minutes | Initial feedback captured |

---

## Beta Monitoring

Every beta tenant is monitored at elevated frequency:
- Errors in {tenant_id} namespace: Slack alert within 15 minutes (vs 1 hour for production)
- DLQ messages for beta tenants: triaged within 4 hours
- Beta-specific Grafana dashboard showing: scans run, entities extracted, findings generated per tenant

PM reviews beta usage weekly:
- Are beta users returning? (session frequency)
- Are they completing scans? (scan completion rate)
- Are they taking action on findings? (finding resolution rate)

---

## Success Metrics for Beta

These metrics determine whether the product is ready for GA:

| Metric | Target | Measurement |
|--------|--------|------------|
| Beta tenant retention (week 6) | ≥ 70% still active | Weekly active tenants / total beta tenants |
| North Star Metric score | {NSM target value} | From NSM definition in north-star.md |
| Scan completion rate | ≥ 90% of initiated scans complete | scan_jobs_completed / scan_jobs_initiated |
| P1/P0 bugs found | 0 at GA readiness | Bug tracker |
| NPS (beta participants) | ≥ 30 | Post-week-6 survey |

---

## Graduation Criteria (Beta → GA)

All of the following must be satisfied before GA announcement:

- [ ] All beta success metrics met
- [ ] 0 open P1 or P0 bugs from beta feedback
- [ ] Data sovereignty validated (no beta tenant data observed in product logs or metrics)
- [ ] Compliance gate passed (security-gate + compliance-gate hooks)
- [ ] SLOs met for all beta tenants for 2 consecutive weeks
- [ ] Legal: beta agreements converted to GA agreements (or new GA terms agreed)
- [ ] Pricing model confirmed; invoicing process ready
- [ ] GA announcement drafted and reviewed

---

## Beta Feedback Channels

| Channel | Purpose | Reviewed by |
|---------|---------|------------|
| Dedicated Slack channel per tenant | Day-to-day questions and issues | PM + Tech Lead (daily) |
| Week 2 video interview | Deep feedback on first impressions | PM (facilitator) |
| Week 6 video interview | Satisfaction + GA readiness | PM + Product |
| In-product feedback widget | Feature requests, bug reports | PM (weekly) |
```

## Quality Checks
- [ ] Participant selection criteria are specific (not "interested customers")
- [ ] Beta tenant limit is set (not open access)
- [ ] Onboarding process has named responsible parties and durations
- [ ] Success metrics are numeric with measurement methods
- [ ] Graduation criteria are checkboxes (binary, not subjective)
- [ ] Data sovereignty explicitly verified in graduation criteria
