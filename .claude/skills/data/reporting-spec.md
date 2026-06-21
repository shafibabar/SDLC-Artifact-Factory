# Skill: data/reporting-spec

## Purpose
Produce a Reporting Specification for a named report — the content, format, data sources, generation mechanism, and distribution method. Reports are the structured, point-in-time outputs that stakeholders use for compliance evidence, board packs, and audit submissions.

## Inputs
- `artifacts/data/analytics-requirements.md`
- `artifacts/ideate/personas/`
- `artifacts/design/data/data-classification.md`
- **Argument required:** report name (e.g. `compliance-posture-summary`, `audit-evidence-export`, `scan-coverage-report`)

## Output
**File:** `artifacts/data/reports/{report-name}.md`
**Registers in manifest:** yes

## Reporting Rules (enforced)
- Every report has an explicit audience (persona) and a stated purpose.
- Export formats are specified: PDF, XLSX, JSON, CSV — not "all formats".
- Reports containing C4 data require access control verification at generation time.
- Scheduled reports document their distribution list and consent basis.
- Reports are reproducible: the same parameters always produce the same output.

## Artifact Template

```markdown
# Reporting Specification: {report-name}

**Product:** {product_name}
**Phase:** Data
**Artifact:** Reporting Specification
**Report name:** {display name}
**Version:** 1.0
**Date:** {date}
**Status:** Approved

---

## Report: Compliance Posture Summary

**Audience:** Compliance Officer, Tenant Administrator, Board / Leadership
**Purpose:** Provide a point-in-time view of the organisation's compliance posture across all active frameworks. Used for: board reporting, internal audits, vendor due diligence.
**Classification:** C3 (Confidential — contains compliance posture of customer organisation)

---

## Report Content

### Section 1: Executive Summary
- Compliance posture score per framework (current + delta vs. prior period)
- Total open findings count by severity
- Count of overdue findings
- Key actions recommended (top 3 by risk)

### Section 2: Framework Scorecard
Per active framework (one table per framework):
| Rule category | Rules evaluated | Violations | Pass rate |
|--------------|----------------|-----------|---------|
| Data retention | 12 | 2 | 83% |
| Access control | 8 | 0 | 100% |
| Encryption | 6 | 1 | 83% |

### Section 3: Open Findings Register
Full list of open findings (sorted by severity, then age):
| Finding ID | Rule | Severity | Entity type | Location | Age | Status |
|-----------|------|---------|------------|---------|-----|--------|
| F-00142 | GDPR Art.5(1)(e) | CRITICAL | PII_NATIONAL_ID | HR Drive | 5d | Open |

**Note:** Entity values are NOT included in this report. Only entity types and locations.

### Section 4: Trend Analysis
- 90-day posture score trend chart (embedded image in PDF; data table in XLSX)
- Top 5 most violated rules over the period

### Section 5: Exceptions Register
All active exceptions: justification, approver, expiry date.

---

## Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `framework` | string | No | All | Filter to specific compliance framework |
| `period_start` | date | Yes | — | Start of reporting period |
| `period_end` | date | Yes | — | End of reporting period (defaults to today) |
| `include_resolved` | boolean | No | false | Include resolved findings in the register |

---

## Export Formats

| Format | Use case | Notes |
|--------|---------|-------|
| PDF | Board packs, audit submissions | Rendered via headless browser (puppeteer-core or WeasyPrint) |
| XLSX | Internal analysis, further processing | One worksheet per section |
| JSON | API-driven integrations, GRC tool import | Structured; same schema as dashboard read model |

Format requested via API: `GET /api/v1/reports/compliance-posture-summary?format=pdf&period_start=2026-01-01`

---

## Access Control

- Minimum role required to generate: `compliance_officer`
- Generation is logged in the audit trail: `{user_id} generated compliance-posture-summary report at {timestamp} for period {period}`
- Report content is scoped to authenticated user's tenant — no cross-tenant data

---

## Data Sources

| Data | Source | Query approach |
|------|--------|---------------|
| Posture scores | `compliance_posture_daily` | Pre-aggregated; point-in-time slice |
| Open findings | `findings` table | Live query with date filter |
| Exceptions | `exceptions` table | Live query |
| Entity type counts | `entity_type_summary_daily` | Pre-aggregated |

---

## Generation SLA

| Trigger | Expected generation time | Timeout |
|---------|------------------------|---------|
| On-demand (user request) | < 30 seconds | 120 seconds |
| Scheduled (monthly board pack) | < 5 minutes | 15 minutes |

Long-running reports (> 5 seconds): generate asynchronously; notify user via in-app notification or email when ready.

---

## Scheduled Distribution

| Schedule | Recipients | Consent basis |
|----------|-----------|--------------|
| Monthly (1st of month) | tenant_admin email | Configured at tenant setup; opt-out available |
| Quarterly | External auditors (if configured) | Explicit consent per auditor in tenant settings |
```

## Quality Checks
- [ ] Audience and purpose are explicit — not "for all users"
- [ ] Entity values are explicitly excluded from report content (only types and locations)
- [ ] Export formats are specific (not "all formats")
- [ ] Access control is defined with minimum role
- [ ] Audit trail logging is specified for report generation
- [ ] Generation SLA distinguishes sync vs async generation
- [ ] Scheduled distribution includes consent basis
