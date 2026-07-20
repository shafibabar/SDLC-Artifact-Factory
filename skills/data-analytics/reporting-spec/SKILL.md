---
name: reporting-spec
description: >
  Teaches how to specify scheduled and exportable reports — content specification,
  parameterization (date range, tenant, framework), output formats (CSV/PDF), report
  definition versioning, and PII/sensitivity handling in exports. Distinguishes a
  report (a point-in-time, parameterized, exportable artifact) from a dashboard (a
  live view — see `dashboard-specification`). The SOC 2 evidence report is the
  flagship example. Used by the data-engineer during Data.
version: 1.0.0
phase: data
owner: data-engineer
created: 2026-07-20
tags: [data, analytics, reporting, export, soc2, evidence, pdf, csv, versioning]
---

# Reporting Spec

## Purpose

A dashboard shows the current state and updates as it changes. A **report** is a different artifact: it is generated at a point in time, over a specific parameterized scope, in a fixed, exportable, shareable format — a snapshot, not a window. A compliance officer does not hand an auditor a link to a live dashboard; she hands them a report whose contents are frozen, versioned, and defensible as of the moment it was generated.

This skill specifies reports: their content, their parameters, their output formats, how their definitions are versioned over time, and — critically in a compliance product — how sensitive data is handled on the way out the door. It builds on `analytics-requirements` for what to include, and on `data-classification` for what must never appear in an export.

---

## Report vs. Dashboard

| | Dashboard (`dashboard-specification`) | Report (this skill) |
|---|---|---|
| Temporal nature | Live, continuously current | Point-in-time snapshot |
| Scope | Whole estate, filterable in the UI | Parameterized at generation time (date range, tenant, framework) |
| Output | Rendered in-app | Exported file (CSV, PDF) or scheduled delivery |
| Audience | Internal, ongoing monitoring | Often external (auditor) or archival |
| Versioning | N/A — always current | The report *definition* is versioned; each generated instance is immutable |

If the requirement is "I need to check this periodically," it is a dashboard. If the requirement is "I need to hand this, frozen, to someone outside the live system," it is a report.

---

## Report Content Specification

Every report definition states:

```
Report: [name]
Answers requirement: [analytics-requirements reference]

Content sections:
  [Ordered list of what the report contains, each mapped to a
   data source, same precision discipline as dashboard-specification]

Parameters:
  [What the requester can vary at generation time]

Output formats:
  [CSV, PDF, or both — and why]

Generation trigger:
  [Scheduled (cron), on-demand, or both]

Sensitivity handling:
  [What classification levels are included/excluded/redacted]

Definition version:
  [The version of this report's structure — see Versioning below]
```

---

## Parameterization

