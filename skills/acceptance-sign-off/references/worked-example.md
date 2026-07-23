# Worked Example — Conditional Sign-Off, Release 1

Self-contained — loadable without reading `SKILL.md` first.

---

```markdown
---
name: acceptance-sign-off-release-1
product: Data Estate Mapping and Compliance Intelligence
release-slice: Release 1 (MVP — Google Drive connect, scan, classify, gap report)
version: 1.0.0
phase: customer-validation
created: 2026-07-26
owner: requirements-analyst
---

# Acceptance Sign-Off — Release 1

## Sign-Off Criteria Checklist
- [x] UAT-001 through UAT-004 all recorded (uat-plan)
- [x] Pass-rate threshold met: 4 of 4 Must Have scenarios passed
- [x] Zero open Critical defects
- [x] Zero open High defects
- [ ] Two Medium-severity items open (FB-001/FB-002 — gap report PDF export
      hard to find; pattern confirmed across 2 of 3 design partners)
- [x] All feedback triaged (feedback-template)
- [x] Beta stage: closed beta graduation criteria met
- [x] Exploratory sessions run and debriefed: 2 of 2 (uat-plan) — surfaced
      FB-003 (corrupted-file retry loop, Medium) and FB-004 (large-report
      export progress indicator, Low), both triaged into the checklist below

## Sign-Off Authority
- Shafi (product owner)
- Maya Chen, Compliance Officer, Northwind Compliance Co. (design-partner
  representative)

## Decision: CONDITIONAL SIGN-OFF

**Conditions:**
- FB-001/FB-002 (gap report PDF export placement, Medium, confirmed pattern) —
  remediation plan: move export control above the fold in the report header —
  owner: ux-architect — target date: 2026-08-05
- FB-003 (corrupted-file retry loop has no user-visible status, Medium, from
  exploratory session 1) — remediation plan: surface a "retrying, please
  wait" status during silent retries — owner: backend-engineer — target
  date: 2026-08-05
- FB-004 (no progress indicator on large-report PDF export, Low, from
  exploratory session 2) — remediation plan: add a progress indicator —
  owner: frontend-engineer — target date: 2026-08-12 (Low severity, does
  not gate this release's rollout pace)

## Rollout Action
canary-deployment widens to 100% across the beta cohort's tenants immediately —
the open items do not affect the Must Have outcome (gap report is exportable,
just not conveniently placed; corrupted files are correctly excluded from
classification, just without clear retry status). feature-flag-design release
flag `gap-report.v1.enabled` scope widens to the full fleet on the same
schedule as the canary; remediation is tracked independently and does not
hold the release.

## Follow-Up
Re-verification of the export placement fix and the retry-status fix
scheduled for 2026-08-05 via a targeted UAT-004 re-run and a repeat of
exploratory session 1's charter, both with the same design-partner cohort.
The progress-indicator fix (FB-004) is re-verified at its own target date
via a repeat of exploratory session 2's charter.
```
