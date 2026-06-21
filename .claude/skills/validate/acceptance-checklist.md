# Skill: validate/acceptance-checklist

## Purpose
Produce the Acceptance Criteria Checklist — the master list of all user story acceptance criteria that must be verified before the product is released. This is the structured handoff between UAT and release decision. Every acceptance criterion is either PASS, FAIL, or DEFERRED with a justification.

## Inputs
- `artifacts/ideate/backlog/stories/` (all user stories with acceptance criteria)
- `artifacts/validate/uat-plan.md`
- `artifacts/validate/scenarios/` (UAT scenario results)
- `artifacts/quality/e2e/` (E2E tests that automate some acceptance criteria)

## Output
**File:** `artifacts/validate/acceptance-checklist.md`
**Registers in manifest:** yes

## Checklist Rules (enforced)
- Every acceptance criterion from every DONE story appears in this checklist.
- Each criterion is marked: PASS (verified) | FAIL (blocking) | DEFERRED (with PM decision and date).
- Criteria verified by automated E2E tests are marked AUTOMATED — no manual re-test needed.
- No release occurs while any criterion is FAIL.
- DEFERRED criteria require: justification, owner, and a target resolution date.

## Artifact Template

```markdown
# Acceptance Criteria Checklist
**Product:** {product_name}
**Phase:** Validate
**Artifact:** Acceptance Criteria Checklist
**Version:** 1.0
**Date:** {date}
**Status:** {IN PROGRESS | APPROVED | BLOCKED}
**Release decision:** APPROVED | BLOCKED | DEFERRED

---

## Summary

| Status | Count |
|--------|-------|
| PASS | {N} |
| AUTOMATED | {N} |
| FAIL | {N} |
| DEFERRED | {N} |
| PENDING | {N} |
| **Total** | **{N}** |

---

## Epic: Storage Location Management

### Story: US-001 — Register a storage location

| AC | Criterion | Verified by | Status | Notes |
|----|-----------|-------------|--------|-------|
| AC-001-1 | Given a valid Google Drive path and credential ref, when I register, then I receive a 201 response with the storage location ID | E2E (e2e/register-and-scan-storage-location.md) | AUTOMATED | ✓ CI passes |
| AC-001-2 | Given a duplicate storage path for the same tenant, when I register, then I receive 409 DUPLICATE_STORAGE_PATH | E2E (same scenario) | AUTOMATED | ✓ CI passes |
| AC-001-3 | Given an invalid credential ref format (no scheme), when I register, then I receive 422 INVALID_CREDENTIAL_REF | Unit test (handler) | AUTOMATED | ✓ CI passes |
| AC-001-4 | Given registration succeeds, when I view the storage location, then status is PENDING | UAT session S-01 | PASS | Verified with {participant}, {date} |

---

### Story: US-002 — Initiate a scan

| AC | Criterion | Verified by | Status | Notes |
|----|-----------|-------------|--------|-------|
| AC-002-1 | Given an ACTIVE storage location, when I initiate a scan, then scan begins within 5 seconds | E2E + UAT | PASS | |
| AC-002-2 | Given a SCANNING location, when I initiate another scan, then I receive 409 SCAN_IN_PROGRESS | E2E | AUTOMATED | |
| AC-002-3 | Given a scan completes, then compliance findings are visible within 10 minutes | UAT S-01 | PASS | Verified {date} — 6 minute actual |

---

## Epic: Compliance Monitoring

### Story: US-010 — View compliance posture

| AC | Criterion | Verified by | Status | Notes |
|----|-----------|-------------|--------|-------|
| AC-010-1 | As a Compliance Officer, I can see my GDPR posture score on the dashboard | UAT S-01 | PASS | All 3 participants found score without assistance |
| AC-010-2 | Score reflects findings in real-time (< 5 min lag) | Performance test | PASS | Avg 2.3 min in PT-01 |
| AC-010-3 | Posture score shows trend over 90 days | UAT S-01 | FAIL | Chart does not render when < 7 days of data — see bug #187 |

---

## FAIL Criteria (must resolve before release)

| AC | Criterion | Bug/ticket | Owner | Target date |
|----|-----------|-----------|-------|------------|
| AC-010-3 | 90-day trend chart fails when < 7 days data | #187 | Tech Lead | {date} |

---

## DEFERRED Criteria (release decision: acceptable for MVP)

| AC | Criterion | Justification | Owner | Target release |
|----|-----------|--------------|-------|---------------|
| AC-020-5 | Data portability export in XLSX format | GDPR Art.20 required but JSON export covers the obligation; XLSX is UX enhancement | PM | v1.1 |

**Deferred criteria require PM sign-off. PM signature:** {PM name}, {date}

---

## Release Recommendation

**Release condition:** All FAIL criteria resolved; no PENDING criteria remain.
**Current status:** {APPROVED TO RELEASE | BLOCKED — N FAIL criteria unresolved}
**Recommended release date:** {date, or "pending bug fixes"}
```

## Quality Checks
- [ ] Every acceptance criterion from every user story is listed
- [ ] AUTOMATED criteria reference the E2E or unit test that covers them
- [ ] FAIL criteria have a bug/ticket number and owner
- [ ] DEFERRED criteria have PM justification and sign-off
- [ ] Release recommendation is explicit (APPROVED or BLOCKED)
- [ ] Summary table shows counts by status
