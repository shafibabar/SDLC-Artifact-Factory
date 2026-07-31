# Report Specification Template

Reference for the `reporting-spec` skill. Holds the full report specification
artifact template, its sensitivity-handling rules at the export boundary, and a
complete worked example — a monthly compliance-gap report. Copy the template,
fill every field, and check it against the sensitivity rules before the report is
built. Grounded in this repo's stack (Go, PostgreSQL + `pgx`, per-tenant physical
isolation) and in the data-estate/compliance product.

---

## 1. The Template

```markdown
---
name: reporting-spec
product: [product name]
report: [report name]
version: [definition version, e.g. 1.0.0]
phase: data
created: [date]
owner: data-engineer
---

# Reporting Spec — [Report Name]

## Classification
- Kind: [operational | analytical]
- Report classification: [Public | Internal | Confidential | Restricted]
- Answers requirement: [analytics-requirements reference]

## Sections
| # | Section | Source (Read Model / mart) | Source grain | Section grain | Additivity | Stated takeaway (analytical) |
|---|---|---|---|---|---|---|

## Parameters
| Parameter | Type | Values / bounds | Source | Printed on output? |
|---|---|---|---|---|
| Tenant | tenant scope | current tenant | session context (never request) | yes |
| Date range | date range | fixed calendar bounds, half-open | request / scheduler | yes |

## Sourcing Notes
[Per-section grain declarations; any cross-period additivity decisions.
 Detail: references/report-parameters-and-sourcing.md]

## Output Formats
| Format | Audience | Rendering | Notes |
|---|---|---|---|

## Schedule and Delivery
- Trigger: [on-demand | scheduled | both]
- Cadence (cron + timezone): [e.g. 0 3 1 * * America/New_York]
- Delivery channel(s): [signed URL | email link | tenant bucket | event]
- Recipients: [validated within tenant]
- Failure handling: [retry/backoff; DLQ or failed state; alert]
[Detail: references/scheduling-and-delivery.md]

## Sensitivity Handling
| Rule | This report's decision |
|---|---|
| Raw Restricted content excluded | [how] |
| k-anonymity floor | [minimum group size; suppression rule] |
| CSV free-text exclusion | [confirm no document-content free-text columns] |
| Distribution control for Confidential+ | [access-controlled channel] |

## Definition Versioning
| Version | Date | Change |
|---|---|---|
```

---

## 2. Sensitivity Handling at the Export Boundary

A report leaving the system is the highest-risk moment for sensitive data — it
is no longer inside the access-controlled application and may travel to an inbox,
a laptop, or a printer. The rules below are inherited from `data-classification`
and re-checked explicitly at the export boundary.

| Rule | Mechanism |
|---|---|
| Reports carry references and metadata, not raw values | Sections cite `sensitivity_level`, counts, and IDs — never an extracted entity's raw text |
| Aggregate-only below a k-anonymity floor | Any breakdown cell below a defined minimum group size (e.g. 5) is suppressed or rolled up — a "gaps by department" cell of size 1 re-identifies an individual through aggregation math even with no name printed |
| Confidential+ content sets the report's own classification | A report referencing Restricted-asset counts is itself at least Confidential and is distributed per `data-classification`'s control mapping — access-controlled, not open email |
| CSV never carries free-text from document content | Only structured, classified metadata fields are exportable; raw extracted text is never a CSV column |

