# Worked Example — UAT Plan for Release 1

Data Estate Mapping and Compliance Intelligence, including the
exploratory-session component. Self-contained — loadable without reading
`SKILL.md` first.

---

```markdown
---
name: uat-plan-release-1
product: Data Estate Mapping and Compliance Intelligence
release-slice: Release 1 (MVP — Google Drive connect, scan, classify, gap report)
version: 1.0.0
phase: customer-validation
created: 2026-07-20
owner: requirements-analyst
---

# UAT Plan — Release 1

## Scope Traceability
| Epic | Must Have Story | AC Ref | UAT Scenario |
|---|---|---|---|
| Data Source Connection | US-001 Connect Google Drive via OAuth | AC-US-001 | UAT-001 |
| Sensitivity Classification | US-005 Trigger scan, classify by sensitivity level | AC-US-005 | UAT-002, UAT-003 |
| Compliance Reporting | US-009 View compliance gap report | AC-US-009 | UAT-004 |

## Participants
- Executor: Maya Chen (Compliance Officer, design partner — Northwind Compliance Co.)
- Facilitator: requirements-analyst
- Sign-off: Shafi + Maya Chen

## Environment
- Canary tenant: tenant-northwind
- Chart version / digest: estate-scanner v0.4.1 @ sha256:9c1f...
- Feature flags: extractor.v2.enabled=false (not in scope this slice)

## Entry Criteria Status
- [x] Quality gates passed (CI run #482)
- [x] Deployed via canary-deployment, stage 3 (50%) held clean 30 min
- [x] Executors briefed 2026-07-21
- [x] Exploratory charters drafted (2 — see below)

## Exit Criteria
- Pass rate threshold: 100% of Must Have scenarios (4 of 4)
- Zero open Critical/High defects
- Exploratory charters run and debriefed: 2 of 2

## Schedule
Day 0: 2026-07-21 · Day 1–3: 2026-07-22 to 2026-07-24 (scripted scenarios + exploratory sessions, same executor, same environment) · Day 4: 2026-07-25 · Day 5 sign-off: 2026-07-26

## Exploratory Sessions

### Session 1
**Charter:** Explore the sensitivity-classification workflow, with a mix of scanned low-quality PDFs and edge-case file types (password-protected, corrupted, zero-byte), to discover whether misclassification or crashes occur outside the happy-path documents already covered by UAT-002/UAT-003.
**Time-box:** 60 min · **Tester:** Maya Chen · **Environment:** tenant-northwind (same as scripted scenarios)
**Notes:** Password-protected PDF correctly flagged as "unreadable, needs manual review" rather than silently skipped or misclassified as Public. Zero-byte file correctly excluded from scan count. Corrupted PDF triggered a retry loop visible in logs but not surfaced to the user — logged as a finding.
**Bugs/Issues found:** FB-003 (Medium) — corrupted file retry loop has no user-visible status; user cannot tell if the scan is stuck or working.
**New charters surfaced:** Explore scan behavior when a Google Drive folder's sharing permissions change mid-scan.
**Debrief:** Classification logic for unreadable/corrupted files is fundamentally sound but needs better user-facing status during silent retries.

### Session 2
**Charter:** Explore the compliance gap report, with a workspace containing zero gaps and a workspace containing 500+ gaps, to discover whether the report's empty state and high-volume rendering both hold up outside the mid-size example already covered by UAT-004.
**Time-box:** 45 min · **Tester:** Maya Chen · **Environment:** tenant-northwind
**Notes:** Empty state renders correctly with a clear "no gaps found" message. 500+ gap report paginates correctly; export-to-PDF took 40 seconds — noticeably slower than the small-report case, no progress indicator shown.
**Bugs/Issues found:** FB-004 (Low) — no loading/progress indicator during large-report PDF export.
**New charters surfaced:** None.
**Debrief:** Report scales correctly at both ends; the only finding is a UX polish item at the high end.
```

---

The exploratory sessions above feed `feedback-template` exactly as a
scripted scenario's failure would (FB-003, FB-004) — see
`acceptance-sign-off`'s Sign-Off Criteria Checklist for how these are
weighed at the go/no-go decision.
