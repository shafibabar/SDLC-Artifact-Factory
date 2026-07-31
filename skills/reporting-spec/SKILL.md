---
name: reporting-spec
description: >
  Teaches the data-engineer to specify a report — the report layout and
  sections, parameter definitions (filters, date ranges, tenant scope), the
  source query/Read Model, scheduling and delivery (cadence, format,
  recipients), and the report specification artifact. Distinguishes an
  operational report from an analytical one. Used during the Data phase for
  recurring or on-demand reports.
version: 2.0.0
phase: data
owner: data-engineer
created: 2026-07-20
tags: [data, analytics, reporting, report-parameters, scheduling, read-model]
related: [dashboard-specification, data-storytelling, data-classification, data-model-design, analytics-requirements, compliance-design]
---

# Reporting Spec

## Purpose

A dashboard shows current state and updates as it changes. A **report** is a
different artifact: generated at a point in time, over a specific parameterized
scope, in a fixed exportable format — a snapshot, not a window. A compliance
officer does not hand an auditor a link to a live dashboard; she hands them a
report whose contents are frozen, versioned, and defensible as of the moment it
was generated.

This skill specifies a report's layout and sections, its parameters, the source
query or Read Model it draws from, its schedule and delivery, and — critically
in a compliance product — how sensitive data is handled on the way out. It builds
on `analytics-requirements` for *what* to include and `data-classification` for
what must never leave the system. Reference material lives in `references/`,
loaded only when the body points to it.

---

## Report vs. Dashboard

| | Dashboard (`dashboard-specification`) | Report (this skill) |
|---|---|---|
| Temporal nature | Live, continuously current | Point-in-time snapshot |
| Scope | Whole estate, filtered live in the UI | Parameterized at generation time |
| Output | Rendered in-app | Exported file (CSV/PDF/XLSX) or scheduled delivery |
| Audience | Internal, ongoing monitoring | Often external (auditor) or archival |
| Versioning | N/A — always current | Definition is versioned; each instance is immutable |

If the requirement is "I need to check this periodically," it is a dashboard. If
it is "I need to hand this, frozen, to someone outside the live system," it is a
report.

---

## Operational vs. Analytical Report

Two report kinds serve two different jobs. Classify a report before specifying
it — the choice drives grain, cadence, format, and audience.

| | Operational report | Analytical report |
|---|---|---|
| Purpose | Run the business day-to-day: what needs action now | Decision support: trends, distributions, "how are we doing" |
| Grain | Fine — one row per event/record (e.g. one row per failed ingestion) | Aggregated — counts, rates, distributions over a period |
| Cadence | Frequent (hourly/daily), often on-demand | Periodic (weekly/monthly/quarterly) |
| Typical audience | Operators, on-call, tenant admins | Compliance officers, executives, auditors |
| Typical format | CSV (feed a spreadsheet or ticket queue) | PDF (formatted, narrated, external) |
| Example | Daily "documents that failed classification" list | Monthly compliance-gap trend report |

An operational report is a worklist; an analytical report is evidence or a
briefing. The SOC 2 evidence report is analytical; a "PII-scan errors since
yesterday" export is operational. When a request mixes both, split it into two
definitions — one worklist, one summary — rather than one report that serves
neither audience well.

---

## Report Specification Fields

Every report definition states these fields. The full artifact template and a
worked monthly compliance-gap example are in
`references/report-spec-template.md`.

- **Name & requirement** — report name and the `analytics-requirements` entry it
  answers. A report with no stated decision it serves is a defect.
- **Kind** — operational or analytical (per the table above).
- **Sections** — ordered list of what the report contains, each mapped to a data
  source with `dashboard-specification`'s precision discipline, plus a stated
  takeaway per section for analytical reports (see PDF Visuals).
- **Parameters** — what the requester varies at generation time; types, safe
  binding, scoping rules → `references/report-parameters-and-sourcing.md`.
- **Source** — the Read Model, mart, or query each section draws from and its
  aggregation grain → `references/report-parameters-and-sourcing.md`.
- **Schedule** — scheduled (cron), on-demand, or both; cadence, delivery
  channels, failure handling → `references/scheduling-and-delivery.md`.
- **Format & recipients** — CSV / PDF / XLSX, and who receives it through which channel.
- **Sensitivity handling** — classification levels, redaction/aggregation, k-anonymity floor.
- **Definition version** — the version of this report's structure (see below).

---

## Parameterization — Scoping Rules

A report is generated against explicit parameters, never "whatever the current
filter state happens to be." Every parameter used is printed **on the report
itself** — an auditor rereading a PDF next year must see exactly what scope
produced it without consulting the system.

Two non-negotiable scoping rules:

- **Tenant scope always comes from the authenticated session context — never a
  client-supplied parameter.** Physical multi-tenancy means a cross-tenant or
  arbitrary-tenant report is not a feature gap to fill later; it is structurally
  out of scope. A tenant value accepted from the request body or query string is
  a defect even if it happens to match the caller's tenant.