A report generator that queries a raw-content field (an `extracted_entities.raw_value`
that should not exist per `data-classification`'s storage constraints) is a defect
regardless of what the report claims to show. The underlying storage constraint
makes this largely self-enforcing, but the report spec is where it is explicitly
re-verified at the export boundary.

---

## 3. Worked Example — Monthly Compliance-Gap Report

```markdown
---
name: reporting-spec
product: Data Estate & Compliance Platform
report: monthly-compliance-gap-report
version: 1.0.0
phase: data
created: 2026-07-31
owner: data-engineer
---

# Reporting Spec — Monthly Compliance-Gap Report

## Classification
- Kind: analytical
- Report classification: Confidential (references Restricted-asset gap counts)
- Answers requirement: AR-014 "Monthly view of compliance-gap posture and trend
  for the tenant's compliance officer, suitable to circulate to leadership."

## Sections
| # | Section | Source (Read Model / mart) | Source grain | Section grain | Additivity | Stated takeaway |
|---|---|---|---|---|---|---|
| 1 | Gaps opened this period | compliance_gap_summary | 1 row per gap | 1 row per severity | additive (count of opened events) | "N new gaps opened, M% at high severity — up/down vs last month." |
| 2 | Gaps closed this period | compliance_gap_summary | 1 row per gap | 1 row per severity | additive (count of closed events) | "K gaps closed; net posture improved/worsened by (opened − closed)." |
| 3 | Open gaps at period end | daily_gap_snapshot | 1 row per gap per day | 1 row per framework, value at period-end | semi-additive (point-in-time balance — take period-end value, never sum across days) | "X gaps remain open at month-end, concentrated in framework F." |
| 4 | Classification coverage | estate_sensitivity_snapshot | 1 row per asset per day | 1 row, ratio at period-end | non-additive (recompute from classified/total, never average daily %) | "P% of assets classified; unclassified assets are the largest remaining audit exposure." |
| 5 | Trend (6 months) | monthly_gap_rollup | 1 row per month | 1 row per month, line chart | additive per-month counts | "Open-gap trend over 6 months — declining/rising." |

## Parameters
| Parameter | Type | Values / bounds | Source | Printed on output? |
|---|---|---|---|---|
| Tenant | tenant scope | current tenant | session context (never request) | yes |
| Date range | date range | previous calendar month, half-open (e.g. 2026-06-01 .. 2026-07-01) | scheduler resolves at trigger | yes |
| Framework | dimension filter | one of {SOC2, GDPR, ISO27001}, or "all in scope" | request / definition default | yes |
| Min group size | threshold | 5 (k-anonymity floor for §3 breakdown) | definition default | no |

## Sourcing Notes
- §3 open-gaps is a periodic-snapshot / semi-additive balance: read the value at
  the period-end boundary from daily_gap_snapshot; never sum open_gap_count
  across the month's days.
- §4 coverage is non-additive: carry classified_count and total_count and compute
  the ratio once at the section grain.
- All queries bind tenant_id from session context and parameters via pgx.
- Detail: references/report-parameters-and-sourcing.md

## Output Formats
| Format | Audience | Rendering | Notes |
|---|---|---|---|
| PDF | Compliance officer, leadership | server-side | Charts follow data-storytelling decluttering/emphasis; one takeaway per section; parameter block + definition-version footer on every page |
| CSV | Officer's internal tracking | server-side stream | §1–§3 gap detail only (structured metadata columns); no free-text document content |

## Schedule and Delivery
- Trigger: both — scheduled monthly snapshot and on-demand before an audit
- Cadence (cron + timezone): 0 3 1 * * America/New_York (reports the month just ended)
- Delivery channel(s): signed expiring URL (in-app) + email link to that URL
- Recipients: the tenant's compliance-officer role members (validated within tenant)
- Failure handling: generation retried with backoff/jitter (cap 5), then failed
  state + operator alert; delivery retried separately against the stored artifact;
  alert if no instance produced by the 2nd of the month

## Sensitivity Handling
| Rule | This report's decision |
|---|---|
| Raw Restricted content excluded | Sections carry gap IDs, counts, severities, framework, and sensitivity levels only — no extracted PII values |
| k-anonymity floor | §3 framework breakdown suppresses any cell below 5; would-be sub-5 cells roll up to "other" |
| CSV free-text exclusion | CSV carries gap_id, severity, framework, opened_at, closed_at — no free-text document-content column |
| Distribution control for Confidential+ | Confidential report delivered only via signed expiring URL / tenant-scoped access; never an open email attachment |

## Definition Versioning
| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-07-31 | Initial definition: sections §1–§5, PDF + CSV, monthly cadence |
```

### Why this example exercises every rule

- **Operational vs. analytical**: correctly classified analytical — aggregated,
  monthly, decision-support for a compliance officer, not a per-record worklist.
- **Additivity**: §1/§2 additive (event counts), §3 semi-additive (a point-in-time
  balance read at the boundary, never summed across days), §4 non-additive (a
  ratio recomputed from additive components). Getting §3 wrong is the classic trap
  the additivity check prevents.
- **Tenant scope**: always from context; framework is the only real free
  parameter, validated against an allow-list.
- **PDF visuals**: a stated takeaway per section, decluttered charts — the report
  stands alone with no narrator (per `data-storytelling`).
- **Sensitivity**: Confidential classification, k-anonymity floor on the
  breakdown, no raw content, access-controlled delivery.
- **Reproducibility**: fixed period bounds resolved at trigger, stamped on the
  output, and a versioned definition — a re-run reproduces the instance exactly.