A report is generated against explicit parameters, never "whatever the current filter state happens to be" (that ambiguity is fine for a dashboard's shareable URL — a compliance evidence report must be self-describing).

| Parameter | Typical values | Notes |
|---|---|---|
| Date range | Fixed period (e.g., "Q3 2026", "2026-01-01 to 2026-03-31") | Never "last 90 days" relative to generation — an auditor rereading the report next year needs the same fixed range to reproduce it |
| Tenant | Single tenant (default — physical multi-tenancy means cross-tenant reports are not a valid parameter at all) | Reports never span tenants |
| Framework | SOC 2 / GDPR / ISO 27001, or "all frameworks in scope" | Drives which control mappings are included (`compliance-design`) |
| Severity threshold | e.g., "medium and above" | Excludes low-severity noise from an executive-facing report |

Every parameter used to generate a report instance is printed **on the report itself** — an auditor reading a PDF six months later must be able to see exactly what scope produced it without consulting the system that generated it.

---

## Output Formats

| Format | Use when | Design notes |
|---|---|---|
| **CSV** | Tabular data for further analysis, import into another tool | Flat structure; one row per record; headers use Ubiquitous Language column names, not internal field names |
| **PDF** | Formatted, presentation-quality, or externally shared (auditor, board) | Generated server-side (see `react-dashboard-components`'s export note — heavy PDF rendering stays out of the browser bundle); includes the parameter block, generation timestamp, and a definition-version footer |

A report that will be read by a human outside the product (an auditor, a board member) is PDF. A report that will be consumed by a spreadsheet or another system is CSV. Offering both from one report definition is common — the content specification is the same; only the rendering differs.

---

## The SOC 2 Evidence Report — Flagship Example

The SOC 2 evidence report is the report this product exists to make trustworthy. It compiles, for a given period and framework, the evidence that controls were operating — not just that they exist on paper (see `compliance-design`'s Compliance as Code principle: evidence must exist continuously, not be assembled at audit time).

```
Report: SOC 2 Evidence Report
Answers requirement: "I need to hand my auditor evidence that CC6 and CC7
  controls operated correctly throughout the audit period." (analytics-requirements)

Content sections:
  1. Control summary — one row per control (CC6.1, CC6.3, CC7.x, A1.x),
     with pass/fail status and evidence count, sourced from the
     compliance-design test-suite evidence log
  2. Access control evidence — authentication enforcement test results
     over the period (CC6.1), sourced from CI evidence artifacts
  3. Access removal evidence — termination-triggered access revocation
     events over the period (CC6.3), sourced from the audit log
  4. Compliance gap history — every gap opened and closed in the period,
     with lineage references (data-lineage-design) for each finding
  5. Data classification summary — sensitivity distribution at period
     start and end, to show the scope of data under evaluation

Parameters:
  Date range: fixed audit period (e.g., 2026-01-01 to 2026-06-30)
  Tenant: single tenant (the customer requesting the report)
  Framework: SOC 2 (CC6, CC7, A1 in scope)

Output formats: PDF (primary, for the auditor); CSV (the gap-history
  section only, for the customer's internal tracking)

Generation trigger: on-demand, requested by the compliance officer
  ahead of an audit window; also available as a scheduled monthly
  snapshot for continuous evidence accumulation

Sensitivity handling: report includes counts, statuses, and metadata
  only. No Restricted-level raw content appears anywhere in the
  report — data asset references appear as IDs and sensitivity levels,
  never as extracted PII values (see PII Handling below)

Definition version: 1.2 (see Versioning)
```

This report is the product's core commercial promise made concrete: it is what a customer pays for.

---

## Report Definition Versioning

A report's **definition** (what sections it contains, what each section means) changes over time as the product evolves. A **generated instance** never changes once produced — it is what was handed to the auditor and must remain exactly reproducible as evidence.

| Concept | Mutability | Example |
|---|---|---|
| Report definition | Versioned; new versions supersede old for future generation | `soc2-evidence-report` v1.2 adds the classification-summary section |
| Generated instance | Immutable once produced | The PDF handed to the auditor on 2026-07-15, stamped "generated from definition v1.1" |

Every generated report instance stamps the definition version it was produced from. This is what lets a dispute ("this report doesn't have the section the current version has") resolve cleanly: the instance is correct for the definition version active when it was generated, and the definition's changelog explains what changed since. Never regenerate an old instance against a new definition and claim it is the same report — that breaks the evidentiary chain the same way editing a registered event schema in place breaks a wire contract (`event-schema-design`).

---

## PII and Sensitivity Handling in Exports

A report leaving the system is the highest-risk moment for sensitive data — it is no longer inside the access-controlled application, and it may travel to an inbox, a laptop, or a printer. The rule inherited from `data-classification` applies without exception: **no raw Restricted-level content ever appears in a report.**

| Rule | Mechanism |
|---|---|
| Reports carry references and metadata, not raw values | Report content specs cite `sensitivity_level`, counts, and IDs — never an extracted entity's raw text |
| Aggregate-only for anything below a k-anonymity floor | A "gaps by department" breakdown with department size 1 is re-identifying; suppress or roll up cells below a defined minimum group size |
| Confidential+ content requires an explicit report-level classification | The report itself carries a classification (e.g., a SOC 2 evidence report referencing Restricted-asset counts is itself at least Confidential) and is handled per `data-classification`'s control mapping — access-controlled distribution, not open email |
| CSV exports never include free-text fields sourced from document content | Only structured, classified metadata fields are exportable; raw extracted text is not a CSV column, ever |

A report generator that queries raw `extracted_entities.raw_value` (which should not exist per `data-classification`'s "the classifier that keeps the evidence" anti-pattern) or any equivalent raw-content field is a defect regardless of what the report claims to show — the underlying storage constraint from `data-classification` and `data-retention-policy` makes this largely self-enforcing, but the report specification is where it is explicitly re-checked at the export boundary.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Report vs. dashboard distinction respected | Point-in-time, parameterized, exportable | A "report" that is actually a live filtered dashboard view |
| Parameters explicit and printed on output | Date range, tenant, framework named and stamped on the artifact | Relative/implicit scope ("last 90 days" with no fixed dates) |
| Single-tenant scope | Every report is generated for exactly one tenant | Any cross-tenant aggregation in a report |
| Format matches audience | PDF for external/human audiences; CSV for tabular/re-use | PDF generated client-side with heavy bundle cost; CSV with free-text PII columns |
| Definition versioned | Every instance stamped with the definition version it was generated from | Instances with no version reference; old instances regenerated against a new definition |
| No raw sensitive content | Reports contain references, counts, and classification levels only | Raw Restricted-level content in any export |
| k-anonymity respected | Small-group breakdowns suppressed or rolled up | Re-identifying single-record breakdowns exposed |
| Traced to a requirement | Every report references its `analytics-requirements` entry | Report built with no stated decision it serves |

---

## Anti-Patterns

- **The report that's actually a dashboard.** Calling something a "report" when it is really a live, unparameterized view rendered to PDF on demand. If two people generate it five minutes apart with different results and no explanation why, it needed fixed parameters and didn't get them.
- **Relative date ranges baked into evidence.** "Last 6 months" computed at generation time means the report is unreproducible — regenerating it next year for a dispute yields a different period. Evidence reports use fixed calendar ranges, always.
- **Silent definition drift.** Changing what a report contains without bumping the definition version, so two "SOC 2 Evidence Report" PDFs from different months are silently structurally different with no way to tell why.
- **Raw content leakage via CSV.** Adding "just one more column" to a CSV export that happens to carry extracted document text or PII, because CSV feels less risky than the UI. Export is the highest-risk exit point — it gets the same no-raw-content rule as everything else, not a lighter one.
- **k-anonymity blindness.** Breaking a report down by a dimension fine enough that a group of one is exposed (e.g., "gaps by employee" in a 3-person department), re-identifying an individual through aggregation math even though no name is printed.
- **Client-side PDF generation for compliance reports.** Shipping a multi-hundred-KB PDF library to every browser session to render an occasional audit export, when server-side generation gives better fidelity and keeps the sensitive-formatting logic in one controlled place.
- **Cross-tenant report parameters.** Allowing "all tenants" or a tenant list as a report parameter. Physical multi-tenancy means this is not a feature gap to fill later — it is structurally out of scope.

---

## Output Format

```markdown
---
name: reporting-spec
product: [product name]
report: [report name]
version: 1.0.0
phase: data
created: [date]
owner: data-engineer
---

# Reporting Spec — [Report Name]

## Content Sections
| # | Section | Data source | Precision notes |
|---|---|---|---|

## Parameters
| Parameter | Values | Printed on output? |
|---|---|---|

## Output Formats
[CSV / PDF, and why]

## Generation Trigger
[Scheduled / on-demand / both, with schedule if applicable]

## Sensitivity Handling
[Classification levels included; redaction/aggregation rules; k-anonymity floor]

## Definition Versioning
| Version | Date | Change |
|---|---|---|
```