- **Date ranges are fixed calendar periods, never relative-to-generation.** "Q3
  2026" or "2026-01-01 to 2026-03-31," never "last 90 days" — an auditor
  regenerating the report must get the identical period.

Parameter types, safe binding to the source query (parameterized via `pgx`,
never string-interpolated), and the tenant-from-context enforcement pattern are
in `references/report-parameters-and-sourcing.md`.

---

## Output Formats and Delivery

| Format | Use when |
|---|---|
| **CSV** | Tabular data for re-analysis or import; one row per record; Ubiquitous Language column headers |
| **PDF** | Formatted, external, human-read (auditor, board); server-side rendered; carries the parameter block and definition-version footer |
| **XLSX** | Multi-section tabular delivery where a spreadsheet consumer wants tabs/formatting CSV cannot carry |

Format follows audience: PDF for humans outside the product, CSV/XLSX for a
spreadsheet or system. One definition may emit several formats — same content
spec, different rendering. Cadence, delivery channels, large-report
pagination/streaming, and retry-on-failure are in
`references/scheduling-and-delivery.md`.

### PDF Visuals

A PDF report gets no spoken narration; it must stand alone. Apply
`data-storytelling`'s decluttering and emphasis rules to any chart: strip
gridlines, borders, and redundant legends; keep a muted base with one deliberate
accent color on the data that carries the point; and state an **explicit takeaway
per section**. A report section with a chart and no stated "so what" is
incomplete.

---

## Report-as-Snapshot and Additivity

The report/dashboard distinction is exactly Kimball's **periodic snapshot**
concept: a report freezes a metric as of its parameterized period, which makes
additivity a live hazard. Before any report section sums a metric across the
date-range parameter, classify how that metric aggregates over time — some
figures (an end-of-period balance, a point-in-time count) cannot be summed
across periods without producing a meaningless total. The classification and the
per-section additivity check are in `references/report-parameters-and-sourcing.md`.

---

## Definition Versioning

A report's **definition** (its sections and their meaning) is versioned and
evolves over time; a **generated instance** is immutable once produced, stamps
the definition version it was generated from, and must remain exactly
reproducible as evidence. Never regenerate an old instance against a new
definition and call it the same report — that breaks the evidentiary chain the
same way editing a registered event schema in place breaks a wire contract
(`event-schema-design`).

---

## Sensitivity Handling in Exports

A report leaving the system is the highest-risk moment for sensitive data. The
rule inherited from `data-classification` applies without exception: **no raw
Restricted-level content ever appears in a report.** Reports carry references,
counts, IDs, and classification levels — never an extracted entity's raw text.
Small-group breakdowns are suppressed or rolled up below a k-anonymity floor (a
"gaps by department" cell of size 1 re-identifies an individual), and CSV exports
never carry free-text fields sourced from document content. Full export-boundary
rules are in `references/report-spec-template.md`'s sensitivity section.

---

## Quality Criteria

| Criterion | Pass | Fail |
|---|---|---|
| Report vs. dashboard respected | Point-in-time, parameterized, exportable | A "report" that is a live filtered view |
| Operational vs. analytical classified | Kind stated; grain and cadence match it | Worklist and trend summary mashed into one |
| Parameters explicit and printed | Range, tenant, framework stamped on the artifact | Relative/implicit scope ("last 90 days") |
| Tenant from context, bound safely | Tenant from session; params bound via `pgx` | Tenant a request param; values concatenated into SQL |
| Additivity checked | Cross-period sums verified additive | Point-in-time balance silently summed across periods |
| Format matches audience | PDF external/human; CSV/XLSX tabular | Client-side PDF; CSV with free-text PII |
| Definition versioned | Each instance stamped with its definition version | No version; old instances regenerated anew |
| No raw sensitive content | References, counts, levels only | Raw Restricted content in any export |

---

## Anti-Patterns

- **The report that's actually a dashboard.** A live, unparameterized view
  rendered to PDF on demand — two people generate it five minutes apart and get
  different results with no explanation.
- **Client-supplied tenant scope.** Accepting a tenant id from the request under
  physical multi-tenancy. Tenant is a context fact, not a parameter.
- **Relative date ranges baked into evidence.** "Last 6 months" computed at
  generation time makes the report unreproducible.
- **Silent additivity error.** Summing a point-in-time balance across the
  report's periods and printing a meaningless total.
- **String-built SQL from a parameter.** Interpolating a filter value into the
  query instead of binding it — an injection vector at the export boundary.
- **Raw content leakage via CSV.** Adding "just one more column" that carries
  extracted document text, because CSV feels less risky than the UI.

---

## Output Format

The full report specification artifact template — frontmatter, sections table,
parameters table, source/grain, schedule, format/recipients, sensitivity, and
versioning — plus a complete worked monthly compliance-gap report example, is in
`references/report-spec-template.md`. Copy and fill it when producing a report
specification.
