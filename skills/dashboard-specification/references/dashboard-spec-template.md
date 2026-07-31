# Dashboard Specification Artifact — Template + Worked Example

Reference material for `dashboard-specification`. The full artifact template followed
by a complete worked example (the compliance officer's audit-prep dashboard). Copy the
template, fill one `## Widget` block per widget, and hand the completed artifact to the
ux-architect (`ui-component-spec`) and frontend-engineer (`react-dashboard-components`).

The artifact follows this repo's Artifact Standards: frontmatter with `name`, `version`,
`phase`, `owner`, `created`; every widget traces to an `analytics-requirements` entry;
Ubiquitous Language only.

---

## Template

```markdown
---
name: dashboard-specification
product: [product name]
dashboard: [dashboard name]
version: 1.0.0
phase: data
created: [date]
owner: data-engineer
---

# Dashboard Specification — [Dashboard Name]

## Dashboard Purpose & Mode
Audience: [persona]
Consumption: [glanced-at weekly / monitored live / reviewed before an event]
Dominant mode: [exploratory-leaning / explanatory-leaning]
  (Standing operational dashboards lean exploratory; a decision-prompting board
   leans explanatory — see SKILL.md "Exploratory vs. Explanatory".)

## Widget: [name]
Answers requirement: [analytics-requirements reference]
Mode: [exploratory (monitor) / explanatory (prompt a decision)]

### Metric Definition
Grain: [the one row this metric counts]
Unit: [count / rate / ratio / percentage]
Definition: [source Read Model + field(s), every filter, grouping, time semantics —
             reproducible enough that two engineers get the same number]

### Formula / Aggregation
```sql
[query against the pre-aggregated Read Model, or pseudocode when app logic is needed]
```

### Data Source
Read Model / table: [name]
Bounded Context: [name]
Populated by: [pipeline stage / event(s)]

### Chart Type & Emphasis Intent
Chart: [type, per references/chart-selection-guide.md — match the form to the question]
Emphasis intent: [which element the accent marks, and why — NOT the hex colour]
Accessibility: [meaning reinforced by position/label/size, not hue alone]

### Filters
[Which filters the widget honours and their default state]

### Drill-Down
[What deeper data a click reveals and its source — terminates at an auditable record]

### Refresh / Staleness Contract
| Field | Value |
|---|---|
| Source recompute cadence | |
| Client staleness tolerance | |
| Staleness indicator required | |

### Empty-State Data Condition
[Exact query condition that counts as empty — distinct from query error and from
 "pipeline never ran" (onboarding-empty)]

### Intended Takeaway   (explanatory widgets only)
[The on-screen "so what" the annotation/target-line must carry. Omit for pure
 monitoring widgets — the user derives their own takeaway by filtering.]

## Handoff Notes
- To ux-architect (`ui-component-spec`): [widget list, labels in Ubiquitous Language,
  chart types, emphasis intents, drill-down existence, staleness-indicator requirement]
- To frontend-engineer (`react-dashboard-components`): [Read Model/API contracts,
  staleness numbers, empty-state data conditions]
```

---

## Worked Example — Compliance Officer Audit-Prep Dashboard

```markdown
---
name: dashboard-specification
product: Data Estate & Compliance Platform
dashboard: Compliance Officer — Audit Prep
version: 1.0.0
phase: data
created: 2026-07-31
owner: data-engineer
---

# Dashboard Specification — Compliance Officer Audit Prep

## Dashboard Purpose & Mode
Audience: Compliance Officer preparing a SOC 2 audit walkthrough
Consumption: reviewed in the days before an audit; glanced at weekly otherwise
Dominant mode: exploratory-leaning (the officer filters by framework and
  Bounded Context on their own schedule), with two explanatory widgets that
  each prompt a specific escalation decision.

## Widget: Classification Coverage
Answers requirement: AR-04 "Do I know the sensitivity of my whole estate?"
Mode: explanatory (prompts "scale classification if coverage is falling")

### Metric Definition
Grain: one DataAsset
Unit: percentage (classified assets / total assets)
Definition: 100 * classified_assets / total_assets from asset_classification_summary,
  deleted assets excluded, as-of-now, tenant-scoped (physical isolation).

### Formula / Aggregation
```sql
SELECT CASE WHEN total_assets = 0 THEN NULL
            ELSE round(100.0 * classified_assets / total_assets, 0)
       END AS coverage_pct
  FROM asset_classification_summary
 WHERE tenant_id = $1;
```

### Data Source
Read Model / table: asset_classification_summary
Bounded Context: Data Estate
Populated by: Classification pipeline stage (DataAssetClassified / DataAssetIngested)

### Chart Type & Emphasis Intent
Chart: single number (%), with a target reference line at the 95% coverage target
Emphasis intent: the number is the accent when below target; the target line marks
  the threshold. Rationale: the officer's decision is "is coverage healthy?"
Accessibility: below-target state reinforced by a label ("below target"), not colour alone

### Filters
Bounded Context (default: all). No time filter — the metric is as-of-now.

### Drill-Down
Click the number → list of unclassified DataAssets (asset_id, connector, ingested_at)
from asset_classification_detail, filtered classified = false.

### Refresh / Staleness Contract
| Field | Value |
|---|---|
| Source recompute cadence | Every 15 min (Classification stage cadence) |
| Client staleness tolerance | 60 s |
| Staleness indicator required | Yes — "as of [time]" |

### Empty-State Data Condition
total_assets = 0 (no assets ingested yet — onboarding-empty).
Distinct from coverage_pct = 0 (assets exist, none classified — a real signal).

### Intended Takeaway
"Coverage is [X]% against a 95% target; [rising/falling] over the last 7 days."

## Widget: Open Gaps by Framework Control
Answers requirement: AR-07 "Which controls have unresolved findings?"
Mode: explanatory (prompts "escalate the top control")

### Metric Definition
Grain: one ComplianceGap
Unit: count, grouped by framework_control + severity
Definition: count of compliance_gap_summary rows where status = 'open',
  as-of-now, tenant-scoped.

### Formula / Aggregation
```sql
SELECT framework_control, severity, count(*) AS open_gap_count
  FROM compliance_gap_summary
 WHERE tenant_id = $1 AND status = 'open'
 GROUP BY framework_control, severity
 ORDER BY open_gap_count DESC;
```

### Data Source
Read Model / table: compliance_gap_summary
Bounded Context: Compliance
Populated by: Compliance Rule Engine stage (ComplianceGapOpened / ComplianceGapClosed)

### Chart Type & Emphasis Intent
Chart: horizontal bar, sorted by open_gap_count descending (long control labels;
  ranking is the point)
Emphasis intent: accent the top (most-gaps) bar — the control to escalate first
Accessibility: rank is carried by position (sorted), not colour

### Filters
Framework (SOC 2 default); severity (default: all).

### Drill-Down
Click a framework_control row → individual ComplianceGap rows (data_asset_id,
opened_at, lineage link) from compliance_gap_detail, filtered by the control.
Terminates at an auditable record with a lineage trail.

### Refresh / Staleness Contract
| Field | Value |
|---|---|
| Source recompute cadence | Every 15 min |
| Client staleness tolerance | 60 s |
| Staleness indicator required | Yes |

### Empty-State Data Condition
Zero rows where status = 'open' (good news — no open gaps).
Distinct from compliance_gap_summary being empty (no rule run yet).

### Intended Takeaway
"[Control] has the most open gaps ([N]); escalate before the walkthrough."

## Handoff Notes
- To ux-architect (`ui-component-spec`): two widgets; labels in Ubiquitous Language
  (DataAsset, ComplianceGap, framework_control, SensitivityLevel); chart types and
  emphasis intents as above; both have drill-downs; both require an as-of indicator.
- To frontend-engineer (`react-dashboard-components`): Read Models
  asset_classification_summary, asset_classification_detail, compliance_gap_summary,
  compliance_gap_detail; 60 s staleTime; empty-state conditions as stated.
```

---

## Filling-out checklist

- [ ] Frontmatter present (`name`, `version`, `phase`, `owner`, `created`).
- [ ] Dashboard mode declared (exploratory-leaning / explanatory-leaning).
- [ ] Every widget traces to an `analytics-requirements` entry.
- [ ] Every widget states grain, unit, filters, and time semantics.
- [ ] Every widget reads a pre-aggregated Read Model, not raw rows.
- [ ] Chart type matches the question (references/chart-selection-guide.md).
- [ ] Explanatory widgets carry an Intended Takeaway; monitoring widgets omit it.
- [ ] Every widget states a refresh/staleness contract (both numbers).
- [ ] Every empty-state condition is exact and distinct from error/onboarding.
- [ ] Handoff notes split cleanly between ux-architect and frontend-engineer.
```
